$log = 'D:\masar_app\masar_app\deploy\local-test\watchdog.log'
$nodeExe = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
$lkExe = 'D:\masar_app\masar_app\deploy\local-test\livekit-server.exe'
$lkCfg = 'D:\masar_app\masar_app\deploy\local-test\livekit-local.yaml'

function Ensure-Server([int]$Port, [string]$Exe, [string]$Args, [string]$WorkDir) {
    $up = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if (-not $up -and (Test-Path $Exe)) {
        $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
            CommandLine = "`"$Exe`" $Args"
            CurrentDirectory = $WorkDir
        }
        if ($r.ReturnValue -ne 0) {
            # خطة بديلة: التشغيل عبر Start-Process
            Start-Process -FilePath $Exe -ArgumentList $Args -WorkingDirectory $WorkDir -WindowStyle Hidden
        }
        Add-Content -Path $log -Value ("{0}  restarted port {1} ({2}) rc={3}" -f (Get-Date -Format 'MM-dd HH:mm:ss'), $Port, (Split-Path $Exe -Leaf), $r.ReturnValue)
    }
}

Ensure-Server 8123 "$env:ComSpec" '/c "D:\masar_app\masar_app\deploy\local-test\start-backend.cmd"' 'D:\masar_app\masar_app'
Ensure-Server 7880 $lkExe "--config `"$lkCfg`"" 'D:\masar_app\masar_app\deploy\local-test'
