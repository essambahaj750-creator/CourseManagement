using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Infrastructure.Data;
using CourseManagement.Infrastructure.Repositories;
using CourseManagement.Infrastructure.Services;
using CourseManagement.Web.Middleware;
using CourseManagement.Web.Security;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<ICourseRepository, CourseRepository>();
builder.Services.AddScoped<IEnrollmentRepository, EnrollmentRepository>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ICourseService, CourseService>();
builder.Services.AddScoped<IEnrollmentService, EnrollmentService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<MvcCookieSecurityEvents>();

var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var secretKey = jwtSettings["Secret"];
if (string.IsNullOrWhiteSpace(secretKey))
    throw new InvalidOperationException(
        "JwtSettings:Secret is missing. Set it via user-secrets or environment variable (JwtSettings__Secret); never commit it to source control.");

if (secretKey.Length < 32)
    throw new InvalidOperationException("JwtSettings:Secret must be at least 32 characters long for HMAC-SHA256.");

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
