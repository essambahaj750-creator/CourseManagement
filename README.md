# Course Management API

Web API لإدارة الكورسات والتسجيلات، مبني بمعمارية Clean Architecture على **.NET 10** مع **EF Core + SQL Server** و **JWT Authentication**.

## المعمارية

| المشروع | المسؤولية |
|---|---|
| `CourseManagement.Domain` | الكيانات (User, Course, Enrollment) والـ Enums وواجهات المستودعات |
| `CourseManagement.Application` | DTOs وواجهات الخدمات — لا يعتمد إلا على Domain |
| `CourseManagement.Infrastructure` | EF Core DbContext والمستودعات والخدمات (تطبيق الواجهات) |
| `CourseManagement.API` | Controllers و Middleware ونقطة التشغيل |

## التشغيل

```bash
dotnet run --project CourseManagement.API
```

- الترحيلات لا تُطبَّق تلقائياً في الإنتاج. تُفعّل في التطوير عبر `Database:ApplyMigrations = true`، أو تُطبّق يدويًا من خط النشر.
- إنشاء Admin الأولي معطل افتراضيًا. فعّله صراحةً بعد وضع بياناته في User Secrets أو متغيرات البيئة.
- Swagger UI متاح في التطوير على `/swagger`، ويمكن تفعيله في بيئة أخرى عبر `Swagger:Enabled = true` بعد تقييد الوصول إليه.

## الإعدادات والأسرار

- `JwtSettings:Secret` غير مخزّن في أي ملف إعدادات. التطبيق يرفض الإقلاع إذا كان مفقودًا أو أقصر من 32 حرفًا.
- لإعداد التطوير باستخدام User Secrets:

```bash
dotnet user-secrets set "JwtSettings:Secret" "ضع-سرًا-عشوائيًا-طويلًا-هنا" --project CourseManagement.API
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "سلسلة-الاتصال" --project CourseManagement.API
dotnet user-secrets set "Cors:AllowedOrigins:0" "https://localhost:5173" --project CourseManagement.API
```

- لتفعيل Admin الأولي، ضع القيم التالية خارج Git:

```bash
dotnet user-secrets set "SeedAdmin:Enabled" "true" --project CourseManagement.API
dotnet user-secrets set "SeedAdmin:FullName" "System Administrator" --project CourseManagement.API
dotnet user-secrets set "SeedAdmin:Email" "admin@example.com" --project CourseManagement.API
dotnet user-secrets set "SeedAdmin:Password" "كلمة-مرور-قوية-وفريدة" --project CourseManagement.API
```

- `Cors:AllowedOrigins` قائمة صريحة؛ إذا كانت فارغة أو تحتوي `*` فسيتم رفض CORS بدل فتحه للجميع.

## الأدوار وتدفق الصلاحيات

- التسجيل العام (`POST /api/auth/register`) ينشئ **Student دائماً** — لا يمكن لأحد تسجيل نفسه Admin.
- الـ **Admin** يرقّي المستخدمين إلى Instructor عبر `PUT /api/users/{id}/role`.
- الـ **Instructor** يدير كورساته هو فقط؛ الـ Admin يتجاوز قيد الملكية.

## أهم النقاط (Endpoints)

| Method | المسار | الصلاحية |
|---|---|---|
| POST | `/api/auth/register` | عام |
| POST | `/api/auth/login` | عام |
| GET | `/api/course` , `/api/course/{id}` , `/api/course/instructor/{id}` | عام |
| POST / PUT / DELETE | `/api/course` , `/api/course/{id}` | Instructor (مالك الكورس) أو Admin |
| POST | `/api/enrollment` | مستخدم مسجّل دخول |
| GET | `/api/enrollment/my` | مستخدم مسجّل دخول |
| GET | `/api/enrollment/{id}` , `/api/enrollment/user/{userId}` | صاحبها أو Admin |
| GET | `/api/enrollment/course/{courseId}` | مدرب الكورس أو Admin |
| DELETE | `/api/enrollment/course/{courseId}` | صاحب التسجيل |
| GET | `/api/users` | Admin |
| GET / PUT | `/api/users/me` | مستخدم مسجّل دخول |
| PUT | `/api/users/{id}/role` | Admin |
| DELETE | `/api/users/{id}` | Admin |

## معالجة الأخطاء

Middleware مركزي يحوّل استثناءات منطق الأعمال إلى رموز HTTP صحيحة:
`404` غير موجود · `403` ممنوع (ملكية) · `401` غير مصادَق · `409` تعارض (تكرار/قواعد عمل) · `400` فشل التحقق من المدخلات · `500` خطأ غير متوقع (بدون تسريب التفاصيل).

ملف `CourseManagement.API/CourseManagement.API.http` يحتوي طلبات جاهزة لتجربة التدفق كاملاً.

## واجهة ASP.NET Core MVC

تمت إضافة واجهة MVC عربية متجاوبة داخل مشروع `CourseManagement.API`. تبدأ الواجهة من المسار `/`، وتستخدم Cookie آمنًا لجلسة Razor MVC، بينما تبقى مسارات `/api/*` معتمدة على JWT Bearer.

### أهم المسارات

- `/` لوحة التحكم الرئيسية.
- `/Account/Login` تسجيل الدخول.
- `/Account/Register` إنشاء حساب.
- `/Account/ChangePassword` تغيير كلمة المرور وإبطال الجلسة الحالية.
- `/Courses` قائمة الكورسات وعمليات CRUD حسب الدور.
- `/Enrollments` تسجيلات المستخدم الحالي.
- `/Admin/Users` إدارة المستخدمين للمشرف.
- `/Admin/Enrollments` إدارة التسجيلات للمشرف.

### تطبيق ترحيل صورة الكورس

بعد تثبيت .NET SDK وتشغيل SQL Server، نفّذ:

```bash
dotnet restore
dotnet ef database update --project CourseManagement.Infrastructure --startup-project CourseManagement.API
dotnet run --project CourseManagement.API
```

تأكد من وضع `JwtSettings:Secret` وسلسلة الاتصال في User Secrets أو متغيرات البيئة، وعدم تخزين الأسرار الحقيقية داخل Git.

## الاختبارات وCI

```bash
dotnet build CourseManagement.API.slnx --configuration Release
dotnet test CourseManagement.API.slnx --configuration Release
```

يحتوي الحل على مشروع `CourseManagement.Tests` لاختبارات السلوك الأمني والتحقق من نماذج MVC. كما ينفذ GitHub Actions ملف `.github/workflows/ci.yml` تلقائيًا عند Push وPull Request.

## تشغيل الترحيلات بأمان

في التطوير يمكن استخدام `Database:ApplyMigrations=true`. في الإنتاج يفضّل تنفيذ الترحيل من خطوة نشر منفصلة ثم تشغيل التطبيق مع `Database:ApplyMigrations=false`:

```bash
dotnet ef database update --project CourseManagement.Infrastructure --startup-project CourseManagement.API --configuration Release
```
