@echo off
chcp 65001 >nul
cd /d "%~dp0"
title WebRTC & IP Leak Audit

echo =========================================================
echo    WebRTC and IP Leak Verification Tool
echo =========================================================
echo.

set PROXY_PORT=10808

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
