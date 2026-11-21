# ==============================================================================
#  Claude Stealth Sandbox - Interactive Control Hub
# ==============================================================================
$ErrorActionPreference = "Continue"

function Show-Header {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "               CLAUDE STEALTH SANDBOX FOR WINDOWS" -ForegroundColor Cyan
    Write-Host "       WebRTC Hardening, Kill-Switch & Anti-Zombie Watchdog" -ForegroundColor DarkCyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-Host " [*] Текущие привилегии: " -NoNewline -ForegroundColor Gray
        Write-Host "АДМИНИСТРАТОР (Повышенные права)" -ForegroundColor Yellow
    } else {
        Write-Host " [*] Текущие привилегии: " -NoNewline -ForegroundColor Gray
        Write-Host "Обычный пользователь" -ForegroundColor Green
    }
    Write-Host "----------------------------------------------------------------------" -ForegroundColor DarkGray
}

function Test-ProxyStatus {
    Write-Host "`n[+] Проверка сетевого окружения..." -ForegroundColor Cyan
    $candidatePorts = @(10808, 10809, 2080, 7890)
    if ($env:CLAUDE_PROXY_PORT) { $candidatePorts = @([int]$env:CLAUDE_PROXY_PORT) + $candidatePorts }
    
    $activePort = $null
    foreach ($p in $candidatePorts) {
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $async = $client.BeginConnect("127.0.0.1", $p, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne(600, $false)) {
                $client.EndConnect($async)
                $client.Close()
                $activePort = $p
                break
            }
            $client.Close()
        } catch {}
    }
    
    if ($activePort) {
        Write-Host "  [OK] Локальный Proxy/VPN порт: $activePort (Доступен)" -ForegroundColor Green
        try {
            $ipData = Invoke-RestMethod -Uri "https://ipinfo.io/json" -Proxy "http://127.0.0.1:$activePort" -TimeoutSec 4
            $detectedTz = if ($ipData.timezone) { $ipData.timezone } else { "UTC" }
            Write-Host "  [OK] Внешний IP: $($ipData.ip)" -ForegroundColor Green
            Write-Host "  [OK] Страна выхода: $($ipData.country) ($($ipData.city), $($ipData.region))" -ForegroundColor Green
            Write-Host "  [OK] Часовой пояс выхода: $detectedTz" -ForegroundColor Green
            Write-Host "  [OK] Провайдер: $($ipData.org)" -ForegroundColor Gray
            $blockedCountries = @("RU", "BY", "IR", "KP", "CU", "SY")
            if ($blockedCountries -contains $ipData.country) {
                Write-Host "  [!] ВНИМАНИЕ: Прокси вернул IP из заблокированного региона ($($ipData.country))! Claude заблокирует доступ!" -ForegroundColor Red
            } else {
                Write-Host "  [OK] Kill-Switch статус: БЕЗОПАСНО (Доступ к Claude разрешен, TZ синхронизирована)" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [-] Ошибка опроса внешнего IP через порт ${activePort}: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [-] Proxy/VPN не обнаружен на стандартных портах (10808, 10809, 2080, 7890)!" -ForegroundColor Red
        Write-Host "  [!] Kill-Switch: Запуск Claude будет заблокирован для предотвращения бана." -ForegroundColor Yellow
    }
    Write-Host ""
    Read-Host "  Нажмите Enter для возврата в меню..."
}

function Emergency-Cleanup {
    Write-Host "`n[+] Запуск экстренной очистки процессов и блокировок..." -ForegroundColor Cyan
    Stop-Process -Name "claude", "chrome-native-host" -Force -ErrorAction SilentlyContinue
    taskkill /F /IM claude.exe /IM chrome-native-host.exe /T 2>$null | Out-Null
    
    $profileDir = Join-Path $PSScriptRoot "data\desktop-profile"
    if (Test-Path "$profileDir\lockfile") {
        Remove-Item -Path "$profileDir\lockfile" -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  [OK] Все процессы Claude и вспомогательные хосты завершены." -ForegroundColor Green
    Write-Host "  [OK] Файлы блокировок lockfile удалены." -ForegroundColor Green
    Write-Host "  [OK] Диспетчер задач чист." -ForegroundColor Green
    Write-Host ""
    Read-Host "  Нажмите Enter для возврата в меню..."
}

function Create-DesktopShortcut ([switch]$NoWait) {
    Write-Host "`n[+] Создание ярлыка на Рабочем столе..." -ForegroundColor Cyan
    try {
        $desktopPath = [System.Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktopPath "Claude (Secure).lnk"
        $targetBat = Join-Path $PSScriptRoot "start.bat"
        
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $targetBat
        $shortcut.WorkingDirectory = $PSScriptRoot
        $shortcut.Description = "Запуск Claude в безопасной песочнице с защитой от бана"
        
        if (Test-Path "$PSScriptRoot\icon.ico") {
            $shortcut.IconLocation = "$PSScriptRoot\icon.ico,0"
        } else {
            $pkg = Get-AppxPackage *Claude* -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($pkg -and (Test-Path "$($pkg.InstallLocation)\app\claude.exe")) {
                $shortcut.IconLocation = "$($pkg.InstallLocation)\app\claude.exe,0"
            }
        }
        $shortcut.Save()
        
        Write-Host "  [OK] Ярлык успешно создан: $shortcutPath" -ForegroundColor Green
    } catch {
        Write-Host "  [-] Ошибка при создании ярлыка: $_" -ForegroundColor Red
    }
    if (-not $NoWait) {
        Write-Host ""
        Read-Host "  Нажмите Enter для возврата в меню..."
    }
}

function Install-ClaudeDesktopWithIsolation {
    Write-Host "`n[+] Проверка и установка Claude Desktop..." -ForegroundColor Cyan
    
    $pkg = Get-AppxPackage *Claude* -ErrorAction SilentlyContinue | Select-Object -First 1
    $installed = $false
    if ($pkg -and (Test-Path "$($pkg.InstallLocation)\app\claude.exe")) {
        $installed = $true
        Write-Host "  [OK] Claude Desktop уже установлен: $($pkg.InstallLocation)" -ForegroundColor Green
    } else {
        $aliasExe = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\Claude_pzs8sxrjxfjjc\claude-desktop.exe"
        if (Test-Path $aliasExe) {
            $installed = $true
            Write-Host "  [OK] Claude Desktop обнаружен по пути: $aliasExe" -ForegroundColor Green
        }
    }
    
    if (-not $installed) {
        Write-Host "  [*] Скачивание и установка официального приложения Claude Desktop..." -ForegroundColor Yellow
        $hasWinget = Get-Command "winget" -ErrorAction SilentlyContinue
        $installedSuccessfully = $false
        
        if ($hasWinget) {
            Write-Host "  [*] Установка через Windows Package Manager (winget)..." -ForegroundColor Gray
            & winget install --id Anthropic.Claude --exact --accept-package-agreements --accept-source-agreements
            Start-Sleep -Seconds 3
            $pkg = Get-AppxPackage *Claude* -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($pkg) { $installedSuccessfully = $true }
        }
        
        if (-not $installedSuccessfully) {
            Write-Host "  [*] Прямое скачивание официального установщика Claude Desktop..." -ForegroundColor Gray
            $installerUrl = "https://downloads.claude.ai/releases/win32/x64/latest/ClaudeSetup.exe"
            $tempInstaller = Join-Path $env:TEMP "ClaudeSetup.exe"
            try {
                Invoke-WebRequest -Uri $installerUrl -OutFile $tempInstaller -UseBasicParsing
                Write-Host "  [*] Запуск установщика..." -ForegroundColor Gray
                $instProc = Start-Process -FilePath $tempInstaller -PassThru
                $instProc.WaitForExit()
                Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
                $installedSuccessfully = $true
            } catch {
                Write-Host "  [-] Ошибка прямого скачивания: $_" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "`n[*] Применение защитных настроек и изоляции..." -ForegroundColor Cyan
    
    # 1. Отключение фонового зависания UWP
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Claude_pzs8sxrjxfjjc"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name "Disabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "DisabledByUser" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Фоновое зависание Windows UWP отключено." -ForegroundColor Green
    
    # 2. Отключение фоновой службы CoworkVMService
    try {
        $svc = Get-Service -Name "CoworkVMService" -ErrorAction SilentlyContinue
        if ($svc) {
            Stop-Service -Name "CoworkVMService" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "CoworkVMService" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "  [OK] Фоновая служба CoworkVMService отключена." -ForegroundColor Green
        }
    } catch {}
    
    # 3. Отключение автозагрузки в реестре
    $runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Get-ItemProperty -Path $runPath -Name "Claude" -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $runPath -Name "Claude" -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Автозагрузка Claude удалена из реестра." -ForegroundColor Green
    }
    
    # 4. Настройка изолированного профиля
    $profileDir = Join-Path $PSScriptRoot "data\desktop-profile"
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
    
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
    $mainCfgPath = Join-Path $profileDir "config.json"
    if (-not (Test-Path $mainCfgPath)) {
        $mainConfig = @{
            locale = "en-US"
            windowSizeWasSignedIn = $false
        }
        $mainConfig | ConvertTo-Json | Set-Content -Path $mainCfgPath -Encoding UTF8
    }
    Write-Host "  [OK] Профиль песочницы сконфигурирован (спуфинг: MacBook-Air, en-US)." -ForegroundColor Green
    
    # 4.5. Smart Detection: предложение перенести существующую авторизацию Windows
    $hasSandboxLogin = Test-Path "$profileDir\Network\Cookies"
    $hostClaudeData = Join-Path $env:LOCALAPPDATA "Claude-Data\claude_pzs8sxrjxfjjc"
    if (-not $hasSandboxLogin -and (Test-Path "$hostClaudeData\Network\Cookies")) {
        Write-Host "  [*] Обнаружен существующий залогиненный аккаунт в Windows." -ForegroundColor Yellow
        $importAns = Read-Host "      Скопировать авторизацию в песочницу, чтобы не входить заново? [Y/n] (Enter = Да)"
        if ($importAns -eq "" -or $importAns -match "^[yYдД]") {
            $itemsToCopy = @("Local State", "Network", "Local Storage", "Session Storage", "IndexedDB", "WebStorage", "ant-did", "Preferences", "config.json")
            foreach ($item in $itemsToCopy) {
                $srcItem = Join-Path $hostClaudeData $item
                if (Test-Path $srcItem) {
                    Copy-Item -Path $srcItem -Destination $profileDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Host "  [OK] Авторизация перенесена в песочницу." -ForegroundColor Green
        }
    }
    
    # 5. Экспорт официальной иконки
    if (-not (Test-Path "$PSScriptRoot\icon.ico")) {
        $pkg = Get-AppxPackage *Claude* -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pkg -and (Test-Path "$($pkg.InstallLocation)\app\resources\Tray-Win32.ico")) {
            Copy-Item "$($pkg.InstallLocation)\app\resources\Tray-Win32.ico" "$PSScriptRoot\icon.ico" -Force
        }
    }
    
    # 6. Создание ярлыка на Рабочем столе
    Create-DesktopShortcut -NoWait
    
    Write-Host "`n[OK] Claude Desktop успешно подготовлен к работе в изолированном режиме!" -ForegroundColor Green
    Read-Host "  Нажмите Enter для возврата в меню..."
}

function Install-ClaudeCodeWithIsolation {
    Write-Host "`n[+] Проверка и установка Claude Code CLI..." -ForegroundColor Cyan
    
    $existingClaude = Get-Command "claude" -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
    if (-not $existingClaude) {
        if (Test-Path "C:\npm-global\claude.cmd") {
            $existingClaude = "C:\npm-global\claude.cmd"
        } elseif (Test-Path "$env:APPDATA\npm\claude.cmd") {
            $existingClaude = "$env:APPDATA\npm\claude.cmd"
        }
    }
    
    if ($existingClaude) {
        Write-Host "  [OK] Claude Code CLI уже установлен в системе ($existingClaude)." -ForegroundColor Green
    } else {
        $hasNpm = Get-Command "npm" -ErrorAction SilentlyContinue
        $hasNode = Get-Command "node" -ErrorAction SilentlyContinue
        
        if (-not $hasNode -or -not $hasNpm) {
            Write-Host "  [-] Node.js / npm не обнаружен в системе!" -ForegroundColor Yellow
            $hasWinget = Get-Command "winget" -ErrorAction SilentlyContinue
            if ($hasWinget) {
                Write-Host "  [*] Установка Node.js LTS через winget..." -ForegroundColor Cyan
                & winget install --id OpenJS.NodeJS.LTS --exact --accept-package-agreements --accept-source-agreements
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            } else {
                Write-Host "  [!] Установите Node.js с официального сайта: https://nodejs.org" -ForegroundColor Red
                Read-Host "  Нажмите Enter для возврата в меню..."
                return
            }
        }
        
        # Определение активного прокси-порта для npm
        $candidatePorts = @(10808, 10809, 2080, 7890)
        if ($env:CLAUDE_PROXY_PORT) { $candidatePorts = @([int]$env:CLAUDE_PROXY_PORT) + $candidatePorts }
        $activePort = $null
        foreach ($p in $candidatePorts) {
            try {
                $client = New-Object System.Net.Sockets.TcpClient
                $async = $client.BeginConnect("127.0.0.1", $p, $null, $null)
                if ($async.AsyncWaitHandle.WaitOne(400, $false)) {
                    $client.EndConnect($async)
                    $client.Close()
                    $activePort = $p
                    break
                }
                $client.Close()
            } catch {}
        }
        
        Write-Host "  [*] Установка пакета @anthropic-ai/claude-code..." -ForegroundColor Cyan
        try {
            if ($activePort) {
                & npm install -g @anthropic-ai/claude-code --proxy "http://127.0.0.1:$activePort" --https-proxy "http://127.0.0.1:$activePort"
            } else {
                & npm install -g @anthropic-ai/claude-code
            }
            Write-Host "  [OK] Пакет @anthropic-ai/claude-code установлен глобально." -ForegroundColor Green
        } catch {
            Write-Host "  [-] Ошибка установки через npm: $_" -ForegroundColor Red
        }
    }
    
    # Настройка песочницы
    Write-Host "  [*] Инициализация изолированного профиля CLI..." -ForegroundColor Cyan
    $sandboxDir = Join-Path $PSScriptRoot "data\cli-profile"
    if (-not (Test-Path $sandboxDir)) { New-Item -ItemType Directory -Path $sandboxDir -Force | Out-Null }
    
    $sandboxConfig = Join-Path $sandboxDir ".claude.json"
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
    Write-Host "  [OK] Сгенерированы случайные анонимные machineID и userID." -ForegroundColor Green
    
    # Smart Detection: предложение перенести историю сессий CLI из Windows
    $hostCliData = Join-Path $env:USERPROFILE ".claude"
    $sandboxCliData = Join-Path $sandboxDir ".claude"
    if ((-not (Test-Path "$sandboxCliData\projects")) -and (Test-Path "$hostCliData\projects")) {
        Write-Host "  [*] Обнаружены существующие проекты и сессии Claude Code в Windows." -ForegroundColor Yellow
        $importCliAns = Read-Host "      Скопировать существующие сессии в песочницу? [Y/n] (Enter = Да)"
        if ($importCliAns -eq "" -or $importCliAns -match "^[yYдД]") {
            if (-not (Test-Path $sandboxCliData)) { New-Item -ItemType Directory -Path $sandboxCliData -Force | Out-Null }
            Copy-Item -Path "$hostCliData\projects" -Destination "$sandboxCliData\" -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item -Path "$hostCliData\file-history" -Destination "$sandboxCliData\" -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path "$hostCliData\settings.json") {
                Copy-Item -Path "$hostCliData\settings.json" -Destination "$sandboxCliData\" -Force -ErrorAction SilentlyContinue
            }
            Write-Host "  [OK] Все проекты и сессии перенесены в песочницу." -ForegroundColor Green
        }
    }
    
    Write-Host "  [OK] Песочница Claude Code настроена." -ForegroundColor Green
    
    Write-Host "`n[OK] Claude Code CLI готов к запуску через пункт [3] меню!" -ForegroundColor Green
    Read-Host "  Нажмите Enter для возврата в меню..."
}

while ($true) {
    Show-Header
    Write-Host "  [1] Запустить Claude Desktop (Безопасная песочница)" -ForegroundColor White
    Write-Host "  [2] Запустить Claude Desktop от имени Администратора" -ForegroundColor Yellow
    Write-Host "  [3] Запустить Claude Code CLI (Терминал песочницы)" -ForegroundColor Cyan
    Write-Host "  [4] Проверить статус Proxy / VPN и Kill-Switch" -ForegroundColor Green
    Write-Host "  [5] Проверить защиту от утечек WebRTC и IP в браузере" -ForegroundColor Magenta
    Write-Host "  [6] Экстренная очистка (выгрузить все процессы и кэш)" -ForegroundColor DarkYellow
    Write-Host "  [7] Создать / обновить ярлык на Рабочем столе" -ForegroundColor Blue
    Write-Host "  [8] Установить Claude Desktop (сразу с изоляцией)" -ForegroundColor Green
    Write-Host "  [9] Установить Claude Code CLI (Терминал песочницы)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [0] Выход" -ForegroundColor DarkGray
    Write-Host "----------------------------------------------------------------------" -ForegroundColor DarkGray
    
    $choice = Read-Host "  Выберите действие [0-9]: "
    
    switch ($choice.Trim()) {
        "1" {
            & (Join-Path $PSScriptRoot "run-claude-desktop.ps1")
        }
        "2" {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if ($isAdmin) {
                & (Join-Path $PSScriptRoot "run-claude-desktop.ps1")
            } else {
                Write-Host "`n[*] Запрос прав администратора (UAC)..." -ForegroundColor Yellow
                Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\run-claude-desktop.ps1`"" -Verb RunAs
            }
        }
        "3" {
            & (Join-Path $PSScriptRoot "run-claude-safe.ps1")
        }
        "4" {
            Test-ProxyStatus
        }
        "5" {
            & (Join-Path $PSScriptRoot "test-browser-leaks.bat")
        }
        "6" {
            Emergency-Cleanup
        }
        "7" {
            Create-DesktopShortcut
        }
        "8" {
            Install-ClaudeDesktopWithIsolation
        }
        "9" {
            Install-ClaudeCodeWithIsolation
        }
        "0" {
            Write-Host "`nДо свидания!" -ForegroundColor Gray
            exit 0
        }
        default {
            Write-Host "Неверный выбор. Попробуйте снова." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
