$dirs = @(
    "CourseManagement.Domain\Entities",
    "CourseManagement.Domain\Enums",
    "CourseManagement.Domain\Interfaces",
    "CourseManagement.Application\DTOs",
    "CourseManagement.Application\Interfaces",
    "CourseManagement.Infrastructure\Data",
    "CourseManagement.Infrastructure\Repositories",
    "CourseManagement.Infrastructure\Services",
    "CourseManagement.API\Controllers",
    "CourseManagement.API\Properties"
)
foreach ($dir in $dirs) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$files = @(
    "CourseManagement.Domain\Entities\User.cs",
    "CourseManagement.Domain\Entities\Course.cs",
    "CourseManagement.Domain\Entities\Enrollment.cs",
    "CourseManagement.Domain\Enums\Role.cs",
    "CourseManagement.Domain\Interfaces\IUserRepository.cs",
    "CourseManagement.Domain\Interfaces\ICourseRepository.cs",
    "CourseManagement.Domain\Interfaces\IEnrollmentRepository.cs",
    "CourseManagement.Application\DTOs\RegisterDto.cs",
    "CourseManagement.Application\DTOs\LoginDto.cs",
    "CourseManagement.Application\DTOs\AuthResponseDto.cs",
    "CourseManagement.Application\DTOs\CourseDto.cs",
    "CourseManagement.Application\DTOs\CourseResponseDto.cs",
    "CourseManagement.Application\DTOs\EnrollDto.cs",
    "CourseManagement.Application\Interfaces\IAuthService.cs",
    "CourseManagement.Application\Interfaces\ICourseService.cs",
    "CourseManagement.Application\Interfaces\IEnrollmentService.cs",
    "CourseManagement.Infrastructure\Data\ApplicationDbContext.cs",
    "CourseManagement.Infrastructure\Repositories\UserRepository.cs",
    "CourseManagement.Infrastructure\Repositories\CourseRepository.cs",
    "CourseManagement.Infrastructure\Repositories\EnrollmentRepository.cs",
    "CourseManagement.Infrastructure\Services\AuthService.cs",
    "CourseManagement.Infrastructure\Services\CourseService.cs",
    "CourseManagement.Infrastructure\Services\EnrollmentService.cs",
    "CourseManagement.API\Program.cs",
    "CourseManagement.API\appsettings.json"
)
foreach ($file in $files) { New-Item -ItemType File -Force -Path $file | Out-Null }
$libProj = "<Project Sdk=""Microsoft.NET.Sdk"">`n  <PropertyGroup>`n    <TargetFramework>net10.0</TargetFramework>`n  </PropertyGroup>`n</Project>"
$webProj = "<Project Sdk=""Microsoft.NET.Sdk.Web"">`n  <PropertyGroup>`n    <TargetFramework>net10.0</TargetFramework>`n  </PropertyGroup>`n</Project>"
Set-Content -Path "CourseManagement.Domain\CourseManagement.Domain.csproj" -Value $libProj -Encoding utf8
Set-Content -Path "CourseManagement.Application\CourseManagement.Application.csproj" -Value $libProj -Encoding utf8
Set-Content -Path "CourseManagement.Infrastructure\CourseManagement.Infrastructure.csproj" -Value $libProj -Encoding utf8
Set-Content -Path "CourseManagement.API\CourseManagement.API.csproj" -Value $webProj -Encoding utf8

dotnet new sln -n CourseManagement
dotnet sln add CourseManagement.Domain\CourseManagement.Domain.csproj
dotnet sln add CourseManagement.Application\CourseManagement.Application.csproj
dotnet sln add CourseManagement.Infrastructure\CourseManagement.Infrastructure.csproj
dotnet sln add CourseManagement.API\CourseManagement.API.csproj
