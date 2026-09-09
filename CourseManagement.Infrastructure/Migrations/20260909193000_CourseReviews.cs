using CourseManagement.Infrastructure.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CourseManagement.Infrastructure.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20260909193000_CourseReviews")]
public partial class CourseReviews : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "CourseReviews",
            columns: table => new
            {
                Id = table.Column<int>(type: "INTEGER", nullable: false)
                    .Annotation("Sqlite:Autoincrement", true),
                UserId = table.Column<int>(type: "INTEGER", nullable: false),
                CourseId = table.Column<int>(type: "INTEGER", nullable: false),
                Rating = table.Column<int>(type: "INTEGER", nullable: false),
                Comment = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                UpdatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_CourseReviews", x => x.Id);
                table.ForeignKey(
                    name: "FK_CourseReviews_Courses_CourseId",
                    column: x => x.CourseId,
                    principalTable: "Courses",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_CourseReviews_Users_UserId",
                    column: x => x.UserId,
                    principalTable: "Users",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_CourseReviews_CourseId",
            table: "CourseReviews",
            column: "CourseId");

        migrationBuilder.CreateIndex(
            name: "IX_CourseReviews_UserId_CourseId",
            table: "CourseReviews",
            columns: new[] { "UserId", "CourseId" },
            unique: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "CourseReviews");
    }
}
