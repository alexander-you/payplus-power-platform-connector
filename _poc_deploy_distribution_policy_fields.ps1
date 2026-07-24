# Creates the dynamic document distribution policy fields on alex_payplusconfiguration
# and migrates the legacy per-channel distribution flags into the new model.

param(
    [string]$Org = 'https://demo-contact-center-en.crm4.dynamics.com',
    [string]$SolutionUniqueName = 'alex_d365_payplus'
)

$ErrorActionPreference = 'Stop'

$entityLogicalName = 'alex_payplusconfiguration'
$solutionHeaderName = 'MSCRM.SolutionUniqueName'

$token = (az account get-access-token --resource $Org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get access token (az account get-access-token).' }

$headers = @{
    Authorization           = "Bearer $token"
    'OData-Version'         = '4.0'
    'OData-MaxVersion'      = '4.0'
    Accept                  = 'application/json'
    'Content-Type'          = 'application/json; charset=utf-8'
    $solutionHeaderName     = $SolutionUniqueName
}
$base = "$Org/api/data/v9.2"

function Get-ErrorContent {
    param([object]$ErrorRecord)

    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
        return $ErrorRecord.ErrorDetails.Message
    }

    $response = $ErrorRecord.Exception.Response
    if ($response -and $response.Content) {
        try { return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() } catch { }
    }

    return $ErrorRecord.Exception.Message
}

function Test-NotFound {
    param([object]$ErrorRecord)

    $response = $ErrorRecord.Exception.Response
    return ($response -and [int]$response.StatusCode -eq 404)
}

function Invoke-Dv {
    param(
        [ValidateSet('Get', 'Post', 'Patch', 'Put', 'Delete')]
        [string]$Method,
        [string]$Uri,
        [object]$Body = $null
    )

    $params = @{ Method = $Method; Uri = $Uri; Headers = $headers }
    if ($null -ne $Body) {
        if ($Body -is [string]) { $json = $Body } else { $json = $Body | ConvertTo-Json -Depth 100 -Compress }
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
    }

    try { return Invoke-RestMethod @params }
    catch { throw "Dataverse $Method failed: $Uri`n$(Get-ErrorContent $_)" }
}

function Get-DataverseOrNull {
    param([string]$Uri)

    try { return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers }
    catch {
        if (Test-NotFound $_) { return $null }
        throw
    }
}

function New-Label {
    param([string]$English, [string]$Hebrew)

    return @{
        LocalizedLabels = @(
            @{ Label = $English; LanguageCode = 1033 },
            @{ Label = $Hebrew; LanguageCode = 1037 }
        )
    }
}

function New-Option {
    param([int]$Value, [string]$English, [string]$Hebrew)

    return @{ Value = $Value; Label = (New-Label $English $Hebrew) }
}

function New-PicklistAttribute {
    param(
        [string]$SchemaName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [object[]]$Options,
        [int]$DefaultValue
    )

    return @{
        '@odata.type'    = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
        SchemaName       = $SchemaName
        DisplayName      = New-Label $EnglishLabel $HebrewLabel
        Description      = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel    = @{
            Value                              = 'None'
            CanBeChanged                       = $true
            ManagedPropertyLogicalName         = 'canmodifyrequirementlevelsettings'
        }
        DefaultFormValue = $DefaultValue
        OptionSet        = @{
            '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'
            IsGlobal      = $false
            OptionSetType = 'Picklist'
            Options       = $Options
        }
    }
}

function Test-AttributeExists {
    param([string]$LogicalName)

    $attribute = Get-DataverseOrNull "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes(LogicalName='$LogicalName')?`$select=LogicalName"
    return ($null -ne $attribute)
}

function Add-PicklistIfMissing {
    param(
        [string]$LogicalName,
        [hashtable]$Metadata
    )

    if (Test-AttributeExists $LogicalName) {
        return [pscustomobject]@{ LogicalName = $LogicalName; Created = $false }
    }

    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes" -Body $Metadata | Out-Null
    return [pscustomobject]@{ LogicalName = $LogicalName; Created = $true }
}

function Remove-AttributeIfExists {
    param([string]$LogicalName)

    if (Test-AttributeExists $LogicalName) {
        Invoke-Dv -Method Delete -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes(LogicalName='$LogicalName')" | Out-Null
        return $true
    }

    return $false
}

function Get-PropertyValue {
    param([object]$Object, [string]$Name)

    if ($null -eq $Object -or -not $Object.PSObject.Properties[$Name]) { return $null }
    return $Object.PSObject.Properties[$Name].Value
}

function Convert-LegacyPolicy {
    param([object]$Config, [string]$Prefix, [string]$Channel)

    $enabled = Get-PropertyValue $Config "$($Prefix)dist_$Channel"
    $method = Get-PropertyValue $Config "$($Prefix)dist_$($Channel)_method"

    if ($enabled -ne $true) { return 100000000 }
    if ($Channel -eq 'whatsapp') { return 100000003 }
    if ($method -eq 100000001) { return 100000003 }
    return 100000001
}

$issuePolicyOptions = @(
    (New-Option 100000000 'Do not send' 'לא לשלוח'),
    (New-Option 100000001 'PayPlus on issue' 'PayPlus בזמן הפקה'),
    (New-Option 100000002 'Business user decides' 'להחלטת המשתמש העסקי'),
    (New-Option 100000003 'Dynamics Flow / plugin' 'Flow / פלאגין ב-Dynamics')
)
$whatsappPolicyOptions = @(
    (New-Option 100000000 'Do not send' 'לא לשלוח'),
    (New-Option 100000002 'Business user decides' 'להחלטת המשתמש העסקי'),
    (New-Option 100000003 'Dynamics Flow / plugin' 'Flow / פלאגין ב-Dynamics')
)
$deliveryLinkOptions = @(
    (New-Option 100000000 'Primary document link' 'קישור מסמך ראשי'),
    (New-Option 100000001 'Original document copy' 'עותק מקור'),
    (New-Option 100000002 'Copy document' 'עותק'),
    (New-Option 100000003 'PDF when available' 'PDF כאשר זמין')
)

$documentTypes = @(
    @{ Key = 'quote'; LabelEn = 'Quote'; LabelHe = 'הצעת מחיר'; Schema = 'Quote' },
    @{ Key = 'invoice'; LabelEn = 'Invoice'; LabelHe = 'חשבונית'; Schema = 'Invoice' },
    @{ Key = 'salesorder'; LabelEn = 'Sales order'; LabelHe = 'הזמנה'; Schema = 'SalesOrder' }
)

$results = @()
foreach ($docType in $documentTypes) {
    $prefix = "alex_doc_$($docType.Key)_"
    $schemaPrefix = "alex_Doc_$($docType.Schema)_"
    $wrongDeliveryName = $prefix + 'delivery_linkmode'
    $desiredDeliveryName = $prefix + 'deliverylinkmode'

    if ((Test-AttributeExists $wrongDeliveryName) -and -not (Test-AttributeExists $desiredDeliveryName)) {
        Remove-AttributeIfExists $wrongDeliveryName | Out-Null
    }

    $results += Add-PicklistIfMissing ($prefix + 'email_issuepolicy') (New-PicklistAttribute `
        ($schemaPrefix + 'Email_IssuePolicy') `
        "$($docType.LabelEn) email issue policy" "מדיניות דוא`"ל בזמן הפקת $($docType.LabelHe)" `
        'Controls email distribution while issuing the document.' 'קובע את מדיניות ההפצה בדוא"ל בזמן הפקת המסמך.' `
        $issuePolicyOptions 100000000)

    $results += Add-PicklistIfMissing ($prefix + 'sms_issuepolicy') (New-PicklistAttribute `
        ($schemaPrefix + 'Sms_IssuePolicy') `
        "$($docType.LabelEn) SMS issue policy" "מדיניות SMS בזמן הפקת $($docType.LabelHe)" `
        'Controls SMS distribution while issuing the document.' 'קובע את מדיניות ההפצה ב-SMS בזמן הפקת המסמך.' `
        $issuePolicyOptions 100000000)

    $results += Add-PicklistIfMissing ($prefix + 'whatsapp_issuepolicy') (New-PicklistAttribute `
        ($schemaPrefix + 'Whatsapp_IssuePolicy') `
        "$($docType.LabelEn) WhatsApp issue policy" "מדיניות WhatsApp בזמן הפקת $($docType.LabelHe)" `
        'Controls WhatsApp distribution policy. PayPlus document API has no WhatsApp send field.' 'קובע את מדיניות ההפצה ב-WhatsApp. ב-API של מסמכי PayPlus אין שדה שליחת WhatsApp.' `
        $whatsappPolicyOptions 100000000)

    $results += Add-PicklistIfMissing ($prefix + 'deliverylinkmode') (New-PicklistAttribute `
        ($schemaPrefix + 'DeliveryLinkMode') `
        "$($docType.LabelEn) delivery link mode" "קישור/עותק להפצת $($docType.LabelHe)" `
        'Controls which PayPlus document link Dynamics automations should use.' 'קובע באיזה קישור/עותק של מסמך PayPlus אוטומציות Dynamics ישתמשו.' `
        $deliveryLinkOptions 100000003)
}

Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = '<importexportxml><entities><entity>alex_payplusconfiguration</entity></entities></importexportxml>' } | Out-Null

$legacySelect = @('alex_payplusconfigurationid')
foreach ($docType in $documentTypes) {
    $prefix = "alex_doc_$($docType.Key)_"
    foreach ($channel in @('email', 'sms', 'whatsapp')) {
        $legacySelect += "$($prefix)dist_$channel"
        $legacySelect += "$($prefix)dist_$($channel)_method"
    }
}

$config = (Invoke-Dv -Method Get -Uri "$base/alex_payplusconfigurations?`$select=$($legacySelect -join ',')&`$top=1").value | Select-Object -First 1
$patch = @{}
if ($config) {
    foreach ($docType in $documentTypes) {
        $prefix = "alex_doc_$($docType.Key)_"
        $patch[$prefix + 'email_issuepolicy'] = Convert-LegacyPolicy $config $prefix 'email'
        $patch[$prefix + 'sms_issuepolicy'] = Convert-LegacyPolicy $config $prefix 'sms'
        $patch[$prefix + 'whatsapp_issuepolicy'] = Convert-LegacyPolicy $config $prefix 'whatsapp'
        $patch[$prefix + 'deliverylinkmode'] = 100000003
    }
    Invoke-Dv -Method Patch -Uri "$base/alex_payplusconfigurations($($config.alex_payplusconfigurationid))" -Body $patch | Out-Null
}

[pscustomobject]@{
    Created = @($results | Where-Object Created).Count
    Existing = @($results | Where-Object { -not $_.Created }).Count
    ConfigId = if ($config) { $config.alex_payplusconfigurationid } else { $null }
    MigratedValues = $patch
    Fields = $results
} | ConvertTo-Json -Depth 10