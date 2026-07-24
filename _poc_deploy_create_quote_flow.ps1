# Deploy "PayPlus - Create Quote" cloud flow (DRAFT) to Dataverse + add to the Sales extension solution.
# Pattern (documented in repo memory): POST/PATCH workflows by name, category=5, type=1,
# primaryentity='none', clientdata = raw file content, then AddSolutionComponent ComponentType=29.
# Flow is created as DRAFT (statecode 0). The USER must activate it in make.powerautomate.com
# (cannot activate via Web API: ConnectionAuthorizationFailed - PayPlus connections are user-owned).

$ErrorActionPreference = 'Stop'

$org        = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution   = 'alex_d365_payplus_sales_extended_data_model'
$flowName   = 'PayPlus - Create Quote'
$flowFile   = Join-Path $PSScriptRoot '_conn\flow_create_quote.json'

# --- token ---
$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get access token (az account get-access-token).' }
$headers = @{
    Authorization    = "Bearer $token"
    'OData-Version'  = '4.0'
    'OData-MaxVersion' = '4.0'
    Accept           = 'application/json'
    'Content-Type'   = 'application/json; charset=utf-8'
}
$base = "$org/api/data/v9.2"

# --- read + validate clientdata (raw file content) ---
$clientData = Get-Content -Raw -LiteralPath $flowFile
$null = $clientData | ConvertFrom-Json  # parse check; throws if invalid JSON

# --- find existing workflow by name + category 5 (modern cloud flow) ---
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
        description   = 'Creates a PayPlus quote document when a Dynamics quote is activated (statecode=1). Matches customer by VAT+email and products by barcode; env-aware (Production/Sandbox).'
        category      = 5      # Modern cloud flow
        type          = 1      # Definition
        primaryentity = 'none'
        statecode     = 0      # Draft
        statuscode    = 1      # Draft
        clientdata    = $clientData
    } | ConvertTo-Json -Depth 3
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $resp = Invoke-WebRequest -Method Post -Uri "$base/workflows" -Headers $headers -Body $bytes
    $entHeader = $resp.Headers['OData-EntityId']
    if ($entHeader -is [array]) { $entHeader = $entHeader[0] }
    if ($entHeader -match 'workflows\(([0-9a-fA-F-]{36})\)') { $wfId = $Matches[1] }
    if (-not $wfId) {
        # fallback: re-query by name
        $existing2 = Invoke-RestMethod -Method Get -Uri $q -Headers $headers
        if ($existing2.value.Count -gt 0) { $wfId = $existing2.value[0].workflowid }
    }
    if (-not $wfId) { throw 'Could not determine new workflowid.' }
    Write-Host "Created flow $wfId (DRAFT)."
}

# --- add to solution (ComponentType 29 = Workflow) ---
Write-Host "Adding to solution '$solution' ..."
$addBody = @{
    ComponentType         = 29
    ComponentId           = $wfId
    SolutionUniqueName     = $solution
    AddRequiredComponents  = $false
} | ConvertTo-Json
$addBytes = [System.Text.Encoding]::UTF8.GetBytes($addBody)
try {
    Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body $addBytes | Out-Null
    Write-Host 'Added to solution.'
}
catch {
    Write-Warning "AddSolutionComponent: $($_.Exception.Message) (may already be in the solution)."
}

Write-Host ''
Write-Host "DONE. Flow '$flowName' = $wfId (DRAFT)."
Write-Host 'NEXT (manual, required):'
Write-Host '  1. make.powerautomate.com -> solution alex_d365_payplus_sales_extended_data_model -> turn the flow ON (activate).'
Write-Host '     (Web API cannot activate: PayPlus connections are user-owned -> ConnectionAuthorizationFailed.)'
Write-Host '  2. If the connector was recently updated, bust the runtime cache (republish connector in maker UI'
Write-Host '     OR recreate the connection) before the CreateQuote action resolves.'
