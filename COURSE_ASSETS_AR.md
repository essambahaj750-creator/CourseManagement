# نظام غلاف وفيديوهات ومرفقات الكورسات

يوفر مشروع **CourseManagement** نظام ملفات حقيقيًا للكورسات. يستطيع مالك الكورس من دور `Instructor` أو أي `Admin` اختيار صورة غلاف، فيديو، أو مرفق من جهازه ورفعه عبر `multipart/form-data`. يستطيع الطالب المسجّل عرض الأصول التعليمية المصرّح بها، تشغيل الفيديو المحمي من Flutter، وتنزيل المرفقات. لا توجد أزرار وهمية ولا تخزين لملفات الصور أو الفيديو داخل SQLite، ولا يحتاج المستخدم إلى إدخال رابط صورة خارجي.

## التصميم والمسؤوليات

| الجزء | المسؤولية |
|---|---|
| `CourseAsset` | حفظ metadata فقط: الاسم الأصلي، النوع (`Video` أو `Attachment` أو `CoverImage`)، MIME، الحجم، وقت الإنشاء، واسم التخزين العشوائي |
| `CourseAssetService` | التحقق من الاسم والامتداد وMIME والحجم والصلاحية، وربط الملف بالكورس |
| `LocalFileStorage` | حفظ bytes خارج قاعدة البيانات باسم GUID، مع ملف مؤقت ثم move ذري وحماية path traversal |
| `CourseAssetsController` | REST endpoints المحمية للقائمة والرفع والتنزيل والحذف |
| `CourseManagement.Web` | نموذج MVC لرفع الملف وقائمة التنزيل والحذف مع Cookie Authentication وAnti-Forgery |
| `CourseManagement.Flutter` | picker من الجهاز، رفع multipart، إدارة الملفات، تشغيل الفيديو المحمي، وتنزيل المرفقات |

توجد migration رسمية باسم `20260825204717_CourseAssets`. عند حذف الكورس تُحذف سجلات `CourseAssets` عبر cascade، كما ينفّذ `CourseService` cleanup للملفات الفيزيائية المرتبطة قبل فقدان metadata. إذا تعذر حذف ملف من القرص بعد حذف السجل، يسجّل النظام warning ولا يعيد فتح صلاحية الوصول إلى الكورس المحذوف.

## مكان التخزين

الإعداد الافتراضي هو:

```text
CourseManagement.Uploads/
```

ويُفسّر المسار النسبي بالنسبة إلى `ContentRootPath` لكل تطبيق، ولذلك تستخدم إعدادات API وMVC قيمة `../CourseManagement.Uploads` ليكون المجلد خارج مجلد المشروع التنفيذي. تستطيع تغيير الموقع في الإعداد التالي:

```json
{
  "FileUploads": {
    "RootPath": "../CourseManagement.Uploads",
    "MaxVideoBytes": 536870912,
    "MaxAttachmentBytes": 52428800,
    "MaxCoverImageBytes": 5242880,
    "AllowedCoverImageExtensions": [ ".jpg", ".jpeg", ".png", ".webp" ]
  }
}
```

المجلد مستبعد من Git عبر `.gitignore`. لا تضف فيديوهات أو مستندات حقيقية إلى المستودع. لا تستخدم `UseStaticFiles` لتقديم هذا المجلد؛ كل تنزيل يمر من endpoint يفحص JWT والصلاحية أولًا.

## أنواع الملفات والحدود

| النوع | الامتدادات | الحد الأقصى | قيم form |
|---|---|---:|---|
| Video | `.mp4`, `.webm`, `.mov`, `.m4v` | 512MB | `type=1` |
| Attachment | `.pdf`, `.doc`, `.docx`, `.ppt`, `.pptx`, `.xls`, `.xlsx`, `.zip`, `.txt` | 50MB | `type=2` |
| CoverImage | `.jpg`, `.jpeg`, `.png`, `.webp` | 5MB | endpoint الغلاف، وليس `type` |

يتحقق الخادم من الامتداد ومحتوى MIME. يُقبل `application/octet-stream` كحالة توافق مع بعض متصفحات وأنظمة اختيار الملفات، لكن الامتداد والحد الأقصى لا يمكن تجاوزهما. الاسم الأصلي يُنظّف بواسطة `Path.GetFileName` ويُحفظ الاسم الفيزيائي الداخلي بصيغة GUID مع امتداد مسموح؛ لذلك لا يستطيع اسم الملف إنشاء مسار خارج مجلد التخزين.

## REST API

| Method | Endpoint | الصلاحية |
|---|---|---|
| `GET` | `/api/course/{courseId}/cover` | عام للعرض فقط بعد رفع الغلاف |
| `POST` | `/api/course/{courseId}/cover` | مالك الكورس من Instructor أو Admin |
| `GET` | `/api/course/{courseId}/assets` | مالك الكورس، Admin، أو Student مسجّل في الكورس |
| `POST` | `/api/course/{courseId}/assets` | مالك الكورس من Instructor أو Admin |
| `GET` | `/api/course/{courseId}/assets/{assetId}/download` | مالك الكورس، Admin، أو Student مسجّل |
| `DELETE` | `/api/course/{courseId}/assets/{assetId}` | مالك الكورس من Instructor أو Admin |

طلب غلاف الكورس يجب أن يكون `multipart/form-data` ويحتوي على الحقل `file` فقط:

```text
file: صورة محلية من جهاز المستخدم (JPG/PNG/WebP، حتى 5MB)
```

يرجع API بعد نجاح رفع الغلاف كائن الكورس مع `imageUrl` مولّد من الخادم مثل `/api/course/{courseId}/cover`. هذا المسار للاستخدام الداخلي في العرض، ولا يكتبه المستخدم ولا يشير إلى موقع خارجي.

أما طلب الأصول التعليمية فيجب أن يكون `multipart/form-data` ويحتوي:

```text
file: الملف المحلي
 type: 1 للفيديو أو 2 للمرفق
```

يعيد الرفع `CourseAssetDto` يتضمن `id`, `courseId`, `originalFileName`, `contentType`, `sizeBytes`, `type`, `createdAtUtc`, و`downloadUrl`. يعيد التنزيل bytes مع اسم الملف الأصلي ويدعم HTTP Range للفيديو. الحالات الأساسية هي `401` للجلسة المفقودة، `403` للمستخدم المصادق غير المصرّح، `404` للكورس أو الأصل غير الموجود، و`400` لملف فارغ أو امتداد/MIME/حجم غير صالح.

## المعاينة قبل النشر

توجد معاينة مباشرة في نموذج إنشاء وتعديل الكورس. عند الكتابة يتحدث العنوان والوصف والسعر فورًا، وعند اختيار صورة من الجهاز تظهر داخل بطاقة تشبه تجربة الطالب. المعاينة محلية داخل الصفحة ولا تحفظ أو ترفع أي شيء حتى يضغط المستخدم زر الحفظ. في Edit يظهر الغلاف الحالي، ويمكن استبداله بصورة جديدة قبل تأكيد التعديل.

## استخدام MVC

شغّل API وMVC على منفذين مختلفين. سجّل الدخول في MVC بحساب Admin أو Instructor مالك للكورس، ثم افتح:

```text
/Courses/Details/{id}
```

تظهر بطاقة **المعاينة المباشرة** بجانب نموذج الإنشاء أو التعديل. بعد حفظ الكورس يظهر قسم **رفع فيديو أو ملف للكورس** للمالك أو Admin فقط. بعد اختيار الملف والنوع، يرسل النموذج الحقلين `file` و`type` مع Anti-Forgery token. تظهر القائمة للمستخدم المصرّح له فقط، ويتطلب تنزيل الملف JWT cookie صالحة. حذف الأصل POST محمي بـAnti-Forgery، ولا يظهر للطالب.

## استخدام Flutter

بعد تشغيل API نفّذ:

```bash
cd CourseManagement.Flutter
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://localhost:7026
```

للمدير أو المدرب افتح **إدارة الكورسات** ثم اضغط إضافة أو تعديل. تظهر بطاقة **معاينة الطالب قبل النشر** داخل النموذج وتتحدث مع العنوان والوصف والسعر والصورة المختارة. من حقل **صورة الغلاف** اضغط اختيار الصورة من الجهاز؛ لا يوجد حقل رابط. بعد حفظ الكورس اضغط **الملفات** داخل بطاقة الكورس لإضافة فيديوهات ومرفقات تعليمية من الجهاز. التطبيق يرسل الملفات إلى API باستخدام Bearer token ويحدّث الواجهة بعد النجاح. كما تمت إعادة تصميم رأس شاشة الإدارة والكتالوج ببطاقات Hero ومساحات أوضح وأزرار ذات حالات واضحة. الأزرار الموجودة في القوائم تنفذ رفعًا وتنزيلًا وحذفًا حقيقيًا، وليست مجرد controls شكلية.

للطالب افتح تفاصيل الكورس. قبل التسجيل تظهر رسالة قفل ولا تُجلب bytes أو metadata. بعد نجاح التسجيل، يجلب التطبيق `/assets` ويعرض المرفقات مع زر تنزيل، ويشغّل الفيديو عبر `video_player` مع Authorization header. على Android Emulator استخدم `https://10.0.2.2:<port>` بدل `localhost`. على الهاتف الفعلي استخدم عنوان LAN وشهادة HTTPS موثوقة؛ لا تضف TLS bypass داخل التطبيق.

## Postman وE2E

تحتوي `CourseManagement.API.postman_collection.json` على مجلد:

```text
03 - Course Assets (Multipart & Permissions)
```

يختبر المجلد رفع صورة غلاف، عرضها من endpoint محلي، رفع فيديو، قائمة Admin، منع الطالب قبل التسجيل، منع رفع الطالب، رفض غلاف GIF، رفض الامتداد غير المسموح، رفع مرفق، السماح بعد enrollment، التنزيل، منع الحذف للطالب، وحذف الأصل للـAdmin.
 توجد fixtures صغيرة بلا بيانات حساسة في `tests/assets/`، ويمكن استخدام مساراتها من جذر المستودع عند تشغيل Newman أو Postman.

لتشغيل collection محليًا، اضبط `baseUrl` وبيانات Admin في Postman Environment فقط. قيمة `adminPassword` الافتراضية هي `CHANGE_ME` عمدًا؛ استبدلها في بيئة Postman المحلية ولا تحفظ كلمة المرور في Git.

## اختبارات الأمان

توجد اختبارات xUnit في `CourseManagement.Tests/Integration/CourseAssetsTests.cs` للتحقق من lifecycle التخزين المحلي، رفض path traversal، تنظيف الاسم، رفض الامتداد وMIME، صلاحية المالك، منع الطالب غير المسجّل، السماح للطالب المسجّل، وتنظيف الملفات عند حذف الكورس. كما تم تنفيذ smoke test multipart حقيقي على API مع SQLite معزولة شمل upload/list/download/enrollment/delete ونجح كاملًا.

## توصيات الإنتاج

التخزين المحلي مناسب للتطوير والعرض الأكاديمي على جهاز واحد، بشرط منح حساب الخدمة صلاحية القراءة والكتابة على المجلد وإنشاء backup منفصل للـSQLite والمجلد معًا. في الإنتاج متعدد النسخ يُفضّل نقل bytes إلى object storage خاص مع signed URLs قصيرة أو proxy محمي، مع إبقاء metadata في قاعدة البيانات.

قبل السماح بملفات مستخدمين في بيئة إنتاج حقيقية، أضف فحص antivirus أو malware scanning، quotas لكل Instructor، مراقبة المساحة، rate limiting للرفع والتنزيل، checksum اختياريًا، ونسخًا احتياطيًا مشفرًا. ينبغي أيضًا معالجة الفيديو عبر transcoding أو streaming service عند الحاجة؛ لا تجعل API أحادي الخادم نقطة الاختناق لملفات 512MB. لا تُسجّل JWT أو محتوى الملفات أو كلمات المرور في logs.
