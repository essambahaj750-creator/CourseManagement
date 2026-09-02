# دليل تسليم منصة المعرفة للعميل

هذه الوثيقة هي المرجع النهائي لتجهيز المشروع وتشغيله ونشره وتسليمه.

## مكونات التسليم

- `CourseManagement.API`: REST API مع JWT وSwagger/Health Check.
- `CourseManagement.Web`: واجهة MVC إدارية/ويب مع Cookie Authentication.
- `CourseManagement.Flutter`: تطبيق Flutter متجاوب للويب والموبايل.
- `CourseManagement.Infrastructure`: EF Core + SQLite + التخزين المحلي الآمن لملفات الكورسات.
- `CourseManagement.Tests`: اختبارات السلوك والصلاحيات والتكامل.

## حالة الجودة

يجب ألا يتم التسليم من Commit لم ينجح عليه CI بالكامل. المسار المعتمد هو:

1. `.NET Restore`
2. `.NET Build Release`
3. `.NET Tests`
4. `Flutter Analyze`
5. `Flutter Unit/Widget Tests`
6. `Flutter Web Release Build`
7. `Flutter Android verification APK build`

GitHub Actions يرفع مخرجات Flutter Web وAPK التحقق كـArtifacts عند نجاح الـCI.

> APK المرفوع من CI مخصص للتحقق الوظيفي فقط. نسخة Android النهائية للنشر على المتجر يجب توقيعها بمفتاح العميل الخاص ولا يجوز حفظ المفتاح أو كلمات مروره داخل Git.

## إعداد الإنتاج

لا تضع أسرار الإنتاج داخل `appsettings.json` أو Git. استخدم متغيرات البيئة أو Secret Store الخاص بخادم العميل.

### API

القيم المطلوبة على الأقل:

```text
ASPNETCORE_ENVIRONMENT=Production
JwtSettings__Secret=<random-secret-at-least-32-characters>
ConnectionStrings__DefaultConnection=Data Source=/var/lib/coursemanagement/coursemanagement.db
Cors__AllowedOrigins__0=https://app.client-domain.com
Database__ApplyMigrations=false
Swagger__Enabled=false
FileUploads__RootPath=/var/lib/coursemanagement/uploads
```

يفضل أن يكون `JwtSettings__Secret` عشوائيًا وطويلًا (64+ حرفًا) ولا يعاد استخدامه في أي نظام آخر.

### MVC Web

```text
ASPNETCORE_ENVIRONMENT=Production
ConnectionStrings__DefaultConnection=Data Source=/var/lib/coursemanagement/coursemanagement.db
Database__ApplyMigrations=false
FileUploads__RootPath=/var/lib/coursemanagement/uploads
```

إذا كان API وMVC يعملان على نفس قاعدة البيانات ومجلد الملفات، يجب تشغيلهما بنفس القيم الفعلية للمسارات.

## قاعدة البيانات والترحيلات

في الإنتاج لا تجعل التطبيق يطبق الترحيلات تلقائيًا أثناء كل تشغيل. نفذها كخطوة نشر منفصلة:

```bash
dotnet ef database update \
  --project CourseManagement.Infrastructure \
  --startup-project CourseManagement.API \
  --configuration Release
```

بعد نجاح الترحيل شغّل التطبيق مع:

```text
Database__ApplyMigrations=false
```

## إنشاء Admin الأول

التسجيل العام ينشئ Student فقط. لإنشاء Admin الأول يمكن تفعيل Seeder مرة واحدة من إعدادات آمنة خارج Git:

```text
SeedAdmin__Enabled=true
SeedAdmin__FullName=System Administrator
SeedAdmin__Email=admin@client-domain.com
SeedAdmin__Password=<strong-unique-password>
```

بعد التأكد من إنشاء الحساب أعد:

```text
SeedAdmin__Enabled=false
```

ولا ترسل كلمة مرور Admin عبر ملف داخل المشروع.

## ملفات الكورسات

المحتوى لا يحفظ داخل `wwwroot`. يجب أن يكون `FileUploads__RootPath` في مجلد دائم قابل للكتابة والنسخ الاحتياطي.

الأنواع:

- `1` = Lesson Video
- `2` = Attachment
- `4` = Preview Video

فيديو المعاينة متاح للزائر من endpoint مخصص، بينما فيديوهات الدروس والمرفقات محمية بالصلاحيات والتسجيل في الكورس.

## Flutter Web

لإنشاء نسخة مرتبطة بدومين API الحقيقي:

```bash
cd CourseManagement.Flutter
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.client-domain.com
```

انشر محتويات:

```text
CourseManagement.Flutter/build/web
```

على خادم Static/PWA يدعم fallback إلى `index.html` لمسارات التطبيق.

## Flutter Android

قبل نشر نسخة متجر نهائية يجب أن يحدد العميل:

- Application ID النهائي إذا كان يريد اسم نطاق خاصًا به.
- Android signing keystore المملوك للعميل.
- كلمات مرور المفتاح عبر Secret Store/CI فقط.

لا تسلم APK متجر موقّعًا بمفتاح Debug. يمكن استخدام APK الـCI فقط للاختبار الداخلي.

## HTTPS وCORS

- في `Development` يسمح API بعناوين loopback لتسهيل تشغيل Flutter محليًا.
- في `Production` يجب أن تكون `Cors:AllowedOrigins` قائمة صريحة بدومينات العميل.
- لا تستخدم `*`.
- يجب نشر API خلف HTTPS موثوق في بيئة العميل.

## النسخ الاحتياطي

يجب نسخ العنصرين معًا:

1. ملف SQLite (`coursemanagement.db`).
2. مجلد `CourseManagement.Uploads` أو المسار المحدد في `FileUploads__RootPath`.

استعادة واحد بدون الآخر قد ينتج Metadata تشير إلى ملفات غير موجودة.

يوصى بنسخة احتياطية يومية مع الاحتفاظ بعدة نسخ تاريخية وتجربة الاستعادة دوريًا.

## فحص ما قبل التسليم

- CI أخضر على Commit التسليم.
- لا توجد أسرار أو كلمات مرور أو قواعد بيانات أو Uploads داخل Git.
- فتح `/health` يعيد نجاحًا.
- Swagger مغلق في Production إلا إذا قرر العميل فتحه خلف حماية.
- تسجيل Student جديد يعمل.
- Login/Logout واستعادة الجلسة تعمل.
- Admin يستطيع ترقية Instructor وإدارة المستخدمين.
- Instructor يستطيع إنشاء كورس ورفع غلاف وPreview ودرس ومرفق.
- Guest يستطيع استكشاف الكورسات ومشاهدة Preview فقط.
- Student غير المسجل لا يستطيع الوصول لمحتوى الدروس.
- Student المسجل يستطيع تشغيل الفيديو وتنزيل المرفقات.
- التصميم لا يسبب overflow على أحجام الهاتف المختبرة.
- عنوان وهوية Flutter Web تظهر باسم «منصة المعرفة» وليس اسم قالب Flutter.
- قاعدة البيانات ومجلد الملفات لهما صلاحيات ونسخ احتياطي.

## ما لا يجب وضعه في التسليم داخل Git

- `*.db`, `*.db-wal`, `*.db-shm`
- `CourseManagement.Uploads/`
- User Secrets
- JWT production secret
- Android keystore أو كلمات مروره
- ملفات نشر تحتوي بيانات اعتماد

هذه العناصر مستبعدة أو يجب إدارتها من بيئة العميل فقط.
