# Adds fields for the designed Bank-Accounts subgrid PCF.
#
# On alex_customerbankaccount:
#   alex_hasstandingorder              (bool)     - is a standing order (הוראת קבע) active on this account
#   alex_standingordersince            (DateOnly) - date the standing order became active
#   alex_standingorderreference        (string)   - mandate / reference number of the standing order
#   alex_paypluscustomerbankaccountuid (string)   - PayPlus bank_account_uid returned after sync
#   alex_syncstatus                    (picklist) - PayPlus sync state: pending / synced / error
#
# On account + contact:
#   alex_paypluscustomeruid            (string)   - PayPlus customer_uid (ensure exists for sync)
#
# Idempotent. Enrichment only - never overwrites core fields.
$ErrorActionPreference = 'Stop'
$org      = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus'

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
function Test-Attr { param([string]$Entity, [string]$Logical)
    try { Invoke-RestMethod -Method Get -Uri "$base/EntityDefinitions(LogicalName='$Entity')/Attributes(LogicalName='$Logical')?`$select=MetadataId" -Headers $headers | Out-Null; return $true }
    catch { return $false }
}
function Add-Attr { param([string]$Entity, [string]$Logical, [hashtable]$Meta)
    if (Test-Attr $Entity $Logical) { Write-Host "  attr exists: $Entity.$Logical"; return }
    Write-Host "  create attr: $Entity.$Logical"
    Invoke-Dv Post "$base/EntityDefinitions(LogicalName='$Entity')/Attributes" $Meta | Out-Null
}

$acct = 'alex_customerbankaccount'
Write-Host '== alex_customerbankaccount: standing order + sync fields =='

Add-Attr $acct 'alex_hasstandingorder' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.BooleanAttributeMetadata'
    SchemaName    = 'alex_HasStandingOrder'
    DisplayName   = New-Label 'Standing order' 'הוראת קבע'
    Description   = New-Label 'Yes if a standing order (direct debit) is active on this bank account.' 'כן אם מוגדרת הוראת קבע פעילה על חשבון הבנק.'
    RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    DefaultValue  = $false
    OptionSet     = @{ TrueOption = @{ Value = 1; Label = New-Label 'Yes' 'כן' }; FalseOption = @{ Value = 0; Label = New-Label 'No' 'לא' } }
}
Add-Attr $acct 'alex_standingordersince' @{
    '@odata.type'   = 'Microsoft.Dynamics.CRM.DateTimeAttributeMetadata'
    SchemaName      = 'alex_StandingOrderSince'
    DisplayName     = New-Label 'Standing order since' 'הוראת קבע מתאריך'
    Description     = New-Label 'Date the standing order became active.' 'התאריך שבו הוראת הקבע נכנסה לתוקף.'
    RequiredLevel   = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    Format          = 'DateOnly'
    DateTimeBehavior = @{ Value = 'DateOnly' }
}
Add-Attr $acct 'alex_standingorderreference' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
    SchemaName    = 'alex_StandingOrderReference'
    DisplayName   = New-Label 'Standing order reference' 'אסמכתא הוראת קבע'
    Description   = New-Label 'Mandate / reference number of the standing order.' 'מספר אסמכתא / הרשאה של הוראת הקבע.'
    RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    MaxLength     = 100
    FormatName    = @{ Value = 'Text' }
}
Add-Attr $acct 'alex_paypluscustomerbankaccountuid' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
    SchemaName    = 'alex_PayPlusCustomerBankAccountUid'
    DisplayName   = New-Label 'PayPlus bank account UID' 'מזהה חשבון בנק ב-PayPlus'
    Description   = New-Label 'PayPlus bank_account_uid returned after syncing this account to PayPlus.' 'מזהה bank_account_uid שמוחזר מ-PayPlus לאחר סנכרון החשבון.'
    RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    MaxLength     = 100
    FormatName    = @{ Value = 'Text' }
}
Add-Attr $acct 'alex_syncstatus' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
    SchemaName    = 'alex_SyncStatus'
    DisplayName   = New-Label 'PayPlus sync status' 'סטטוס סנכרון PayPlus'
    Description   = New-Label 'State of syncing this bank account to PayPlus.' 'מצב סנכרון חשבון הבנק אל PayPlus.'
    RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
    OptionSet     = @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'
        IsGlobal      = $false
        OptionSetType = 'Picklist'
        Options       = @(
            @{ Value = 100000000; Label = New-Label 'Pending' 'ממתין' }
            @{ Value = 100000001; Label = New-Label 'Synced'  'סונכרן' }
            @{ Value = 100000002; Label = New-Label 'Error'   'שגיאה' }
        )
    }
}

foreach ($customerEntity in @('account', 'contact')) {
    Write-Host "== ${customerEntity}: PayPlus customer UID =="
    Add-Attr $customerEntity 'alex_paypluscustomeruid' @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
        SchemaName    = 'alex_PayPlusCustomerUid'
        DisplayName   = New-Label 'PayPlus customer UID' 'מזהה לקוח ב-PayPlus'
        Description   = New-Label 'PayPlus customer_uid mirror of this Dynamics customer.' 'מזהה customer_uid ב-PayPlus כשיקוף של לקוח Dynamics.'
        RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
        MaxLength     = 100
        FormatName    = @{ Value = 'Text' }
    }
}

Write-Host '== lookups on alex_customerbankaccount (for @odata.bind reference) =='
$lk = Invoke-RestMethod -Method Get -Headers $headers -Uri "$base/EntityDefinitions(LogicalName='$acct')/Attributes/Microsoft.Dynamics.CRM.LookupAttributeMetadata?`$select=LogicalName,SchemaName,Targets"
$lk.value | ForEach-Object { Write-Host ("  {0}  schema={1}  targets={2}" -f $_.LogicalName, $_.SchemaName, ($_.Targets -join ',')) }

$es = Invoke-RestMethod -Method Get -Headers $headers -Uri "$base/EntityDefinitions(LogicalName='$acct')?`$select=EntitySetName,LogicalCollectionName"
Write-Host ("  entitySet={0}  collection={1}" -f $es.EntitySetName, $es.LogicalCollectionName)

Write-Host 'Publishing customizations...'
Invoke-Dv Post "$base/PublishAllXml" @{} | Out-Null
Write-Host 'Done.'
