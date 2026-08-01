using CourseManagement.API.Middleware;
using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Infrastructure.Data;
using CourseManagement.Infrastructure.Repositories;
using CourseManagement.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// ─── قاعدة البيانات SQL Server ─────────────────────────────────────────────
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// ─── تسجيل الـ Repositories والـ Services ──────────────────────────────────
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<ICourseRepository, CourseRepository>();
builder.Services.AddScoped<IEnrollmentRepository, EnrollmentRepository>();

builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ICourseService, CourseService>();
builder.Services.AddScoped<IEnrollmentService, EnrollmentService>();
builder.Services.AddScoped<IUserService, UserService>();

// ─── JWT Authentication ───────────────────────────────────────────────────
var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var secretKey = jwtSettings["Secret"];

if (string.IsNullOrWhiteSpace(secretKey))
    throw new InvalidOperationException(
        "JwtSettings:Secret is missing. Set it via user-secrets, environment variable (JwtSettings__Secret), or appsettings.Development.json — never commit a real secret to source control.");

if (secretKey.Length < 32)
    throw new InvalidOperationException("JwtSettings:Secret must be at least 32 characters long for HMAC-SHA256.");

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtSettings["Issuer"],
            ValidAudience = jwtSettings["Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey))
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// ─── CORS (كان مفقوداً تماماً — أي واجهة أمامية كانت ستفشل) ─────────────────
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (allowedOrigins.Length == 0 || allowedOrigins.Contains("*"))
            policy.AllowAnyOrigin();
        else
            policy.WithOrigins(allowedOrigins);

        policy.AllowAnyHeader().AllowAnyMethod();
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

// ─── تهيئة قاعدة البيانات: الترحيلات + بذر حساب الـ Admin ───────────────────
// (كان Migrate داخل شرط Development فقط — فبيئة الإنتاج لا تُرحَّل أبداً!)
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await db.Database.MigrateAsync();
    await DbSeeder.SeedAsync(db, app.Configuration, app.Logger);
}

if (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled"))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
