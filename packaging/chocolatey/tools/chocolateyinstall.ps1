$ErrorActionPreference = 'Stop'

$packageName = 'palladium'
$version = '1.1.0'
$url = "https://github.com/M-2000-0/Palladium/releases/download/v$version/palladium-windows.zip"
$checksum = 'REPLACE_WITH_SHA256'
$checksumType = 'sha256'

$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition
$installDir = Join-Path $toolsDir 'palladium'

# Download and extract
$zipFile = Join-Path $toolsDir "palladium-$version.zip"
Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $zipFile -Url $url -Checksum $checksum -ChecksumType $checksumType

# Extract
Expand-Archive -Path $zipFile -DestinationPath $installDir -Force

# Create shim
$exePath = Join-Path $installDir 'palladium\palladium'
Install-BinFile -Name 'palladium' -Path $exePath

# Add to PATH (user scope)
$installDirFull = Join-Path $installDir 'palladium'
$pathToAdd = $installDirFull
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($currentPath -notlike "*$pathToAdd*") {
    [Environment]::SetEnvironmentVariable('PATH', $currentPath + ';' + $pathToAdd, 'User')
}

# Cleanup
Remove-Item $zipFile -Force

Write-Host "Palladium $version installed successfully!" -ForegroundColor Green
Write-Host "Run 'palladium' to start." -ForegroundColor Cyan