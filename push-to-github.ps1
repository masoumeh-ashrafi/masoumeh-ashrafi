#requires -Version 5.1
<#
.SYNOPSIS
    ابزار انتقال خودکار پروژه از دیسک به یک مخزن گیت‌هاب (GitHub)

.DESCRIPTION
    این اسکریپت مسیر مشخص‌شده روی دیسک را در صورت نیاز به یک مخزن گیت تبدیل می‌کند،
    ریموت (remote) گیت‌هاب را تنظیم یا به‌روزرسانی می‌کند، فایل‌های تغییر یافته را
    Add و Commit می‌کند و در نهایت تغییرات را به شاخه مشخص‌شده Push می‌کند.
    تمام خطاهای رایج (نبود Git، نبود مسیر پروژه، شکست در Push و ...) با پیام فارسی
    واضح به کاربر نمایش داده می‌شود.

.PARAMETER ProjectPath
    مسیر پوشه پروژه روی دیسک. مقدار پیش‌فرض: D:\Projects

.PARAMETER RepoUrl
    آدرس مخزن گیت‌هاب (مثال: https://github.com/username/repo.git)
    در صورت عدم ارسال، از کاربر به صورت تعاملی پرسیده می‌شود.

.PARAMETER CommitMessage
    پیام کامیت. در صورت عدم ارسال، یک پیام پیش‌فرض همراه با تاریخ و زمان تولید می‌شود.

.PARAMETER BranchName
    نام شاخه‌ای که باید Push شود. مقدار پیش‌فرض: main

.EXAMPLE
    .\push-to-github.ps1 -ProjectPath "D:\Projects\MyApp" -RepoUrl "https://github.com/user/repo.git" -CommitMessage "بروزرسانی طراحی" -BranchName "main"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = "D:\Projects",

    [Parameter(Mandatory = $false)]
    [string]$RepoUrl,

    [Parameter(Mandatory = $false)]
    [string]$CommitMessage,

    [Parameter(Mandatory = $false)]
    [string]$BranchName = "main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# توابع کمکی برای نمایش پیام‌ها
# ---------------------------------------------------------------------------

function Write-InfoMsg {
    param([string]$Message)
    Write-Host "[اطلاعات] $Message" -ForegroundColor Cyan
}

function Write-SuccessMsg {
    param([string]$Message)
    Write-Host "[موفقیت] $Message" -ForegroundColor Green
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[هشدار] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[خطا] $Message" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# تابع اجرای دستورات گیت با مدیریت خطا
# ---------------------------------------------------------------------------

function Invoke-GitCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$IgnoreExitCode,

        [string]$FailureMessage = "اجرای دستور گیت با خطا مواجه شد."
    )

    $displayCommand = "git " + ($Arguments -join " ")
    Write-Host "در حال اجرا: $displayCommand" -ForegroundColor DarkGray

    $output = & git @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($output) {
        $output | ForEach-Object { Write-Host $_ }
    }

    if ($exitCode -ne 0 -and -not $IgnoreExitCode) {
        throw "$FailureMessage`nکد خروج گیت: $exitCode`nخروجی گیت:`n$($output -join "`n")"
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output   = $output
    }
}

# ---------------------------------------------------------------------------
# مرحله ۱: بررسی نصب بودن Git روی سیستم
# ---------------------------------------------------------------------------

Write-InfoMsg "در حال بررسی نصب بودن Git روی سیستم..."

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCommand) {
    Write-ErrorMsg "برنامه Git روی این سیستم نصب نیست یا در مسیر PATH قرار ندارد."
    Write-ErrorMsg "لطفاً ابتدا Git را از آدرس https://git-scm.com/download/win نصب کنید و دوباره اسکریپت را اجرا کنید."
    exit 1
}

Write-SuccessMsg "Git روی سیستم نصب است (مسیر: $($gitCommand.Source))."

# ---------------------------------------------------------------------------
# مرحله ۲: بررسی معتبر بودن مسیر پروژه
# ---------------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    Write-ErrorMsg "مسیر پروژه (ProjectPath) نباید خالی باشد."
    exit 1
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    Write-ErrorMsg "مسیر پروژه با آدرس '$ProjectPath' پیدا نشد."
    Write-ErrorMsg "لطفاً از صحیح بودن مسیر وارد شده مطمئن شوید و دوباره تلاش کنید."
    exit 1
}

Write-SuccessMsg "مسیر پروژه معتبر است: $ProjectPath"

# ---------------------------------------------------------------------------
# مرحله ۳: دریافت آدرس مخزن گیت‌هاب در صورت عدم ارسال
# ---------------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
    Write-WarnMsg "آدرس مخزن گیت‌هاب (RepoUrl) مشخص نشده است."
    $RepoUrl = Read-Host "لطفاً آدرس مخزن گیت‌هاب را وارد کنید (مثال: https://github.com/username/repo.git)"
}

if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
    Write-ErrorMsg "آدرس مخزن گیت‌هاب وارد نشد. عملیات متوقف شد."
    exit 1
}

$RepoUrl = $RepoUrl.Trim()

if ($RepoUrl -notmatch '^(https?://|git@)') {
    Write-ErrorMsg "آدرس مخزن وارد شده معتبر به نظر نمی‌رسد: $RepoUrl"
    Write-ErrorMsg "آدرس باید با https:// یا git@ شروع شود."
    exit 1
}

# ---------------------------------------------------------------------------
# مرحله ۴: تعیین پیام کامیت در صورت عدم ارسال
# ---------------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $CommitMessage = "بروزرسانی پروژه - $timestamp"
    Write-InfoMsg "پیام کامیت مشخص نشده بود، از پیام پیش‌فرض استفاده می‌شود: '$CommitMessage'"
}

if ([string]::IsNullOrWhiteSpace($BranchName)) {
    $BranchName = "main"
}

$BranchName = $BranchName.Trim()

# ---------------------------------------------------------------------------
# مرحله ۵: ورود به مسیر پروژه و اجرای عملیات گیت
# ---------------------------------------------------------------------------

$originalLocation = Get-Location

try {
    Push-Location -LiteralPath $ProjectPath

    Write-InfoMsg "مسیر فعلی: $(Get-Location)"

    # -------------------------------------------------------------------
    # بررسی وجود پوشه .git و راه‌اندازی مخزن در صورت نیاز
    # -------------------------------------------------------------------

    $gitFolderPath = Join-Path -Path (Get-Location) -ChildPath ".git"

    if (-not (Test-Path -LiteralPath $gitFolderPath -PathType Container)) {
        Write-InfoMsg "پوشه .git در این مسیر یافت نشد. در حال راه‌اندازی مخزن گیت جدید (git init)..."
        try {
            Invoke-GitCommand -Arguments @("init") -FailureMessage "راه‌اندازی مخزن گیت (git init) با خطا مواجه شد."
            Write-SuccessMsg "مخزن گیت با موفقیت راه‌اندازی شد."
        }
        catch {
            Write-ErrorMsg "امکان راه‌اندازی مخزن گیت وجود نداشت."
            Write-ErrorMsg $_.Exception.Message
            exit 1
        }
    }
    else {
        Write-InfoMsg "پوشه .git از قبل وجود دارد. از مخزن موجود استفاده می‌شود."
    }

    # -------------------------------------------------------------------
    # اطمینان از تنظیم بودن نام کاربری و ایمیل گیت (در صورت نبود، محلی تنظیم می‌شود)
    # -------------------------------------------------------------------

    $userNameResult = Invoke-GitCommand -Arguments @("config", "user.name") -IgnoreExitCode
    $userEmailResult = Invoke-GitCommand -Arguments @("config", "user.email") -IgnoreExitCode

    if ($userNameResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace(($userNameResult.Output -join ""))) {
        Write-WarnMsg "نام کاربری گیت (user.name) تنظیم نشده است. مقدار موقت محلی تنظیم می‌شود."
        Invoke-GitCommand -Arguments @("config", "user.name", "GitHub Uploader") -IgnoreExitCode | Out-Null
    }

    if ($userEmailResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace(($userEmailResult.Output -join ""))) {
        Write-WarnMsg "ایمیل گیت (user.email) تنظیم نشده است. مقدار موقت محلی تنظیم می‌شود."
        Invoke-GitCommand -Arguments @("config", "user.email", "uploader@local") -IgnoreExitCode | Out-Null
    }

    # -------------------------------------------------------------------
    # تنظیم یا به‌روزرسانی ریموت origin
    # -------------------------------------------------------------------

    Write-InfoMsg "در حال بررسی وضعیت ریموت 'origin'..."

    $remoteCheck = Invoke-GitCommand -Arguments @("remote", "get-url", "origin") -IgnoreExitCode

    if ($remoteCheck.ExitCode -eq 0) {
        Write-InfoMsg "ریموت 'origin' از قبل وجود دارد. آدرس آن به‌روزرسانی می‌شود."
        try {
            Invoke-GitCommand -Arguments @("remote", "set-url", "origin", $RepoUrl) -FailureMessage "به‌روزرسانی آدرس ریموت origin با خطا مواجه شد."
            Write-SuccessMsg "آدرس ریموت origin با موفقیت به‌روزرسانی شد."
        }
        catch {
            Write-ErrorMsg "امکان به‌روزرسانی ریموت origin وجود نداشت."
            Write-ErrorMsg $_.Exception.Message
            exit 1
        }
    }
    else {
        Write-InfoMsg "ریموت 'origin' وجود ندارد. در حال اضافه کردن آن..."
        try {
            Invoke-GitCommand -Arguments @("remote", "add", "origin", $RepoUrl) -FailureMessage "اضافه کردن ریموت origin با خطا مواجه شد."
            Write-SuccessMsg "ریموت origin با موفقیت اضافه شد."
        }
        catch {
            Write-ErrorMsg "امکان اضافه کردن ریموت origin وجود نداشت."
            Write-ErrorMsg $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------
    # افزودن تمام فایل‌ها به استیج (git add -A)
    # -------------------------------------------------------------------

    Write-InfoMsg "در حال افزودن فایل‌های تغییر یافته به استیج (git add -A)..."

    try {
        Invoke-GitCommand -Arguments @("add", "-A") -FailureMessage "افزودن فایل‌ها به استیج (git add) با خطا مواجه شد."
        Write-SuccessMsg "فایل‌ها با موفقیت به استیج اضافه شدند."
    }
    catch {
        Write-ErrorMsg "امکان افزودن فایل‌ها به استیج وجود نداشت."
        Write-ErrorMsg $_.Exception.Message
        exit 1
    }

    # -------------------------------------------------------------------
    # بررسی وجود تغییرات واقعی قبل از کامیت
    # -------------------------------------------------------------------

    $statusResult = Invoke-GitCommand -Arguments @("status", "--porcelain") -IgnoreExitCode
    $hasChanges = ($statusResult.Output -join "").Trim().Length -gt 0

    if (-not $hasChanges) {
        Write-WarnMsg "هیچ تغییری برای کامیت کردن وجود ندارد. مرحله کامیت نادیده گرفته می‌شود."
    }
    else {
        Write-InfoMsg "در حال ثبت کامیت با پیام: '$CommitMessage'"
        try {
            Invoke-GitCommand -Arguments @("commit", "-m", $CommitMessage) -FailureMessage "ثبت کامیت (git commit) با خطا مواجه شد."
            Write-SuccessMsg "کامیت با موفقیت ثبت شد."
        }
        catch {
            Write-ErrorMsg "امکان ثبت کامیت وجود نداشت."
            Write-ErrorMsg $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------
    # تنظیم نام شاخه فعلی به شاخه موردنظر
    # -------------------------------------------------------------------

    Write-InfoMsg "در حال تنظیم نام شاخه به '$BranchName'..."

    $branchRenameResult = Invoke-GitCommand -Arguments @("branch", "-M", $BranchName) -IgnoreExitCode

    if ($branchRenameResult.ExitCode -ne 0) {
        Write-WarnMsg "تغییر نام شاخه با مشکل مواجه شد. این موضوع معمولاً در صورت نبود هیچ کامیتی در مخزن رخ می‌دهد."
        Write-WarnMsg "اگر این اولین اجرای اسکریپت است و هنوز هیچ فایلی کامیت نشده، لطفاً از وجود حداقل یک فایل در مسیر پروژه مطمئن شوید."
    }

    # -------------------------------------------------------------------
    # ارسال تغییرات به گیت‌هاب (git push)
    # -------------------------------------------------------------------

    Write-InfoMsg "در حال ارسال تغییرات به گیت‌هاب (git push -u origin $BranchName)..."

    $pushResult = Invoke-GitCommand -Arguments @("push", "-u", "origin", $BranchName) -IgnoreExitCode

    if ($pushResult.ExitCode -eq 0) {
        Write-SuccessMsg "عملیات Push با موفقیت انجام شد. تغییرات روی گیت‌هاب قرار گرفت."
        Write-SuccessMsg "آدرس مخزن: $RepoUrl"
        Write-SuccessMsg "شاخه: $BranchName"
    }
    else {
        $outputText = ($pushResult.Output -join "`n")

        Write-ErrorMsg "عملیات Push با خطا مواجه شد."

        if ($outputText -match "(?i)authentication|could not read Username|Permission denied|fatal: Authentication") {
            Write-ErrorMsg "به نظر می‌رسد مشکل از احراز هویت گیت‌هاب است."
            Write-ErrorMsg "گیت‌هاب دیگر از رمز عبور عادی پشتیبانی نمی‌کند. لطفاً از Personal Access Token (PAT) یا SSH Key استفاده کنید."
            Write-ErrorMsg "راهنما: https://docs.github.com/en/authentication"
        }
        elseif ($outputText -match "(?i)rejected|non-fast-forward|fetch first") {
            Write-ErrorMsg "مخزن گیت‌هاب شامل تغییراتی است که در نسخه محلی شما وجود ندارد."
            Write-ErrorMsg "لطفاً ابتدا با دستور 'git pull origin $BranchName --rebase' تغییرات را دریافت کنید و سپس دوباره Push را اجرا کنید."
        }
        elseif ($outputText -match "(?i)repository not found|not found|does not exist") {
            Write-ErrorMsg "مخزن مشخص شده پیدا نشد. لطفاً آدرس مخزن و دسترسی خود به آن را بررسی کنید."
            Write-ErrorMsg "آدرس وارد شده: $RepoUrl"
        }
        else {
            Write-ErrorMsg "جزئیات خطا:"
            Write-ErrorMsg $outputText
        }

        exit 1
    }
}
catch {
    Write-ErrorMsg "خطای غیرمنتظره‌ای رخ داد:"
    Write-ErrorMsg $_.Exception.Message
    exit 1
}
finally {
    Set-Location -LiteralPath $originalLocation
}

Write-SuccessMsg "عملیات با موفقیت به پایان رسید."
exit 0