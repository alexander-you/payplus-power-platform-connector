# Adds partial-payment control fields to alex_paypluspaymentline:
#   alex_requesteddocflow (picklist) - which accounting document to issue for the PAID part
#                                       (0 use config default / 1 receipt only / 2 tax invoice receipt)
#   alex_issueremainderdoc (bool)    - whether to issue a document for the remaining open balance
#   alex_remainderdocflow  (picklist)- which document to issue for the remainder
#                                       (0 none / 1 payment request / 2 proforma invoice)
# These let the Payment Wizard record a per-transaction override; the workbench flow reads them.
$ErrorActionPreference = 'Stop'
$org      = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus'
$entity   = 'alex_paypluspaymentline'

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
function New-Option { param([int]$Value, [string]$En, [string]$He)
    return @{ Value = $Value; Label = New-Label $En $He }
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
function New-Picklist { param([string]$Schema, [hashtable]$DisplayName, [hashtable]$Description, [array]$Options, [int]$DefaultValue = -1)
    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
        SchemaName    = $Schema
        DisplayName   = $DisplayName
        Description   = $Description
        RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
        OptionSet     = @{
            '@odata.type'  = 'Microsoft.Dynamics.CRM.OptionSetMetadata'
            IsGlobal       = $false
            OptionSetType  = 'Picklist'
            Options        = $Options
        }
        DefaultFormValue = $DefaultValue
    }
}

Write-Host '== alex_paypluspaymentline partial-payment control fields =='

Add-Attr 'alex_requesteddocflow' (New-Picklist 'alex_RequestedDocFlow' `
    (New-Label 'Requested document (paid part)' 'מסמך מבוקש (חלק ששולם)') `
    (New-Label 'Which accounting document to issue for the paid part of a partial payment. Use configuration default unless a legal override is chosen.' 'איזה מסמך חשבונאי להפיק עבור החלק ששולם בתשלום חלקי. ברירת המחדל מגיעה מההגדרות, אלא אם נבחרה חלופה חוקית.') `
    @(
        (New-Option 100000000 'Use configuration default' 'ברירת מחדל מההגדרות'),
        (New-Option 100000001 'Receipt only' 'קבלה בלבד'),
        (New-Option 100000002 'Tax invoice receipt' 'חשבונית מס קבלה')
    ) 100000000)

Add-Attr 'alex_issueremainderdoc' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.BooleanAttributeMetadata'
    SchemaName    = 'alex_IssueRemainderDoc'
    DisplayName   = New-Label 'Issue document for remainder' 'הפק מסמך ליתרה'
    Description   = New-Label 'Yes if a document should be issued for the remaining open balance of a partial payment.' 'כן אם יש להפיק מסמך עבור היתרה הפתוחה הנותרת בתשלום חלקי.'
    RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    DefaultValue  = $false
    OptionSet     = @{ TrueOption = @{ Value = 1; Label = New-Label 'Yes' 'כן' }; FalseOption = @{ Value = 0; Label = New-Label 'No' 'לא' } }
}

Add-Attr 'alex_remainderdocflow' (New-Picklist 'alex_RemainderDocFlow' `
    (New-Label 'Remainder document' 'מסמך ליתרה') `
    (New-Label 'Which document to issue for the remaining open balance of a partial payment.' 'איזה מסמך להפיק עבור היתרה הפתוחה הנותרת בתשלום חלקי.') `
    @(
        (New-Option 100000000 'None' 'ללא'),
        (New-Option 100000001 'Payment request' 'בקשת תשלום'),
        (New-Option 100000002 'Proforma invoice' 'חשבונית עסקה')
    ) 100000000)

Write-Host 'Publishing customizations...'
Invoke-Dv Post "$base/PublishAllXml" @{} | Out-Null
Write-Host 'Done.'
