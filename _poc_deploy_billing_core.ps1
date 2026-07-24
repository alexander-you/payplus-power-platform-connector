# Deploy PayPlus billing core data model and organization billing policy.
# Scope: base PayPlus solution. Sales-specific source lookups stay in Sales extensions.

param(
    [string]$Org = 'https://demo-contact-center-en.crm4.dynamics.com',
    [string]$SolutionUniqueName = 'alex_d365_payplus',
    [string]$ConfigurationFormId = 'ffe4c2f2-b26d-4e56-ae80-ed8a9cf9dabb',
    [string]$SetupWebResourceId = '356b9ccd-dd7a-f111-ab0e-7ced8d726840',
    [string]$SetupWebResourcePath = 'webresources/alex_payplus_setup.html',
    [switch]$SkipPublish,
    [switch]$SkipWebResource
)

$ErrorActionPreference = 'Stop'

$billingCaseEntity = 'alex_payplusbillingcase'
$paymentLineEntity = 'alex_paypluspaymentline'
$receiptAllocationEntity = 'alex_payplusreceiptallocation'
$documentEntity = 'alex_payplusdocument'
$configurationEntity = 'alex_payplusconfiguration'
$solutionHeaderName = 'MSCRM.SolutionUniqueName'

$token = (az account get-access-token --resource $Org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get access token (az account get-access-token).' }

$headers = @{
    Authorization       = "Bearer $token"
    'OData-Version'     = '4.0'
    'OData-MaxVersion'  = '4.0'
    Accept              = 'application/json'
    'Content-Type'      = 'application/json; charset=utf-8'
    $solutionHeaderName = $SolutionUniqueName
}
$base = "$Org/api/data/v9.2"

function Get-ErrorContent {
    param([object]$ErrorRecord)
    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) { return $ErrorRecord.ErrorDetails.Message }
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
        [ValidateSet('Get', 'Post', 'Patch', 'Put', 'Delete')][string]$Method,
        [string]$Uri,
        [object]$Body = $null,
        [hashtable]$HeadersOverride = $null
    )
    $params = @{ Method = $Method; Uri = $Uri; Headers = $(if ($HeadersOverride) { $HeadersOverride } else { $headers }) }
    if ($null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 100 -Compress }
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
    }
    try { return Invoke-RestMethod @params }
    catch { throw "Dataverse $Method failed: $Uri`n$(Get-ErrorContent $_)" }
}

function Try-GetDv {
    param([string]$Uri)
    try { return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers }
    catch { if (Test-NotFound $_) { return $null } throw }
}

function New-Label {
    param([string]$English, [string]$Hebrew)
    return @{ LocalizedLabels = @(@{ Label = $English; LanguageCode = 1033 }, @{ Label = $Hebrew; LanguageCode = 1037 }) }
}

function New-RequiredLevel {
    param([string]$Value = 'None')
    return @{ Value = $Value; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
}

function New-Option {
    param([int]$Value, [string]$English, [string]$Hebrew)
    return @{ Value = $Value; Label = (New-Label $English $Hebrew) }
}

function New-StringAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [int]$MaxLength = 100, [string]$RequiredLevel = 'None', [string]$FormatName = 'Text')
    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = New-RequiredLevel $RequiredLevel
        MaxLength     = $MaxLength
        FormatName    = @{ Value = $FormatName }
    }
}

function New-MemoAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [int]$MaxLength = 1048576)
    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.MemoAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = New-RequiredLevel 'None'
        MaxLength     = $MaxLength
        FormatName    = @{ Value = 'TextArea' }
    }
}

function New-IntegerAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [int]$MinValue = -2147483648, [int]$MaxValue = 2147483647)
    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.IntegerAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = New-RequiredLevel 'None'
        MinValue      = $MinValue
        MaxValue      = $MaxValue
        Format        = 'None'
    }
}

function New-DecimalAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [decimal]$MinValue = -100000000000, [decimal]$MaxValue = 100000000000, [int]$Precision = 4)
    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.DecimalAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = New-RequiredLevel 'None'
        MinValue      = $MinValue
        MaxValue      = $MaxValue
        Precision     = $Precision
    }
}

function New-BooleanAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [bool]$DefaultValue = $false)
    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.BooleanAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = New-RequiredLevel 'None'
        DefaultValue  = $DefaultValue
        OptionSet     = @{ TrueOption = @{ Value = 1; Label = New-Label 'Yes' 'כן' }; FalseOption = @{ Value = 0; Label = New-Label 'No' 'לא' } }
    }
}

function New-PicklistAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [array]$Options, [object]$DefaultFormValue = $null, [string]$RequiredLevel = 'None')
    $metadata = @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = New-RequiredLevel $RequiredLevel
        OptionSet     = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'; IsGlobal = $false; OptionSetType = 'Picklist'; Options = $Options }
    }
    if ($null -ne $DefaultFormValue) { $metadata.DefaultFormValue = [int]$DefaultFormValue }
    return $metadata
}

function New-DateTimeAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription)
    return @{
        '@odata.type'    = 'Microsoft.Dynamics.CRM.DateTimeAttributeMetadata'
        SchemaName       = $SchemaName
        DisplayName      = New-Label $EnglishLabel $HebrewLabel
        Description      = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel    = New-RequiredLevel 'None'
        Format           = 'DateAndTime'
        DateTimeBehavior = @{ Value = 'UserLocal' }
    }
}

function New-DateOnlyAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription)
    return @{
        '@odata.type'    = 'Microsoft.Dynamics.CRM.DateTimeAttributeMetadata'
        SchemaName       = $SchemaName
        DisplayName      = New-Label $EnglishLabel $HebrewLabel
        Description      = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel    = New-RequiredLevel 'None'
        Format           = 'DateOnly'
        DateTimeBehavior = @{ Value = 'DateOnly' }
    }
}

function Get-EntityMeta {
    param([string]$Entity)
    return Try-GetDv "$base/EntityDefinitions(LogicalName='$Entity')?`$select=MetadataId,LogicalName,EntitySetName"
}

function Test-EntityExists {
    param([string]$Entity)
    return ($null -ne (Get-EntityMeta $Entity))
}

function Test-AttributeExists {
    param([string]$Entity, [string]$LogicalName)
    $attr = Try-GetDv "$base/EntityDefinitions(LogicalName='$Entity')/Attributes(LogicalName='$LogicalName')?`$select=MetadataId,LogicalName"
    return ($null -ne $attr)
}

function Add-AttributeIfMissing {
    param([string]$Entity, [string]$LogicalName, [hashtable]$Metadata)
    if (Test-AttributeExists $Entity $LogicalName) { Write-Host "  attr exists: $Entity.$LogicalName"; return [pscustomobject]@{ Entity=$Entity; LogicalName=$LogicalName; Created=$false } }
    Write-Host "  create attr: $Entity.$LogicalName"
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$Entity')/Attributes" -Body $Metadata | Out-Null
    return [pscustomobject]@{ Entity=$Entity; LogicalName=$LogicalName; Created=$true }
}

function Ensure-Entity {
    param([string]$Entity, [string]$EnglishName, [string]$HebrewName, [string]$EnglishCollection, [string]$HebrewCollection, [string]$EnglishDescription, [string]$HebrewDescription, [bool]$HasNotes = $false)
    $meta = Get-EntityMeta $Entity
    if ($meta) { Write-Host "Entity exists: $Entity ($($meta.MetadataId))"; return $meta }

    Write-Host "Creating entity: $Entity"
    $body = @{
        '@odata.type'         = 'Microsoft.Dynamics.CRM.EntityMetadata'
        SchemaName            = $Entity
        DisplayName           = New-Label $EnglishName $HebrewName
        DisplayCollectionName = New-Label $EnglishCollection $HebrewCollection
        Description           = New-Label $EnglishDescription $HebrewDescription
        OwnershipType         = 'UserOwned'
        HasActivities         = $false
        HasNotes              = $HasNotes
        IsActivity            = $false
        Attributes            = @(@{
            '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
            SchemaName    = 'alex_name'
            DisplayName   = New-Label 'Name' 'שם'
            Description   = New-Label 'Primary display name.' 'שם תצוגה ראשי.'
            RequiredLevel = New-RequiredLevel 'ApplicationRequired'
            MaxLength     = 300
            FormatName    = @{ Value = 'Text' }
            IsPrimaryName = $true
        })
    }
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions" -Body $body | Out-Null
    $meta = Get-EntityMeta $Entity
    if (-not $meta) { throw "Entity created but metadata not available yet: $Entity" }
    return $meta
}

function Ensure-Lookup {
    param(
        [string]$SchemaName,
        [string]$ReferencedEntity,
        [string]$ReferencingEntity,
        [string]$LookupSchema,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [string]$RequiredLevel = 'None',
        [string]$DeleteCascade = 'RemoveLink'
    )
    if (-not (Test-EntityExists $ReferencedEntity)) { Write-Warning "Skipping lookup $LookupSchema because target entity does not exist: $ReferencedEntity"; return }
    if (-not (Test-EntityExists $ReferencingEntity)) { Write-Warning "Skipping lookup $LookupSchema because referencing entity does not exist: $ReferencingEntity"; return }
    $rel = Try-GetDv "$base/RelationshipDefinitions(SchemaName='$SchemaName')?`$select=MetadataId,SchemaName"
    if ($rel) { Write-Host "  rel exists: $SchemaName"; return }

    Write-Host "  create rel: $SchemaName"
    $body = @{
        '@odata.type'        = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
        SchemaName           = $SchemaName
        ReferencedEntity     = $ReferencedEntity
        ReferencingEntity    = $ReferencingEntity
        CascadeConfiguration = @{ Assign='NoCascade'; Delete=$DeleteCascade; Merge='NoCascade'; Reparent='NoCascade'; Share='NoCascade'; Unshare='NoCascade'; RollupView='NoCascade' }
        Lookup               = @{
            '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'
            SchemaName    = $LookupSchema
            DisplayName   = New-Label $EnglishLabel $HebrewLabel
            Description   = New-Label $EnglishDescription $HebrewDescription
            RequiredLevel = New-RequiredLevel $RequiredLevel
            Targets       = @($ReferencedEntity)
        }
    }
    Invoke-Dv -Method Post -Uri "$base/RelationshipDefinitions" -Body $body | Out-Null
}

function Ensure-ConfigBillingPolicyFields {
    $defaultFlowOptions = @(
        (New-Option 100000000 'Proforma invoice' 'חשבונית עסקה'),
        (New-Option 100000001 'Payment request' 'בקשת תשלום'),
        (New-Option 100000002 'Tax invoice' 'חשבונית מס'),
        (New-Option 100000003 'Tax invoice receipt' 'חשבונית מס קבלה'),
        (New-Option 100000004 'Manual choice' 'בחירה ידנית')
    )
    $cancellationOptions = @(
        (New-Option 100000000 'Manual review required' 'נדרשת בדיקה ידנית'),
        (New-Option 100000001 'Create reversal documents' 'יצירת מסמכי ביטול/זיכוי'),
        (New-Option 100000002 'Block after receipt' 'חסימה לאחר קבלה')
    )
    $paymentPageOptions = @(
        (New-Option 100000000 'Do not include payment page' 'לא לצרף עמוד תשלום'),
        (New-Option 100000001 'User decides' 'להחלטת המשתמש'),
        (New-Option 100000003 'Include for open-balance documents' 'לצרף למסמכים עם יתרה פתוחה')
    )
    $savedTokenOptions = @(
        (New-Option 100000000 'Do not use saved token charge' 'לא להשתמש בחיוב טוקן שמור'),
        (New-Option 100000001 'User decides' 'להחלטת המשתמש'),
        (New-Option 100000002 'Prefer saved token when available' 'להעדיף טוקן שמור כאשר קיים'),
        (New-Option 100000003 'Require saved token when available' 'לחייב בטוקן שמור כאשר קיים')
    )
    $tokenFallbackOptions = @(
        (New-Option 100000000 'Offer payment page' 'להציע עמוד תשלום'),
        (New-Option 100000001 'User decides' 'להחלטת המשתמש'),
        (New-Option 100000002 'Block token charge' 'לחסום חיוב טוקן')
    )

    $results = @()
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_default_flow' (New-PicklistAttribute 'alex_Billing_Default_Flow' 'Default billing flow' 'מסלול גבייה ברירת מחדל' 'Defines which accounting document flow is used by default for invoice/billing actions.' 'קובע איזה מסלול מסמך חשבונאי ישמש כברירת מחדל לפעולות חיוב וחשבוניות.' $defaultFlowOptions 100000004)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_allow_user_override' (New-BooleanAttribute 'alex_Billing_Allow_User_Override' 'Allow user override' 'אפשר שינוי על ידי משתמש' 'Allows business users to override the default billing flow when a process explicitly supports it.' 'מאפשר למשתמשים עסקיים לשנות את מסלול הגבייה כאשר התהליך תומך בכך במפורש.' $false)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_require_receipt_to_close_invoice' (New-BooleanAttribute 'alex_Billing_Require_Receipt_To_Close_Invoice' 'Require receipt to close invoice' 'נדרשת קבלה לסגירת חשבונית' 'Keeps an issued invoice open until receipt allocations cover its amount.' 'משאיר חשבונית שהופקה פתוחה עד שקבלות משויכות מכסות את סכומה.' $true)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_auto_close_invoice_when_receipts_match' (New-BooleanAttribute 'alex_Billing_Auto_Close_Invoice_When_Receipts_Match' 'Auto-close invoice when receipt amount matches' 'סגור אוטומטית חשבונית כאשר סכום הקבלה תואם' 'Marks the invoice as paid when one receipt, or the sum of allocated receipts, covers the invoice amount.' 'מסמן את החשבונית כשולמה כאשר קבלה אחת, או סך הקבלות המשויכות, מכסה את סכום החשבונית.' $true)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_auto_receipt_after_payment' (New-BooleanAttribute 'alex_Billing_Auto_Receipt_After_Payment' 'Auto receipt after payment' 'הפק קבלה אוטומטית לאחר תשלום' 'Allows automation to create a receipt after a successful PayPlus payment.' 'מאפשר לאוטומציה ליצור קבלה לאחר תשלום מוצלח ב-PayPlus.' $false)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_cancellation_policy' (New-PicklistAttribute 'alex_Billing_Cancellation_Policy' 'Cancellation policy' 'מדיניות ביטול' 'Controls the default approach for cancelling or reversing issued billing documents.' 'קובע את ברירת המחדל לביטול או היפוך מסמכי חיוב שהופקו.' $cancellationOptions 100000000)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_create_d365_reversal_invoice' (New-BooleanAttribute 'alex_Billing_Create_D365_Reversal_Invoice' 'Create D365 reversal invoice on cancellation' 'צור חשבונית נגדית ב-D365 בעת ביטול' 'Controls whether Dynamics 365 should also create a reversal invoice when an issued PayPlus accounting document is cancelled. Requires validation that credit/negative lines are supported.' 'קובע האם ליצור גם חשבונית נגדית ב-Dynamics 365 בעת ביטול מסמך חשבונאי שהופק ב-PayPlus. דורש אימות שתמיכה בשורות זיכוי/מינוס קיימת.' $false)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_payment_page_policy' (New-PicklistAttribute 'alex_Billing_Payment_Page_Policy' 'Payment page link policy' 'מדיניות צירוף עמוד תשלום' 'Controls when a PayPlus payment page link should be included with billing documents.' 'קובע מתי לצרף קישור לעמוד תשלום PayPlus למסמכי חיוב.' $paymentPageOptions 100000001)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_create_payment_page_with_document' (New-BooleanAttribute 'alex_Billing_Create_Payment_Page_With_Document' 'Create payment page with billing document' 'חולל עמוד תשלום עם מסמך הגבייה' 'Creates a PayPlus payment page immediately when a billing document is issued, when the process supports it.' 'יוצר עמוד תשלום PayPlus מיד בעת הפקת מסמך גבייה, כאשר התהליך תומך בכך.' $false)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_saved_token_policy' (New-PicklistAttribute 'alex_Billing_Saved_Token_Policy' 'Saved token charge policy' 'מדיניות חיוב טוקן שמור' 'Controls when the billing wizard should use a saved PayPlus card token for direct charge.' 'קובע מתי אשף הגבייה ישתמש בטוקן כרטיס PayPlus שמור לחיוב ישיר.' $savedTokenOptions 100000001)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_token_charge_requires_confirm' (New-BooleanAttribute 'alex_Billing_Token_Charge_Requires_Confirm' 'Require confirmation for token charge' 'דרוש אישור לחיוב טוקן' 'Requires explicit user confirmation before a saved token is charged.' 'מחייב אישור משתמש מפורש לפני חיוב טוקן שמור.' $true)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_token_missing_fallback' (New-PicklistAttribute 'alex_Billing_Token_Missing_Fallback' 'Missing token fallback' 'חלופה כאשר אין טוקן' 'Controls what the wizard should offer when token charge is selected but no saved token is available.' 'קובע מה האשף יציע כאשר נבחר חיוב טוקן אך אין טוקן שמור זמין.' $tokenFallbackOptions 100000000)
    $results += Add-AttributeIfMissing $configurationEntity 'alex_billing_payment_page_create_token' (New-BooleanAttribute 'alex_Billing_Payment_Page_Create_Token' 'Create token from payment page' 'יצירת טוקן מעמוד תשלום' 'Requests token creation when a payment page is used, so future billing can use saved token charge.' 'מבקש יצירת טוקן כאשר משתמשים בעמוד תשלום, כדי שחיובים עתידיים יוכלו להשתמש בטוקן שמור.' $true)

    $billingDocuments = @(
        @{ Key = 'taxinvoice'; Schema = 'TaxInvoice'; En = 'Tax invoice'; He = 'חשבונית מס' },
        @{ Key = 'taxinvoicereceipt'; Schema = 'TaxInvoiceReceipt'; En = 'Tax invoice receipt'; He = 'חשבונית מס קבלה' },
        @{ Key = 'paymentdemand'; Schema = 'PaymentDemand'; En = 'Proforma invoice'; He = 'חשבונית עסקה' },
        @{ Key = 'paymentrequest'; Schema = 'PaymentRequest'; En = 'Payment request'; He = 'בקשת תשלום' },
        @{ Key = 'receipt'; Schema = 'Receipt'; En = 'Receipt'; He = 'קבלה' },
        @{ Key = 'credit'; Schema = 'Credit'; En = 'Credit invoice'; He = 'חשבונית זיכוי' }
    )
    # Receipt and credit documents are reactive: a receipt is produced when money is captured and a
    # credit invoice reverses an already-issued document. They are never drafted, previewed, or bulk
    # created up front, so - like the tax invoice receipt - they only expose enable, issue, and send.
    $sendOnlyDocKeys = @('taxinvoicereceipt', 'receipt', 'credit')
    foreach ($doc in $billingDocuments) {
        $prefix = "alex_billing_doc_$($doc.Key)_"
        $schemaPrefix = "alex_Billing_Doc_$($doc.Schema)_"
        $results += Add-AttributeIfMissing $configurationEntity ($prefix + 'enabled') (New-BooleanAttribute ($schemaPrefix + 'Enabled') "$($doc.En) enabled" "$($doc.He) פעיל" "Allows this billing document type to appear in PayPlus invoice actions." "מאפשר להציג סוג מסמך גבייה זה בפעולות PayPlus לחשבונית." $true)
        $results += Add-AttributeIfMissing $configurationEntity ($prefix + 'issue_allowed') (New-BooleanAttribute ($schemaPrefix + 'Issue_Allowed') "$($doc.En) issue allowed" "אפשר הפקת $($doc.He)" "Allows issuing this billing document type." "מאפשר להפיק סוג מסמך גבייה זה." $true)
        # Tax invoice receipt, receipt, and credit invoice are issued only through their own processes
        # (payment capture / reversal), so they have no standalone preview and no bulk creation; those
        # attributes are intentionally not created for them.
        if ($doc.Key -notin $sendOnlyDocKeys) {
            $results += Add-AttributeIfMissing $configurationEntity ($prefix + 'preview_allowed') (New-BooleanAttribute ($schemaPrefix + 'Preview_Allowed') "$($doc.En) preview allowed" "אפשר תצוגה מקדימה של $($doc.He)" "Allows previewing this billing document type before issue." "מאפשר תצוגה מקדימה של מסמך זה לפני הפקה." $true)
            $results += Add-AttributeIfMissing $configurationEntity ($prefix + 'bulkcreate') (New-BooleanAttribute ($schemaPrefix + 'BulkCreate') "$($doc.En) bulk creation allowed" "אפשר יצירה מרובה של $($doc.He)" "Allows creating multiple documents of this billing type from list views." "מאפשר יצירה מרובה של מסמכים מסוג גבייה זה מתוך תצוגות רשימה." $false)
        }
        $results += Add-AttributeIfMissing $configurationEntity ($prefix + 'send_email_allowed') (New-BooleanAttribute ($schemaPrefix + 'Send_Email_Allowed') "$($doc.En) email send allowed" "אפשר שליחת $($doc.He) בדוא״ל" "Allows sending this billing document by email." "מאפשר שליחת מסמך גבייה זה בדוא״ל." $true)
        $results += Add-AttributeIfMissing $configurationEntity ($prefix + 'send_sms_allowed') (New-BooleanAttribute ($schemaPrefix + 'Send_Sms_Allowed') "$($doc.En) SMS send allowed" "אפשר שליחת $($doc.He) ב-SMS" "Allows sending this billing document by SMS." "מאפשר שליחת מסמך גבייה זה ב-SMS." $true)
        $results += Add-AttributeIfMissing $configurationEntity ($prefix + 'send_whatsapp_allowed') (New-BooleanAttribute ($schemaPrefix + 'Send_Whatsapp_Allowed') "$($doc.En) WhatsApp send allowed" "אפשר שליחת $($doc.He) ב-WhatsApp" "Allows sending this billing document by WhatsApp." "מאפשר שליחת מסמך גבייה זה ב-WhatsApp." $true)
    }
    return $results
}

function Ensure-BillingCaseAttributes {
    $statusOptions = @(
        (New-Option 100000000 'Draft' 'טיוטה'),
        (New-Option 100000001 'Open' 'פתוח'),
        (New-Option 100000002 'Payment requested' 'נשלחה בקשת תשלום'),
        (New-Option 100000003 'Invoiced' 'הופקה חשבונית'),
        (New-Option 100000004 'Partially paid' 'שולם חלקית'),
        (New-Option 100000005 'Paid / closed' 'שולם / נסגר'),
        (New-Option 100000006 'Cancellation pending' 'ביטול ממתין'),
        (New-Option 100000007 'Cancelled' 'בוטל'),
        (New-Option 100000008 'Failed' 'נכשל')
    )
    $flowOptions = @(
        (New-Option 100000000 'Proforma invoice' 'חשבונית עסקה'),
        (New-Option 100000001 'Payment request' 'בקשת תשלום'),
        (New-Option 100000002 'Tax invoice' 'חשבונית מס'),
        (New-Option 100000003 'Tax invoice receipt' 'חשבונית מס קבלה'),
        (New-Option 100000004 'Manual choice' 'בחירה ידנית')
    )

    Add-AttributeIfMissing $billingCaseEntity 'alex_uniqueidentifier' (New-StringAttribute 'alex_UniqueIdentifier' 'Unique Identifier' 'מזהה ייחודי' 'Correlation key for this billing case.' 'מפתח קורלציה לתיק חיוב זה.' 200) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_status' (New-PicklistAttribute 'alex_Status' 'Billing status' 'סטטוס גבייה' 'Lifecycle status of the billing case.' 'סטטוס מחזור החיים של תיק הגבייה.' $statusOptions 100000000) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_defaultflow' (New-PicklistAttribute 'alex_DefaultFlow' 'Selected billing flow' 'מסלול גבייה שנבחר' 'Billing flow selected or inherited for this case.' 'מסלול הגבייה שנבחר או הועתק לתיק זה.' $flowOptions 100000004) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_sourceentitylogicalname' (New-StringAttribute 'alex_SourceEntityLogicalName' 'Source table logical name' 'שם לוגי של טבלת מקור' 'Logical name of the source Dataverse table.' 'שם לוגי של טבלת המקור ב-Dataverse.' 100) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_sourceentityid' (New-StringAttribute 'alex_SourceEntityId' 'Source row ID' 'מזהה רשומת מקור' 'Dataverse source row ID.' 'מזהה רשומת המקור ב-Dataverse.' 100) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_sourcedisplayname' (New-StringAttribute 'alex_SourceDisplayName' 'Source display name' 'שם תצוגת מקור' 'Source record number or display name.' 'מספר או שם תצוגה של רשומת המקור.' 300) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_sourceurl' (New-StringAttribute 'alex_SourceUrl' 'Source URL' 'קישור למקור' 'URL to the source Dataverse record.' 'כתובת לרשומת המקור ב-Dataverse.' 2000 'None' 'Url') | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_currencycode' (New-StringAttribute 'alex_CurrencyCode' 'Currency code' 'קוד מטבע' 'ISO currency code for this billing case.' 'קוד מטבע ISO של תיק החיוב.' 3) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_totalamount' (New-DecimalAttribute 'alex_TotalAmount' 'Total amount' 'סכום כולל' 'Total amount expected for this billing case.' 'הסכום הכולל הצפוי לתיק חיוב זה.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_vatamount' (New-DecimalAttribute 'alex_VatAmount' 'VAT amount' 'סכום מע״מ' 'VAT amount for this billing case.' 'סכום המע״מ בתיק החיוב.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_paidamount' (New-DecimalAttribute 'alex_PaidAmount' 'Paid amount' 'סכום ששולם' 'Amount allocated by receipts.' 'סכום ששויך באמצעות קבלות.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_openbalance' (New-DecimalAttribute 'alex_OpenBalance' 'Open balance' 'יתרה פתוחה' 'Current open balance.' 'היתרה הפתוחה הנוכחית.' -100000000000 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_requirereceipttocloseinvoice' (New-BooleanAttribute 'alex_RequireReceiptToCloseInvoice' 'Require receipt to close invoice' 'נדרשת קבלה לסגירת חשבונית' 'Snapshot of whether receipts are required to close an invoice in this case.' 'תצלום האם נדרשת קבלה לסגירת חשבונית בתיק זה.' $true) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_customername' (New-StringAttribute 'alex_CustomerName' 'Customer name' 'שם לקוח' 'Customer name snapshot.' 'תצלום שם הלקוח.' 300) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_customeremail' (New-StringAttribute 'alex_CustomerEmail' 'Customer email' 'דוא״ל לקוח' 'Customer email snapshot.' 'תצלום דוא״ל הלקוח.' 200 'None' 'Email') | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_customerphone' (New-StringAttribute 'alex_CustomerPhone' 'Customer phone' 'טלפון לקוח' 'Customer phone snapshot.' 'תצלום טלפון הלקוח.' 100 'None' 'Phone') | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_customervatnumber' (New-StringAttribute 'alex_CustomerVatNumber' 'Customer VAT number' 'מספר עוסק/ח.פ לקוח' 'Customer VAT, company, or ID number snapshot.' 'תצלום מספר עוסק, ח.פ או ת.ז של הלקוח.' 100) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_openedon' (New-DateTimeAttribute 'alex_OpenedOn' 'Opened on' 'נפתח בתאריך' 'Date and time the billing case was opened.' 'תאריך ושעה שבהם תיק הגבייה נפתח.') | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_closedon' (New-DateTimeAttribute 'alex_ClosedOn' 'Closed on' 'נסגר בתאריך' 'Date and time the billing case was closed.' 'תאריך ושעה שבהם תיק הגבייה נסגר.') | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_cancelledon' (New-DateTimeAttribute 'alex_CancelledOn' 'Cancelled on' 'בוטל בתאריך' 'Date and time the billing case was cancelled.' 'תאריך ושעה שבהם תיק הגבייה בוטל.') | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_notes' (New-MemoAttribute 'alex_Notes' 'Notes' 'הערות' 'Operational notes for this billing case.' 'הערות תפעוליות לתיק גבייה זה.' 4000) | Out-Null
}

function Ensure-PaymentLineAttributes {
    $chargeModeOptions = @(
        (New-Option 100000000 'Recorded payment' 'תשלום נרשם ידנית'),
        (New-Option 100000001 'Payment page' 'עמוד תשלום'),
        (New-Option 100000002 'Saved token charge' 'חיוב טוקן שמור'),
        (New-Option 100000003 'Imported PayPlus transaction' 'עסקת PayPlus מיובאת')
    )
    $methodOptions = @(
        (New-Option 100000000 'Cash' 'מזומן'),
        (New-Option 100000001 'Check' 'צ׳ק'),
        (New-Option 100000002 'Credit card' 'כרטיס אשראי'),
        (New-Option 100000003 'Bank transfer' 'העברה בנקאית'),
        (New-Option 100000004 'PayPlus transaction' 'עסקת PayPlus'),
        (New-Option 100000005 'Direct debit' 'הוראת קבע'),
        (New-Option 100000006 'Other' 'אחר')
    )
    $statusOptions = @(
        (New-Option 100000000 'Draft' 'טיוטה'),
        (New-Option 100000001 'Pending' 'ממתין'),
        (New-Option 100000002 'Cleared' 'נפרע'),
        (New-Option 100000003 'Cancelled' 'בוטל'),
        (New-Option 100000004 'Failed' 'נכשל')
    )

    Add-AttributeIfMissing $paymentLineEntity 'alex_sequence' (New-IntegerAttribute 'alex_Sequence' 'Sequence' 'סדר' 'Payment line order in the receipt.' 'סדר שורת התשלום בקבלה.' 1 10000) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_chargemode' (New-PicklistAttribute 'alex_ChargeMode' 'Charge mode' 'אופן חיוב' 'How this payment line is collected or recorded.' 'האופן שבו שורת תשלום זו נגבית או נרשמת.' $chargeModeOptions 100000000) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_paymentmethod' (New-PicklistAttribute 'alex_PaymentMethod' 'Payment method' 'אמצעי תשלום' 'Payment method for this line.' 'אמצעי התשלום של שורה זו.' $methodOptions 100000001) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_status' (New-PicklistAttribute 'alex_Status' 'Payment status' 'סטטוס תשלום' 'Processing status of this payment line.' 'סטטוס עיבוד של שורת תשלום זו.' $statusOptions 100000000) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_amount' (New-DecimalAttribute 'alex_Amount' 'Amount' 'סכום' 'Payment amount.' 'סכום התשלום.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_currencycode' (New-StringAttribute 'alex_CurrencyCode' 'Currency code' 'קוד מטבע' 'ISO currency code.' 'קוד מטבע ISO.' 3) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_paymentdate' (New-DateOnlyAttribute 'alex_PaymentDate' 'Payment date' 'תאריך תשלום' 'Payment date.' 'תאריך התשלום.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_duedate' (New-DateOnlyAttribute 'alex_DueDate' 'Due date' 'תאריך פירעון' 'Due date for checks or deferred payments.' 'תאריך פירעון לצ׳קים או תשלומים דחויים.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_reference' (New-StringAttribute 'alex_Reference' 'Reference' 'אסמכתא' 'External or manual payment reference.' 'אסמכתת תשלום חיצונית או ידנית.' 200) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_externaltransactionid' (New-StringAttribute 'alex_ExternalTransactionId' 'External transaction ID' 'מזהה עסקה חיצוני' 'External payment processor transaction ID.' 'מזהה עסקה במעבד תשלומים חיצוני.' 200) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_checknumber' (New-StringAttribute 'alex_CheckNumber' 'Check number' 'מספר צ׳ק' 'Check number.' 'מספר הצ׳ק.' 50) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_banknumber' (New-StringAttribute 'alex_BankNumber' 'Bank number' 'מספר בנק' 'Bank number for check payments.' 'מספר בנק עבור תשלום בצ׳ק.' 20) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_branchnumber' (New-StringAttribute 'alex_BranchNumber' 'Branch number' 'מספר סניף' 'Branch number for check payments.' 'מספר סניף עבור תשלום בצ׳ק.' 20) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_accountnumber' (New-StringAttribute 'alex_AccountNumber' 'Bank account number' 'מספר חשבון בנק' 'Bank account number for check payments.' 'מספר חשבון בנק עבור תשלום בצ׳ק.' 50) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_cardlast4' (New-StringAttribute 'alex_CardLast4' 'Card last 4' 'ארבע ספרות אחרונות' 'Last four digits of a card payment.' 'ארבע ספרות אחרונות של תשלום בכרטיס.' 4) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_cardbrand' (New-StringAttribute 'alex_CardBrand' 'Card brand' 'מותג כרטיס' 'Card brand, when available.' 'מותג הכרטיס, כאשר זמין.' 100) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_approvalnumber' (New-StringAttribute 'alex_ApprovalNumber' 'Approval number' 'מספר אישור' 'Card or payment approval number.' 'מספר אישור של כרטיס או תשלום.' 100) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_installments' (New-IntegerAttribute 'alex_Installments' 'Installments' 'מספר תשלומים' 'Number of card installments.' 'מספר תשלומי האשראי.' 1 120) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_tokenchargeconfirmed' (New-BooleanAttribute 'alex_TokenChargeConfirmed' 'Token charge confirmed' 'חיוב טוקן אושר' 'Indicates that a user explicitly confirmed direct saved-token charge for this payment line.' 'מציין שמשתמש אישר במפורש חיוב ישיר של טוקן שמור עבור שורת תשלום זו.' $false) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_tokenchargeconfirmedon' (New-DateTimeAttribute 'alex_TokenChargeConfirmedOn' 'Token charge confirmed on' 'חיוב טוקן אושר בתאריך' 'Date and time when token charge was confirmed.' 'תאריך ושעה שבהם אושר חיוב הטוקן.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_tokenchargeconfirmedby' (New-StringAttribute 'alex_TokenChargeConfirmedBy' 'Token charge confirmed by' 'חיוב טוקן אושר על ידי' 'User name or ID that confirmed token charge.' 'שם או מזהה המשתמש שאישר חיוב טוקן.' 300) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_banktransferreference' (New-StringAttribute 'alex_BankTransferReference' 'Bank transfer reference' 'אסמכתת העברה בנקאית' 'Reference for a bank transfer.' 'אסמכתה להעברה בנקאית.' 200) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_rawpaymentjson' (New-MemoAttribute 'alex_RawPaymentJson' 'Raw payment JSON' 'JSON תשלום גולמי' 'Raw payment payload used or returned by PayPlus.' 'Payload תשלום גולמי שנשלח או חזר מ-PayPlus.' 1048576) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_notes' (New-MemoAttribute 'alex_Notes' 'Notes' 'הערות' 'Payment line notes.' 'הערות לשורת התשלום.' 4000) | Out-Null
}

function Ensure-ReceiptAllocationAttributes {
    $statusOptions = @(
        (New-Option 100000000 'Draft' 'טיוטה'),
        (New-Option 100000001 'Applied' 'שויך'),
        (New-Option 100000002 'Reversed' 'הופך')
    )
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_allocatedamount' (New-DecimalAttribute 'alex_AllocatedAmount' 'Allocated amount' 'סכום משויך' 'Amount allocated from a receipt/payment line to an invoice or billing case.' 'סכום ששויך מקבלה/שורת תשלום לחשבונית או תיק חיוב.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_currencycode' (New-StringAttribute 'alex_CurrencyCode' 'Currency code' 'קוד מטבע' 'ISO currency code.' 'קוד מטבע ISO.' 3) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_status' (New-PicklistAttribute 'alex_Status' 'Allocation status' 'סטטוס שיוך' 'Processing status of the receipt allocation.' 'סטטוס עיבוד של שיוך הקבלה.' $statusOptions 100000000) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_allocatedon' (New-DateTimeAttribute 'alex_AllocatedOn' 'Allocated on' 'שויך בתאריך' 'Date and time the allocation was applied.' 'תאריך ושעה שבהם השיוך בוצע.') | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_notes' (New-MemoAttribute 'alex_Notes' 'Notes' 'הערות' 'Allocation notes.' 'הערות לשיוך.' 4000) | Out-Null
}

function Ensure-DocumentBillingAttributes {
    $roleOptions = @(
        (New-Option 100000000 'Proforma invoice' 'חשבונית עסקה'),
        (New-Option 100000001 'Tax invoice' 'חשבונית מס'),
        (New-Option 100000002 'Receipt' 'קבלה'),
        (New-Option 100000003 'Tax invoice receipt' 'חשבונית מס קבלה'),
        (New-Option 100000004 'Credit / cancellation' 'זיכוי / ביטול'),
        (New-Option 100000005 'Receipt cancellation' 'קבלת ביטול')
    )
    Add-AttributeIfMissing $documentEntity 'alex_documentrole' (New-PicklistAttribute 'alex_DocumentRole' 'Billing document role' 'תפקיד מסמך בגבייה' 'Role of this PayPlus document inside a billing case.' 'תפקיד מסמך PayPlus זה בתוך תיק גבייה.' $roleOptions) | Out-Null
    Add-AttributeIfMissing $documentEntity 'alex_balanceimpact' (New-DecimalAttribute 'alex_BalanceImpact' 'Balance impact' 'השפעה על יתרה' 'Signed amount by which this document affects the billing balance.' 'סכום חתום שבו המסמך משפיע על יתרת תיק הגבייה.' -100000000000 100000000000 4) | Out-Null
    Add-AttributeIfMissing $documentEntity 'alex_billingsequence' (New-IntegerAttribute 'alex_BillingSequence' 'Billing sequence' 'סדר בתיק גבייה' 'Document order inside the billing case.' 'סדר המסמך בתוך תיק הגבייה.' 1 10000) | Out-Null
}

function Ensure-Relationships {
    Ensure-Lookup 'alex_payplusconfiguration_alex_payplusbillingcase' $configurationEntity $billingCaseEntity 'alex_configurationid' 'Configuration' 'קונפיגורציה' 'PayPlus configuration used by this billing case.' 'קונפיגורציית PayPlus ששימשה לתיק חיוב זה.' 'ApplicationRequired'
    Ensure-Lookup 'alex_account_alex_payplusbillingcase' 'account' $billingCaseEntity 'alex_accountid' 'Account' 'לקוח' 'Customer account related to this billing case.' 'לקוח המקושר לתיק חיוב זה.'
    Ensure-Lookup 'alex_contact_alex_payplusbillingcase' 'contact' $billingCaseEntity 'alex_contactid' 'Contact' 'איש קשר' 'Customer contact related to this billing case.' 'איש קשר המקושר לתיק חיוב זה.'

    Ensure-Lookup 'alex_payplusbillingcase_alex_payplusdocument' $billingCaseEntity $documentEntity 'alex_billingcaseid' 'Billing Case' 'תיק גבייה' 'Billing case that groups this PayPlus document with related invoices, receipts, payments, and reversals.' 'תיק הגבייה שמקבץ מסמך PayPlus זה עם חשבוניות, קבלות, תשלומים וביטולים קשורים.'
    Ensure-Lookup 'alex_parent_payplusdocument_alex_payplusdocument' $documentEntity $documentEntity 'alex_parentdocumentid' 'Parent PayPlus Document' 'מסמך PayPlus אב' 'Parent document in the billing document chain.' 'מסמך אב בשרשרת מסמכי הגבייה.'
    Ensure-Lookup 'alex_reversed_payplusdocument_alex_payplusdocument' $documentEntity $documentEntity 'alex_reversesdocumentid' 'Reverses PayPlus Document' 'מבטל מסמך PayPlus' 'Original document reversed or credited by this document.' 'המסמך המקורי שמסמך זה מבטל או מזכה.'
    Ensure-Lookup 'alex_invoice_payplusdocument_alex_payplusdocument' $documentEntity $documentEntity 'alex_relatedinvoicedocumentid' 'Related Invoice Document' 'חשבונית קשורה' 'Invoice document related to this receipt or reversal.' 'מסמך החשבונית המקושר לקבלה או לביטול זה.'

    Ensure-Lookup 'alex_payplusbillingcase_alex_paypluspaymentline' $billingCaseEntity $paymentLineEntity 'alex_billingcaseid' 'Billing Case' 'תיק גבייה' 'Billing case this payment line belongs to.' 'תיק הגבייה שאליו שייכת שורת תשלום זו.' 'ApplicationRequired' 'Cascade'
    Ensure-Lookup 'alex_receipt_payplusdocument_alex_paypluspaymentline' $documentEntity $paymentLineEntity 'alex_receiptdocumentid' 'Receipt Document' 'מסמך קבלה' 'Receipt PayPlus document created from this payment line.' 'מסמך קבלה PayPlus שנוצר משורת תשלום זו.'
    Ensure-Lookup 'alex_creditcard_alex_paypluspaymentline' 'alex_creditcard' $paymentLineEntity 'alex_creditcardid' 'Saved Card' 'כרטיס שמור' 'Saved PayPlus card token selected for direct token charge.' 'טוקן כרטיס PayPlus שמור שנבחר לחיוב ישיר.'

    Ensure-Lookup 'alex_payplusbillingcase_alex_payplusreceiptallocation' $billingCaseEntity $receiptAllocationEntity 'alex_billingcaseid' 'Billing Case' 'תיק גבייה' 'Billing case this receipt allocation belongs to.' 'תיק הגבייה שאליו שייך שיוך קבלה זה.' 'ApplicationRequired' 'Cascade'
    Ensure-Lookup 'alex_paypluspaymentline_alex_payplusreceiptallocation' $paymentLineEntity $receiptAllocationEntity 'alex_paymentlineid' 'Payment Line' 'שורת תשלום' 'Payment line allocated to an invoice or billing case.' 'שורת התשלום המשויכת לחשבונית או לתיק חיוב.'
    Ensure-Lookup 'alex_invoice_payplusdocument_alex_payplusreceiptallocation' $documentEntity $receiptAllocationEntity 'alex_invoicedocumentid' 'Invoice Document' 'מסמך חשבונית' 'Invoice document being closed by this allocation.' 'מסמך החשבונית שנסגר על ידי שיוך זה.'
    Ensure-Lookup 'alex_receipt_payplusdocument_alex_payplusreceiptallocation' $documentEntity $receiptAllocationEntity 'alex_receiptdocumentid' 'Receipt Document' 'מסמך קבלה' 'Receipt document that carries this allocation.' 'מסמך הקבלה שנושא שיוך זה.'
}

function New-GuidText { return ([guid]::NewGuid().ToString('B')).ToUpperInvariant() }
function Escape-XmlAttribute { param([AllowNull()][string]$Value) if ($null -eq $Value) { return '' } return [System.Security.SecurityElement]::Escape($Value) }

$classes = @{
    String   = '{4273EDBD-AC1D-40d3-9FB2-095C621B552D}'
    Memo     = '{E0DECE4B-6FC8-4a8f-A065-082708572369}'
    Picklist = '{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}'
    Boolean  = '{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}'
    Integer  = '{C6D124CA-7EDA-4A60-AEA9-7FB8D318B68F}'
    Decimal  = '{C3EFE0C3-0EC6-42be-8349-CBD9079DFD8E}'
    DateTime = '{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}'
    Lookup   = '{270BD3DB-D9AF-4782-9025-509E298DEC0A}'
}

function New-FormCellXml {
    param([string]$Field, [string]$EnglishLabel, [string]$HebrewLabel, [string]$ClassId)
    return '<row><cell id="{0}" showlabel="true"><labels><label description="{1}" languagecode="1033" /><label description="{2}" languagecode="1037" /></labels><control id="{3}" classid="{4}" datafieldname="{3}" /></cell></row>' -f (New-GuidText), (Escape-XmlAttribute $EnglishLabel), (Escape-XmlAttribute $HebrewLabel), $Field, $ClassId
}

function New-FormSectionXml {
    param([string]$Name, [string]$EnglishLabel, [string]$HebrewLabel, [array]$Rows)
    return '<section name="{0}" showlabel="true" showbar="false" IsUserDefined="1" id="{1}"><labels><label description="{2}" languagecode="1033" /><label description="{3}" languagecode="1037" /></labels><rows>{4}</rows></section>' -f $Name, (New-GuidText), (Escape-XmlAttribute $EnglishLabel), (Escape-XmlAttribute $HebrewLabel), ($Rows -join '')
}

function Ensure-MainForm {
    param([string]$Entity, [array]$Sections, [string[]]$RequiredFields)
    $existing = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq '$Entity' and type eq 2 and name eq 'מידע'&`$top=1"
    $existingForm = if ($existing.value.Count -gt 0) { $existing.value[0] } else { $null }
    $formXml = '<form><tabs><tab name="tab_information" verticallayout="true" id="{0}" IsUserDefined="1"><labels><label description="Information" languagecode="1033" /><label description="מידע" languagecode="1037" /></labels><columns><column width="100%"><sections>{1}</sections></column></columns></tab></tabs></form>' -f (New-GuidText), ($Sections -join '')
    if ($existingForm) {
        $missing = @($RequiredFields | Where-Object { $existingForm.formxml -notlike "*datafieldname=`"$_`"*" -and $existingForm.formxml -notlike "*datafieldname='$_'*" })
        if ($missing.Count -eq 0) { Write-Host "Main form already includes billing fields: $Entity"; return }
        Write-Host "Updating main form: $Entity / מידע"
        Invoke-Dv -Method Patch -Uri "$base/systemforms($($existingForm.formid))" -Body @{ formxml = $formXml } | Out-Null
        return
    }
    Write-Host "Creating main form: $Entity / מידע"
    Invoke-Dv -Method Post -Uri "$base/systemforms" -Body @{ name='מידע'; type=2; objecttypecode=$Entity; formxml=$formXml } | Out-Null
}

function Ensure-Forms {
    $caseSections = @(
        (New-FormSectionXml 'sec_general' 'General' 'כללי' @(
            (New-FormCellXml 'alex_name' 'Name' 'שם' $classes.String),
            (New-FormCellXml 'alex_status' 'Billing status' 'סטטוס גבייה' $classes.Picklist),
            (New-FormCellXml 'alex_defaultflow' 'Selected billing flow' 'מסלול גבייה שנבחר' $classes.Picklist),
            (New-FormCellXml 'alex_configurationid' 'Configuration' 'קונפיגורציה' $classes.Lookup),
            (New-FormCellXml 'alex_accountid' 'Account' 'לקוח' $classes.Lookup),
            (New-FormCellXml 'alex_contactid' 'Contact' 'איש קשר' $classes.Lookup)
        )),
        (New-FormSectionXml 'sec_amounts' 'Amounts' 'סכומים' @(
            (New-FormCellXml 'alex_currencycode' 'Currency code' 'קוד מטבע' $classes.String),
            (New-FormCellXml 'alex_totalamount' 'Total amount' 'סכום כולל' $classes.Decimal),
            (New-FormCellXml 'alex_vatamount' 'VAT amount' 'סכום מע״מ' $classes.Decimal),
            (New-FormCellXml 'alex_paidamount' 'Paid amount' 'סכום ששולם' $classes.Decimal),
            (New-FormCellXml 'alex_openbalance' 'Open balance' 'יתרה פתוחה' $classes.Decimal)
        )),
        (New-FormSectionXml 'sec_source' 'Source' 'מקור' @(
            (New-FormCellXml 'alex_sourceentitylogicalname' 'Source table' 'טבלת מקור' $classes.String),
            (New-FormCellXml 'alex_sourceentityid' 'Source row ID' 'מזהה רשומת מקור' $classes.String),
            (New-FormCellXml 'alex_sourcedisplayname' 'Source display name' 'שם תצוגת מקור' $classes.String),
            (New-FormCellXml 'alex_sourceurl' 'Source URL' 'קישור למקור' $classes.String)
        )),
        (New-FormSectionXml 'sec_lifecycle' 'Lifecycle' 'מחזור חיים' @(
            (New-FormCellXml 'alex_openedon' 'Opened on' 'נפתח בתאריך' $classes.DateTime),
            (New-FormCellXml 'alex_closedon' 'Closed on' 'נסגר בתאריך' $classes.DateTime),
            (New-FormCellXml 'alex_cancelledon' 'Cancelled on' 'בוטל בתאריך' $classes.DateTime),
            (New-FormCellXml 'alex_notes' 'Notes' 'הערות' $classes.Memo)
        ))
    )
    Ensure-MainForm $billingCaseEntity $caseSections @('alex_status','alex_totalamount','alex_openbalance')

    $paymentSections = @(
        (New-FormSectionXml 'sec_general' 'General' 'כללי' @(
            (New-FormCellXml 'alex_name' 'Name' 'שם' $classes.String),
            (New-FormCellXml 'alex_billingcaseid' 'Billing Case' 'תיק גבייה' $classes.Lookup),
            (New-FormCellXml 'alex_receiptdocumentid' 'Receipt Document' 'מסמך קבלה' $classes.Lookup),
            (New-FormCellXml 'alex_sequence' 'Sequence' 'סדר' $classes.Integer),
            (New-FormCellXml 'alex_chargemode' 'Charge mode' 'אופן חיוב' $classes.Picklist),
            (New-FormCellXml 'alex_paymentmethod' 'Payment method' 'אמצעי תשלום' $classes.Picklist),
            (New-FormCellXml 'alex_status' 'Payment status' 'סטטוס תשלום' $classes.Picklist),
            (New-FormCellXml 'alex_amount' 'Amount' 'סכום' $classes.Decimal),
            (New-FormCellXml 'alex_duedate' 'Due date' 'תאריך פירעון' $classes.DateTime)
        )),
        (New-FormSectionXml 'sec_check' 'Check details' 'פרטי צ׳ק' @(
            (New-FormCellXml 'alex_checknumber' 'Check number' 'מספר צ׳ק' $classes.String),
            (New-FormCellXml 'alex_banknumber' 'Bank number' 'מספר בנק' $classes.String),
            (New-FormCellXml 'alex_branchnumber' 'Branch number' 'מספר סניף' $classes.String),
            (New-FormCellXml 'alex_accountnumber' 'Bank account number' 'מספר חשבון בנק' $classes.String)
        )),
        (New-FormSectionXml 'sec_card' 'Card / transfer' 'כרטיס / העברה' @(
            (New-FormCellXml 'alex_cardlast4' 'Card last 4' 'ארבע ספרות אחרונות' $classes.String),
            (New-FormCellXml 'alex_creditcardid' 'Saved Card' 'כרטיס שמור' $classes.Lookup),
            (New-FormCellXml 'alex_cardbrand' 'Card brand' 'מותג כרטיס' $classes.String),
            (New-FormCellXml 'alex_approvalnumber' 'Approval number' 'מספר אישור' $classes.String),
            (New-FormCellXml 'alex_installments' 'Installments' 'מספר תשלומים' $classes.Integer),
            (New-FormCellXml 'alex_tokenchargeconfirmed' 'Token charge confirmed' 'חיוב טוקן אושר' $classes.Boolean),
            (New-FormCellXml 'alex_tokenchargeconfirmedon' 'Token charge confirmed on' 'חיוב טוקן אושר בתאריך' $classes.DateTime),
            (New-FormCellXml 'alex_tokenchargeconfirmedby' 'Token charge confirmed by' 'חיוב טוקן אושר על ידי' $classes.String),
            (New-FormCellXml 'alex_banktransferreference' 'Bank transfer reference' 'אסמכתת העברה בנקאית' $classes.String)
        ))
    )
    Ensure-MainForm $paymentLineEntity $paymentSections @('alex_paymentmethod','alex_amount','alex_billingcaseid','alex_chargemode','alex_creditcardid')

    $allocationSections = @(
        (New-FormSectionXml 'sec_general' 'General' 'כללי' @(
            (New-FormCellXml 'alex_name' 'Name' 'שם' $classes.String),
            (New-FormCellXml 'alex_billingcaseid' 'Billing Case' 'תיק גבייה' $classes.Lookup),
            (New-FormCellXml 'alex_paymentlineid' 'Payment Line' 'שורת תשלום' $classes.Lookup),
            (New-FormCellXml 'alex_invoicedocumentid' 'Invoice Document' 'מסמך חשבונית' $classes.Lookup),
            (New-FormCellXml 'alex_receiptdocumentid' 'Receipt Document' 'מסמך קבלה' $classes.Lookup),
            (New-FormCellXml 'alex_allocatedamount' 'Allocated amount' 'סכום משויך' $classes.Decimal),
            (New-FormCellXml 'alex_status' 'Allocation status' 'סטטוס שיוך' $classes.Picklist),
            (New-FormCellXml 'alex_allocatedon' 'Allocated on' 'שויך בתאריך' $classes.DateTime)
        ))
    )
    Ensure-MainForm $receiptAllocationEntity $allocationSections @('alex_allocatedamount','alex_invoicedocumentid','alex_receiptdocumentid')
}

function Ensure-DocumentBillingFieldsOnForms {
    $forms = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq '$documentEntity' and type eq 2"
    foreach ($form in $forms.value) {
        if ($form.formxml -like '*datafieldname="alex_billingcaseid"*' -or $form.formxml -like "*datafieldname='alex_billingcaseid'*") { Write-Host "Document form already has billing fields: $($form.name)"; continue }
        $rows = @(
            (New-FormCellXml 'alex_billingcaseid' 'Billing Case' 'תיק גבייה' $classes.Lookup),
            (New-FormCellXml 'alex_documentrole' 'Billing document role' 'תפקיד מסמך בגבייה' $classes.Picklist),
            (New-FormCellXml 'alex_parentdocumentid' 'Parent PayPlus Document' 'מסמך PayPlus אב' $classes.Lookup),
            (New-FormCellXml 'alex_reversesdocumentid' 'Reverses PayPlus Document' 'מבטל מסמך PayPlus' $classes.Lookup),
            (New-FormCellXml 'alex_relatedinvoicedocumentid' 'Related Invoice Document' 'חשבונית קשורה' $classes.Lookup),
            (New-FormCellXml 'alex_balanceimpact' 'Balance impact' 'השפעה על יתרה' $classes.Decimal)
        )
        $section = New-FormSectionXml 'sec_billing_context' 'Billing Context' 'הקשר גבייה' $rows
        $newFormXml = ([regex]'</sections>').Replace($form.formxml, "$section</sections>", 1)
        if ($newFormXml -eq $form.formxml) { Write-Warning "Could not find sections node on PayPlus document form: $($form.name)"; continue }
        Write-Host "Updating PayPlus document form with billing fields: $($form.name)"
        Invoke-Dv -Method Patch -Uri "$base/systemforms($($form.formid))" -Body @{ formxml = $newFormXml } | Out-Null
    }
}

function Ensure-ConfigurationBillingPolicyTab {
    $form = Invoke-Dv -Method Get -Uri "$base/systemforms($ConfigurationFormId)?`$select=formxml"
    [xml]$xml = $form.formxml
    $fields = @(
        @{ Name='alex_billing_default_flow'; En='Default billing flow'; He='מסלול גבייה ברירת מחדל'; Class=$classes.Picklist },
        @{ Name='alex_billing_allow_user_override'; En='Allow user override'; He='אפשר שינוי על ידי משתמש'; Class=$classes.Boolean },
        @{ Name='alex_billing_require_receipt_to_close_invoice'; En='Require receipt to close invoice'; He='נדרשת קבלה לסגירת חשבונית'; Class=$classes.Boolean },
        @{ Name='alex_billing_auto_close_invoice_when_receipts_match'; En='Auto-close invoice when receipt amount matches'; He='סגור אוטומטית חשבונית כאשר סכום הקבלה תואם'; Class=$classes.Boolean },
        @{ Name='alex_billing_auto_receipt_after_payment'; En='Auto receipt after payment'; He='הפק קבלה אוטומטית לאחר תשלום'; Class=$classes.Boolean },
        @{ Name='alex_billing_cancellation_policy'; En='Cancellation policy'; He='מדיניות ביטול'; Class=$classes.Picklist },
        @{ Name='alex_billing_payment_page_policy'; En='Payment page link policy'; He='מדיניות צירוף עמוד תשלום'; Class=$classes.Picklist },
        @{ Name='alex_billing_create_payment_page_with_document'; En='Create payment page with billing document'; He='חולל עמוד תשלום עם מסמך הגבייה'; Class=$classes.Boolean },
        @{ Name='alex_billing_saved_token_policy'; En='Saved token charge policy'; He='מדיניות חיוב טוקן שמור'; Class=$classes.Picklist },
        @{ Name='alex_billing_token_charge_requires_confirm'; En='Require confirmation for token charge'; He='דרוש אישור לחיוב טוקן'; Class=$classes.Boolean },
        @{ Name='alex_billing_token_missing_fallback'; En='Missing token fallback'; He='חלופה כאשר אין טוקן'; Class=$classes.Picklist },
        @{ Name='alex_billing_payment_page_create_token'; En='Create token from payment page'; He='יצירת טוקן מעמוד תשלום'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_taxinvoice_bulkcreate'; En='Tax invoice bulk creation'; He='יצירה מרובה של חשבונית מס'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_paymentdemand_bulkcreate'; En='Proforma invoice bulk creation'; He='יצירה מרובה של חשבונית עסקה'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_paymentrequest_bulkcreate'; En='Payment request bulk creation'; He='יצירה מרובה של בקשת תשלום'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_receipt_enabled'; En='Receipt enabled'; He='קבלה פעיל'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_receipt_issue_allowed'; En='Receipt issue allowed'; He='אפשר הפקת קבלה'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_receipt_send_email_allowed'; En='Receipt email send allowed'; He='אפשר שליחת קבלה בדוא״ל'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_receipt_send_sms_allowed'; En='Receipt SMS send allowed'; He='אפשר שליחת קבלה ב-SMS'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_receipt_send_whatsapp_allowed'; En='Receipt WhatsApp send allowed'; He='אפשר שליחת קבלה ב-WhatsApp'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_credit_enabled'; En='Credit invoice enabled'; He='חשבונית זיכוי פעיל'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_credit_issue_allowed'; En='Credit invoice issue allowed'; He='אפשר הפקת חשבונית זיכוי'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_credit_send_email_allowed'; En='Credit invoice email send allowed'; He='אפשר שליחת חשבונית זיכוי בדוא״ל'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_credit_send_sms_allowed'; En='Credit invoice SMS send allowed'; He='אפשר שליחת חשבונית זיכוי ב-SMS'; Class=$classes.Boolean },
        @{ Name='alex_billing_doc_credit_send_whatsapp_allowed'; En='Credit invoice WhatsApp send allowed'; He='אפשר שליחת חשבונית זיכוי ב-WhatsApp'; Class=$classes.Boolean }
    )
    $existing = $xml.SelectSingleNode("//tab[@name='tab_billing_policy']")
    if ($existing) {
        $rowsNode = $existing.SelectSingleNode('.//section[@name=''sec_billing_policy'']/rows')
        if (-not $rowsNode) { $rowsNode = $existing.SelectSingleNode('.//section/rows') }
        if (-not $rowsNode) { throw 'Billing Policy tab exists but has no rows node.' }

        $inserted = 0
        foreach ($field in $fields) {
            if ($existing.SelectSingleNode(".//control[@datafieldname='$($field.Name)']")) { continue }
            $fragment = $xml.CreateDocumentFragment()
            $fragment.InnerXml = New-FormCellXml $field.Name $field.En $field.He $field.Class
            $rowsNode.AppendChild($fragment.FirstChild) | Out-Null
            $inserted++
        }
        if ($inserted -gt 0) {
            Write-Host "Updating Billing Policy tab with missing fields: $inserted"
            Invoke-Dv -Method Patch -Uri "$base/systemforms($ConfigurationFormId)" -Body @{ formxml = $xml.OuterXml } | Out-Null
        }
        else {
            Write-Host 'Configuration form already has Billing Policy tab.'
        }
        return
    }

    $rows = @($fields | ForEach-Object { New-FormCellXml $_.Name $_.En $_.He $_.Class })
    $section = New-FormSectionXml 'sec_billing_policy' 'Billing Policy' 'מדיניות גבייה' $rows
    $tabXml = '<tab name="tab_billing_policy" verticallayout="true" id="{0}" IsUserDefined="1"><labels><label description="Billing Policy" languagecode="1033" /><label description="מדיניות גבייה" languagecode="1037" /></labels><columns><column width="100%"><sections>{1}</sections></column></columns></tab>' -f (New-GuidText), $section
    $fragment = $xml.CreateDocumentFragment()
    $fragment.InnerXml = $tabXml
    $tabs = $xml.SelectSingleNode('//tabs')
    if (-not $tabs) { throw 'Configuration form has no tabs node.' }
    $anchorTab = $xml.SelectSingleNode("//tab[.//control[@datafieldname='alex_document_vat_mode']]")
    if ($anchorTab -and $anchorTab.NextSibling) { $tabs.InsertBefore($fragment.FirstChild, $anchorTab.NextSibling) | Out-Null }
    elseif ($anchorTab) { $tabs.AppendChild($fragment.FirstChild) | Out-Null }
    else { $tabs.AppendChild($fragment.FirstChild) | Out-Null }
    Invoke-Dv -Method Patch -Uri "$base/systemforms($ConfigurationFormId)" -Body @{ formxml = $xml.OuterXml } | Out-Null
}

function New-ViewLayoutXml {
    param([string]$EntityIdName, [array]$Columns)
    $cells = ($Columns | ForEach-Object { "<cell name='$($_.Name)' width='$($_.Width)' />" }) -join ''
    return "<grid name='resultset' object='1' jump='alex_name' select='1' icon='1' preview='1'><row name='result' id='$EntityIdName'>$cells</row></grid>"
}

function Ensure-View {
    param([string]$Entity, [string]$Name, [string]$FetchXml, [string]$LayoutXml)
    $nameEsc = $Name.Replace("'", "''")
    $existing = Invoke-Dv -Method Get -Uri "$base/savedqueries?`$select=savedqueryid,name&`$filter=returnedtypecode eq '$Entity' and querytype eq 0 and name eq '$nameEsc'&`$top=1"
    if ($existing.value.Count -gt 0) { Write-Host "View exists: $Name"; return }
    Write-Host "Creating view: $Name"
    Invoke-Dv -Method Post -Uri "$base/savedqueries" -Body @{ name=$Name; returnedtypecode=$Entity; querytype=0; fetchxml=$FetchXml; layoutxml=$LayoutXml } | Out-Null
}

function Ensure-Views {
    Ensure-View $billingCaseEntity 'תיקי גבייה פעילים' "<fetch><entity name='$billingCaseEntity'><attribute name='alex_name' /><attribute name='alex_status' /><attribute name='alex_sourcedisplayname' /><attribute name='alex_customername' /><attribute name='alex_totalamount' /><attribute name='alex_paidamount' /><attribute name='alex_openbalance' /><order attribute='modifiedon' descending='true' /></entity></fetch>" (New-ViewLayoutXml 'alex_payplusbillingcaseid' @(@{Name='alex_status';Width=140},@{Name='alex_sourcedisplayname';Width=180},@{Name='alex_customername';Width=220},@{Name='alex_totalamount';Width=120},@{Name='alex_paidamount';Width=120},@{Name='alex_openbalance';Width=120}))
    Ensure-View $paymentLineEntity 'שורות תשלום פעילות' "<fetch><entity name='$paymentLineEntity'><attribute name='alex_name' /><attribute name='alex_billingcaseid' /><attribute name='alex_sequence' /><attribute name='alex_chargemode' /><attribute name='alex_paymentmethod' /><attribute name='alex_creditcardid' /><attribute name='alex_amount' /><attribute name='alex_duedate' /><attribute name='alex_status' /><order attribute='createdon' descending='true' /></entity></fetch>" (New-ViewLayoutXml 'alex_paypluspaymentlineid' @(@{Name='alex_billingcaseid';Width=180},@{Name='alex_sequence';Width=80},@{Name='alex_chargemode';Width=140},@{Name='alex_paymentmethod';Width=140},@{Name='alex_creditcardid';Width=180},@{Name='alex_amount';Width=120},@{Name='alex_duedate';Width=120},@{Name='alex_status';Width=120}))
    Ensure-View $receiptAllocationEntity 'שיוכי קבלות פעילים' "<fetch><entity name='$receiptAllocationEntity'><attribute name='alex_name' /><attribute name='alex_billingcaseid' /><attribute name='alex_paymentlineid' /><attribute name='alex_invoicedocumentid' /><attribute name='alex_receiptdocumentid' /><attribute name='alex_allocatedamount' /><attribute name='alex_status' /><order attribute='createdon' descending='true' /></entity></fetch>" (New-ViewLayoutXml 'alex_payplusreceiptallocationid' @(@{Name='alex_billingcaseid';Width=180},@{Name='alex_paymentlineid';Width=180},@{Name='alex_invoicedocumentid';Width=180},@{Name='alex_receiptdocumentid';Width=180},@{Name='alex_allocatedamount';Width=120},@{Name='alex_status';Width=120}))
}

function Publish-WebResource {
    if ($SkipWebResource) { Write-Host 'Skipping setup web resource publish by request.'; return }
    $fullPath = Join-Path $PSScriptRoot $SetupWebResourcePath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Missing setup webresource source file: $fullPath" }
    $content = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fullPath))
    $body = @{ content = $content } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/webresourceset($SetupWebResourceId)" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $body | Out-Null
    Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = "<importexportxml><webresources><webresource>$SetupWebResourceId</webresource></webresources></importexportxml>" } | Out-Null
}

function Publish-Entities {
    param([string[]]$Entities)
    if ($SkipPublish) { Write-Host 'Skipping publish by request.'; return }
    $entityXml = ($Entities | ForEach-Object { "<entity>$_</entity>" }) -join ''
    Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = "<importexportxml><entities>$entityXml</entities></importexportxml>" } | Out-Null
}

function Backfill-ConfigurationDefaults {
    Publish-Entities @($configurationEntity)
    $billingDocumentDefaultFields = @(
        'alex_billing_doc_taxinvoice_enabled','alex_billing_doc_taxinvoice_issue_allowed','alex_billing_doc_taxinvoice_preview_allowed','alex_billing_doc_taxinvoice_bulkcreate','alex_billing_doc_taxinvoice_send_email_allowed','alex_billing_doc_taxinvoice_send_sms_allowed','alex_billing_doc_taxinvoice_send_whatsapp_allowed',
        'alex_billing_doc_taxinvoicereceipt_enabled','alex_billing_doc_taxinvoicereceipt_issue_allowed','alex_billing_doc_taxinvoicereceipt_send_email_allowed','alex_billing_doc_taxinvoicereceipt_send_sms_allowed','alex_billing_doc_taxinvoicereceipt_send_whatsapp_allowed',
        'alex_billing_doc_paymentdemand_enabled','alex_billing_doc_paymentdemand_issue_allowed','alex_billing_doc_paymentdemand_preview_allowed','alex_billing_doc_paymentdemand_bulkcreate','alex_billing_doc_paymentdemand_send_email_allowed','alex_billing_doc_paymentdemand_send_sms_allowed','alex_billing_doc_paymentdemand_send_whatsapp_allowed',
        'alex_billing_doc_paymentrequest_enabled','alex_billing_doc_paymentrequest_issue_allowed','alex_billing_doc_paymentrequest_preview_allowed','alex_billing_doc_paymentrequest_bulkcreate','alex_billing_doc_paymentrequest_send_email_allowed','alex_billing_doc_paymentrequest_send_sms_allowed','alex_billing_doc_paymentrequest_send_whatsapp_allowed',
        'alex_billing_doc_receipt_enabled','alex_billing_doc_receipt_issue_allowed','alex_billing_doc_receipt_send_email_allowed','alex_billing_doc_receipt_send_sms_allowed','alex_billing_doc_receipt_send_whatsapp_allowed',
        'alex_billing_doc_credit_enabled','alex_billing_doc_credit_issue_allowed','alex_billing_doc_credit_send_email_allowed','alex_billing_doc_credit_send_sms_allowed','alex_billing_doc_credit_send_whatsapp_allowed'
    )
    $select = 'alex_payplusconfigurationid,alex_billing_default_flow,alex_billing_allow_user_override,alex_billing_require_receipt_to_close_invoice,alex_billing_auto_close_invoice_when_receipts_match,alex_billing_auto_receipt_after_payment,alex_billing_cancellation_policy,alex_billing_create_d365_reversal_invoice,alex_billing_payment_page_policy,alex_billing_create_payment_page_with_document,alex_billing_saved_token_policy,alex_billing_token_charge_requires_confirm,alex_billing_token_missing_fallback,alex_billing_payment_page_create_token,' + ($billingDocumentDefaultFields -join ',')
    $config = (Invoke-Dv -Method Get -Uri "$base/alex_payplusconfigurations?`$select=$select&`$top=1").value | Select-Object -First 1
    if (-not $config) { return $null }
    $patch = @{}
    if ($null -eq $config.alex_billing_default_flow) { $patch.alex_billing_default_flow = 100000004 }
    if ($null -eq $config.alex_billing_allow_user_override) { $patch.alex_billing_allow_user_override = $false }
    if ($null -eq $config.alex_billing_require_receipt_to_close_invoice) { $patch.alex_billing_require_receipt_to_close_invoice = $true }
    if ($null -eq $config.alex_billing_auto_close_invoice_when_receipts_match) { $patch.alex_billing_auto_close_invoice_when_receipts_match = $true }
    if ($null -eq $config.alex_billing_auto_receipt_after_payment) { $patch.alex_billing_auto_receipt_after_payment = $false }
    if ($null -eq $config.alex_billing_cancellation_policy) { $patch.alex_billing_cancellation_policy = 100000000 }
    if ($null -eq $config.alex_billing_create_d365_reversal_invoice) { $patch.alex_billing_create_d365_reversal_invoice = $false }
    if ($null -eq $config.alex_billing_payment_page_policy -or $config.alex_billing_payment_page_policy -eq 100000002) { $patch.alex_billing_payment_page_policy = 100000001 }
    if ($null -eq $config.alex_billing_create_payment_page_with_document) { $patch.alex_billing_create_payment_page_with_document = $false }
    if ($null -eq $config.alex_billing_saved_token_policy) { $patch.alex_billing_saved_token_policy = 100000001 }
    if ($null -eq $config.alex_billing_token_charge_requires_confirm) { $patch.alex_billing_token_charge_requires_confirm = $true }
    if ($null -eq $config.alex_billing_token_missing_fallback) { $patch.alex_billing_token_missing_fallback = 100000000 }
    if ($null -eq $config.alex_billing_payment_page_create_token) { $patch.alex_billing_payment_page_create_token = $true }
    foreach ($fieldName in $billingDocumentDefaultFields) {
        if (-not $config.PSObject.Properties[$fieldName] -or $null -eq $config.PSObject.Properties[$fieldName].Value) {
            $patch[$fieldName] = if ($fieldName -like '*_bulkcreate') { $false } else { $true }
        }
    }
    if ($patch.Count -gt 0) { Invoke-Dv -Method Patch -Uri "$base/alex_payplusconfigurations($($config.alex_payplusconfigurationid))" -Body $patch | Out-Null }
    return [pscustomobject]@{ ConfigId=$config.alex_payplusconfigurationid; DefaultsApplied=$patch }
}

$createdConfigFields = Ensure-ConfigBillingPolicyFields
Ensure-Entity $billingCaseEntity 'PayPlus Billing Case' 'תיק גבייה PayPlus' 'PayPlus Billing Cases' 'תיקי גבייה PayPlus' 'Business transaction container that groups payment requests, invoices, receipts, payment lines, allocations, and reversals.' 'מיכל טרנזקציה עסקית שמקבץ דרישות תשלום, חשבוניות, קבלות, שורות תשלום, שיוכים וביטולים.' $true | Out-Null
Ensure-Entity $paymentLineEntity 'PayPlus Payment Line' 'שורת תשלום PayPlus' 'PayPlus Payment Lines' 'שורות תשלום PayPlus' 'One payment instrument line, such as a check, credit card charge, cash payment, or bank transfer.' 'שורת אמצעי תשלום אחת, כגון צ׳ק, חיוב אשראי, מזומן או העברה בנקאית.' $false | Out-Null
Ensure-Entity $receiptAllocationEntity 'PayPlus Receipt Allocation' 'שיוך קבלה PayPlus' 'PayPlus Receipt Allocations' 'שיוכי קבלות PayPlus' 'Allocation of a receipt or payment line to an invoice or billing balance.' 'שיוך קבלה או שורת תשלום לחשבונית או יתרת תיק חיוב.' $false | Out-Null
Ensure-BillingCaseAttributes
Ensure-PaymentLineAttributes
Ensure-ReceiptAllocationAttributes
Ensure-DocumentBillingAttributes
Ensure-Relationships
Ensure-Forms
Ensure-Views
Ensure-DocumentBillingFieldsOnForms
Ensure-ConfigurationBillingPolicyTab
$configBackfill = Backfill-ConfigurationDefaults
Publish-WebResource
Publish-Entities @($configurationEntity, $documentEntity, $billingCaseEntity, $paymentLineEntity, $receiptAllocationEntity)

[pscustomobject]@{
    Solution = $SolutionUniqueName
    Scope = 'Base PayPlus solution'
    BillingPolicyFieldsCreated = @($createdConfigFields | Where-Object Created).Count
    BillingPolicyFieldsExisting = @($createdConfigFields | Where-Object { -not $_.Created }).Count
    BillingCaseEntity = $billingCaseEntity
    PaymentLineEntity = $paymentLineEntity
    ReceiptAllocationEntity = $receiptAllocationEntity
    ConfigurationDefaults = $configBackfill
    ConfigurationFormTab = 'tab_billing_policy'
    SetupWebResourcePublished = (-not $SkipWebResource)
} | ConvertTo-Json -Depth 10