@echo off
chcp 65001 >nul
cd /d "%~dp0"
title WebRTC and IP Leak Audit

echo =========================================================
echo    WebRTC and IP Leak Verification Tool
echo =========================================================
echo.

set PROXY_PORT=10808
if not "%CLAUDE_PROXY_PORT%"=="" set PROXY_PORT=%CLAUDE_PROXY_PORT%

rem Detect active proxy port if default 10808 is closed
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "$ports = @(10808, 10809, 2080, 7890); if ($env:CLAUDE_PROXY_PORT) { $ports = @([int]$env:CLAUDE_PROXY_PORT) + $ports }; foreach ($p in $ports) { try { $c = New-Object System.Net.Sockets.TcpClient; $a = $c.BeginConnect('127.0.0.1', $p, $null, $null); if ($a.AsyncWaitHandle.WaitOne(300, $false)) { $c.EndConnect($a); $c.Close(); Write-Output $p; break } $c.Close() } catch {} }"') do set "PROXY_PORT=%%i"

rem Find Chrome or Edge
set TARGET_BROWSER=
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
    set "TARGET_BROWSER=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
) else if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    set "TARGET_BROWSER=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
)

if "%TARGET_BROWSER%"=="" (
    echo [-] Chrome or Edge not found. Please test manually at browserleaks.com/webrtc
    pause
    exit /b 1
)

echo [*] Launching temporary isolated browser profile through proxy (127.0.0.1:%PROXY_PORT%)...
echo [*] Checking browserleaks.com/webrtc and browserleaks.com/ip...

start "" "%TARGET_BROWSER%" --proxy-server="http://127.0.0.1:%PROXY_PORT%" --force-webrtc-ip-handling-policy=disable_non_proxied_udp --enforce-webrtc-ip-permission-check --lang=en-US --user-data-dir="%~dp0data\audit-profile" "https://browserleaks.com/webrtc" "https://browserleaks.com/ip"

echo.
echo [+] Opened browserleaks.com. Verify that:
echo     1. WebRTC Public IP matches your Proxy/VPN exit node (NO Russian/host IP).
echo     2. WebRTC Local IP is not leaked.
echo.
pause
