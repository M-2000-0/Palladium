# watch-usb.ps1 - Background monitor for Palladium USB drive
# Runs via Task Scheduler; launches Palladium in a visible terminal when USB is plugged in.

param(
    [string]$MarkerFile = "autorun.inf",
    [int]$PollInterval = 3
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$usbRoot = (Get-Item $scriptPath).Root.Name.TrimEnd('\')
$markerPath = Join-Path $usbRoot $MarkerFile
$batPath = Join-Path $usbRoot "start-palladium.bat"

$traceFile = Join-Path $env:TEMP "palladium-watch.log"
"watch-usb.ps1 started at $(Get-Date)" | Out-File $traceFile -Append
"Watching for: $markerPath" | Out-File $traceFile -Append

while ($true) {
    if (Test-Path $markerPath) {
        "USB detected at $(Get-Date) - launching Palladium" | Out-File $traceFile -Append

        if (Test-Path $batPath) {
            # Use Shell.Application to open the terminal in the user's session
            $shell = New-Object -ComObject "Shell.Application"
            $shell.ShellExecute("cmd.exe", "/c `"$batPath`"", "", "open", 1)

            # Give the terminal a moment to open, then bring it to front
            Start-Sleep 2
            try {
                $shell = New-Object -ComObject "Shell.Application"
                # Minimize all windows briefly so the terminal becomes visible
                $shell.MinimizeAll()
                Start-Sleep 0.5
                # Find our terminal window and activate it
                $windows = (New-Object -ComObject "Shell.Application").Windows()
                # Restore the minimized windows
                $shell.UndoMinimizeALL()
            } catch {}
        } else {
            "WARNING: $batPath not found" | Out-File $traceFile -Append
        }

        while (Test-Path $markerPath) {
            Start-Sleep -Seconds $PollInterval
        }
        "USB removed at $(Get-Date)" | Out-File $traceFile -Append
    }
    Start-Sleep -Seconds $PollInterval
}
