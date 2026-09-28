[CmdletBinding()]
param(
    [Parameter(Mandatory)] [uri] $EnvironmentUrl,
    [Parameter(Mandatory)] [string] $SolutionUniqueName,
    [Parameter(Mandatory)] [string] $PublisherPrefix,
    [string] $DisplayName = 'Release Record',
    [string] $DisplayCollectionName = 'Release Records',
    [int] $LanguageCode = 1033
)

$ErrorActionPreference = 'Stop'
if ($EnvironmentUrl.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($EnvironmentUrl.Host) -or $EnvironmentUrl.Query -or $EnvironmentUrl.Fragment -or $EnvironmentUrl.AbsolutePath.Trim('/') ) {
    throw 'EnvironmentUrl must be an HTTPS Dataverse organization base URL without a path, query, or fragment.'
}
if ($PublisherPrefix -notmatch '^[a-z][a-z0-9]{1,7}$') {
    throw 'PublisherPrefix must start with a lowercase letter and contain 2-8 lowercase letters or digits.'
}
if ($SolutionUniqueName -notmatch '^[A-Za-z][A-Za-z0-9_]{0,49}$') {
    throw 'SolutionUniqueName must be a valid Dataverse solution unique name.'
}

$exactUrl = $EnvironmentUrl.AbsoluteUri.TrimEnd('/')
$confirmation = Read-Host "This script will create one Dataverse table in $exactUrl and add it to solution '$SolutionUniqueName'. Type the full URL to continue"
if ($confirmation.TrimEnd('/') -ne $exactUrl) { throw 'Environment URL confirmation did not match. No request was sent.' }

$existingProfile = & pac org who 2>&1
if ($LASTEXITCODE -ne 0) { throw 'PAC CLI has no active authenticated profile. Run pac auth create for the intended Dev environment, then pac org who.' }
Write-Host 'Confirm the PAC org output above identifies the same Dev environment URL before continuing.' -ForegroundColor Yellow
$orgConfirmed = Read-Host 'Type YES only after comparing the active PAC organization with the URL above'
if ($orgConfirmed -cne 'YES') { throw 'Active PAC organization was not confirmed. No Dataverse request was sent.' }

$tokenText = (& pac auth token 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $tokenText -notmatch '^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.') {
    throw 'Could not obtain a PAC access token. Authenticate with pac auth create and retry. Token output is not displayed.'
}
$headers = @{
    Authorization = "Bearer $tokenText"
    Accept = 'application/json'
    'OData-MaxVersion' = '4.0'
    'OData-Version' = '4.0'
    'MSCRM.SolutionUniqueName' = $SolutionUniqueName
}
$tokenText = $null

$api = "$exactUrl/api/data/v9.2"
$solutionFilter = [uri]::EscapeDataString("uniquename eq '$SolutionUniqueName'")
$solutionResult = Invoke-RestMethod -Method Get -Uri "$api/solutions?`$select=uniquename&`$filter=$solutionFilter" -Headers $headers
if (@($solutionResult.value).Count -ne 1) { throw "Solution '$SolutionUniqueName' must already exist exactly once in the confirmed Dev environment. No table was created." }

$logicalName = "$PublisherPrefix`_releaserecord"
$escapedLogicalName = [uri]::EscapeDataString($logicalName)
$metadataUri = "$api/EntityDefinitions(LogicalName='$escapedLogicalName')?`$select=LogicalName"
$existingTable = $null
try { $existingTable = Invoke-RestMethod -Method Get -Uri $metadataUri -Headers $headers -ErrorAction Stop }
catch {
    if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { $existingTable = $null }
    else { throw }
}
if ($existingTable) { throw "Table '$logicalName' already exists. This script never overwrites or modifies an existing table; review and add it to the solution manually if appropriate." }

function New-Label([string] $Text) {
    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.Label'
        LocalizedLabels = @(@{
            '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'
            Label = $Text
            LanguageCode = $LanguageCode
        })
    }
}

$primaryNameSchema = "${PublisherPrefix}_Name"
$table = @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.EntityMetadata'
    SchemaName = "${PublisherPrefix}_ReleaseRecord"
    DisplayName = (New-Label $DisplayName)
    DisplayCollectionName = (New-Label $DisplayCollectionName)
    Description = (New-Label 'Small synthetic-data table used to demonstrate Power Platform solution promotion.')
    OwnershipType = 'UserOwned'
    IsActivity = $false
    HasActivities = $false
    HasNotes = $false
    Attributes = @(@{
        '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
        AttributeType = 'String'
        SchemaName = $primaryNameSchema
        DisplayName = (New-Label "$DisplayName Name")
        Description = (New-Label 'Primary name for a demonstration release record.')
        RequiredLevel = @{ Value = 'None'; CanBeChanged = $true }
        IsPrimaryName = $true
        FormatName = @{ Value = 'Text' }
        MaxLength = 100
    })
}
$body = $table | ConvertTo-Json -Depth 20

Invoke-RestMethod -Method Post -Uri "$api/EntityDefinitions" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $body | Out-Null
$createdTable = Invoke-RestMethod -Method Get -Uri $metadataUri -Headers $headers
if ($createdTable.LogicalName -ne $logicalName) { throw 'Readback did not return the expected table logical name.' }
Write-Host "Created and read back '$logicalName' in solution '$SolutionUniqueName'. Export and unpack the solution source before committing it." -ForegroundColor Green

