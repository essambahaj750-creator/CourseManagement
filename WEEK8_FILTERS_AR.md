# تطوير Week 8 — فلترة منصة الكورسات وتكامل API

## الهدف

تم تطوير كتالوج الكورسات ليصبح تجربة Full-Stack حقيقية: تدخل معايير البحث من واجهة MVC أو عميل Flutter، تمر عبر عقد Application مشترك، ثم تُنفذ داخل EF Core على SQLite مع ترتيب وتقسيم صفحات.

## Architecture

يعتمد التنفيذ على Clean Architecture. يحتوي Domain على `CourseSearchCriteria` و`CourseSortBy` ونتيجة البحث، وتحتوي Application على `CourseFilterDto` و`CourseCatalogDto`، بينما ينفذ Infrastructure الاستعلام داخل `CourseRepository` ويحوّل النتائج في `CourseService`. تستخدم MVC وREST API العقد نفسه بدل تكرار منطق الفلترة في كل واجهة.

## الفلاتر المدعومة

| الفلتر | اسم Query String | السلوك |
|---|---|---|
| البحث | `q` | يبحث في العنوان والوصف واسم المدرّس |
| المدرّس | `instructorId` | يقيّد النتائج بمدرّس محدد |
| أقل سعر | `minPrice` | يستبعد الكورسات الأقل من القيمة |
| أعلى سعر | `maxPrice` | يستبعد الكورسات الأعلى من القيمة |
| الترتيب | `sort` | featured، newest، price-low، price-high، title |
| الصفحة | `page` | تبدأ من 1 وتُضبط إلى حد آمن |
| حجم الصفحة | `pageSize` | يُضبط بين 6 و24 |

إذا أُرسل نطاق سعر معكوس، يتم تصحيحه تلقائيًا. وإذا أُرسل ترتيب غير معروف، يعود النظام إلى `featured`.

## Screens وNavigation

تحتوي صفحة `/Courses` على رأس واضح للكتالوج، لوحة فلاتر جانبية، ملخص للفلاتر المطبقة، نتائج Grid، تبديل Grid/List، حالة فارغة، وترقيم صفحات. على الشاشات الصغيرة تتحول لوحة الفلاتر إلى Drawer مع زر فتح وإغلاق، بينما يبقى AppBar وDrawer العام وBottom Navigation متوافقين مع التصميم العربي RTL.

تظل المسارات الأساسية واضحة في MVC، ويقابلها تطبيق Flutter مستقل داخل `CourseManagement.Flutter`:

```text
MVC:    /                       Dashboard
MVC:    /Courses                Catalog
MVC:    /Courses/Details/{id}   Course Details
MVC:    /Enrollments            My Enrollments
MVC:    /Admin/Users            User Management
MVC:    /Admin/Enrollments      Enrollment Management

Flutter: /                       Dashboard
Flutter: /courses                Catalog + filters
Flutter: /courses/:id            Course Details
Flutter: /enrollments            My Enrollments
Flutter: /manage/courses         Course CRUD [Instructor/Admin]
Flutter: /admin/users            User Management [Admin]
Flutter: /admin/enrollments      Enrollment Management [Admin]
```

## API Integration

### البحث

```http
GET /api/course/search?q=flutter&minPrice=10&maxPrice=500&sort=price-low&page=1&pageSize=6
```

مثال استجابة:

```json
{
  "items": [],
  "totalCount": 0,
  "page": 1,
  "pageSize": 6,
  "totalPages": 0
}
```

### المدرّسون

```http
GET /api/course/instructors
```

يعيد قائمة صغيرة تحتوي على `id` و`name` فقط، دون كشف البريد أو أي بيانات حساب غير لازمة للفلاتر.

### عميل Flutter

يستخدم `CourseManagement.Flutter/lib/core/network/api_client.dart` العقد نفسه مع query parameters typed، ويحوّل الاستجابة الصفحية إلى `CourseCatalog`. شاشة الكتالوج تعيد تحميل النتائج عند تغيير البحث أو السعر أو المدرس أو الترتيب، وتعرض loading/error/empty/retry. كما أن `CourseManagement.Flutter/lib/features/profile/admin_courses_page.dart` يضيف CRUD حقيقيًا عبر `POST /api/course` و`PUT /api/course/{id}` و`DELETE /api/course/{id}`، مع حراسة GoRouter ومسار Drawer يظهر فقط للـInstructor/Admin.

## الجودة والأمان

الفلاتر تُنفذ في Backend باستخدام استعلامات EF Core، ولا تعتمد على JavaScript كحاجز أمني. تم تطبيع القيم وحدود الصفحة، والإبقاء على صلاحيات CRUD وAnti-Forgery كما هي. عمليات الكتابة ما زالت تتطلب الأدوار المناسبة، بينما بحث الكتالوج عام.

تم اختبار المسارات محليًا عبر HTTPS، وفحص `/health`، واختبار صفحة `/Courses` بالمعايير الافتراضية والمفلترة. كما أضيفت اختبارات لعقد الفلترة، ويحتوي مشروع Flutter على اختبارات نماذج وفلاتر ناجحة. أُجري smoke test حقيقي على API المعزولة شمل CORS وJWT، تسجيل Student، Course CRUD كاملًا، البحث المفلتر، التسجيل والإلغاء، وقوائم Admin.

## ملاحظة توسعة مستقبلية

الحقول الحالية لا تحتوي على Category أو Level أو Duration. إضافة هذه الفلاتر تتطلب تحديث Entity وDbContext وMigration وDTO والـAPI وواجهة MVC وعميل Flutter معًا؛ لا يتم عرض فلاتر شكلية لا تدعمها قاعدة البيانات.
