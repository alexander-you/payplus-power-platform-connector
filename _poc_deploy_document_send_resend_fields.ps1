# Creates the corrected document send/resend configuration fields on alex_payplusconfiguration.
# Scope: fields only. Does not update ribbon, flows, forms, or webresources.

param(
    [string]$Org = 'https://demo-contact-center-en.crm4.dynamics.com',
    [string]$SolutionUniqueName = 'alex_d365_payplus'
)

$ErrorActionPreference = 'Stop'

$entityLogicalName = 'alex_payplusconfiguration'

$token = (az account get-access-token --resource $Org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get access token (az account get-access-token).' }

$headers = @{
    Authorization           = "Bearer $token"
    'OData-Version'         = '4.0'
    'OData-MaxVersion'      = '4.0'
    Accept                  = 'application/json'
    'Content-Type'          = 'application/json; charset=utf-8'
    'MSCRM.SolutionUniqueName' = $SolutionUniqueName
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

function Invoke-Dataverse {
    param(
        [ValidateSet('Get', 'Post', 'Patch')]
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

function New-BooleanAttribute {
    param(
        [string]$SchemaName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [bool]$DefaultValue = $false
    )

    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.BooleanAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = @{
            Value                              = 'None'
            CanBeChanged                       = $true
            ManagedPropertyLogicalName         = 'canmodifyrequirementlevelsettings'
        }
        DefaultValue  = $DefaultValue
        OptionSet     = @{
            TrueOption  = @{ Value = 1; Label = (New-Label 'Yes' 'כן') }
            FalseOption = @{ Value = 0; Label = (New-Label 'No' 'לא') }
        }
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
        [array]$Options,
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

function Add-BooleanIfMissing {
    param(
        [string]$LogicalName,
        [hashtable]$Metadata
    )

    if (Test-AttributeExists $LogicalName) {
        return [pscustomobject]@{ LogicalName = $LogicalName; Created = $false }
    }

    Invoke-Dataverse -Method Post -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes" -Body $Metadata | Out-Null
    return [pscustomobject]@{ LogicalName = $LogicalName; Created = $true }
}

function Add-PicklistIfMissing {
    param(
        [string]$LogicalName,
        [hashtable]$Metadata
    )

    if (Test-AttributeExists $LogicalName) {
        return [pscustomobject]@{ LogicalName = $LogicalName; Created = $false }
    }

    Invoke-Dataverse -Method Post -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes" -Body $Metadata | Out-Null
    return [pscustomobject]@{ LogicalName = $LogicalName; Created = $true }
}

function Get-PropertyValue {
    param([object]$Object, [string]$Name)

    if ($null -eq $Object -or -not $Object.PSObject.Properties[$Name]) { return $null }
    return $Object.PSObject.Properties[$Name].Value
}

function Test-OldPolicyIsPayPlusIssue {
    param([object]$Config, [string]$FieldName)

    return ((Get-PropertyValue $Config $FieldName) -eq 100000001)
}

function Test-OldPolicyAllowsResend {
    param([object]$Config, [string]$FieldName)

    $value = Get-PropertyValue $Config $FieldName
    return ($value -eq 100000002 -or $value -eq 100000003)
}

$documentTypes = @(
    @{ Key = 'quote'; LabelEn = 'Quote'; LabelHe = 'הצעת מחיר'; Schema = 'Quote' },
    @{ Key = 'invoice'; LabelEn = 'Invoice'; LabelHe = 'חשבונית'; Schema = 'Invoice' },
    @{ Key = 'salesorder'; LabelEn = 'Sales order'; LabelHe = 'הזמנה'; Schema = 'SalesOrder' }
)

$results = @()
foreach ($docType in $documentTypes) {
    $prefix = "alex_doc_$($docType.Key)_"
    $schemaPrefix = "alex_Doc_$($docType.Schema)_"

    $results += Add-BooleanIfMissing "$($prefix)issue_send_email" (New-BooleanAttribute `
        "$($schemaPrefix)Issue_Send_Email" `
        "$($docType.LabelEn): send email on issue" "שליחת דוא`"ל בעת הפקת $($docType.LabelHe)" `
        'When true, the PayPlus create-document call asks PayPlus to send the document by email during initial issue.' 'כאשר מופעל, קריאת יצירת המסמך ב-PayPlus מבקשת שליחת דוא"ל בזמן ההפקה הראשונית.')

    $results += Add-BooleanIfMissing "$($prefix)issue_send_sms" (New-BooleanAttribute `
        "$($schemaPrefix)Issue_Send_Sms" `
        "$($docType.LabelEn): send SMS on issue" "שליחת SMS בעת הפקת $($docType.LabelHe)" `
        'When true, the PayPlus create-document call asks PayPlus to send the document by SMS during initial issue.' 'כאשר מופעל, קריאת יצירת המסמך ב-PayPlus מבקשת שליחת SMS בזמן ההפקה הראשונית.')

    $results += Add-BooleanIfMissing "$($prefix)resend_email_allowed" (New-BooleanAttribute `
        "$($schemaPrefix)Resend_Email_Allowed" `
        "$($docType.LabelEn): allow email resend" "אפשר שליחה חוזרת בדוא`"ל עבור $($docType.LabelHe)" `
        'When true, the business allows post-issue email resend from Dynamics. A Flow or plugin must implement the actual send.' 'כאשר מופעל, העסק מאפשר שליחה חוזרת בדוא"ל מתוך Dynamics לאחר ההפקה. Flow או פלאגין צריכים לבצע את השליחה בפועל.')

    $results += Add-BooleanIfMissing "$($prefix)resend_sms_allowed" (New-BooleanAttribute `
        "$($schemaPrefix)Resend_Sms_Allowed" `
        "$($docType.LabelEn): allow SMS resend" "אפשר שליחה חוזרת ב-SMS עבור $($docType.LabelHe)" `
        'When true, the business allows post-issue SMS resend from Dynamics. A Flow or plugin must implement the actual send.' 'כאשר מופעל, העסק מאפשר שליחה חוזרת ב-SMS מתוך Dynamics לאחר ההפקה. Flow או פלאגין צריכים לבצע את השליחה בפועל.')

    $results += Add-BooleanIfMissing "$($prefix)resend_whatsapp_allowed" (New-BooleanAttribute `
        "$($schemaPrefix)Resend_Whatsapp_Allowed" `
        "$($docType.LabelEn): allow WhatsApp resend" "אפשר שליחה חוזרת ב-WhatsApp עבור $($docType.LabelHe)" `
        'When true, the business allows post-issue WhatsApp resend from Dynamics. PayPlus document API does not send WhatsApp; a Flow or plugin must implement the actual send.' 'כאשר מופעל, העסק מאפשר שליחה חוזרת ב-WhatsApp מתוך Dynamics לאחר ההפקה. API מסמכי PayPlus לא שולח WhatsApp; Flow או פלאגין צריכים לבצע את השליחה בפועל.')

    $results += Add-PicklistIfMissing "$($prefix)resend_default_linktype" (New-PicklistAttribute `
        "$($schemaPrefix)Resend_Default_LinkType" `
        "$($docType.LabelEn): resend default link" "ברירת מחדל לקישור שליחה חוזרת עבור $($docType.LabelHe)" `
        'Default document link type selected when requesting post-issue delivery from Dynamics.' 'סוג קישור המסמך שנבחר כברירת מחדל בבקשת שליחה חוזרת מתוך Dynamics.' `
        @((New-Option 100000000 'Original' 'מקור'), (New-Option 100000001 'Copy' 'עותק')) 100000001)

    $results += Add-BooleanIfMissing "$($prefix)resend_original_allowed" (New-BooleanAttribute `
        "$($schemaPrefix)Resend_Original_Allowed" `
        "$($docType.LabelEn): allow original resend" "אפשר שליחת מקור עבור $($docType.LabelHe)" `
        'When true, users may select the original PDF for post-issue delivery from Dynamics.' 'כאשר מופעל, משתמשים יכולים לבחור את PDF המקור לשליחה חוזרת מתוך Dynamics.' $true)

    $results += Add-BooleanIfMissing "$($prefix)resend_copy_allowed" (New-BooleanAttribute `
        "$($schemaPrefix)Resend_Copy_Allowed" `
        "$($docType.LabelEn): allow copy resend" "אפשר שליחת עותק עבור $($docType.LabelHe)" `
        'When true, users may select the copy PDF for post-issue delivery from Dynamics.' 'כאשר מופעל, משתמשים יכולים לבחור את PDF העותק לשליחה חוזרת מתוך Dynamics.' $true)
}

Invoke-Dataverse -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = '<importexportxml><entities><entity>alex_payplusconfiguration</entity></entities></importexportxml>' } | Out-Null

$select = @('alex_payplusconfigurationid')
$existingOldPolicyFields = @{}
foreach ($docType in $documentTypes) {
    $prefix = "alex_doc_$($docType.Key)_"
    foreach ($fieldName in @("$($prefix)email_issuepolicy", "$($prefix)sms_issuepolicy", "$($prefix)whatsapp_issuepolicy")) {
        if (Test-AttributeExists $fieldName) {
            $select += $fieldName
            $existingOldPolicyFields[$fieldName] = $true
        }
    }
    $select += "$($prefix)resend_default_linktype"
    $select += "$($prefix)resend_original_allowed"
    $select += "$($prefix)resend_copy_allowed"
}

$config = (Invoke-Dataverse -Method Get -Uri "$base/alex_payplusconfigurations?`$select=$($select -join ',')&`$top=1").value | Select-Object -First 1
$patch = @{}
if ($config) {
    foreach ($docType in $documentTypes) {
        $prefix = "alex_doc_$($docType.Key)_"
        if ($existingOldPolicyFields.ContainsKey("$($prefix)email_issuepolicy")) {
            $patch["$($prefix)issue_send_email"] = Test-OldPolicyIsPayPlusIssue $config "$($prefix)email_issuepolicy"
            $patch["$($prefix)resend_email_allowed"] = Test-OldPolicyAllowsResend $config "$($prefix)email_issuepolicy"
        }
        if ($existingOldPolicyFields.ContainsKey("$($prefix)sms_issuepolicy")) {
            $patch["$($prefix)issue_send_sms"] = Test-OldPolicyIsPayPlusIssue $config "$($prefix)sms_issuepolicy"
            $patch["$($prefix)resend_sms_allowed"] = Test-OldPolicyAllowsResend $config "$($prefix)sms_issuepolicy"
        }
        if ($existingOldPolicyFields.ContainsKey("$($prefix)whatsapp_issuepolicy")) {
            $patch["$($prefix)resend_whatsapp_allowed"] = Test-OldPolicyAllowsResend $config "$($prefix)whatsapp_issuepolicy"
        }
        if ((Get-PropertyValue $config "$($prefix)resend_default_linktype") -eq $null) { $patch["$($prefix)resend_default_linktype"] = 100000001 }
        if ((Get-PropertyValue $config "$($prefix)resend_original_allowed") -eq $null) { $patch["$($prefix)resend_original_allowed"] = $true }
        if ((Get-PropertyValue $config "$($prefix)resend_copy_allowed") -eq $null) { $patch["$($prefix)resend_copy_allowed"] = $true }
    }
    if ($patch.Count -gt 0) { Invoke-Dataverse -Method Patch -Uri "$base/alex_payplusconfigurations($($config.alex_payplusconfigurationid))" -Body $patch | Out-Null }
}

[pscustomobject]@{
    Created = @($results | Where-Object Created).Count
    Existing = @($results | Where-Object { -not $_.Created }).Count
    ConfigId = if ($config) { $config.alex_payplusconfigurationid } else { $null }
    MigratedValues = $patch
    Fields = $results
} | ConvertTo-Json -Depth 10