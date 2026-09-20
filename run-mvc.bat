@echo off
setlocal
cd /d "%~dp0"

echo ===============================================
echo CourseManagement.Web - MVC Launcher
echo ===============================================

where dotnet >nul 2>nul
if errorlevel 1 (
    echo ERROR: .NET 10 SDK is not installed or is not on PATH.
    pause
    exit /b 1
)

if not exist "CourseManagement.Web\CourseManagement.Web.csproj" (
    echo ERROR: Run this file from the repository root.
    pause
    exit /b 1
)

if "%JwtSettings__Secret%"=="" (
    set /p "JwtSettings__Secret=Enter a temporary JWT secret (minimum 32 characters): "
)

if "%JwtSettings__Secret%"=="" (
    echo ERROR: JwtSettings__Secret is required.
    pause
    exit /b 1
)

set "ASPNETCORE_ENVIRONMENT=Development"
set "Database__ApplyMigrations=true"
set "SeedAdmin__Enabled=false"

echo.
echo Starting MVC at https://localhost:7026 ...
echo Open: https://localhost:7026/Account/Login
 echo.

dotnet run --project "CourseManagement.Web\CourseManagement.Web.csproj" --launch-profile https

pause
