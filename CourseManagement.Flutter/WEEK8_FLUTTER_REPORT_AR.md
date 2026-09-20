# تقرير تطبيق Flutter — Week 8

## الملخص التنفيذي

تم تنفيذ تطبيق Flutter مستقل لمنصة المعرفة، متصل فعليًا بمشروع `CourseManagement.API` عبر REST API. التطبيق يحافظ على فصل واضح بين واجهة المستخدم، إدارة الحالة، التخزين، نماذج البيانات، وطبقة الاتصال، ويعرض تجربة عربية RTL متجاوبة تصلح للعرض الأكاديمي على Web أو Android بعد تجهيز SDK والجهاز.

## مطابقة المتطلبات

| المتطلب الأكاديمي | التنفيذ الفعلي | دليل التحقق |
|---|---|---|
| Architecture | `core/network` و`core/storage` و`core/theme`، نماذج typed، features مستقلة وwidgets مشتركة | `flutter analyze` بلا مشاكل |
| Screens | Splash، Login، Register، Dashboard، Catalog، Details، Enrollments، Profile، Admin Users، Admin Enrollments، Course Management | مسارات GoRouter في `lib/app.dart` |
| Navigation | GoRouter مع ShellRoute، Drawer، Bottom Navigation، وروابط التفاصيل والإدارة | حراسة `/admin` و`/manage` حسب الدور |
| API Integration | ApiClient مركزي يرسل JSON وBearer JWT، ويحوّل استجابات API إلى نماذج Dart | smoke test حقيقي على API معزولة |
| Filters | query، instructorId، minPrice، maxPrice، sort، page، pageSize | عقد `CourseFilter` و`GET /api/course/search` |
| Authentication | Login/Register، حفظ الجلسة، استعادة bounded، logout، ورسائل أخطاء | JWT issued في smoke test، مع حماية المسارات |
| Student flow | تصفح، فتح التفاصيل، تسجيل، مراجعة التسجيلات، إلغاء التسجيل | POST/GET/DELETE نجحت في smoke test |
| Instructor/Admin flow | إنشاء وتعديل وحذف الكورسات، مع إدارة كورسات المالك للـInstructor وجميع الكورسات للـAdmin | POST/PUT/DELETE محمية في API ومتصلة بالواجهة |
| Admin flow | تغيير الدور ومراجعة جميع التسجيلات | `/api/users` و`/api/enrollment` نجحت مع JWT Admin |
| UI states | Loading، Empty، Error، Retry، validation، busy buttons، confirmation dialog | موجودة في الشاشات المشتركة والصفحات |

## خريطة التنقل

```text
Splash
├── Login
│   └── Register
└── authenticated shell
    ├── Dashboard
    ├── Catalog
    │   └── Course Details
    ├── My Enrollments
    ├── Profile
    ├── Manage Courses        [Instructor/Admin]
    ├── Admin Users           [Admin]
    └── Admin Enrollments     [Admin]
```

## تدفق العرض المقترح

ابدأ API أولًا، ثم افتح Flutter على Web. سجّل حساب Student جديدًا، استعرض الكتالوج وطبّق فلتر السعر أو المدرس، افتح تفاصيل كورس، ثم نفّذ التسجيل والإلغاء. بعد ذلك استخدم حساب Admin المجهز عبر User Secrets لترقية حساب إلى Instructor، ثم أعد تسجيل الدخول وجرّب إنشاء كورس وتعديله وحذفه من **إدارة الكورسات**. أخيرًا راجع **إدارة المستخدمين** و**إدارة التسجيلات** لإظهار منطق الصلاحيات.

## نتائج الاختبارات

| الاختبار | النتيجة |
|---|---|
| `flutter analyze` | ناجح — لا توجد مشاكل |
| `flutter test` | ناجح — 4 اختبارات |
| `flutter build web --release` | ناجح مع `API_BASE_URL=https://localhost:7026` |
| `/health` في API | HTTP 200 |
| CORS preflight | origin المصرح به عاد في header |
| Admin login | JWT صادر بنجاح |
| Course CRUD | إنشاء وتعديل وحذف والتحقق من 404 بعد الحذف نجحت |
| Student registration/enrollment | التسجيل واسترجاع تسجيلاتي ناجحان |
| Admin lists | المستخدمون والتسجيلات رجعا بيانات حقيقية |
| Unenrollment | DELETE نجح مع استجابة 204 بلا body |

## ملاحظات أمنية

لا يحتوي Flutter على `JwtSettings:Secret` ولا على أي مفتاح ثابت. السر وبيانات Admin تبقى في User Secrets أو environment variables داخل API. كما أن CORS يجب أن يستخدم قائمة origins صريحة، بينما يُستخدم HTTPS وشهادة موثوقة في بيئة العرض. حراسة الواجهة ليست بديلًا عن `[Authorize]` في الخادم؛ لذلك يبقى API هو مصدر القرار النهائي للصلاحيات.

## ملاحظة تشغيلية

نسخة Web تستخدم `SharedPreferences` لحفظ جلسة العميل عند تشغيل demo على HTTP المحلي، بينما تستخدم المنصات الأصلية `flutter_secure_storage`. استعادة الجلسة لها timeout مدته 3 ثوانٍ حتى لا تتحول مشكلة Plugin أو storage إلى شاشة Splash عالقة. لم يتم تضمين APK جاهز لأن بيئة البناء الحالية لا تحتوي Android SDK؛ بناء APK على Windows يتطلب تثبيت Android Studio/SDK ثم تشغيل `flutter build apk --release`.

## المراجع

[1]: https://docs.flutter.dev/reference/flutter-cli Flutter CLI documentation.
[2]: https://developer.android.com/studio/run/emulator-networking Android Emulator networking.
