# حارس خادم القاعات — يتحقق كل دقيقة عبر المهمة المجدولة
# ويعيد تشغيل server.js تلقائياً إن لم يكن يعمل.
$ErrorActionPreference = 'SilentlyContinue'

$node = 'C:\Program Files\nodejs\node.exe'
$work = 'D:\masar_app\masar_app'
$log  = 'C:\Users\JAMAL\AppData\Local\Temp\opencode\server.out.log'
$err  = 'C:\Users\JAMAL\AppData\Local\Temp\opencode\server.err.log'

if (-not (Test-Path -LiteralPath $node)) { exit 0 }

$running = Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -like '*server.js*' }

if ($running) { exit 0 }

# إن بدأ الخادم لكنه لم يُسمع للمنافذ بعد، انتظر قليلاً قبل إعادة الإطلاق.
Start-Process -FilePath $node -ArgumentList 'server.js' -WorkingDirectory $work `
    -RedirectStandardOutput $log -RedirectStandardError $err -WindowStyle Hidden
