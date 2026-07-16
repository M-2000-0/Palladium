# watch-usb.ps1 - Background monitor for Palladium USB drive
# Runs silently via Task Scheduler; launches Palladium when USB is plugged in.
# Place this in palladium/ alongside the other scripts.

param(
    [string]$MarkerFile = "autorun.inf",
    [int]$PollInterval = 3
)

# Determine the script's own drive letter (where this script lives)
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$usbRoot = (Get-Item $scriptPath).Root.Name.TrimEnd('\')
$markerPath = Join-Path $usbRoot $MarkerFile
$batPath = Join-Path $usbRoot "start-palladium.bat"

# Write a small trace file so we can verify it's running
$traceFile = Join-Path $env:TEMP "palladium-watch.log"
"watch-usb.ps1 started at $(Get-Date)" | Out-File $traceFile -Append
"Watching for: $markerPath" | Out-File $traceFile -Append

while ($true) {
    if (Test-Path $markerPath) {
        "USB detected at $(Get-Date) - launching Palladium" | Out-File $traceFile -Append
        if (Test-Path $batPath) {
            Start-Process -FilePath $batPath -WindowStyle Normal
        } else {
            "WARNING: $batPath not found" | Out-File $traceFile -Append
        }
        # Block: don't relaunch while the USB is still plugged in
        while (Test-Path $markerPath) {
            Start-Sleep -Seconds $PollInterval
        }
        "USB removed at $(Get-Date)" | Out-File $traceFile -Append
    }
    Start-Sleep -Seconds $PollInterval
}
