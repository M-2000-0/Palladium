# uninstall.ps1 - Remove Palladium from Windows
# Run: powershell -ExecutionPolicy Bypass -File uninstall.ps1

Write-Host ""
Write-Host "  ═══ Palladium Uninstall ═══" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This will remove:" -ForegroundColor Yellow
Write-Host "    • PowerShell profile alias"
Write-Host "    • Docker containers created by Palladium"
Write-Host "    • All installed service data"
Write-Host ""
$confirm = Read-Host "  Uninstall Palladium? [y/N]"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "  Cancelled."
    exit
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "  Removing PowerShell profile alias..." -ForegroundColor Cyan
$profilePath = $PROFILE.CurrentUserAllHosts
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw
    $content = $content -replace ".*palladium.*`n", ""
    Set-Content $profilePath $content
    Write-Host "  ✓ Cleaned PowerShell profile" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Stopping Docker containers..." -ForegroundColor Cyan
$installedDir = Join-Path $scriptPath "palladium\data\installed"
if (Test-Path $installedDir) {
    Get-ChildItem $installedDir -Directory | ForEach-Object {
        $svc = $_.Name
        $composeFile = Join-Path $_.FullName "docker-compose.yml"
        if (Test-Path $composeFile) {
            Write-Host "  Stopping $svc..."
            docker compose -f $composeFile down -v 2>$null
        }
    }
    Write-Host "  ✓ Containers stopped" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Removing data directory..." -ForegroundColor Cyan
$dataDir = Join-Path $scriptPath "palladium\data"
if (Test-Path $dataDir) {
    Remove-Item -Recurse -Force $dataDir
    Write-Host "  ✓ Removed palladium\data\" -ForegroundColor Green
}

Write-Host ""
Write-Host "  ═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Palladium has been uninstalled." -ForegroundColor Green
Write-Host ""
Write-Host "  Your project files are still at:" -ForegroundColor Gray
Write-Host "    $scriptPath" -ForegroundColor White
Write-Host ""
Write-Host "  To remove them manually, delete the folder." -ForegroundColor Gray
Write-Host ""
