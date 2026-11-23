# ==============================================================================
#  Claude Code CLI Secure Sandbox Launcher
#  Features: Isolated Profile, Dynamic Drive, Hardware Spoofing & Watchdog
# ==============================================================================
$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   CLAUDE CODE SECURE SANDBOX LAUNCHER" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "[*] РЕЖИМ АДМИНИСТРАТОРА: ВКЛЮЧЕН" -ForegroundColor Yellow
    Write-Host "    (Claude Code запущен с полными правами Администратора и доступом ко всем консолям)" -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Host "[*] Обычный режим (без прав Администратора)." -ForegroundColor DarkGray
    Write-Host ""
}

# 1. Проверка активности VPN / Proxy (порты 10808, 10809, 2080, 7890 или системный TUN/VPN)
Write-Host "[1/5] Проверка подключения Proxy/VPN... " -NoNewline
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
    Write-Host "[2/5] Проверка внешнего IP через Proxy... " -NoNewline
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
        Write-Host "[-] Не удалось связаться с сервером проверки через прокси: $_" -ForegroundColor Red
        Read-Host "Нажмите Enter для выхода..."
        exit 1
    }
} else {
    # Проверка прямого соединения на системный VPN / TUN (Amnezia, Outline, WireGuard)
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
        Write-Host "[2/5] Проверка внешнего IP (TUN)... " -NoNewline
        Write-Host "OK ($($check.ip) [$($check.country)], TZ: $targetTz)" -ForegroundColor Green
    } catch {
        Write-Host "ОШИБКА!" -ForegroundColor Red
        Write-Host ""
        Write-Host "[-] Нет подключения к интернету или VPN/Proxy выключен!" -ForegroundColor Red
        Write-Host "[-] Запуск Claude Code остановлен (Kill-Switch активен)." -ForegroundColor Red
        Write-Host ""
        Read-Host "Нажмите Enter для выхода..."
        exit 1
    }
}

# 3. Идемпотентное монтирование виртуального диска (динамический выбор свободной буквы)
Write-Host "[3/5] Монтирование виртуального диска... " -NoNewline
$currentFolder = $PSScriptRoot
$availableLetters = @('X', 'Y', 'Z', 'W', 'V', 'U', 'T')
$driveLetter = $null

$substList = & subst
foreach ($line in $substList) {
    foreach ($l in $availableLetters) {
        if ($line -match "(?i)^$l\\:\s*=>\s*" + [regex]::Escape($currentFolder)) {
            $driveLetter = "$l`:"
            break
        }
    }
    if ($driveLetter) { break }
}

if (-not $driveLetter) {
    foreach ($l in $availableLetters) {
        if (-not (Get-PSDrive -Name $l -ErrorAction SilentlyContinue) -and -not (Test-Path "$l`:\")) {
            $driveLetter = "$l`:"
            & subst $driveLetter "$currentFolder" | Out-Null
            break
        }
    }
}

if (-not $driveLetter) {
    $driveLetter = "X:"
    & subst $driveLetter /D 2>$null | Out-Null
    & subst $driveLetter "$currentFolder" | Out-Null
}
Write-Host "OK (Диск $driveLetter)" -ForegroundColor Green

# 4. Настройка изолированной песочницы на диске
Write-Host "[4/5] Изоляция профиля и анонимизация окружения... " -ForegroundColor Cyan
$sandboxDir = "$driveLetter\data\cli-profile"
if (-not (Test-Path $sandboxDir)) {
    New-Item -ItemType Directory -Path $sandboxDir -Force | Out-Null
}

# Smart Detection & Universal Vault для Claude Code CLI
$sandboxCliData = Join-Path $sandboxDir ".claude"
$sandboxConfig = Join-Path $sandboxDir ".claude.json"
$vaultCliDir = Join-Path $env:USERPROFILE ".claude-sandbox-vault\cli-profile"
$hostCliData = Join-Path $env:USERPROFILE ".claude"
$hostCliConfig = Join-Path $env:USERPROFILE ".claude.json"

# 1. Восстановление из Universal Vault
if ((-not (Test-Path "$sandboxCliData\projects")) -and (Test-Path "$vaultCliDir\.claude\projects")) {
    Write-Host "  [*] ОБНАРУЖЕНЫ СЕССИИ CLI В СЕЙФЕ СЕССИЙ (SESSION VAULT)!" -ForegroundColor Green
    Write-Host "      Автоматическое восстановление проектов и авторизации... " -NoNewline -ForegroundColor Cyan
    if (-not (Test-Path $sandboxCliData)) { New-Item -ItemType Directory -Path $sandboxCliData -Force | Out-Null }
    Copy-Item -Path "$vaultCliDir\.claude\*" -Destination "$sandboxCliData\" -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path "$vaultCliDir\.claude.json") {
        Copy-Item -Path "$vaultCliDir\.claude.json" -Destination $sandboxConfig -Force -ErrorAction SilentlyContinue
    }
    Write-Host "OK! (Все диалоги и авторизация на месте)" -ForegroundColor Green
}

# 2. Если в Vault пусто, проверяем Host
if ((-not (Test-Path "$sandboxCliData\projects")) -and (Test-Path "$hostCliData\projects")) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host " [*] ОБНАРУЖЕНЫ СУЩЕСТВУЮЩИЕ СЕССИИ CLAUDE CODE CLI В WINDOWS!" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host "  Хотите скопировать историю проектов и авторизацию в песочницу?" -ForegroundColor Gray
    Write-Host "  (Все ваши прошлые диалоги будут доступны по команде /resume)" -ForegroundColor Gray
    Write-Host ""
    $importChoice = Read-Host "  Скопировать сессии в песочницу и Сейф? [Y/n] (Enter = Да)"
    if ($importChoice -eq "" -or $importChoice -match "^[yYдД]") {
        Write-Host "  [*] Клонирование истории проектов в песочницу... " -NoNewline -ForegroundColor Cyan
        if (-not (Test-Path $sandboxCliData)) { New-Item -ItemType Directory -Path $sandboxCliData -Force | Out-Null }
        Copy-Item -Path "$hostCliData\projects" -Destination "$sandboxCliData\" -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "$hostCliData\file-history" -Destination "$sandboxCliData\" -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path "$hostCliData\settings.json") {
            Copy-Item -Path "$hostCliData\settings.json" -Destination "$sandboxCliData\" -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $hostCliConfig) {
            Copy-Item -Path $hostCliConfig -Destination $sandboxConfig -Force -ErrorAction SilentlyContinue
        }
        # Зеркалируем в Universal Vault
        if (-not (Test-Path "$vaultCliDir\.claude")) { New-Item -ItemType Directory -Path "$vaultCliDir\.claude" -Force | Out-Null }
        Copy-Item -Path "$sandboxCliData\*" -Destination "$vaultCliDir\.claude\" -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $sandboxConfig) {
            Copy-Item -Path $sandboxConfig -Destination "$vaultCliDir\.claude.json" -Force -ErrorAction SilentlyContinue
        }
        Write-Host "OK!" -ForegroundColor Green
        Write-Host "  [OK] Все проекты и сессии перенесены!" -ForegroundColor Green
    } else {
        Write-Host "  [*] Запуск с чистого профиля CLI." -ForegroundColor DarkGray
    }
    Write-Host ""
}

if (-not (Test-Path $sandboxConfig)) {
    $randomMachineId = [System.Guid]::NewGuid().ToString("N") + [System.Guid]::NewGuid().ToString("N")
    $randomUserId = [System.Guid]::NewGuid().ToString("N") + [System.Guid]::NewGuid().ToString("N")
    $fakeConfig = @{
        firstStartTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        machineID = $randomMachineId
        userID = $randomUserId
        migrationVersion = 15
    }
    $fakeConfig | ConvertTo-Json | Set-Content -Path $sandboxConfig -Encoding UTF8
}

# Подмена системных переменных окружения
if (-not $isTunMode) {
    $env:HTTP_PROXY = "http://127.0.0.1:$proxyPort"
    $env:HTTPS_PROXY = "http://127.0.0.1:$proxyPort"
    $env:ALL_PROXY = "socks5://127.0.0.1:$proxyPort"
}
$env:USERPROFILE = $sandboxDir
$env:HOME = $sandboxDir
$env:CLAUDE_CONFIG_DIR = $sandboxDir
$env:APPDATA = "$sandboxDir\AppData\Roaming"
$env:LOCALAPPDATA = "$sandboxDir\AppData\Local"
$env:TEMP = "$sandboxDir\Temp"
$env:TMP = "$sandboxDir\Temp"
$env:USERNAME = "developer"
$env:USER = "developer"
$env:COMPUTERNAME = "MacBook-Air"
$env:TZ = $targetTz
$env:LANG = "en_US.UTF-8"

# Подавление телеметрии Anthropic
$env:DISABLE_TELEMETRY = "1"
$env:DO_NOT_TRACK = "1"
$env:DISABLE_ERROR_REPORTING = "1"
$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
$env:DISABLE_GROWTHBOOK = "1"
Write-Host "OK" -ForegroundColor Green

# 5. Поиск команды claude
$claudeCmd = Get-Command "claude" -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
if (-not $claudeCmd) {
    if (Test-Path "C:\npm-global\claude.cmd") {
        $claudeCmd = "C:\npm-global\claude.cmd"
    } elseif (Test-Path "$env:APPDATA\npm\claude.cmd") {
        $claudeCmd = "$env:APPDATA\npm\claude.cmd"
    }
}

if (-not $claudeCmd) {
    Write-Host "[-] ОШИБКА: Команда 'claude' (Claude Code CLI) не найдена!" -ForegroundColor Red
    Write-Host "    Установите её через: npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow
    Read-Host "Нажмите Enter для выхода..."
    exit 1
}

# 6. Запуск Claude Code внутри смонтированного диска
if ($isAdmin) {
    Write-Host "[5/5] Запуск Claude Code в режиме Администратора..." -ForegroundColor Yellow
} else {
    Write-Host "[5/5] Запуск Claude Code в изолированном режиме..." -ForegroundColor Cyan
}
Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray

Set-Location "$driveLetter\"

$finalArgs = @($args)
if ($isAdmin) {
    if ($finalArgs -notcontains "--dangerously-skip-permissions") {
        $finalArgs += "--dangerously-skip-permissions"
    }
}

# Запуск скрытого независимого сторожа (Watchdog)
$watchdogPath = Join-Path $PSScriptRoot "claude-watchdog.ps1"
if (Test-Path $watchdogPath) {
    $wdArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdogPath`" -launcherPid $PID"
    if ($isTunMode) { $wdArgs += " -liveKillSwitch" }
    Start-Process powershell.exe -ArgumentList $wdArgs -WindowStyle Hidden
}

try {
    & $claudeCmd $finalArgs
} finally {
    Set-Location $currentFolder
    Stop-Process -Name "claude" -Force -ErrorAction SilentlyContinue
    # Зеркалирование сессий CLI в Universal Vault
    if (Test-Path "$sandboxCliData\projects") {
        if (-not (Test-Path "$vaultCliDir\.claude")) { New-Item -ItemType Directory -Path "$vaultCliDir\.claude" -Force | Out-Null }
        Copy-Item -Path "$sandboxCliData\*" -Destination "$vaultCliDir\.claude\" -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $sandboxConfig) {
            Copy-Item -Path $sandboxConfig -Destination "$vaultCliDir\.claude.json" -Force -ErrorAction SilentlyContinue
        }
    }
}
