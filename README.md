# منصة المعرفة — Course Management

منصة تعليمية متكاملة لإدارة الكورسات والتسجيلات والمحتوى، مبنية على **.NET 10 + EF Core + SQLite** مع عميل **Flutter** متجاوب للويب والموبايل.

## مكونات المشروع

| المشروع | الوظيفة |
|---|---|
| `CourseManagement.Domain` | الكيانات وEnums وعقود المستودعات |
| `CourseManagement.Application` | DTOs وواجهات الخدمات وقواعد التطبيق |
| `CourseManagement.Infrastructure` | EF Core والمستودعات والخدمات والتخزين |
| `CourseManagement.API` | REST API + JWT + CORS + Rate limiting + Swagger + Health Check |
| `CourseManagement.Web` | ASP.NET Core MVC + Cookie Authentication |
| `CourseManagement.Flutter` | Flutter RTL: Guest / Student / Instructor / Admin |
| `CourseManagement.Tests` | اختبارات السلوك والصلاحيات والتكامل |

## الوظائف الأساسية

- تسجيل وإنشاء حساب Student آمن.
- Admin يدير المستخدمين والأدوار والتسجيلات.
- Instructor ينشئ ويدير كورساته.
- Admin يستطيع تعيين Instructor حقيقي للكورس.
- كتالوج بحث وفلترة وترتيب وتقسيم صفحات من الخادم.
- رفع صورة غلاف من جهاز المستخدم.
- Preview Video مستقل ومتاح للزائر.
- فيديوهات الدروس والمرفقات محمية ولا تظهر إلا للمصرح لهم.
- تسجيل/إلغاء تسجيل الطالب في الكورس.
- تشغيل الفيديو وتنزيل المرفقات للطالب المسجل.
- Flutter Mobile-first مع Bottom Navigation للموبايل وDrawer/Sidebar للشاشات الأكبر.
- حالات Loading / Empty / Error ومعالجة مركزية لأخطاء API.

## تشغيل التطوير محليًا

### 1. إعداد سر JWT للـAPI مرة واحدة

```powershell
```

### 2. تشغيل API

```powershell
dotnet run --project CourseManagement.API --launch-profile http
```

العنوان المحلي الافتراضي:

```text
http://localhost:5205
```

Swagger في Development:

```text
http://localhost:5205/swagger
```

Health Check:

```text
http://localhost:5205/health
```

### 3. تشغيل Flutter Web

```powershell
cd CourseManagement.Flutter
flutter run -d chrome --no-pub
```

في Development يستخدم Flutter العنوان المحلي للـAPI. ويمكن تجاوز العنوان لأي بيئة:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=https://api.example.com
```

### 4. تشغيل MVC

```powershell
dotnet run --project CourseManagement.Web
```

لا يحتاج مشروع MVC إلى `JwtSettings:Secret` لأنه يستخدم Cookie Authentication.

## قاعدة البيانات

الإعداد الافتراضي للتطوير:

```text
Data Source=coursemanagement.db
```

ملفات SQLite المحلية مستبعدة من Git. في Production يوصى بمسار دائم مثل:

```text
Data Source=/var/lib/coursemanagement/coursemanagement.db
```

لا تُطبّق الترحيلات تلقائيًا في Production. نفّذها كخطوة نشر مستقلة:

```bash
dotnet ef database update \
  --project CourseManagement.Infrastructure \
  --startup-project CourseManagement.API \
  --configuration Release
```

ثم اجعل:

```text
Database__ApplyMigrations=false
```

## الأسرار وإعداد Production

لا تحفظ أي Secret داخل Git. القيم المهمة للـAPI:

```text
ASPNETCORE_ENVIRONMENT=Production
JwtSettings__Secret=<strong-random-secret>
ConnectionStrings__DefaultConnection=<production-connection-string>
Cors__AllowedOrigins__0=https://app.client-domain.com
Database__ApplyMigrations=false
Swagger__Enabled=false
FileUploads__RootPath=<persistent-upload-path>
```

في Production يجب استخدام HTTPS موثوق وقائمة CORS صريحة. لا تستخدم `*`.

## ملفات الكورسات

أنواع الأصول:

| القيمة | النوع |
|---:|---|
| `1` | Lesson Video |
| `2` | Attachment |
| `4` | Preview Video |

المجلد المحلي الافتراضي:

```text
CourseManagement.Uploads/
```

وهو مستبعد من Git ولا يتم تقديمه كـStatic Files. الغلاف والمعاينة لهما endpoints مخصصة، أما الدروس والمرفقات فتخضع للصلاحيات والتسجيل.

## الأدوار

- **Guest:** الرئيسية، الكتالوج، التفاصيل، Preview، تسجيل الدخول/الحساب.
- **Student:** تسجيلاته، المحتوى المحمي بعد التسجيل، الملف الشخصي.
- **Instructor:** إدارة كورساته وملفاتها.
- **Admin:** إدارة المستخدمين والأدوار والتسجيلات وتجاوز قيود الملكية الإدارية.

التسجيل العام ينشئ **Student فقط**؛ لا يمكن تسجيل Admin ذاتيًا.

## بناء Flutter للتسليم

Web:

```bash
cd CourseManagement.Flutter
flutter build web --release --dart-define=API_BASE_URL=https://api.client-domain.com
```

الناتج:

```text
CourseManagement.Flutter/build/web
```

Android Verification:

```bash
flutter build apk --debug --dart-define=API_BASE_URL=https://api.client-domain.com
```

نسخة Android النهائية للنشر في متجر يجب توقيعها بمفتاح العميل الخاص، ولا يجوز تخزين الـkeystore أو كلمات مروره في Git.

## CI

GitHub Actions يتحقق من:

- .NET Restore
- .NET Release Build
- .NET Tests
- Flutter Analyze
- Flutter Unit/Widget Tests
- Flutter Web Release Build
- Flutter Android verification APK build

وعند النجاح يرفع مخرجات Flutter Web وAPK التحقق كـArtifacts.

## قبل تسليم العميل

المرجع النهائي هو:

**[`CLIENT_DELIVERY_AR.md`](CLIENT_DELIVERY_AR.md)**

ويحتوي إعداد Production، الأسرار، الترحيلات، إنشاء Admin الأول، CORS/HTTPS، النسخ الاحتياطي، Flutter Web/Android، وقائمة فحص ما قبل التسليم.

للتفاصيل الخاصة بأمان ملفات الكورسات راجع `COURSE_ASSETS_AR.md`.
