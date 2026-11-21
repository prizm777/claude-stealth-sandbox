# ==============================================================================
#  Claude Stealth Sandbox - Interactive Control Hub
# ==============================================================================
$ErrorActionPreference = "Continue"

function Show-Header {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "             🛡️  CLAUDE STEALTH SANDBOX FOR WINDOWS  🛡️" -ForegroundColor Cyan
    Write-Host "      Anti-Ban, WebRTC Hardening, Kill-Switch & Anti-Zombie Watchdog" -ForegroundColor DarkCyan
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
        Write-Host "  [✓] Локальный Proxy/VPN порт: $activePort (Доступен)" -ForegroundColor Green
        try {
            $ipData = Invoke-RestMethod -Uri "https://ipinfo.io/json" -Proxy "http://127.0.0.1:$activePort" -TimeoutSec 4
            Write-Host "  [✓] Внешний IP: $($ipData.ip)" -ForegroundColor Green
            Write-Host "  [✓] Страна выхода: $($ipData.country) ($($ipData.city), $($ipData.region))" -ForegroundColor Green
            Write-Host "  [✓] Провайдер: $($ipData.org)" -ForegroundColor Gray
            if ($ipData.country -eq "RU") {
                Write-Host "  [!] ВНИМАНИЕ: Прокси вернул IP из РФ! Claude заблокирует доступ!" -ForegroundColor Red
            } else {
                Write-Host "  [✓] Kill-Switch статус: БЕЗОПАСНО (Доступ к Claude разрешен)" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [-] Ошибка опроса внешнего IP через порт ${activePort}: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [-] Proxy/VPN не обнаружен на стандартных портах (10808, 10809, 2080, 7890)!" -ForegroundColor Red
        Write-Host "  [!] Kill-Switch: Запуск Claude будет заблокирован для предотвращения бана." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Нажмите любую клавишу для возврата в меню..." -ForegroundColor Gray
    [void][System.Console]::ReadKey($true)
}

function Emergency-Cleanup {
    Write-Host "`n[+] Запуск экстренной очистки процессов и блокировок..." -ForegroundColor Cyan
    Stop-Process -Name "claude", "chrome-native-host" -Force -ErrorAction SilentlyContinue
    taskkill /F /IM claude.exe /IM chrome-native-host.exe /T 2>$null | Out-Null
    
    $profileDir = Join-Path $PSScriptRoot "data\desktop-profile"
    if (Test-Path "$profileDir\lockfile") {
        Remove-Item -Path "$profileDir\lockfile" -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  [✓] Все процессы Claude и вспомогательные хосты завершены." -ForegroundColor Green
    Write-Host "  [✓] Файлы блокировок lockfile удалены." -ForegroundColor Green
    Write-Host "  [✓] Диспетчер задач чист." -ForegroundColor Green
    Write-Host ""
    Start-Sleep -Seconds 1
}

function Create-DesktopShortcut {
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
        
        # Попытка найти иконку Claude
        if (Test-Path "$PSScriptRoot\icon.ico") {
            $shortcut.IconLocation = "$PSScriptRoot\icon.ico,0"
        } else {
            $pkg = Get-AppxPackage *Claude* -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($pkg -and (Test-Path "$($pkg.InstallLocation)\app\claude.exe")) {
                $shortcut.IconLocation = "$($pkg.InstallLocation)\app\claude.exe,0"
            }
        }
        $shortcut.Save()
        
        Write-Host "  [✓] Ярлык успешно создан: $shortcutPath" -ForegroundColor Green
    } catch {
        Write-Host "  [-] Ошибка при создании ярлыка: $_" -ForegroundColor Red
    }
    Write-Host ""
    Start-Sleep -Seconds 2
}

while ($true) {
    Show-Header
    Write-Host "  [1] 🚀 Запустить Claude Desktop (Безопасная песочница)" -ForegroundColor White
    Write-Host "  [2] ⚡ Запустить Claude Desktop от имени Администратора" -ForegroundColor Yellow
    Write-Host "  [3] 💻 Запустить Claude Code CLI (Терминал песочницы)" -ForegroundColor Cyan
    Write-Host "  [4] 🌐 Проверить статус Proxy / VPN и Kill-Switch" -ForegroundColor Green
    Write-Host "  [5] 🧪 Проверить защиту от утечек WebRTC и IP в браузере" -ForegroundColor Magenta
    Write-Host "  [6] 🧹 Экстренная очистка (выгрузить все процессы и кэш)" -ForegroundColor DarkYellow
    Write-Host "  [7] 📌 Создать ярлык на Рабочем столе" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  [0] ❌ Выход" -ForegroundColor DarkGray
    Write-Host "----------------------------------------------------------------------" -ForegroundColor DarkGray
    
    $choice = Read-Host "  Выберите действие [0-7]"
    
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
