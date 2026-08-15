using CourseManagement.API.Middleware;
using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Infrastructure.Data;
using CourseManagement.Infrastructure.Repositories;
using CourseManagement.Infrastructure.Services;
using CourseManagement.API.Mvc.Security;
using CourseManagement.API.Security;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using System.Text;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

// ─── قاعدة البيانات SQLite ─────────────────────────────────────────────────
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection")));

// ─── تسجيل الـ Repositories والـ Services ──────────────────────────────────
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<ICourseRepository, CourseRepository>();
builder.Services.AddScoped<IEnrollmentRepository, EnrollmentRepository>();

builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ICourseService, CourseService>();
builder.Services.AddScoped<IEnrollmentService, EnrollmentService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<JwtSecurityStampEvents>();
builder.Services.AddScoped<MvcCookieSecurityEvents>();

// ─── JWT Authentication ───────────────────────────────────────────────────
var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var secretKey = jwtSettings["Secret"];
const string SmartAuthenticationScheme = "SmartAuthentication";

if (string.IsNullOrWhiteSpace(secretKey))
    throw new InvalidOperationException(
        "JwtSettings:Secret is missing. Set it via user-secrets or environment variable (JwtSettings__Secret); never commit it to source control.");

if (secretKey.Length < 32)
    throw new InvalidOperationException("JwtSettings:Secret must be at least 32 characters long for HMAC-SHA256.");

builder.Services.AddAuthentication(options =>
    {
        // يختار JWT لمسارات /api وCookie لواجهة MVC، حتى تظهر هوية المستخدم في Dashboard أيضًا.
        options.DefaultAuthenticateScheme = SmartAuthenticationScheme;
        options.DefaultChallengeScheme = SmartAuthenticationScheme;
    })
    .AddPolicyScheme(SmartAuthenticationScheme, "Smart authentication", options =>
    {
        options.ForwardDefaultSelector = context =>
            context.Request.Path.StartsWithSegments("/api")
                ? JwtBearerDefaults.AuthenticationScheme
                : MvcAuthenticationDefaults.Scheme;
    })
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
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("auth", httpContext => RateLimitPartition.GetFixedWindowLimiter(
        httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 10,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0,
            AutoReplenishment = true
        }));
});
builder.Services.AddControllersWithViews();
builder.Services.AddHealthChecks();
builder.Services.AddEndpointsApiExplorer();

// ─── CORS (كان مفقوداً تماماً — أي واجهة أمامية كانت ستفشل) ─────────────────
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (allowedOrigins.Length == 0 || allowedOrigins.Any(string.IsNullOrWhiteSpace) || allowedOrigins.Contains("*"))
            policy.SetIsOriginAllowed(_ => false);
        else
            policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod();
    });
});

// ─── Swagger ───────────────────────────────────────────────────────────────
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Course Management API",
        Version = "v1",
        Description = "API لإدارة الكورسات والتسجيلات — المصادقة عبر JWT Bearer."
    });

    // النمط الصحيح: Http + bearer — المستخدم يلصق التوكن فقط بدون كلمة "Bearer"
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

// ─── معالجة الأخطاء المركزية — أول الأنبوب دائماً ──────────────────────────
app.UseMiddleware<ExceptionHandlingMiddleware>();

// ─── تهيئة قاعدة البيانات اختيارياً ─────────────────────────────────────────
// لا تُطبّق الترحيلات تلقائياً في الإنتاج إلا بعد تفعيل الخيار صراحةً.
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

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllerRoute(
    name: "mvc",
    pattern: "{controller=Home}/{action=Index}/{id?}");
app.MapControllers();
app.MapHealthChecks("/health");

app.Run();
