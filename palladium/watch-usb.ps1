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
            # Launch Palladium in a visible, maximized terminal window
            try {
                $wshell = New-Object -ComObject WScript.Shell
                $wshell.Run("cmd.exe /c `"$batPath`"", 3, $false)  # 3=maximized, $false=no wait
            } catch {
                try {
                    $shell = New-Object -ComObject "Shell.Application"
                    $shell.ShellExecute("cmd.exe", "/c `"$batPath`"", "", "open", 1)
                } catch {
                    Start-Process cmd.exe -ArgumentList "/c `"$batPath`"" -WindowStyle Maximized
                }
            }

            Start-Sleep 3

            # Close any File Explorer windows showing this drive
            try {
                $shell = New-Object -ComObject "Shell.Application"
                $shell.Windows() | Where-Object {
                    try { $_.LocationURL -match "^file:///$($usbRoot.Replace('\','/'))" } catch { $false }
                } | ForEach-Object { $_.Quit() }
            } catch {}

            # Bring Palladium terminal to foreground via AppActivate
            try {
                $wshell = New-Object -ComObject WScript.Shell
                $wshell.AppActivate("Palladium Portable Server")
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
