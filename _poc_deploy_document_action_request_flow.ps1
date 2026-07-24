# Deploy "PayPlus - Document Action Request" placeholder cloud flow.
# The flow intentionally does not send Email/SMS/WhatsApp and does not call PayPlus cancel/close APIs.
# It only resolves the selected document link and composes a payload for a future implementation step.

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus'
$flowName = 'PayPlus - Document Action Request'
$sourceFlowFile = Join-Path $PSScriptRoot '_conn\flow_document_action_request.json'

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get Dataverse access token.' }

$headers = @{
    Authorization       = "Bearer $token"
    'OData-Version'     = '4.0'
    'OData-MaxVersion'  = '4.0'
    Accept              = 'application/json'
    'Content-Type'      = 'application/json; charset=utf-8'
}
$base = "$org/api/data/v9.2"

function Get-EntityIdFromHeader($ResponseHeaders, [string]$EntitySet) {
    $entityHeader = $ResponseHeaders['OData-EntityId']
    if ($entityHeader -is [array]) { $entityHeader = $entityHeader[0] }
    if ($entityHeader -match "$EntitySet\(([0-9a-fA-F-]{36})\)") { return $Matches[1] }
    return $null
}

$clientData = Get-Content -Raw -LiteralPath $sourceFlowFile
$null = $clientData | ConvertFrom-Json -Depth 100

$nameEsc = $flowName.Replace("'", "''")
$existing = Invoke-RestMethod -Method Get -Uri "$base/workflows?`$select=workflowid,statecode,statuscode&`$filter=name eq '$nameEsc' and category eq 5&`$top=1" -Headers $headers
$workflowId = $null
if ($existing.value.Count -gt 0) { $workflowId = $existing.value[0].workflowid }

if ($workflowId) {
    Write-Host "Updating existing flow $workflowId ..."
    $patch = @{ clientdata = $clientData; description = 'Placeholder flow for PayPlus document action requests. Resolves the selected link and composes a payload only.' } | ConvertTo-Json -Depth 5 -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($patch)) | Out-Null
}
else {
    Write-Host 'Creating new DRAFT flow ...'
    $body = @{
        name = $flowName
        description = 'Placeholder flow for PayPlus document action requests. Resolves the selected link and composes a payload only.'
        category = 5
        type = 1
        primaryentity = 'none'
        statecode = 0
        statuscode = 1
        clientdata = $clientData
    } | ConvertTo-Json -Depth 5 -Compress
    $response = Invoke-WebRequest -Method Post -Uri "$base/workflows" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($body))
    $workflowId = Get-EntityIdFromHeader $response.Headers 'workflows'
    if (-not $workflowId) {
        $created = Invoke-RestMethod -Method Get -Uri "$base/workflows?`$select=workflowid&`$filter=name eq '$nameEsc' and category eq 5&`$top=1" -Headers $headers
        if ($created.value.Count -gt 0) { $workflowId = $created.value[0].workflowid }
    }
}
if (-not $workflowId) { throw 'Could not determine document action request workflow id.' }

$addBody = @{ ComponentType = 29; ComponentId = $workflowId; SolutionUniqueName = $solution; AddRequiredComponents = $false } | ConvertTo-Json -Compress
try { Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($addBody)) | Out-Null }
catch { Write-Warning "AddSolutionComponent: $($_.Exception.Message)" }

try {
    $activate = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($activate)) | Out-Null
}
catch {
    Write-Warning "Flow was saved but could not be activated via API: $($_.Exception.Message)"
}

Write-Host "DONE. Flow '$flowName' = $workflowId."