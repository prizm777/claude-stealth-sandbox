<#
.SYNOPSIS
    Claude Stealth Watchdog - background cleanup supervisor.
.DESCRIPTION
    Monitors parent launcher PID and immediately terminates all lingering Claude processes
    and helper native hosts when the console window is closed, preventing the Windows UWP
    "Suspended / In Pause" background leak.
#>
param(
    [int]$launcherPid = 0,
    [string]$profileDir = ""
)

if ($launcherPid -gt 0) {
    $proc = Get-Process -Id $launcherPid -ErrorAction SilentlyContinue
    if ($proc) {
        $proc.WaitForExit()
    }
}

# Forcefully terminate any lingering Claude & native host processes
Stop-Process -Name "claude", "chrome-native-host" -Force -ErrorAction SilentlyContinue
taskkill /F /IM claude.exe /IM chrome-native-host.exe /T 2>$null | Out-Null

# Clean up Chromium singleton lockfile if profile directory was provided
if ($profileDir -and (Test-Path "$profileDir\lockfile")) {
    Remove-Item -Path "$profileDir\lockfile" -Force -ErrorAction SilentlyContinue
}
