# Adds the "Import Terminals & Pages" control fields to alex_payplusconfiguration,
# then deploys the "PayPlus - Import Terminals & Pages" cloud flow (DRAFT) and adds
# it to the solution. Mirrors _poc_deploy_import_doctypes_flow.ps1.
$ErrorActionPreference = 'Stop'
$org      = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus'
$flowName = 'PayPlus - Import Terminals & Pages'
$flowFile = Join-Path $PSScriptRoot '_conn\flow_import_terminals_pages.json'
$configEntity = 'alex_payplusconfiguration'

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get access token.' }
$headers = @{
    Authorization                = "Bearer $token"
    'OData-Version'              = '4.0'
    'OData-MaxVersion'           = '4.0'
    Accept                       = 'application/json'
    'Content-Type'               = 'application/json; charset=utf-8'
    'MSCRM.SolutionUniqueName'   = $solution
}
$base = "$org/api/data/v9.2"

function New-Label { param([string]$En, [string]$He)
    return @{ LocalizedLabels = @(@{ Label = $En; LanguageCode = 1033 }, @{ Label = $He; LanguageCode = 1037 }) }
}
function Invoke-Dv { param([string]$Method, [string]$Uri, [object]$Body)
    $p = @{ Method = $Method; Uri = $Uri; Headers = $headers }
    if ($Body) { $p.Body = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 60 -Compress)) }
    return Invoke-RestMethod @p
}
function Test-Attr { param([string]$Logical)
    try { Invoke-RestMethod -Method Get -Uri "$base/EntityDefinitions(LogicalName='$configEntity')/Attributes(LogicalName='$Logical')?`$select=MetadataId" -Headers $headers | Out-Null; return $true }
    catch { return $false }
}
function Add-Attr { param([string]$Logical, [hashtable]$Meta)
    if (Test-Attr $Logical) { Write-Host "  attr exists: $Logical"; return }
    Write-Host "  create attr: $Logical"
    Invoke-Dv Post "$base/EntityDefinitions(LogicalName='$configEntity')/Attributes" $Meta | Out-Null
}

Write-Host '== Config control fields =='
Add-Attr 'alex_terminals_import_enabled' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.BooleanAttributeMetadata'
    SchemaName    = 'alex_terminals_import_enabled'
    DisplayName   = New-Label 'Import Terminals & Pages' 'ייבוא מסופים ועמודי תשלום'
    Description   = New-Label 'Set to Yes to trigger the terminals & payment pages import flow.' 'קבע ל-כן כדי להפעיל את זרימת ייבוא המסופים ועמודי התשלום.'
    RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    DefaultValue  = $false
    OptionSet     = @{ TrueOption = @{ Value = 1; Label = New-Label 'Yes' 'כן' }; FalseOption = @{ Value = 0; Label = New-Label 'No' 'לא' } }
}
Add-Attr 'alex_terminals_import_status' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
    SchemaName    = 'alex_terminals_import_status'
    DisplayName   = New-Label 'Terminals Import Status' 'סטטוס ייבוא מסופים'
    Description   = New-Label 'Result of the last terminals & pages import.' 'תוצאת הייבוא האחרון של מסופים ועמודי תשלום.'
    RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    OptionSet     = @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'
        IsGlobal      = $false
        OptionSetType = 'Picklist'
        Options       = @(
            @{ Value = 100000000; Label = New-Label 'Not Started' 'לא התחיל' },
            @{ Value = 100000001; Label = New-Label 'Pending' 'בתהליך' },
            @{ Value = 100000002; Label = New-Label 'Success' 'הצליח' },
            @{ Value = 100000003; Label = New-Label 'Failed' 'נכשל' }
        )
    }
}
Add-Attr 'alex_terminals_import_on' @{
    '@odata.type'    = 'Microsoft.Dynamics.CRM.DateTimeAttributeMetadata'
    SchemaName       = 'alex_terminals_import_on'
    DisplayName      = New-Label 'Terminals Imported On' 'מסופים יובאו בתאריך'
    Description      = New-Label 'When the last terminals & pages import completed.' 'מועד סיום הייבוא האחרון של מסופים ועמודי תשלום.'
    RequiredLevel    = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    Format           = 'DateAndTime'
    DateTimeBehavior = @{ Value = 'UserLocal' }
}
Add-Attr 'alex_terminals_import_message' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
    SchemaName    = 'alex_terminals_import_message'
    DisplayName   = New-Label 'Terminals Import Message' 'הודעת ייבוא מסופים'
    Description   = New-Label 'Details of the last terminals & pages import.' 'פירוט הייבוא האחרון של מסופים ועמודי תשלום.'
    RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    MaxLength     = 400
    FormatName    = @{ Value = 'Text' }
}

Write-Host 'Publishing customizations...'
Invoke-Dv Post "$base/PublishAllXml" @{} | Out-Null

# --- flow deploy ---------------------------------------------------------
$flowHeaders = @{
    Authorization      = "Bearer $token"
    'OData-Version'    = '4.0'
    'OData-MaxVersion' = '4.0'
    Accept             = 'application/json'
    'Content-Type'     = 'application/json; charset=utf-8'
}
$clientData = Get-Content -Raw -LiteralPath $flowFile
$null = $clientData | ConvertFrom-Json  # parse check

$nameEsc = $flowName.Replace("'", "''")
$filterEnc = [uri]::EscapeDataString("name eq '$nameEsc' and category eq 5")
$q = "$base/workflows?`$select=workflowid,statecode&`$filter=$filterEnc"
$existing = Invoke-RestMethod -Method Get -Uri $q -Headers $flowHeaders
$wfId = if ($existing.value.Count -gt 0) { $existing.value[0].workflowid } else { $null }

if ($wfId) {
    Write-Host "Updating existing flow $wfId ..."
    $patch = @{ clientdata = $clientData } | ConvertTo-Json -Depth 3 -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($wfId)" -Headers $flowHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes($patch)) | Out-Null
    Write-Host 'Flow clientdata updated.'
}
else {
    Write-Host 'Creating new DRAFT flow ...'
    $body = @{
        name          = $flowName
        description   = 'Syncs PayPlus terminals (MyTerminals) and their payment pages (ListPaymentPages) into alex_payplus_terminal / alex_payplus_paymentpage. Triggered by alex_terminals_import_enabled on the config row; env-aware; preserves business/policy fields; writes back import status.'
        category      = 5
        type          = 1
        primaryentity = 'none'
        statecode     = 0
        statuscode    = 1
        clientdata    = $clientData
    } | ConvertTo-Json -Depth 3
    $resp = Invoke-WebRequest -Method Post -Uri "$base/workflows" -Headers $flowHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
    $entHeader = $resp.Headers['OData-EntityId']
    if ($entHeader -is [array]) { $entHeader = $entHeader[0] }
    if ($entHeader -match 'workflows\(([0-9a-fA-F-]{36})\)') { $wfId = $Matches[1] }
    if (-not $wfId) {
        $existing2 = Invoke-RestMethod -Method Get -Uri $q -Headers $flowHeaders
        if ($existing2.value.Count -gt 0) { $wfId = $existing2.value[0].workflowid }
    }
    if (-not $wfId) { throw 'Could not determine new workflowid.' }
    Write-Host "Created flow $wfId (DRAFT)."
}

Write-Host "Adding to solution '$solution' ..."
$addBody = @{ ComponentType = 29; ComponentId = $wfId; SolutionUniqueName = $solution; AddRequiredComponents = $false } | ConvertTo-Json
try {
    Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $flowHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes($addBody)) | Out-Null
    Write-Host 'Added to solution.'
} catch {
    Write-Warning "AddSolutionComponent: $($_.Exception.Message) (may already be in the solution)."
}
Write-Host ''
Write-Host "DONE. Flow '$flowName' = $wfId (DRAFT). Activate manually in make.powerautomate.com, then set alex_terminals_import_enabled = Yes on the config row."
