# تطبيق منصة المعرفة — Flutter

هذا المجلد هو تطبيق Flutter مستقل لمنصة إدارة الكورسات، ويتصل مباشرة بمشروع `CourseManagement.API` عبر REST API. التطبيق ليس واجهة شكلية؛ فهو ينفذ المصادقة بـJWT، يستعيد الجلسة، يعرض الكتالوج مع بحث وفلاتر وفرز وتقسيم صفحات، يفتح تفاصيل الكورس، ينفذ التسجيل والإلغاء، يعرض الملف الشخصي، ويوفر مساحات إدارة محمية حسب الدور.

> **ملاحظة مهمة:** `CourseManagement.Web` يستخدم Cookie Authentication، بينما هذا التطبيق يستخدم JWT Bearer مع `CourseManagement.API`. لا تستخدم سر JWT داخل Flutter أو داخل Git؛ السر يبقى في إعدادات API فقط.

## خريطة الوظائف

| المجال | ما ينفذه التطبيق | المسارات المستخدمة |
|---|---|---|
| المصادقة | تسجيل الدخول، إنشاء حساب، حفظ الجلسة، تسجيل الخروج، مهلة استعادة آمنة | `POST /api/auth/login` و`POST /api/auth/register` |
| التعلم | لوحة رئيسية، كتالوج، تفاصيل، حالات تحميل/فراغ/خطأ وإعادة المحاولة | `GET /api/course/search` و`GET /api/course/{id}` |
| الفلاتر | بحث نصي، مدرس، أقل سعر، أعلى سعر، ترتيب، صفحات | `GET /api/course/instructors` و`GET /api/course/search` |
| تسجيلات الطالب | تسجيل في الكورس، عرض تسجيلاتي، إلغاء التسجيل، معالجة 204 | `POST /api/enrollment` و`GET /api/enrollment/my` و`DELETE /api/enrollment/course/{id}` |
| إدارة المحتوى | Instructor يدير كورساته، وAdmin يدير جميع الكورسات: إنشاء/تعديل/حذف | `POST/PUT/DELETE /api/course` |
| الإدارة | Admin يراجع المستخدمين والتسجيلات ويغير أدوار المستخدمين | `GET /api/users` و`PUT /api/users/{id}/role` و`GET /api/enrollment` |
| أصول الكورسات | Instructor/Admin يختار صورة غلاف من الجهاز عند إنشاء/تعديل الكورس، ثم يختار فيديو أو مرفقًا من الجهاز ويديره، والطالب المسجّل يشغّل الفيديو وينزّل المرفق | `POST /api/course/{id}/cover` و`GET /api/course/{id}/cover` و`GET/POST/DELETE /api/course/{id}/assets` |

التسجيل العام ينشئ دور `Student` دائمًا. بعد ذلك يرقّي Admin المستخدم إلى `Instructor` أو `Admin` من خلال شاشة إدارة المستخدمين، ثم تظهر أدوات إدارة الكورسات فقط للدور المسموح. توجد حراسة مزدوجة: التطبيق يخفي المسار غير المسموح، والـAPI يفرض `[Authorize(Roles = "Instructor,Admin")]` على الخادم.

## البنية الداخلية

التطبيق مقسم إلى طبقات صغيرة واضحة بدل وضع منطق الشبكة داخل الشاشات. يوجد `ApiClient` مركزي لكل طلبات HTTP، و`SessionStore` للتخزين، و`AuthController` لحالة الجلسة، و`GoRouter` للتنقل والحراسة، ونماذج typed للبيانات، وWidgets مشتركة للغلاف والحالات والبطاقات. على Web يستخدم التخزين `SharedPreferences` حتى يعمل على أصل HTTP المحلي، وعلى Android/iOS يستخدم `flutter_secure_storage`.

```text
lib/
├── core/
│   ├── network/api_client.dart
│   ├── storage/session_store.dart
│   └── theme/app_theme.dart
├── features/
│   ├── auth/
│   ├── catalog/
│   ├── enrollments/
│   ├── home/
│   └── profile/
├── models/models.dart
├── widgets/app_shell.dart
└── app.dart / main.dart
```

## المتطلبات

ثبت Flutter من قناة stable وتأكد من أن إصدار Dart يطابق قيد المشروع في `pubspec.yaml`. يمكن فحص البيئة بالأمر التالي، ثم تشغيل التطبيق من هذا المجلد. توصي وثائق Flutter باستخدام أوامر CLI نفسها للتحقق والبناء والتشغيل [1].

```bash
flutter --version
flutter doctor
flutter pub get
```

## تشغيل API أولًا

افتح Terminal مستقلًا من مجلد الحل، واضبط سرًا عشوائيًا لا يقل عن 32 حرفًا في User Secrets. لا تضع القيمة الحقيقية في `appsettings.json` أو داخل التطبيق.

```bash
dotnet user-secrets set "JwtSettings:Secret" "ضع-سرًا-عشوائيًا-طويلًا-خاصًا-ببيئتك" --project CourseManagement.API

dotnet user-secrets set "Database:ApplyMigrations" "true" --project CourseManagement.API

dotnet run --project CourseManagement.API --launch-profile https
```

للديمو المحلي على Flutter Web، يجب السماح فقط لأصل المتصفح الذي ستستخدمه. لا تستخدم `*`؛ إعداد CORS في API يرفض القائمة الفارغة أو wildcard عمدًا.

```bash
dotnet user-secrets set "Cors:AllowedOrigins:0" "http://localhost:5111" --project CourseManagement.API
dotnet user-secrets set "Cors:AllowedOrigins:1" "http://127.0.0.1:5111" --project CourseManagement.API
```

عند تقديم المشروع، شغّل API وFlutter من طرفين منفصلين. لا تشغّل `CourseManagement.Web` و`CourseManagement.API` على نفس المنفذ في الوقت نفسه؛ استخدم ملف `launchSettings.json` أو `--urls` لمنح كل خدمة منفذًا مختلفًا.

## تشغيل Flutter Web

إذا كان API يعمل على رابط HTTPS الافتراضي `https://localhost:7026`، يكفي تشغيل الأمر التالي من مجلد Flutter:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://localhost:7026
```

لبناء نسخة Release قابلة للعرض عبر خادم ملفات محلي:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://localhost:7026
npx http-server build/web -p 5111
```

بعدها افتح `http://127.0.0.1:5111`. عنوان `API_BASE_URL` قيمة compile-time، ولذلك يجب تمريره عند كل `flutter run` أو `flutter build` إذا كان API يستخدم عنوانًا مختلفًا. القيمة الافتراضية داخل `ApiClient` هي `https://localhost:7026`.

## تشغيل Android Emulator أو هاتف فعلي

من Android Emulator، يشير `localhost` إلى المحاكي نفسه وليس إلى جهاز التطوير؛ عنوان `10.0.2.2` هو العنوان الخاص للوصول إلى loopback جهاز التطوير بحسب توثيق Android Emulator [2]. مثال تشغيل:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://10.0.2.2:7026
```

في جهاز فعلي، استخدم عنوان LAN لجهاز التطوير مثل `https://192.168.1.25:7026`، وتأكد من فتح المنفذ في الشبكة. شهادة ASP.NET Core development certificate قد لا تكون موثوقة تلقائيًا على الهاتف أو المحاكي؛ الحل الصحيح للديمو الآمن هو تثبيت شهادة موثوقة/CA في بيئة الاختبار أو استخدام HTTPS بشهادة صالحة. لا تعطل التحقق من الشهادة داخل `ApiClient` ولا تضع bypass دائمًا في التطبيق.

إذا احتجت اختبار Android محليًا ولم يظهر جهاز في `flutter devices`، ثبّت Android Studio وAndroid SDK ثم اضبط المحاكي أو الهاتف مع USB debugging. بناء APK لا يتطلب API مدمجًا داخل التطبيق، لكنه يتطلب Android SDK على جهاز البناء.

## إنشاء Admin للتجربة الأكاديمية

الحساب العام لا ينشئ Admin. لإنشاء أول مدير محليًا، خزّن هذه القيم خارج Git ثم شغّل API مرة واحدة:

```bash
dotnet user-secrets set "SeedAdmin:Enabled" "true" --project CourseManagement.API
dotnet user-secrets set "SeedAdmin:FullName" "System Administrator" --project CourseManagement.API
dotnet user-secrets set "SeedAdmin:Email" "admin@example.com" --project CourseManagement.API
dotnet user-secrets set "SeedAdmin:Password" "كلمة-مرور-قوية-وفريدة" --project CourseManagement.API
```

بعد أول تشغيل، أوقف seed مرة أخرى حتى لا يبقى مسار التهيئة مفعّلًا:

```bash
dotnet user-secrets set "SeedAdmin:Enabled" "false" --project CourseManagement.API
```

سجّل دخول Admin من Flutter، افتح **إدارة المستخدمين**، رقِّ حسابًا إلى Instructor، ثم جرّب **إدارة الكورسات** لإنشاء وتعديل وحذف كورس. Admin يستطيع إدارة جميع الكورسات، بينما Instructor يرى ويدير الكورسات التي يملكها وفق قواعد الخادم.

## معاينة الكورس وتصميم الواجهة

من شاشة **إدارة الكورسات** اضغط إضافة أو تعديل الكورس. ستظهر بطاقة **معاينة الطالب قبل النشر** داخل النموذج؛ تتحدث مباشرة أثناء كتابة العنوان والوصف والسعر، وتعرض صورة الغلاف المختارة من الجهاز. هذه المعاينة محلية ولا تحفظ شيئًا قبل الضغط على الحفظ.

تم تحسين واجهة Flutter بتصميم بصري موحّد: Hero متدرج، بطاقات إبراز واضحة، مساحات بيضاء متوازنة، أزرار ذات حالات مفهومة، وبطاقات كورسات أكثر وضوحًا على الهاتف والويب. لا تعتمد الواجهة على أرقام أو بيانات وهمية؛ البطاقات والمحتوى تأتي من API الحقيقي.

## رفع صورة الغلاف والفيديوهات والمرفقات

في نموذج إنشاء أو تعديل الكورس اضغط **اختيار صورة الغلاف من الجهاز**، ثم احفظ الكورس. يستخدم التطبيق `file_picker` لقراءة bytes الصورة ويرسلها إلى `POST /api/course/{id}/cover` عبر `multipart/form-data` في الحقل `file`. لا يوجد حقل URL، ولا يحتاج المستخدم إلى رفع الصورة إلى موقع خارجي. الامتدادات المسموحة `jpg/jpeg/png/webp` والحجم الأقصى 5MB.

بعد إنشاء الكورس اضغط **الملفات** داخل بطاقة الكورس. اختر `فيديو تعليمي` أو `ملف مرفق`، ثم اضغط **اختيار ورفع** واختر ملفًا من جهازك. يستخدم التطبيق `file_picker` لقراءة bytes ويرسلها عبر `multipart/form-data` إلى API باسم الحقل `file` وقيمة `type` الرقمية. بعد نجاح العملية تظهر metadata في القائمة، ويمكنك تنزيل الأصل من endpoint المحمي أو حذفه بصلاحية المالك/Admin.

في صفحة **تفاصيل الكورس** لا يجلب التطبيق أصولًا للمستخدم غير المصادق. الطالب غير المسجّل يرى رسالة قفل، وبعد نجاح enrollment تظهر المرفقات مع زر **تنزيل** ويظهر الفيديو داخل مشغل محمي يرسل Bearer token. إذا أعاد API `403` فلا يعني ذلك أن الرفع فشل؛ بل يعني أن الحساب يحتاج التسجيل في الكورس أو أن الحساب ليس مالكًا له.

حدود الملفات يفرضها الخادم: صورة الغلاف `jpg/jpeg/png/webp` حتى 5MB، الفيديو `mp4/webm/mov/m4v` حتى 512MB، والمرفقات `pdf/doc/docx/ppt/pptx/xls/xlsx/zip/txt` حتى 50MB. لا تحفظ bytes في SQLite ولا تضع مجلد uploads داخل `build/web` أو `assets`.

## الاختبارات والتحقق

نفّذ أوامر التحقق من مجلد `CourseManagement.Flutter`:

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://localhost:7026
```

يغطي الاختبار الحالي نماذج الجلسة، انتهاء JWT، عقد الكتالوج الصفحي، وسلوك فلاتر البحث. يجب تشغيل API smoke test أو تجربة التدفق يدويًا قبل العرض: تسجيل دخول، فتح الكتالوج، تغيير فلتر السعر، فتح التفاصيل، التسجيل، مراجعة **تسجيلاتي**، ثم تجربة مسار Admin/Instructor ورفع ملف صغير وتنزيله. تم التحقق أيضًا من التكامل الحقيقي مع API محلية معزولة، بما في ذلك upload/list/download للأصول، منع الطالب قبل enrollment، والسماح له بعد التسجيل.

## استكشاف الأخطاء

| العرض | السبب المرجح | الإجراء |
|---|---|---|
| `تعذر الاتصال بالخادم` | API متوقف أو عنوان `API_BASE_URL` خاطئ | افحص `/health` وشغّل Flutter بنفس العنوان الذي يعمل عليه API |
| `401` بعد Login | سر/Issuer/Audience غير متطابق أو جلسة قديمة | أعد ضبط إعدادات API، امسح بيانات التطبيق، وسجّل الدخول من جديد |
| خطأ CORS في Web | أصل Flutter غير موجود في `Cors:AllowedOrigins` | أضف `http://localhost:5111` أو `http://127.0.0.1:5111` صراحةً، ولا تستخدم `*` |
| Android لا يصل إلى localhost | localhost داخل المحاكي يشير للمحاكي | استخدم `10.0.2.2` للمحاكي أو عنوان LAN للهاتف |
| تحذير شهادة HTTPS | شهادة التطوير غير موثوقة على الجهاز | استخدم شهادة موثوقة في بيئة العرض، ولا تتجاوز TLS داخل الكود |
| التطبيق يبقى على Splash | مشكلة مؤقتة في إضافة التخزين | النسخة الحالية تستخدم fallback Web وtimeout لاستعادة الجلسة؛ امسح بيانات الموقع وأعد التشغيل |
| لا يظهر رابط الإدارة | الحساب Student أو الجلسة القديمة محفوظة | رقِّ الدور من Admin ثم سجّل الخروج والدخول من جديد |

## مراجع

[1]: https://docs.flutter.dev/reference/flutter-cli Flutter CLI documentation — أوامر التشغيل والبناء والتحقق.
[2]: https://developer.android.com/studio/run/emulator-networking Android Emulator networking — العنوان `10.0.2.2` للوصول إلى جهاز التطوير.
