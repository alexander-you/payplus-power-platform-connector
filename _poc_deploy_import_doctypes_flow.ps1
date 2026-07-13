# Deploy "PayPlus - Import Document Types" cloud flow (DRAFT) to Dataverse + add to solution.
$ErrorActionPreference = 'Stop'
$org        = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution   = 'alex_d365_payplus'
$flowName   = 'PayPlus - Import Document Types'
$flowFile   = Join-Path $PSScriptRoot '_conn\flow_import_doctypes.json'

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get access token.' }
$headers = @{
    Authorization      = "Bearer $token"
    'OData-Version'    = '4.0'
    'OData-MaxVersion' = '4.0'
    Accept             = 'application/json'
    'Content-Type'     = 'application/json; charset=utf-8'
}
$base = "$org/api/data/v9.2"

$clientData = Get-Content -Raw -LiteralPath $flowFile
$null = $clientData | ConvertFrom-Json  # parse check

$nameEsc = $flowName.Replace("'", "''")
$q = "$base/workflows?`$select=workflowid,statecode&`$filter=name eq '$nameEsc' and category eq 5"
$existing = Invoke-RestMethod -Method Get -Uri $q -Headers $headers
$wfId = $null
if ($existing.value.Count -gt 0) { $wfId = $existing.value[0].workflowid }

if ($wfId) {
    Write-Host "Updating existing flow $wfId ..."
    $patch = @{ clientdata = $clientData } | ConvertTo-Json -Depth 3 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($patch)
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($wfId)" -Headers $headers -Body $bytes | Out-Null
    Write-Host 'Flow clientdata updated.'
}
else {
    Write-Host 'Creating new DRAFT flow ...'
    $body = @{
        name          = $flowName
        description   = 'Imports PayPlus document types (GetDocumentTypes, he+en) into alex_payplus_documenttype. Triggered by alex_doc_import_enabled on the config row; env-aware (Production/Sandbox); writes back import status.'
        category      = 5
        type          = 1
        primaryentity = 'none'
        statecode     = 0
        statuscode    = 1
        clientdata    = $clientData
    } | ConvertTo-Json -Depth 3
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $resp = Invoke-WebRequest -Method Post -Uri "$base/workflows" -Headers $headers -Body $bytes
    $entHeader = $resp.Headers['OData-EntityId']
    if ($entHeader -is [array]) { $entHeader = $entHeader[0] }
    if ($entHeader -match 'workflows\(([0-9a-fA-F-]{36})\)') { $wfId = $Matches[1] }
    if (-not $wfId) {
        $existing2 = Invoke-RestMethod -Method Get -Uri $q -Headers $headers
        if ($existing2.value.Count -gt 0) { $wfId = $existing2.value[0].workflowid }
    }
    if (-not $wfId) { throw 'Could not determine new workflowid.' }
    Write-Host "Created flow $wfId (DRAFT)."
}

Write-Host "Adding to solution '$solution' ..."
$addBody = @{
    ComponentType         = 29
    ComponentId           = $wfId
    SolutionUniqueName    = $solution
    AddRequiredComponents = $false
} | ConvertTo-Json
$addBytes = [System.Text.Encoding]::UTF8.GetBytes($addBody)
try {
    Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body $addBytes | Out-Null
    Write-Host 'Added to solution.'
} catch {
    Write-Warning "AddSolutionComponent: $($_.Exception.Message) (may already be in the solution)."
}
Write-Host ''
Write-Host "DONE. Flow '$flowName' = $wfId (DRAFT). Activate manually in make.powerautomate.com."
