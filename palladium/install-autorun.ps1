# install-autorun.ps1 - Install Palladium USB autorun as a Windows scheduled task
# Run this once (as admin) to auto-start Palladium whenever the USB is plugged in.
# Run with -Remove to uninstall.

param(
    [switch]$Remove
)

$taskName = "Palladium USB Autorun"
$scriptPath = Join-Path $PSScriptRoot "watch-usb.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: watch-usb.ps1 not found at $scriptPath" -ForegroundColor Red
    exit 1
}

if ($Remove) {
    Write-Host "Removing scheduled task '$taskName'..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Done." -ForegroundColor Green
    exit 0
}

# Check if task already exists
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Task '$taskName' already exists. Updating..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

Write-Host "Creating scheduled task '$taskName'..." -ForegroundColor Cyan

# Action: run the watch script at user logon (hidden PowerShell window)
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

# Trigger: at user logon (not just startup — runs in user session)
$trigger = New-ScheduledTaskTrigger -AtLogOn

# Run as the current user, with lowest privileges
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -RunLevel "Limited" `
    -LogonType "Interactive"

# Settings: don't stop if running for days, allow manual start
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -Priority 7 `
    -ExecutionTimeLimit ([TimeSpan]::Zero)  # no time limit

# Register
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Force

if ($?) {
    Write-Host ""
    Write-Host "SUCCESS: Palladium will now auto-start when USB is plugged in." -ForegroundColor Green
    Write-Host ""
    Write-Host "How it works:" -ForegroundColor Cyan
    Write-Host "  - A background task runs at every login"
    Write-Host "  - It watches for the USB drive (detected by $scriptPath)"
    Write-Host "  - When USB is inserted -> launches start-palladium.bat in a terminal"
    Write-Host "  - When USB is removed -> waits silently"
    Write-Host ""
    Write-Host "To remove:" -ForegroundColor Yellow
    Write-Host "  powershell -File `"$PSScriptRoot\install-autorun.ps1`" -Remove"
    Write-Host ""
} else {
    Write-Host "ERROR: Failed to register task. Try running as Administrator." -ForegroundColor Red
}
