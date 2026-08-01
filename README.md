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

- الترحيلات (Migrations) تُطبَّق تلقائياً عند الإقلاع.
- في بيئة التطوير يُبذر حساب Admin أولي تلقائياً (من قسم `SeedAdmin` في `appsettings.Development.json`):
  - **Email:** `admin@coursemanagement.local`
  - **Password:** `Admin@12345` — ⚠️ غيّره فور أول تسجيل دخول.
- Swagger UI متاح في التطوير على `/swagger` (ويمكن تفعيله في أي بيئة عبر `Swagger:Enabled = true`).

## الإعدادات والأسرار

- `JwtSettings:Secret` **غير مخزّن** في `appsettings.json` عمداً. ضعه في:
  - `appsettings.Development.json` (موجود للتطوير)، أو
  - User Secrets: `dotnet user-secrets set "JwtSettings:Secret" "<64+ chars>"`، أو
  - متغير بيئة: `JwtSettings__Secret`.
- التطبيق يرفض الإقلاع إذا كان السر مفقوداً أو أقصر من 32 حرفاً.
- `Cors:AllowedOrigins`: حدد نطاقات الواجهة الأمامية في الإنتاج (فارغة/`*` = السماح للجميع، للتطوير فقط).

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
