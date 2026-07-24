# Adds PayPlus enrichment fields to alex_bank:
#   alex_ispayplussupported (bool) - bank_code exists in PayPlus BranchesList dictionary
#   alex_payplusbankname    (string) - bank name as returned by PayPlus BranchesList
# These ENRICH the data.gov.il-sourced bank records; they never overwrite core fields.
$ErrorActionPreference = 'Stop'
$org      = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus'
$entity   = 'alex_bank'

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get access token.' }
$headers = @{
    Authorization              = "Bearer $token"
    'OData-Version'            = '4.0'
    'OData-MaxVersion'         = '4.0'
    Accept                     = 'application/json'
    'Content-Type'             = 'application/json; charset=utf-8'
    'MSCRM.SolutionUniqueName' = $solution
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
    try { Invoke-RestMethod -Method Get -Uri "$base/EntityDefinitions(LogicalName='$entity')/Attributes(LogicalName='$Logical')?`$select=MetadataId" -Headers $headers | Out-Null; return $true }
    catch { return $false }
}
function Add-Attr { param([string]$Logical, [hashtable]$Meta)
    if (Test-Attr $Logical) { Write-Host "  attr exists: $Logical"; return }
    Write-Host "  create attr: $Logical"
    Invoke-Dv Post "$base/EntityDefinitions(LogicalName='$entity')/Attributes" $Meta | Out-Null
}

Write-Host '== alex_bank PayPlus enrichment fields =='
Add-Attr 'alex_ispayplussupported' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.BooleanAttributeMetadata'
    SchemaName    = 'alex_IsPayPlusSupported'
    DisplayName   = New-Label 'PayPlus Supported' 'נתמך ב-PayPlus'
    Description   = New-Label 'Yes if this bank code appears in the PayPlus banks dictionary (BranchesList).' 'כן אם קוד הבנק מופיע במילון הבנקים של PayPlus (BranchesList).'
    RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    DefaultValue  = $false
    OptionSet     = @{ TrueOption = @{ Value = 1; Label = New-Label 'Yes' 'כן' }; FalseOption = @{ Value = 0; Label = New-Label 'No' 'לא' } }
}
Add-Attr 'alex_payplusbankname' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
    SchemaName    = 'alex_PayPlusBankName'
    DisplayName   = New-Label 'PayPlus Bank Name' 'שם בנק ב-PayPlus'
    Description   = New-Label 'Bank name as returned by the PayPlus banks dictionary (BranchesList).' 'שם הבנק כפי שמוחזר ממילון הבנקים של PayPlus (BranchesList).'
    RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    MaxLength     = 200
    FormatName    = @{ Value = 'Text' }
}

Write-Host 'Publishing customizations...'
Invoke-Dv Post "$base/PublishAllXml" @{} | Out-Null
Write-Host 'Done.'
