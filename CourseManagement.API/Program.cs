using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Application.Options;
using CourseManagement.Infrastructure.Data;
using CourseManagement.Infrastructure.Repositories;
using CourseManagement.Infrastructure.Services;
using CourseManagement.API.Middleware;
using CourseManagement.API.Security;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using System.Globalization;
using System.Net;
using System.Text;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<ICourseRepository, CourseRepository>();
builder.Services.AddScoped<IEnrollmentRepository, EnrollmentRepository>();
builder.Services.AddScoped<ICourseAssetRepository, CourseAssetRepository>();
builder.Services.AddScoped<IUnitOfWork, EfUnitOfWork>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ICourseService, CourseService>();
builder.Services.AddScoped<IEnrollmentService, EnrollmentService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<ICourseAssetService, CourseAssetService>();
builder.Services.AddSingleton<IFileStorage, LocalFileStorage>();

var fileUploadSection = builder.Configuration.GetSection("FileUploads");
var fileUploadOptions = fileUploadSection.Get<FileUploadOptions>() ?? new FileUploadOptions();
if (fileUploadOptions.MaxVideoBytes < 1 ||
    fileUploadOptions.MaxAttachmentBytes < 1 ||
    fileUploadOptions.MaxCoverImageBytes < 1)
{
    throw new InvalidOperationException("All FileUploads size limits must be greater than zero.");
}

var maxConfiguredUploadBytes = Math.Max(
    fileUploadOptions.MaxVideoBytes,
    Math.Max(fileUploadOptions.MaxAttachmentBytes, fileUploadOptions.MaxCoverImageBytes));
var multipartBodyLengthLimit = checked(maxConfiguredUploadBytes + (1L * 1024 * 1024));

builder.Services.Configure<FileUploadOptions>(fileUploadSection);
builder.Services.Configure<FormOptions>(options =>
    options.MultipartBodyLengthLimit = multipartBodyLengthLimit);
builder.WebHost.ConfigureKestrel(options =>
    options.Limits.MaxRequestBodySize = multipartBodyLengthLimit);
builder.Services.AddScoped<JwtSecurityStampEvents>();

var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var secretKey = jwtSettings["Secret"];
if (string.IsNullOrWhiteSpace(secretKey))
    throw new InvalidOperationException(
        "JwtSettings:Secret is missing. Set it via user-secrets or environment variable (JwtSettings__Secret); never commit it to source control.");

if (secretKey.Length < 32)
    throw new InvalidOperationException("JwtSettings:Secret must be at least 32 characters long for HMAC-SHA256.");

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.EventsType = typeof(JwtSecurityStampEvents);
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtSettings["Issuer"],
            ValidAudience = jwtSettings["Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });

builder.Services.AddAuthorization();

var authRateLimiting = builder.Configuration.GetSection("RateLimiting:Auth");
var authPermitLimit = authRateLimiting.GetValue<int?>("PermitLimit") ?? 10;
var authWindowSeconds = authRateLimiting.GetValue<int?>("WindowSeconds") ?? 60;
if (authPermitLimit < 1)
    throw new InvalidOperationException("RateLimiting:Auth:PermitLimit must be at least 1.");
if (authWindowSeconds < 1)
    throw new InvalidOperationException("RateLimiting:Auth:WindowSeconds must be at least 1.");

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (context, cancellationToken) =>
    {
        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
        {
            var seconds = Math.Max(1, (int)Math.Ceiling(retryAfter.TotalSeconds));
            context.HttpContext.Response.Headers.RetryAfter = seconds.ToString(CultureInfo.InvariantCulture);
        }

        var problem = new ProblemDetails
        {
            Status = StatusCodes.Status429TooManyRequests,
            Title = "Too many requests",
            Detail = "Too many authentication attempts. Please wait before trying again.",
            Instance = context.HttpContext.Request.Path
        };
        problem.Extensions["traceId"] = context.HttpContext.TraceIdentifier;

        await context.HttpContext.Response.WriteAsJsonAsync(
            problem,
            options: null,
            contentType: "application/problem+json",
            cancellationToken: cancellationToken);
    };

    options.AddPolicy("auth", httpContext => RateLimitPartition.GetFixedWindowLimiter(
        httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = authPermitLimit,
            Window = TimeSpan.FromSeconds(authWindowSeconds),
            QueueLimit = 0,
            AutoReplenishment = true
        }));
});

builder.Services.AddControllers();
builder.Services.AddHealthChecks();
builder.Services.AddEndpointsApiExplorer();

var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
var allowDevelopmentLoopback = builder.Environment.IsDevelopment() && allowedOrigins.Length == 0;
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (allowDevelopmentLoopback)
        {
            policy.SetIsOriginAllowed(origin =>
            {
                if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri))
                    return false;
                if (uri.Scheme is not ("http" or "https"))
                    return false;

                return string.Equals(uri.Host, "localhost", StringComparison.OrdinalIgnoreCase) ||
                       IPAddress.TryParse(uri.Host, out var address) && IPAddress.IsLoopback(address);
            }).AllowAnyHeader().AllowAnyMethod();
            return;
        }

        if (allowedOrigins.Length == 0 || allowedOrigins.Any(string.IsNullOrWhiteSpace) || allowedOrigins.Contains("*"))
            policy.SetIsOriginAllowed(_ => false);
        else
            policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod();
    });
});

builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Course Management API",
        Version = "v1",
        Description = "API لإدارة الكورسات والتسجيلات — المصادقة عبر JWT Bearer."
    });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "الصق التوكن (JWT) فقط هنا — بدون البادئة 'Bearer '.",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT"
    });
    c.AddSecurityRequirement(doc => new OpenApiSecurityRequirement
    {
        { new OpenApiSecuritySchemeReference("Bearer", doc), new List<string>() }
    });
});

var app = builder.Build();

app.UseMiddleware<TraceIdentifierMiddleware>();
app.UseMiddleware<ExceptionHandlingMiddleware>();

var applyMigrations = app.Configuration.GetValue<bool>("Database:ApplyMigrations");
var seedAdmin = app.Configuration.GetValue<bool>("SeedAdmin:Enabled");
if (applyMigrations || seedAdmin)
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

    if (applyMigrations)
        await db.Database.MigrateAsync();

    if (seedAdmin)
        await DbSeeder.SeedAsync(db, app.Configuration, app.Logger);
}

if (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled"))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Keep loopback HTTP usable during local Flutter Web development. Browsers otherwise
// follow the HTTPS redirect and can reject the self-signed development certificate.
if (!app.Environment.IsDevelopment())
    app.UseHttpsRedirection();

app.UseRouting();
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health");

app.Run();

public partial class Program;