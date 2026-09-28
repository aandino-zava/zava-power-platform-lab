[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter(Mandatory)] [guid] $EnvironmentAccessGroupId
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) {
    throw 'Microsoft.PowerApps.Administration.PowerShell currently requires Windows PowerShell 5.x. Run this script in Windows PowerShell 5.1, not PowerShell 7.'
}

$resolvedConfig = (Resolve-Path -LiteralPath $ConfigPath).Path
. (Join-Path $PSScriptRoot 'Validate-Config.ps1') -Path $resolvedConfig
$config = Get-Content -LiteralPath $resolvedConfig -Raw | ConvertFrom-Json

if (-not (Get-Module -ListAvailable -Name Microsoft.PowerApps.Administration.PowerShell)) {
    throw 'Install Microsoft.PowerApps.Administration.PowerShell from the PowerShell Gallery, then rerun.'
}
Import-Module Microsoft.PowerApps.Administration.PowerShell
if (-not (Get-AdminPowerAppEnvironment -ErrorAction SilentlyContinue)) {
    Add-PowerAppsAccount | Out-Null
}

$environmentPlan = @(
    @{ Name = $config.environments.devName; Sku = $config.environments.devType; Description = 'Development environment for unmanaged solution source.' },
    @{ Name = $config.environments.uatName; Sku = $config.environments.uatType; Description = 'User acceptance testing environment; pipeline target.' },
    @{ Name = $config.environments.prodName; Sku = $config.environments.prodType; Description = 'Production environment; managed pipeline target with approval gate.' },
    @{ Name = $config.environments.pipelineHostName; Sku = $config.environments.pipelineHostType; Description = 'Dedicated Power Platform Pipelines configuration and approval host.' }
)

$existing = @(Get-AdminPowerAppEnvironment)
foreach ($item in $environmentPlan) {
    $matches = @($existing | Where-Object { $_.DisplayName -eq $item.Name })
    if ($matches.Count -gt 1) {
        throw "More than one tenant environment has the display name '$($item.Name)'. Resolve the ambiguity manually; no environment was changed by this script."
    }
    if ($matches.Count -eq 1) {
        Write-Host "REUSE CANDIDATE: '$($item.Name)' ($($matches[0].EnvironmentName)). This script will not modify it. Verify its type, region, database, access group, and purpose manually." -ForegroundColor Yellow
        continue
    }

    $description = $item.Description
    $displayName = $item.Name
    $sku = $item.Sku
    if ($PSCmdlet.ShouldProcess($displayName, "Create $sku environment with Dataverse database and the specified access group")) {
        New-AdminPowerAppEnvironment `
            -DisplayName $displayName `
            -LocationName $config.location `
            -EnvironmentSku $sku `
            -ProvisionDatabase `
            -CurrencyName $config.currencyName `
            -LanguageName $config.languageName `
            -SecurityGroupId $EnvironmentAccessGroupId.ToString() `
            -Description $description `
            -WaitUntilFinished $true | Out-Host
    }
    else {
        Write-Host "WOULD CREATE: '$displayName' ($sku), location '$($config.location)', Dataverse database, access group $EnvironmentAccessGroupId."
    }
}

Write-Host 'Environment creation requests completed. Re-read each environment in PPAC and verify provisioning, access group, region, and database settings. Existing environments were not modified.' -ForegroundColor Cyan

