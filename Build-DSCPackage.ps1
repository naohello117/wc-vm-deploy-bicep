# Build DSC Configuration Package
# This script compiles the DSC configuration and creates a zip package for deployment
# Requires PowerShell 7+

#Requires -Version 7.0

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\dsc-package",
    
    [Parameter(Mandatory = $false)]
    [string]$BlobStorageUrl = ""
)

Write-Host "Building DSC configuration package..." -ForegroundColor Green
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan

# Ensure PSDesiredStateConfiguration module is available
if (-not (Get-Module -ListAvailable -Name PSDesiredStateConfiguration)) {
    Write-Host "Installing PSDesiredStateConfiguration module..." -ForegroundColor Yellow
    Install-Module -Name PSDesiredStateConfiguration -Force -Scope CurrentUser -AllowClobber
}

# Force use of built-in PSDesiredStateConfiguration for Windows PowerShell 5.1
$env:PSModulePath = $env:PSModulePath -replace [regex]::Escape("$HOME\Documents\WindowsPowerShell\Modules;"), ""

# Create output directory
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null

# Import the DSC configuration
. .\dsc\ConfigureIIS.ps1

# Compile the DSC configuration
Write-Host "Compiling DSC configuration..." -ForegroundColor Yellow
ConfigureIIS -MachineName 'localhost' -BlobStorageUrl $BlobStorageUrl -OutputPath $OutputPath

# Copy the ConfigureIIS.ps1 script to the output directory
Copy-Item -Path ".\dsc\ConfigureIIS.ps1" -Destination $OutputPath -Force

# Create zip archive
$zipPath = ".\ConfigureIIS.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host "Creating zip archive..." -ForegroundColor Yellow
Compress-Archive -Path "$OutputPath\*" -DestinationPath $zipPath -Force

Write-Host "DSC package created successfully: $zipPath" -ForegroundColor Green
Write-Host "Package contents:"
Get-ChildItem $OutputPath | Format-Table Name, Length

# Cleanup
Remove-Item $OutputPath -Recurse -Force

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Upload ConfigureIIS.zip to Blob Storage"
Write-Host "2. Upload web-content files (index.html, style.css) to Blob Storage"
Write-Host "3. Deploy the infrastructure with Bicep"
