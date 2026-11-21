<#
.SYNOPSIS
    Claude Stealth Watchdog - background cleanup supervisor & active Kill-Switch.
.DESCRIPTION
    Monitors parent launcher PID and immediately terminates all lingering Claude processes
    and helper native hosts when the console window is closed, preventing the Windows UWP
    "Suspended / In Pause" background leak.
    Also provides live Kill-Switch for TUN/VPN modes to abort immediately if connection leaks.
#>
param(
    [int]$launcherPid = 0,
    [string]$profileDir = "",
    [switch]$liveKillSwitch = $false
)

$blockedCountries = @("RU", "BY", "IR", "KP", "CU", "SY")

if ($launcherPid -gt 0) {
    $proc = Get-Process -Id $launcherPid -ErrorAction SilentlyContinue
    if ($proc) {
        if ($liveKillSwitch) {
            # Active Kill-Switch loop for TUN / System VPN mode
            while (-not $proc.HasExited) {
                Start-Sleep -Seconds 4
                try {
                    $check = Invoke-RestMethod -Uri "https://ipinfo.io/json" -TimeoutSec 3 -ErrorAction SilentlyContinue
                    if ($check -and ($blockedCountries -contains $check.country)) {
                        # Critical IP leak detected: terminate immediately!
                        break
                    }
                } catch {}
            }
        } else {
            $proc.WaitForExit()
        }
    }
}

# Forcefully terminate any lingering Claude & native host processes
Stop-Process -Name "claude", "claude-desktop", "chrome-native-host" -Force -ErrorAction SilentlyContinue
taskkill /F /IM claude.exe /IM claude-desktop.exe /IM chrome-native-host.exe /T 2>$null | Out-Null

# Clean up Chromium singleton locks if profile directory was provided
if ($profileDir) {
    $lockFiles = @("lockfile", "SingletonLock", "SingletonSocket", "SingletonCookie")
    foreach ($lf in $lockFiles) {
        $p = Join-Path $profileDir $lf
        if (Test-Path $p) {
            Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
        }
    }
}
