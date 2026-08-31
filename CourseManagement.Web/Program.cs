using CourseManagement.Application.Interfaces;
using CourseManagement.Application.Options;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Infrastructure.Data;
using CourseManagement.Infrastructure.Repositories;
using CourseManagement.Infrastructure.Services;
using CourseManagement.Web.Middleware;
using CourseManagement.Web.Security;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Globalization;
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
builder.Services.AddScoped<MvcCookieSecurityEvents>();

builder.Services.AddAuthentication(options =>
    {
        options.DefaultAuthenticateScheme = MvcAuthenticationDefaults.Scheme;
        options.DefaultChallengeScheme = MvcAuthenticationDefaults.Scheme;
    })
    .AddCookie(MvcAuthenticationDefaults.Scheme, options =>
    {
        options.EventsType = typeof(MvcCookieSecurityEvents);
        options.Cookie.Name = MvcAuthenticationDefaults.CookieName;
        options.Cookie.HttpOnly = true;
        options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.LoginPath = "/Account/Login";
        options.AccessDeniedPath = "/Account/AccessDenied";
        options.SlidingExpiration = true;
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
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

        if (!context.HttpContext.Response.HasStarted)
        {
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
        }
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

builder.Services.AddControllersWithViews();
builder.Services.AddHealthChecks();

var app = builder.Build();

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

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");
app.MapHealthChecks("/health");

app.Run();

public partial class Program;