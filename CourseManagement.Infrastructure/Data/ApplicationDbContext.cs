using CourseManagement.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace CourseManagement.Infrastructure.Data;

public class ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
    : DbContext(options)
{
    public DbSet<User> Users { get; set; }
    public DbSet<Course> Courses { get; set; }
    public DbSet<Enrollment> Enrollments { get; set; }
    public DbSet<CourseAsset> CourseAssets { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            // NOCASE makes both the unique index and every equality comparison
            // case-insensitive. SQLite TEXT columns default to BINARY collation, which
            // let "A@x.com" and "a@x.com" coexist and made mixed-case logins fail.
            entity.Property(e => e.Email).IsRequired().HasMaxLength(256).UseCollation("NOCASE");
            // يولّد User.SecurityStamp قيمته في طبقة Domain، لذلك لا نعتمد على دالة SQL Server.
            entity.Property(e => e.SecurityStamp)
                .IsRequired();
            entity.Property(e => e.IsActive).IsRequired().HasDefaultValue(true);
            entity.HasIndex(e => e.Email).IsUnique();
        });

        modelBuilder.Entity<Course>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title).IsRequired().HasMaxLength(200);
            entity.Property(e => e.Description).IsRequired().HasMaxLength(2000);
            entity.Property(e => e.ImageUrl).HasMaxLength(500);
            // SQLite لا يملك نوع decimal أصليًا؛ نخزّن السعر كسنتات INTEGER مع إبقاء API بصيغة decimal.
            entity.Property(e => e.Price)
                .HasConversion(
                    value => decimal.ToInt64(decimal.Round(value * 100m, 0, MidpointRounding.AwayFromZero)),
                    value => value / 100m);

            entity.HasOne(e => e.Instructor)
                  .WithMany()
                  .HasForeignKey(e => e.InstructorId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<CourseAsset>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.OriginalFileName).IsRequired().HasMaxLength(255);
            entity.Property(e => e.StoredFileName).IsRequired().HasMaxLength(120);
            entity.Property(e => e.ContentType).IsRequired().HasMaxLength(150);
            entity.Property(e => e.Type).IsRequired();
            entity.Property(e => e.CreatedAtUtc).IsRequired();
            entity.HasIndex(e => new { e.CourseId, e.Type });
            entity.HasOne(e => e.Course)
                  .WithMany(c => c.Assets)
                  .HasForeignKey(e => e.CourseId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Enrollment>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.CompletedLessonAssetIds)
                  .IsRequired()
                  .HasDefaultValue("[]");

            entity.HasOne(e => e.User)
                  .WithMany()
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Course)
                  .WithMany()
                  .HasForeignKey(e => e.CourseId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.UserId, e.CourseId }).IsUnique();
        });
    }
}