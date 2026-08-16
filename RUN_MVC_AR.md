# تشغيل واجهة MVC العربية

## سبب عدم ظهور الواجهة في المجلد الجذر

المجلد الذي يحتوي على `CourseManagement.API.slnx` هو مجلد الحل، وليس صفحة ويب. واجهة MVC موجودة داخل مشروع الويب:

```text
CourseManagement.API/
└── CourseManagement.API/
    ├── CourseManagement.API.csproj
    ├── Program.cs
    ├── Mvc/Controllers/
    └── Views/
```

ملفات الواجهة موجودة داخل:

```text
CourseManagement.API/Views/
```

وهي Razor Views تُعرض داخل المتصفح بعد تشغيل مشروع `CourseManagement.API`، وليست ملفات HTML تُفتح بالنقر المزدوج من File Explorer.

## التشغيل في Windows

ثبّت .NET 10 SDK، ثم افتح Terminal داخل المجلد الذي يحتوي على `CourseManagement.API.slnx` ونفّذ:

```powershell
dotnet restore

dotnet user-secrets init --project CourseManagement.API/CourseManagement.API.csproj
dotnet user-secrets set "JwtSettings:Secret" "ضع-مفتاحًا-عشوائيًا-طويلًا-هنا-لا-يقل-عن-32-حرفًا" --project CourseManagement.API/CourseManagement.API.csproj

dotnet run --project CourseManagement.API/CourseManagement.API.csproj --launch-profile https
```

بعد ظهور رسالة التشغيل، افتح:

```text
https://localhost:7026/Account/Login
```

يمكن أيضًا فتح الصفحة الرئيسية:

```text
https://localhost:7026/
```

إذا ظهر تحذير شهادة HTTPS في أول تشغيل، اختر Advanced ثم Continue to localhost؛ هذه شهادة تطوير محلية وليست شهادة إنتاج.

## تشغيل بنقرة واحدة

من مجلد الحل، انقر مرتين على:

```text
run-mvc.bat
```

سيطلب منك الملف مفتاح JWT مؤقتًا، ثم يشغل مشروع MVC مع SQLite ويطبّق Migrations. لا تضع مفتاحًا حقيقيًا داخل ملفات المشروع أو GitHub.

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

صفحات الإدارة تحتاج حسابًا يملك دور `Admin`. أما الصفحات العامة مثل تسجيل الدخول والتسجيل والكورسات فتُفتح من خلال الرابط بعد تشغيل التطبيق.
