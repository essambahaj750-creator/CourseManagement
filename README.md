# Course Management API + Web

Web API لإدارة الكورسات والتسجيلات، مبني بمعمارية Clean Architecture على **.NET 10** مع **EF Core + SQLite** و **JWT Authentication**.

## المعمارية

| المشروع | المسؤولية |
|---|---|
| `CourseManagement.Domain` | الكيانات (User, Course, Enrollment) والـ Enums وواجهات المستودعات |
| `CourseManagement.Application` | DTOs وواجهات الخدمات — لا يعتمد إلا على Domain |
| `CourseManagement.Infrastructure` | EF Core DbContext والمستودعات والخدمات (تطبيق الواجهات) |
| `CourseManagement.API` | REST API وJWT وSwagger وHealth Check — مستقل عن واجهة MVC |
| `CourseManagement.Web` | ASP.NET Core MVC: Controllers وViews وwwwroot وCookie Authentication |
| `CourseManagement.Flutter` | تطبيق Flutter مستقل: RTL UI، JWT client، كتالوج، تسجيلات، وإدارة محمية حسب الدور |

## التشغيل

```bash
dotnet run --project CourseManagement.API
```

- الترحيلات لا تُطبَّق تلقائياً في الإنتاج. تُفعّل في التطوير عبر `Database:ApplyMigrations = true`، أو تُطبّق يدويًا من خط النشر.
- إنشاء Admin الأولي معطل افتراضيًا. فعّله صراحةً بعد وضع بياناته في User Secrets أو متغيرات البيئة.
- Swagger UI متاح في التطوير على `/swagger`، ويمكن تفعيله في بيئة أخرى عبر `Swagger:Enabled = true` بعد تقييد الوصول إليه.

## الإعدادات والأسرار

- `JwtSettings:Secret` خاص بمشروع `CourseManagement.API` الذي يصدر JWT؛ لا تضعه داخل Git.
- مشروع `CourseManagement.Web` يستخدم Cookie Authentication ولا يحتاج `JwtSettings:Secret` عند التشغيل أو الضغط على F5.
- لإعداد تطوير الـAPI باستخدام User Secrets:

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

### أصول الكورس: الغلاف والفيديوهات والمرفقات المحلية

يوفر النظام رفعًا حقيقيًا من جهاز المستخدم عبر `multipart/form-data`، وليس عناصر واجهة وهمية. من نموذج إنشاء أو تعديل الكورس يختار المستخدم صورة الغلاف مباشرة من جهازه؛ لا يوجد حقل رابط صورة. وبعد إنشاء الكورس يمكن رفع الفيديوهات والمرفقات من صفحة التفاصيل أو شاشة إدارة الكورس في Flutter. تُحفظ bytes في مجلد محلي خارج قاعدة SQLite، بينما تُحفظ في SQLite بيانات الملف فقط مثل الاسم الأصلي الآمن، النوع، MIME، الحجم، وقت الإنشاء، واسم التخزين الداخلي العشوائي. المجلد `CourseManagement.Uploads/` مستبعد من Git ولا يُقدّم عبر `wwwroot` أو static files.

| Method | المسار | الصلاحية | الاستخدام |
|---|---|---|---|
| GET | `/api/course/{courseId}/cover` | عام للعرض فقط | عرض صورة الغلاف التي رفعها Admin أو مالك الكورس |
| POST | `/api/course/{courseId}/cover` | Instructor المالك أو Admin | رفع صورة الغلاف المحلية في الحقل `file` |
| GET | `/api/course/{courseId}/assets` | مالك الكورس أو Admin أو Student مسجّل | قائمة metadata المحمية |
| POST | `/api/course/{courseId}/assets` | Instructor المالك أو Admin | رفع `file` و`type` بقيمتي `1=Video` أو `2=Attachment` |
| GET | `/api/course/{courseId}/assets/{assetId}/download` | مالك الكورس أو Admin أو Student مسجّل | تنزيل/stream محمي مع Range support |
| DELETE | `/api/course/{courseId}/assets/{assetId}` | Instructor المالك أو Admin | حذف metadata والbytes معًا |

الفيديوهات المسموحة هي `mp4` و`webm` و`mov` و`m4v` بحد أقصى 512MB، والمرفقات هي `pdf` و`doc/docx` و`ppt/pptx` و`xls/xlsx` و`zip` و`txt` بحد أقصى 50MB، وصورة الغلاف هي `jpg/jpeg/png/webp` بحد أقصى 5MB. يتحقق الخادم من الامتداد وMIME والحجم والاسم، ويقبل `application/octet-stream` فقط كحالة توافق شائعة من متصفحات اختيار الملفات، مع بقاء الامتداد والحدود مفروضة. الطالب لا يرى ولا ينزّل الملفات التعليمية قبل enrollment، بينما الغلاف مخصص للعرض العام ولا يكشف مسار التخزين الفيزيائي.

في MVC افتح **إضافة كورس** أو **تعديل الكورس** واختر صورة الغلاف من حقل الملف، ثم افتح `/Courses/Details/{id}` لرفع وإدارة الفيديوهات والمرفقات. وفي Flutter استخدم **إدارة الكورسات** ثم اختر صورة الغلاف من الجهاز، أو افتح **الملفات** لإضافة محتوى الكورس. الطالب المسجّل يستطيع تشغيل الفيديو وتنزيل المرفقات. التفاصيل التشغيلية والأمنية موجودة في `COURSE_ASSETS_AR.md`.

## معالجة الأخطاء

Middleware مركزي يحوّل استثناءات منطق الأعمال إلى رموز HTTP صحيحة:
`404` غير موجود · `403` ممنوع (ملكية) · `401` غير مصادَق · `409` تعارض (تكرار/قواعد عمل) · `400` فشل التحقق من المدخلات · `500` خطأ غير متوقع (بدون تسريب التفاصيل).

ملف `CourseManagement.API/CourseManagement.API.http` يحتوي طلبات جاهزة لتجربة التدفق كاملاً.

## واجهة ASP.NET Core MVC

تمت إضافة مشروع MVC مستقل باسم `CourseManagement.Web` داخل الحل، مطابق لنمط المشاريع المنفصلة في Solution Explorer. يحتوي `CourseManagement.Web` على Controllers وViewModels وViews وwwwroot ويستخدم Cookie آمنًا لجلسة Razor MVC، بينما يبقى `CourseManagement.API` مشروع REST API مستقلًا مع JWT Bearer وSwagger. تبدأ الواجهة من المسار `/` بعد تشغيل `CourseManagement.Web/CourseManagement.Web.csproj`، ولا تُفتح Razor Views بالنقر المزدوج من File Explorer لأنها تُعرض أثناء تشغيل ASP.NET Core.

للتشغيل السريع في Windows، افتح مجلد الحل الذي يحتوي على `CourseManagement.API.slnx` وانقر `run-mvc.bat`؛ سيشغّل الملف مشروع `CourseManagement.Web` مباشرة. أو اجعل `CourseManagement.Web` هو Startup Project في Visual Studio. راجع `RUN_MVC_AR.md` للتعليمات التفصيلية. استخدم رابط HTTPS الذي يظهر في Terminal، وغالبًا يكون `https://localhost:7027/Account/Login`؛ API يبقى على `https://localhost:7026`.

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

بعد تثبيت .NET SDK، افتح الحل واختر `CourseManagement.Web` كمشروع البدء ثم اضغط `F5` باستخدام Profile `https`. لا يحتاج Web إلى سر JWT؛ نفّذ الأوامر التالية فقط إذا أردت تطبيق Migration يدويًا:

```bash
dotnet restore
dotnet ef database update --project CourseManagement.Infrastructure --startup-project CourseManagement.Web
dotnet run --project CourseManagement.Web
```

سيُنشأ ملف `coursemanagement.db` تلقائيًا داخل مجلد التشغيل. عند تشغيل مشروع الـAPI المستقل فقط، ضع `JwtSettings:Secret` في User Secrets أو متغيرات البيئة، ولا تخزّن الأسرار الحقيقية داخل Git.

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

يمكن تغيير موقع ملف SQLite عبر `ConnectionStrings:DefaultConnection`، مثل `Data Source=/var/lib/coursemanagement/coursemanagement.db`. يجب منح حساب التطبيق صلاحية القراءة والكتابة على المجلد، مع نسخ احتياطي دوري للملف.


## إعادة التصميم الاحترافية — منصة المعرفة

أُعيد تصميم واجهة MVC العربية بالكامل لتقديم تجربة تعليمية RTL باسم **منصة المعرفة**، مع الحفاظ على Clean Architecture وطبقة الخدمات والصلاحيات الحالية. يتضمن التصميم AppBar وDrawer متجاوبًا وBottom Navigation للهاتف، Dashboard رئيسيًا، شبكة بطاقات للكورسات، جداول DataTables عربية، Bootstrap Modals، حالات فارغة ورسائل نجاح وخطأ، ونماذج مصادقة محسنة.

| المجال | الشاشات أو المكونات |
|---|---|
| الحساب | تسجيل الدخول، إنشاء الحساب، تغيير كلمة المرور |
| التعلم | Dashboard، استكشاف الكورسات، تفاصيل الكورس، تسجيلاتي |
| إدارة المحتوى | إضافة كورس، تعديل كورس، حذف كورس، صورة الكورس |
| الإدارة | المستخدمون، تغيير الدور عبر Modal، كل التسجيلات |
| التصميم | Bootstrap RTL 5.3، Cairo، Bootstrap Icons، CSS Variables، Responsive Drawer |

يشرح `REDESIGN_PLAN_AR.md` خطة التنفيذ ومعايير القبول، بينما يشرح `REDESIGN_REPORT_AR.md` المطابقة التفصيلية لمتطلبات Week 7 والوحدات والشاشات ومنطق الأعمال. توجد لقطات التحقق البصري في `docs/screenshots/`.

### بحث الكورسات

يرتبط البحث الموجود في AppBar فعليًا بالمسار `/Courses?q=...`، ويبحث في عنوان الكورس ووصفه واسم المدرب عبر `CoursesController`، ثم يعرض النتائج في البطاقات والجدول.

### التحقق البصري

تم التحقق محليًا من أن `/Account/Login` و`/Account/Register` يعيدان `HTTP 200` وتظهر فيهما الهوية البصرية العربية الجديدة. كما يعيد `/health` القيمة `200`، ونجحت اختبارات xUnit الأربعة بعد إعادة التصميم.


## فلترة كتالوج الكورسات — Week 8

أضيفت طبقة فلترة مشتركة بين Domain وApplication وInfrastructure، لذلك تُنفذ الشروط داخل EF Core/SQLite بدل تحميل كل الكورسات ثم فلترتها في المتصفح. تدعم الفلترة البحث في العنوان والوصف واسم المدرّس، المدرّس، نطاق السعر، الترتيب، والتقسيم الصفحي.

### مسارات REST API الجديدة

| Method | المسار | الوصف |
|---|---|---|
| GET | `/api/course/search` | بحث الكتالوج مع الفلاتر والصفحات |
| GET | `/api/course/instructors` | قائمة المدرّسين المستخدمة في خيارات الفلترة |

مثال:

```text
GET /api/course/search?q=flutter&minPrice=10&maxPrice=500&sort=price-low&page=1&pageSize=6
```

القيم المدعومة لـ`sort` هي `featured` و`newest` و`price-low` و`price-high` و`title`. يعيد endpoint البحث `items` و`totalCount` و`page` و`pageSize` و`totalPages`، مما يجعله مناسبًا لشاشة Flutter تحتوي على بحث، فلاتر، فرز، وترقيم صفحات.

### واجهة MVC

صفحة `/Courses` تستخدم النموذج نفسه عبر `CoursesController`، وتوفر لوحة فلاتر متجاوبة تشمل البحث، المدرّس، أقل سعر، أعلى سعر، والترتيب. تحفظ الفلاتر في Query String، لذلك يمكن نسخ الرابط أو استخدام زر الرجوع دون فقدان حالة البحث. على الهاتف تتحول اللوحة إلى Drawer، وتتوفر حالة فارغة، ملخص للفلاتر، وترقيم صفحات واضح.

### حدود الفلاتر الحالية

نموذج البيانات الحالي يحتوي على العنوان والوصف والسعر والصورة والمدرّس فقط، لذلك لا تعرض الواجهة فلاتر وهمية مثل التصنيف أو المستوى أو المدة. إضافة هذه الأبعاد مستقبلًا تتطلب حقولًا وMigration جديدة في Domain وDbContext ثم توسيع `CourseFilterDto` و`CourseSearchCriteria` وواجهات العملاء.

### خريطة Week 8

| المتطلب | التطبيق داخل المشروع |
|---|---|
| Architecture | Clean Architecture: Domain، Application، Infrastructure، API، Web |
| Screens | Dashboard، Course Catalog، Course Details، Enrollments، Admin |
| Navigation | AppBar، Drawer، Bottom Navigation، روابط Back وQuery String |
| API Integration | `/api/course/search` و`/api/course/instructors` بعقد paginated واضح |
| UI State | نتائج، حالة فارغة، فلاتر مطبقة، أخطاء، تحقق، واستجابة للهاتف |

## تطبيق Flutter المستقل

يوجد تطبيق Flutter مستقل داخل `CourseManagement.Flutter` يعمل كعميل حقيقي لـ`CourseManagement.API` عبر JWT Bearer، وليس مجرد واجهة تجريبية. يشمل التطبيق المصادقة، استعادة الجلسة، الكتالوج مع الفلاتر server-side، تفاصيل الكورس، التسجيلات، الملف الشخصي، وحراسة مسارات الإدارة. كما أضيفت شاشة CRUD لإدارة الكورسات للـInstructor/Admin، مع إدارة المستخدمين والتسجيلات للـAdmin. وتدعم شاشة إدارة الكورس اختيار فيديو أو مرفق من جهاز المستخدم ورفعه multipart، كما يدعم الطالب المسجّل تشغيل الفيديو المحمي وتنزيل المرفقات من خلال Bearer token.

للتشغيل، ابدأ API أولًا واضبط `JwtSettings:Secret` و`Cors:AllowedOrigins` خارج Git، ثم نفّذ من مجلد Flutter:

```bash
cd CourseManagement.Flutter
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://localhost:7026
```

للمحاكي Android استخدم `https://10.0.2.2:<port>` بدل `localhost`، وللهاتف الفعلي استخدم عنوان LAN مع شهادة HTTPS موثوقة. توجد التعليمات التفصيلية وخريطة الوظائف والاختبارات في `CourseManagement.Flutter/README.md`.

| المسار | الغرض |
|---|---|
| `/` | لوحة Flutter الرئيسية |
| `/courses` | كتالوج وفلاتر وصفحات |
| `/courses/:id` | تفاصيل وتسجيل/إلغاء التسجيل |
| `/enrollments` | تسجيلات الطالب |
| `/manage/courses` | CRUD للكورسات للـInstructor/Admin |
| `/admin/users` | إدارة أدوار المستخدمين للـAdmin |
| `/admin/enrollments` | مراجعة التسجيلات للـAdmin |
