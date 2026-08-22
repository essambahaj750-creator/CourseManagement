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

تظل المسارات الأساسية واضحة:

```text
/                       Dashboard
/Courses                Catalog
/Courses/Details/{id}   Course Details
/Enrollments            My Enrollments
/Admin/Users            User Management
/Admin/Enrollments      Enrollment Management
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

## الجودة والأمان

الفلاتر تُنفذ في Backend باستخدام استعلامات EF Core، ولا تعتمد على JavaScript كحاجز أمني. تم تطبيع القيم وحدود الصفحة، والإبقاء على صلاحيات CRUD وAnti-Forgery كما هي. عمليات الكتابة ما زالت تتطلب الأدوار المناسبة، بينما بحث الكتالوج عام.

تم اختبار المسارات محليًا عبر HTTPS، وفحص `/health`، واختبار صفحة `/Courses` بالمعايير الافتراضية والمفلترة. كما أضيفت اختبارات لعقد الفلترة، ليصبح إجمالي اختبارات المشروع ستة اختبارات ناجحة.

## ملاحظة توسعة مستقبلية

الحقول الحالية لا تحتوي على Category أو Level أو Duration. إضافة هذه الفلاتر تتطلب تحديث Entity وDbContext وMigration وDTO والـAPI وواجهة MVC وعميل Flutter معًا؛ لا يتم عرض فلاتر شكلية لا تدعمها قاعدة البيانات.
