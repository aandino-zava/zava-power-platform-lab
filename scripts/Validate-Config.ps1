[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Path
)

$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $Path).Path
$config = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
$errors = [System.Collections.Generic.List[string]]::new()

if ($config.labPrefix -match '^REPLACE_ME|^\s*$') { $errors.Add('labPrefix must be set to a customer-specific prefix.') }
if ($config.location -match '^REPLACE_ME|^\s*$') { $errors.Add('location must be set to a valid Power Platform region.') }
if ($config.solution.publisherPrefix -notmatch '^[a-z][a-z0-9]{1,7}$') { $errors.Add('solution.publisherPrefix must start with a lowercase letter and contain 2-8 lowercase letters or digits.') }
if ($config.solution.uniqueName -notmatch '^[A-Za-z][A-Za-z0-9_]{0,49}$') { $errors.Add('solution.uniqueName must be a valid Dataverse solution unique name.') }
if ($config.safety.neverDeleteExistingEnvironments -ne $true) { $errors.Add('Safety invariant failed: neverDeleteExistingEnvironments must remain true.') }
if ($config.safety.neverMoveExistingAgents -ne $true) { $errors.Add('Safety invariant failed: neverMoveExistingAgents must remain true.') }
if ($config.safety.requireExplicitApplySwitch -ne $true) { $errors.Add('Safety invariant failed: requireExplicitApplySwitch must remain true.') }

$requiredNames = @(
    $config.environments.devName, $config.environments.uatName, $config.environments.prodName, $config.environments.pipelineHostName,
    $config.groups.admins, $config.groups.makers, $config.groups.approvers, $config.groups.environmentAccess,
    $config.pipeline.name, $config.solution.displayName
)
foreach ($name in $requiredNames) {
    if ([string]::IsNullOrWhiteSpace($name) -or $name -match 'REPLACE_ME') { $errors.Add("Required name is blank or still contains REPLACE_ME: '$name'") }
}
if ($config.pipeline.requireProductionPreDeploymentStep -ne $true) { $errors.Add('Production pre-deployment approval must remain enabled.') }

if ($errors.Count) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Configuration valid: $resolved" -ForegroundColor Green
Write-Host "Lab prefix: $($config.labPrefix); region: $($config.location)"
Write-Host "Environments: $($config.environments.devName), $($config.environments.uatName), $($config.environments.prodName), host $($config.environments.pipelineHostName)"
Write-Host 'No tenant changes were made.'

