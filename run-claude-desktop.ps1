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

# 1. Проверка активности VPN / Proxy (порты 10808, 10809, 2080, 7890 или системный TUN/VPN)
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
        if ($async.AsyncWaitHandle.WaitOne(800, $false)) {
            $client.EndConnect($async)
            $client.Close()
            $proxyPort = $port
            break
        }
        $client.Close()
    } catch {}
}

$isTunMode = $false
$blockedCountries = @("RU", "BY", "IR", "KP", "CU", "SY")
$targetTz = "UTC"

if ($proxyPort) {
    Write-Host "OK (Локальный прокси порт $proxyPort)" -ForegroundColor Green
    Write-Host "[2/4] Проверка внешнего IP через Proxy... " -NoNewline
    try {
        $check = Invoke-RestMethod -Uri "https://ipinfo.io/json" -Proxy "http://127.0.0.1:$proxyPort" -TimeoutSec 5
        if ($blockedCountries -contains $check.country) {
            Write-Host "ОШИБКА!" -ForegroundColor Red
            Write-Host ""
            Write-Host "[-] КРИТИЧЕСКАЯ ОШИБКА: Прокси вернул IP из заблокированного региона ($($check.ip) [$($check.country)])!" -ForegroundColor Red
            Write-Host "[-] Запуск отменен для страховки от утечки реального IP." -ForegroundColor Red
            Write-Host ""
            Read-Host "Нажмите Enter для выхода..."
            exit 1
        }
        if ($check.timezone) { $targetTz = $check.timezone }
        Write-Host "OK ($($check.ip) [$($check.country)], TZ: $targetTz)" -ForegroundColor Green
    } catch {
        Write-Host "ОШИБКА!" -ForegroundColor Red
        Write-Host "[-] Не удалось проверить IP через Proxy: $_" -ForegroundColor Red
        Read-Host "Нажмите Enter для выхода..."
        exit 1
    }
} else {
    # Проверка на системный VPN / TUN (Amnezia, Outline, WireGuard, OpenVPN)
    try {
        $check = Invoke-RestMethod -Uri "https://ipinfo.io/json" -TimeoutSec 4 -ErrorAction Stop
        if ($blockedCountries -contains $check.country) {
            Write-Host "ОШИБКА!" -ForegroundColor Red
            Write-Host ""
            Write-Host "[-] VPN/Proxy не запущен! Текущий IP: $($check.ip) [$($check.country)]" -ForegroundColor Red
            Write-Host "[-] Запуск остановлен (Kill-Switch). Включите VPN и повторите запуск." -ForegroundColor Yellow
            Write-Host ""
            Read-Host "Нажмите Enter для выхода..."
            exit 1
        }
        $isTunMode = $true
        if ($check.timezone) { $targetTz = $check.timezone }
        Write-Host "OK (Системный VPN / TUN режим)" -ForegroundColor Green
        Write-Host "[2/4] Проверка внешнего IP (TUN)... " -NoNewline
        Write-Host "OK ($($check.ip) [$($check.country)], TZ: $targetTz)" -ForegroundColor Green
    } catch {
        Write-Host "ОШИБКА!" -ForegroundColor Red
        Write-Host ""
        Write-Host "[-] Нет подключения к интернету или VPN/Proxy выключен!" -ForegroundColor Red
        Write-Host "[-] Запуск Claude Desktop остановлен (Kill-Switch активен)." -ForegroundColor Red
        Write-Host ""
        Read-Host "Нажмите Enter для выхода..."
        exit 1
    }
}

# 3. Подготовка изолированного профиля и очистка блокировок
Write-Host "[3/4] Подготовка изолированного профиля... " -ForegroundColor Cyan

# Отключаем фоновую приостановку UWP в Windows
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Claude_pzs8sxrjxfjjc"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "Disabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPath -Name "DisabledByUser" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# Universal Session Vault & Smart Detection
$profileDir = Join-Path $PSScriptRoot "data\desktop-profile"
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$vaultDir = Join-Path $env:USERPROFILE ".claude-sandbox-vault\desktop-profile"
$itemsToSync = @("Local State", "Network", "Local Storage", "Session Storage", "IndexedDB", "WebStorage", "ant-did", "Preferences", "config.json", "claude_desktop_config.json")

$hasLocalLogin = Test-Path "$profileDir\Network\Cookies"
$hasVaultLogin = Test-Path "$vaultDir\Network\Cookies"

if (-not $hasLocalLogin -and $hasVaultLogin) {
    Write-Host "  [*] ОБНАРУЖЕНА АКТИВНАЯ АВТОРИЗАЦИЯ В СЕЙФЕ СЕССИЙ (SESSION VAULT)!" -ForegroundColor Green
    Write-Host "      Автоматическое восстановление сессии в эту песочницу... " -NoNewline -ForegroundColor Cyan
    foreach ($item in $itemsToSync) {
        $src = Join-Path $vaultDir $item
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $profileDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "OK!" -ForegroundColor Green
    $hasLocalLogin = Test-Path "$profileDir\Network\Cookies"
}

if (-not $hasLocalLogin) {
    # Поиск сессии в альтернативных песочницах и Windows
    $potentialSources = @(
        "D:\claude-secure-sandbox\data\desktop-profile",
        (Join-Path $env:LOCALAPPDATA "AnthropicClaude"),
        (Join-Path $env:LOCALAPPDATA "Claude"),
        (Join-Path $env:LOCALAPPDATA "Claude-Data\claude_pzs8sxrjxfjjc")
    )
    $foundSource = $null
    foreach ($ps in $potentialSources) {
        if ((Test-Path "$ps\Network\Cookies") -and ($ps -ne $profileDir)) {
            $foundSource = $ps
            break
        }
    }
    
    if ($foundSource) {
        Write-Host ""
        Write-Host "==========================================================" -ForegroundColor Yellow
        Write-Host " [*] ОБНАРУЖЕН СУЩЕСТВУЮЩИЙ АККАУНТ CLAUDE DESKTOP!" -ForegroundColor Yellow
        Write-Host "==========================================================" -ForegroundColor Yellow
        Write-Host "  Найдена сохранённая авторизация: $foundSource" -ForegroundColor DarkGray
        Write-Host "  Хотите скопировать сессию в песочницу и Сейф?" -ForegroundColor Gray
        $importChoice = Read-Host "  Импортировать сессию? [Y/n] (Enter = Да)"
        if ($importChoice -eq "" -or $importChoice -match "^[yYдД]") {
            Write-Host "  [*] Клонирование авторизации и истории в песочницу... " -NoNewline -ForegroundColor Cyan
            foreach ($item in $itemsToSync) {
                $srcItem = Join-Path $foundSource $item
                if (Test-Path $srcItem) {
                    Copy-Item -Path $srcItem -Destination $profileDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            # Зеркалируем в Universal Vault
            if (-not (Test-Path $vaultDir)) { New-Item -ItemType Directory -Path $vaultDir -Force | Out-Null }
            foreach ($item in $itemsToSync) {
                $srcItem = Join-Path $profileDir $item
                if (Test-Path $srcItem) {
                    Copy-Item -Path $srcItem -Destination $vaultDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Host "OK!" -ForegroundColor Green
            Write-Host "  [OK] Сессия перенесена! Вы будете сразу залогинены в своем аккаунте." -ForegroundColor Green
        } else {
            Write-Host "  [*] Запуск с чистого профиля (потребуется отдельный вход)." -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

# Снятие блокировок Chromium singleton lock
$lockFiles = @("lockfile", "SingletonLock", "SingletonSocket", "SingletonCookie")
foreach ($lf in $lockFiles) {
    $p = Join-Path $profileDir $lf
    if (Test-Path $p) {
        Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
    }
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

$candidatePaths = @(
    (Join-Path $env:LOCALAPPDATA "AnthropicClaude\claude.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Claude\Claude.exe"),
    (Join-Path $env:PROGRAMFILES "Claude\Claude.exe"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\Claude_pzs8sxrjxfjjc\claude-desktop.exe")
)

$aliasExe = $null
foreach ($cp in $candidatePaths) {
    if (Test-Path $cp) {
        $aliasExe = $cp
        break
    }
}

if (-not $aliasExe) {
    $squirrelApp = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "AnthropicClaude") -Filter "claude.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($squirrelApp) {
        $aliasExe = $squirrelApp.FullName
    }
}

if (-not $aliasExe) {
    $pkg = Get-AppxPackage *Claude* -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg -and (Test-Path (Join-Path $pkg.InstallLocation "app\claude.exe"))) {
        $aliasExe = Join-Path $pkg.InstallLocation "app\claude.exe"
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
    "--lang=en-US",
    "--disable-breakpad",
    "--disable-crash-reporter",
    "--disable-client-side-phishing-detection",
    "--disable-component-update",
    "--disable-domain-reliability",
    "--disable-sync",
    "--no-pings",
    "--enable-features=DnsOverHttps",
    "--dns-over-https-templates=https://chrome.cloudflare-dns.com/dns-query",
    "--user-data-dir=`"$profileDir`""
)

if ($isTunMode) {
    # В режиме TUN весь сетевой стек уже маршрутизируется через виртуальный адаптер VPN
    $appArgs += "--force-webrtc-ip-handling-policy=default_public_interface_only"
} else {
    # В режиме локального прокси принудительно направляем трафик и отключаем непроксированный UDP
    $appArgs += "--proxy-server=http://127.0.0.1:$proxyPort"
    $appArgs += "--force-webrtc-ip-handling-policy=disable_non_proxied_udp"
    $appArgs += "--enforce-webrtc-ip-permission-check"
}

# Переменные окружения для защиты часового пояса и подавления телеметрии
$env:TZ = $targetTz
$env:LANG = "en_US.UTF-8"
if (-not $isTunMode) {
    $env:HTTP_PROXY = "http://127.0.0.1:$proxyPort"
    $env:HTTPS_PROXY = "http://127.0.0.1:$proxyPort"
    $env:ALL_PROXY = "socks5://127.0.0.1:$proxyPort"
}
$env:DISABLE_TELEMETRY = "1"
$env:DO_NOT_TRACK = "1"
$env:DISABLE_ERROR_REPORTING = "1"
$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
$env:DISABLE_GROWTHBOOK = "1"

# Запуск скрытого независимого сторожа (Watchdog)
$watchdogPath = Join-Path $PSScriptRoot "claude-watchdog.ps1"
if (Test-Path $watchdogPath) {
    $wdArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdogPath`" -launcherPid $PID -profileDir `"$profileDir`""
    if ($isTunMode) { $wdArgs += " -liveKillSwitch" }
    else { $wdArgs += " -tripwire" }
    Start-Process powershell.exe -ArgumentList $wdArgs -WindowStyle Hidden
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
    Stop-Process -Name "claude", "claude-desktop", "chrome-native-host" -Force -ErrorAction SilentlyContinue
    taskkill /F /IM claude.exe /IM claude-desktop.exe /IM chrome-native-host.exe /T 2>$null | Out-Null
    foreach ($lf in $lockFiles) {
        $p = Join-Path $profileDir $lf
        if (Test-Path $p) {
            Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
        }
    }
    # Зеркалирование свежей рабочей сессии в Universal Session Vault
    if (Test-Path "$profileDir\Network\Cookies") {
        if (-not (Test-Path $vaultDir)) { New-Item -ItemType Directory -Path $vaultDir -Force | Out-Null }
        foreach ($item in $itemsToSync) {
            $src = Join-Path $profileDir $item
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $vaultDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
