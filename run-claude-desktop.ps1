# ==============================================================================
#  Claude Desktop Secure Sandbox Launcher
#  Features: Kill-Switch, WebRTC Protection, Hardware Spoofing & Anti-Leak Watchdog
# ==============================================================================
$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   CLAUDE DESKTOP SECURE SANDBOX LAUNCHER" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "[*] РЕЖИМ АДМИНИСТРАТОРА: ВКЛЮЧЕН" -ForegroundColor Yellow
    Write-Host "    (Claude получит полные права Администратора и доступ ко всем консолям)" -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Host "[*] Обычный режим (без прав Администратора)." -ForegroundColor DarkGray
    Write-Host ""
}

# 1. Проверка активности VPN / Proxy (порты 10808, 10809, 2080, 7890)
Write-Host "[1/4] Проверка подключения Proxy/VPN... " -NoNewline
$proxyPort = $null
$candidatePorts = @(10808, 10809, 2080, 7890)
if ($env:CLAUDE_PROXY_PORT) {
    $candidatePorts = @([int]$env:CLAUDE_PROXY_PORT) + $candidatePorts
}

foreach ($port in $candidatePorts) {
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect("127.0.0.1", $port, $null, $null)
        if ($async.AsyncWaitHandle.WaitOne(1000, $false)) {
            $client.EndConnect($async)
            $client.Close()
            $proxyPort = $port
            break
        }
        $client.Close()
    } catch {}
}

if (-not $proxyPort) {
    Write-Host "ОШИБКА!" -ForegroundColor Red
    Write-Host ""
    Write-Host "[-] VPN/Proxy не запущен или локальные порты закрыты!" -ForegroundColor Red
    Write-Host "[-] Запуск Claude Desktop остановлен (Kill Switch активен)." -ForegroundColor Red
    Write-Host "[-] Твой реальный IP в безопасности. Включи VPN и повтори запуск." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Нажмите Enter для выхода..."
    exit 1
}
Write-Host "OK (порт $proxyPort)" -ForegroundColor Green

# 2. Проверка внешнего IP и страны через прокси (Kill-Switch)
Write-Host "[2/4] Проверка внешнего IP через Proxy... " -NoNewline
try {
    $check = Invoke-RestMethod -Uri "https://ipinfo.io/json" -Proxy "http://127.0.0.1:$proxyPort" -TimeoutSec 5
    if ($check.country -eq "RU") {
        Write-Host "ОШИБКА!" -ForegroundColor Red
        Write-Host ""
        Write-Host "[-] КРИТИЧЕСКАЯ ОШИБКА: Прокси вернул IP из РФ ($($check.ip))!" -ForegroundColor Red
        Write-Host "[-] Запуск отменен для защиты аккаунта от бана." -ForegroundColor Red
        Write-Host ""
        Read-Host "Нажмите Enter для выхода..."
        exit 1
    }
    Write-Host "OK ($($check.ip) [$($check.country)])" -ForegroundColor Green
} catch {
    Write-Host "ОШИБКА!" -ForegroundColor Red
    Write-Host ""
    Write-Host "[-] Не удалось проверить IP через Proxy: $_" -ForegroundColor Red
    Write-Host "[-] Запуск остановлен для безопасности." -ForegroundColor Red
    Write-Host ""
    Read-Host "Нажмите Enter для выхода..."
    exit 1
}

# 3. Подготовка изолированного профиля и очистка блокировок
Write-Host "[3/4] Подготовка изолированного профиля... " -NoNewline

# Отключаем фоновую приостановку UWP в Windows (предотвращает зависание в диспетчере задач)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Claude_pzs8sxrjxfjjc"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "Disabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPath -Name "DisabledByUser" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

$profileDir = Join-Path $PSScriptRoot "data\desktop-profile"
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Снятие блокировки Singleton Lock
if (Test-Path "$profileDir\lockfile") {
    Remove-Item -Path "$profileDir\lockfile" -Force -ErrorAction SilentlyContinue
}

# Спуфинг имени устройства (MacBook-Air) в конфиге
$cfgPath = Join-Path $profileDir "claude_desktop_config.json"
if (-not (Test-Path $cfgPath)) {
    $deviceConfig = @{
        preferences = @{
            coworkLegacyRootGrantsPruned = $true
            remoteToolsDeviceName = "MacBook-Air"
            launchPreviewPersistedWorkspaces = @()
            launchPreviewSessionScopedSessions = @()
            httpCacheZstdLatched = $true
            coworkWebSearchEnabled = $true
            coworkScheduledTasksEnabled = $false
            ccdScheduledTasksEnabled = $false
        }
    }
    $deviceConfig | ConvertTo-Json -Depth 4 | Set-Content -Path $cfgPath -Encoding UTF8
}

# Локаль en-US
$mainCfgPath = Join-Path $profileDir "config.json"
if (-not (Test-Path $mainCfgPath)) {
    $mainConfig = @{
        locale = "en-US"
        windowSizeWasSignedIn = $false
    }
    $mainConfig | ConvertTo-Json | Set-Content -Path $mainCfgPath -Encoding UTF8
}
Write-Host "OK" -ForegroundColor Green

# 4. Поиск бинарника Claude Desktop
Write-Host "[4/4] Запуск Claude Desktop (Secure Sandbox)..." -ForegroundColor Cyan

$aliasExe = "$env:LOCALAPPDATA\Microsoft\WindowsApps\Claude_pzs8sxrjxfjjc\claude-desktop.exe"
if (-not (Test-Path $aliasExe)) {
    $pkg = Get-AppxPackage *Claude* -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg -and (Test-Path "$($pkg.InstallLocation)\app\claude.exe")) {
        $aliasExe = "$($pkg.InstallLocation)\app\claude.exe"
    }
}

if (-not (Test-Path $aliasExe)) {
    Write-Host "[-] ОШИБКА: Исполняемый файл Claude Desktop не найден!" -ForegroundColor Red
    Write-Host "    Убедитесь, что официальное приложение Claude Desktop установлено." -ForegroundColor Yellow
    Read-Host "Нажмите Enter для выхода..."
    exit 1
}

# Аргументы безопасности Chromium / Electron
$appArgs = @(
    "--proxy-server=http://127.0.0.1:$proxyPort",
    "--force-webrtc-ip-handling-policy=disable_non_proxied_udp",
    "--enforce-webrtc-ip-permission-check",
    "--user-data-dir=`"$profileDir`"",
    "--lang=en-US",
    "--disable-breakpad",
    "--disable-crash-reporter"
)

# Переменные окружения для защиты часового пояса и подавления телеметрии
$env:TZ = "Europe/Berlin"
$env:LANG = "en_US.UTF-8"
$env:HTTP_PROXY = "http://127.0.0.1:$proxyPort"
$env:HTTPS_PROXY = "http://127.0.0.1:$proxyPort"
$env:ALL_PROXY = "socks5://127.0.0.1:$proxyPort"
$env:DISABLE_TELEMETRY = "1"
$env:DO_NOT_TRACK = "1"
$env:DISABLE_ERROR_REPORTING = "1"
$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
$env:DISABLE_GROWTHBOOK = "1"

# Запуск скрытого независимого сторожа (Watchdog)
$watchdogPath = Join-Path $PSScriptRoot "claude-watchdog.ps1"
if (Test-Path $watchdogPath) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdogPath`" -launcherPid $PID -profileDir `"$profileDir`"" -WindowStyle Hidden
}

if ($isAdmin) {
    Start-Process -FilePath $aliasExe -ArgumentList $appArgs -Verb RunAs
    Write-Host "[+] Claude Desktop запущен с ПРАВАМИ АДМИНИСТРАТОРА!" -ForegroundColor Green
} else {
    Start-Process -FilePath $aliasExe -ArgumentList $appArgs
    Write-Host "[+] Claude Desktop запущен на экране в изолированной среде!" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [i] КОНСОЛЬ РАБОТАЕТ В РЕЖИМЕ СУПЕРВИЗОРА" -ForegroundColor Cyan
Write-Host "  * Закроешь окно Claude     -> эта консоль закроется сама" -ForegroundColor Gray
Write-Host "  * Закроешь эту консоль (X) -> Claude закроется полностью," -ForegroundColor Gray
Write-Host "                                без зависших процессов в фоне" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

Start-Sleep -Seconds 3

try {
    while ($true) {
        Start-Sleep -Milliseconds 800
        $procs = Get-Process -Name "claude" -ErrorAction SilentlyContinue
        if (-not $procs) {
            break
        }
    }
} finally {
    Stop-Process -Name "claude", "chrome-native-host" -Force -ErrorAction SilentlyContinue
    taskkill /F /IM claude.exe /IM chrome-native-host.exe /T 2>$null | Out-Null
    if (Test-Path "$profileDir\lockfile") {
        Remove-Item -Path "$profileDir\lockfile" -Force -ErrorAction SilentlyContinue
    }
}
