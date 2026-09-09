using CourseManagement.Infrastructure.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CourseManagement.Infrastructure.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20260909190000_CourseLearningProgress")]
public partial class CourseLearningProgress : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "CompletedLessonAssetIds",
            table: "Enrollments",
            type: "TEXT",
            nullable: false,
            defaultValue: "[]");

        migrationBuilder.AddColumn<DateTime>(
            name: "LastAccessedAtUtc",
            table: "Enrollments",
            type: "TEXT",
            nullable: true);

        migrationBuilder.AddColumn<int>(
            name: "LastLessonAssetId",
            table: "Enrollments",
            type: "INTEGER",
            nullable: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(
            name: "CompletedLessonAssetIds",
            table: "Enrollments");

        migrationBuilder.DropColumn(
            name: "LastAccessedAtUtc",
            table: "Enrollments");

        migrationBuilder.DropColumn(
            name: "LastLessonAssetId",
            table: "Enrollments");
    }
}
