# تشغيل واجهة CourseManagement.Web

## الهيكل الصحيح للمشروع

أصبح الحل الآن مقسمًا إلى مشاريع مستقلة مثل الهيكل المطلوب:

```text
CourseManagement.API.slnx
├── CourseManagement.API             # REST API وJWT وSwagger فقط
├── CourseManagement.Application     # منطق التطبيق وواجهات الخدمات
├── CourseManagement.Domain          # الكيانات وقواعد المجال
├── CourseManagement.Infrastructure  # EF Core وSQLite والمستودعات والخدمات
├── CourseManagement.Tests           # اختبارات xUnit
└── CourseManagement.Web             # مشروع ASP.NET Core MVC وواجهة الموقع
```

مشروع الويب المستقل موجود هنا:

```text
CourseManagement.Web/
├── CourseManagement.Web.csproj
├── Program.cs
├── Controllers/
├── ViewModels/
├── Views/
└── wwwroot/
```

أما API فأصبح مستقلًا ولا يحتوي على Controllers أو Views الخاصة بواجهة MVC.

## التشغيل في Visual Studio

افتح ملف الحل الموجود في الجذر:

```text
CourseManagement.API.slnx
```

من **Solution Explorer** ستجد مشروعًا مستقلًا باسم:

```text
CourseManagement.Web
```

اضغط عليه بزر الفأرة الأيمن واختر **Set as Startup Project**، ثم شغّله باستخدام Profile باسم `https` أو اضغط `Ctrl + F5`.

بعد التشغيل افتح:

```text
https://localhost:7026/Account/Login
```

## التشغيل من Terminal

افتح Terminal داخل مجلد الحل الذي يحتوي على `CourseManagement.API.slnx`، ثم نفّذ:

```powershell
dotnet restore

dotnet user-secrets init --project CourseManagement.Web/CourseManagement.Web.csproj
dotnet user-secrets set "JwtSettings:Secret" "CourseManagement-local-development-secret-2026" --project CourseManagement.Web/CourseManagement.Web.csproj

dotnet run --project CourseManagement.Web/CourseManagement.Web.csproj --launch-profile https
```

سيستخدم Web قاعدة SQLite الموجودة في:

```text
coursemanagement.db
```

ويمكن تفعيل تطبيق الـMigrations أثناء التطوير عبر متغير البيئة:

```powershell
$env:Database__ApplyMigrations="true"
```

في أول تشغيل قد يظهر تحذير شهادة HTTPS محلية؛ اختر **Advanced** ثم **Continue to localhost**.

## التشغيل بنقرة واحدة في Windows

من مجلد الحل، انقر مرتين على:

```text
run-mvc.bat
```

الملف يشغّل المشروع التالي مباشرةً:

```text
CourseManagement.Web/CourseManagement.Web.csproj
```

وسيطلب مفتاح JWT مؤقتًا ثم يفتح واجهة MVC على منفذ HTTPS.

## أهم صفحات الواجهة

| الصفحة | الرابط |
|---|---|
| تسجيل الدخول | `/Account/Login` |
| إنشاء حساب | `/Account/Register` |
| لوحة التحكم | `/` |
| الكورسات | `/Courses/Index` |
| تفاصيل كورس | `/Courses/Details/{id}` |
| تسجيلاتي | `/Enrollments/Index` |
| إدارة المستخدمين | `/Admin/Users` |
| إدارة التسجيلات | `/Admin/Enrollments` |
| فحص الصحة | `/health` |

صفحات الإدارة تحتاج حسابًا بدور `Admin`. لا تفتح ملفات `.cshtml` بالنقر المزدوج؛ هذه Razor Views تُعرض فقط من خلال تشغيل مشروع `CourseManagement.Web`.
