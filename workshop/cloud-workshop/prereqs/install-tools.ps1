<#
.SYNOPSIS
  Installs all tools needed for the "From Zero to Xeon" workshop on Windows.

.DESCRIPTION
  Uses winget (built into Windows 10 1809+ and Windows 11) to install:
    - Git
    - Visual Studio Code
    - AWS CLI v2
    - Google Cloud SDK
    - Terraform (via HashiCorp's official package)

  Re-running this script is safe; winget skips already-installed packages.

.NOTES
  Run from PowerShell. No admin required for per-user installs.
#>

$ErrorActionPreference = "Stop"

function Install-Pkg {
    param([string]$Id, [string]$Name)
    Write-Host ""
    Write-Host "==> Installing $Name ($Id)" -ForegroundColor Cyan
    winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        # -1978335189 == "no applicable upgrade found" / already installed
        Write-Warning "winget exit code $LASTEXITCODE for $Name. Continuing."
    }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is not available. Install 'App Installer' from the Microsoft Store, then re-run."
}

Install-Pkg -Id "Git.Git"                  -Name "Git"
Install-Pkg -Id "Microsoft.VisualStudioCode" -Name "Visual Studio Code"
Install-Pkg -Id "Amazon.AWSCLI"            -Name "AWS CLI v2"
Install-Pkg -Id "Google.CloudSDK"          -Name "Google Cloud SDK"
Install-Pkg -Id "Hashicorp.Terraform"      -Name "Terraform"

Write-Host ""
Write-Host "All installs attempted." -ForegroundColor Green
Write-Host "IMPORTANT: close this PowerShell window and open a NEW one before running verify-tools.ps1." -ForegroundColor Yellow
