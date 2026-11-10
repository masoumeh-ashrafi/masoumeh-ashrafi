@echo off
chcp 65001 >nul
setlocal
title ابزار انتقال خودکار پروژه به گیت‌هاب
color 0B

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%push-to-github.ps1"

echo ================================================================
echo              ابزار انتقال خودکار پروژه به گیت‌هاب
echo ================================================================
echo.

if not exist "%PS_SCRIPT%" (
    echo [خطا] فایل push-to-github.ps1 در کنار این فایل پیدا نشد.
    echo مسیر جستجو شده: "%PS_SCRIPT%"
    echo.
    echo لطفاً مطمئن شوید فایل‌های push-to-github.bat و push-to-github.ps1
    echo هر دو در یک پوشه قرار دارند و فایل را جابجا نکرده‌اید.
    echo.
    pause
    exit /b 1
)

where powershell >nul 2>nul
if errorlevel 1 (
    echo [خطا] برنامه PowerShell روی این سیستم پیدا نشد.
    echo لطفاً از نصب بودن PowerShell روی ویندوز خود مطمئن شوید.
    echo.
    pause
    exit /b 1
)

echo این ابزار پروژه شما را از روی دیسک به مخزن گیت‌هاب ارسال می‌کند.
echo لطفاً اطلاعات زیر را به ترتیب وارد کنید.
echo ^(برای استفاده از مقدار پیش‌فرض نمایش داده‌شده، فقط کلید Enter را بزنید^)
echo.

set "PROJECT_PATH="
set /p "PROJECT_PATH=مسیر پوشه پروژه روی دیسک [پیش‌فرض: D:\Projects]: "
if "%PROJECT_PATH%"=="" set "PROJECT_PATH=D:\Projects"

echo.
if not exist "%PROJECT_PATH%\" (
    echo [هشدار] مسیر وارد شده در حال حاضر روی دیسک وجود ندارد: %PROJECT_PATH%
    echo اسکریپت PowerShell در ادامه این موضوع را بررسی و اعلام خواهد کرد.
    echo.
)

set "REPO_URL="
set /p "REPO_URL=آدرس مخزن گیت‌هاب (مثال: https://github.com/username/repo.git): "

:askRepoAgain
if "%REPO_URL%"=="" (
    echo.
    echo [هشدار] آدرس مخزن گیت‌هاب نمی‌تواند خالی باشد.
    set /p "REPO_URL=آدرس مخزن گیت‌هاب را وارد کنید: "
    goto askRepoAgain
)

echo.
set "COMMIT_MSG="
set /p "COMMIT_MSG=پیام کامیت [پیش‌فرض: بروزرسانی خودکار پروژه]: "
if "%COMMIT_MSG%"=="" set "COMMIT_MSG=بروزرسانی خودکار پروژه"

echo.
set "BRANCH_NAME="
set /p "BRANCH_NAME=نام شاخه (Branch) [پیش‌فرض: main]: "
if "%BRANCH_NAME%"=="" set "BRANCH_NAME=main"

echo.
echo ================================================================
echo خلاصه اطلاعات وارد شده:
echo ----------------------------------------------------------------
echo مسیر پروژه   : %PROJECT_PATH%
echo آدرس مخزن    : %REPO_URL%
echo پیام کامیت   : %COMMIT_MSG%
echo نام شاخه     : %BRANCH_NAME%
echo ================================================================
echo.

set "CONFIRM="
set /p "CONFIRM=آیا اطلاعات فوق صحیح است و می‌خواهید ادامه دهید؟ (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo.
    echo عملیات توسط کاربر لغو شد. هیچ تغییری اعمال نشد.
    echo.
    pause
    exit /b 0
)

echo.
echo در حال اجرای اسکریپت PowerShell، لطفاً صبر کنید...
echo ----------------------------------------------------------------
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -ProjectPath "%PROJECT_PATH%" -RepoUrl "%REPO_URL%" -CommitMessage "%COMMIT_MSG%" -BranchName "%BRANCH_NAME%"

set "PS_EXIT_CODE=%ERRORLEVEL%"

echo.
echo ================================================================
if "%PS_EXIT_CODE%"=="0" (
    echo عملیات با موفقیت به پایان رسید. پروژه شما روی گیت‌هاب قرار گرفت.
) else (
    echo عملیات با خطا مواجه شد. کد خطا: %PS_EXIT_CODE%
    echo لطفاً پیام‌های نمایش داده‌شده در بالا را با دقت بررسی کنید.
    echo در صورت نیاز، این فایل را دوباره اجرا کرده و اطلاعات را اصلاح نمایید.
)
echo ================================================================
echo.

pause
endlocal
exit /b %PS_EXIT_CODE%