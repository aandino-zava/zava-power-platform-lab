[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Path
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Validate-Config.ps1') -Path $Path
$config = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json

$plan = @(
    "Create/reuse Dev sandbox: $($config.environments.devName) ($($config.environmentGroups.nonProd))",
    "Create/reuse UAT sandbox: $($config.environments.uatName) ($($config.environmentGroups.nonProd)); managed environment required as pipeline target",
    "Create/reuse Prod environment: $($config.environments.prodName) ($($config.environmentGroups.prod)); managed environment required as pipeline target",
    "Create/reuse dedicated pipeline host: $($config.environments.pipelineHostName); install Power Platform Pipelines application",
    "Create/review Entra groups: $($config.groups.admins), $($config.groups.makers), $($config.groups.approvers), $($config.groups.environmentAccess)",
    "Configure DLP scopes: $($config.dlpPolicies.default); $($config.dlpPolicies.nonProd); $($config.dlpPolicies.prod)",
    "Configure pipeline '$($config.pipeline.name)' with UAT then Prod; require Prod approval",
    "Keep Copilot Studio AI and preview features enabled unless tenant risk review identifies a specific reason to change them",
    'Do not delete, archive, move, or alter existing environments or agents.'
)

Write-Host 'Planned lab configuration:' -ForegroundColor Cyan
$plan | ForEach-Object { Write-Host " - $_" }
Write-Host "`nPlan only. No tenant changes were made. Review docs/deployment-runbook.md before applying changes." -ForegroundColor Yellow

