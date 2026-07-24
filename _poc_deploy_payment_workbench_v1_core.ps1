# Add Payment Workbench V1 metadata to the base PayPlus solution.
# Scope: base PayPlus solution only. Sales-specific invoice/invoicedetail lookups stay in the Sales extension.

param(
    [string]$Org = 'https://demo-contact-center-en.crm4.dynamics.com',
    [string]$SolutionUniqueName = 'alex_d365_payplus',
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'

$billingCaseEntity = 'alex_payplusbillingcase'
$paymentLineEntity = 'alex_paypluspaymentline'
$receiptAllocationEntity = 'alex_payplusreceiptallocation'
$documentEntity = 'alex_payplusdocument'
$companyBankAccountEntity = 'alex_companybankaccount'
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
        [object]$Body = $null
    )

    $params = @{ Method = $Method; Uri = $Uri; Headers = $headers }
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
    return @{ Value = $Value; English = $English; Hebrew = $Hebrew; Label = (New-Label $English $Hebrew) }
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
        OptionSet     = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'; IsGlobal = $false; OptionSetType = 'Picklist'; Options = @($Options | ForEach-Object { @{ Value = $_.Value; Label = $_.Label } }) }
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
    if (Test-AttributeExists $Entity $LogicalName) {
        Write-Host "  attr exists: $Entity.$LogicalName"
        return [pscustomobject]@{ Entity = $Entity; LogicalName = $LogicalName; Created = $false }
    }

    Write-Host "  create attr: $Entity.$LogicalName"
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$Entity')/Attributes" -Body $Metadata | Out-Null
    return [pscustomobject]@{ Entity = $Entity; LogicalName = $LogicalName; Created = $true }
}

function Ensure-Entity {
    param(
        [string]$Entity,
        [string]$EnglishName,
        [string]$HebrewName,
        [string]$EnglishCollection,
        [string]$HebrewCollection,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [ValidateSet('UserOwned', 'OrganizationOwned')][string]$OwnershipType = 'UserOwned',
        [bool]$HasNotes = $false
    )

    $meta = Get-EntityMeta $Entity
    if ($meta) { Write-Host "Entity exists: $Entity ($($meta.MetadataId))"; return $meta }

    Write-Host "Creating entity: $Entity"
    $body = @{
        '@odata.type'         = 'Microsoft.Dynamics.CRM.EntityMetadata'
        SchemaName            = $Entity
        DisplayName           = New-Label $EnglishName $HebrewName
        DisplayCollectionName = New-Label $EnglishCollection $HebrewCollection
        Description           = New-Label $EnglishDescription $HebrewDescription
        OwnershipType         = $OwnershipType
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
    return Get-EntityMeta $Entity
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
        CascadeConfiguration = @{ Assign = 'NoCascade'; Delete = $DeleteCascade; Merge = 'NoCascade'; Reparent = 'NoCascade'; Share = 'NoCascade'; Unshare = 'NoCascade'; RollupView = 'NoCascade' }
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

function Ensure-LocalPicklistOption {
    param([string]$Entity, [string]$Attribute, [hashtable]$Option)

    if (-not (Test-AttributeExists $Entity $Attribute)) {
        Write-Warning "Skipping option $Entity.${Attribute}:$($Option.Value) because the attribute does not exist."
        return
    }

    $insertBody = @{
        EntityLogicalName    = $Entity
        AttributeLogicalName = $Attribute
        Value                = $Option.Value
        Label                = New-Label $Option.English $Option.Hebrew
        SolutionUniqueName   = $SolutionUniqueName
    }

    try {
        Invoke-Dv -Method Post -Uri "$base/InsertOptionValue" -Body $insertBody | Out-Null
        Write-Host "  inserted option: $Entity.$Attribute = $($Option.Value)"
    }
    catch {
        Write-Host "  option exists or insert skipped: $Entity.$Attribute = $($Option.Value)"
    }

    $updateBody = @{
        EntityLogicalName    = $Entity
        AttributeLogicalName = $Attribute
        Value                = $Option.Value
        Label                = New-Label $Option.English $Option.Hebrew
        MergeLabels          = $true
        ParentValues         = @()
        SolutionUniqueName   = $SolutionUniqueName
    }
    Invoke-Dv -Method Post -Uri "$base/UpdateOptionValue" -Body $updateBody | Out-Null
}

function Ensure-LocalPicklistOptions {
    param([string]$Entity, [string]$Attribute, [array]$Options)
    foreach ($option in $Options) { Ensure-LocalPicklistOption $Entity $Attribute $option }
}

function Ensure-BillingCaseV1Attributes {
    Add-AttributeIfMissing $billingCaseEntity 'alex_amountdue' (New-DecimalAttribute 'alex_AmountDue' 'Amount due' 'סכום לחיוב' 'Current amount due before applying proposed payment actions.' 'הסכום הפתוח לפני פעולות תשלום מוצעות.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_proposedamount' (New-DecimalAttribute 'alex_ProposedAmount' 'Proposed amount' 'סכום מוצע' 'Total draft or proposed payment amount that is not yet received.' 'סך תשלומים בטיוטה או בהצעה שטרם התקבלו.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_processingamount' (New-DecimalAttribute 'alex_ProcessingAmount' 'Processing amount' 'סכום בעיבוד' 'Total amount currently locked for payment execution.' 'סך סכומים הנמצאים כעת בעיבוד תשלום.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_receivedamount' (New-DecimalAttribute 'alex_ReceivedAmount' 'Received amount' 'סכום שהתקבל' 'Received and cleared amount. Mirrors the business meaning of paid amount for Workbench V1.' 'סכום שהתקבל ונפרע. משקף את משמעות סכום ששולם בגרסת Workbench V1.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_pendingverificationamount' (New-DecimalAttribute 'alex_PendingVerificationAmount' 'Pending verification amount' 'סכום ממתין לאימות' 'Amount reported but not yet verified, such as bank transfer reports.' 'סכום שדווח אך טרם אומת, כגון דיווח העברה בנקאית.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_futurecommitmentamount' (New-DecimalAttribute 'alex_FutureCommitmentAmount' 'Future commitment amount' 'התחייבות עתידית' 'Future-dated payment commitments such as post-dated checks.' 'התחייבויות תשלום עתידיות כגון צ׳קים דחויים.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_allocatedamount' (New-DecimalAttribute 'alex_AllocatedAmount' 'Allocated amount' 'סכום משויך' 'Amount applied by active allocations.' 'סכום שיושם באמצעות שיוכים פעילים.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_unallocatedamount' (New-DecimalAttribute 'alex_UnallocatedAmount' 'Unallocated amount' 'סכום לא משויך' 'Received amount that is not allocated to items yet.' 'סכום שהתקבל אך עדיין לא שויך לפריטים.' -100000000000 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_failedamount' (New-DecimalAttribute 'alex_FailedAmount' 'Failed amount' 'סכום שנכשל' 'Amount from failed or declined payment attempts.' 'סכום מניסיונות תשלום שנכשלו או נדחו.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_nextexpecteddocument' (New-StringAttribute 'alex_NextExpectedDocument' 'Next expected document' 'המסמך הבא הצפוי' 'Expected financial document based on the current Workbench state.' 'מסמך פיננסי צפוי לפי מצב שולחן העבודה הנוכחי.' 200) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_lastissueddocument' (New-StringAttribute 'alex_LastIssuedDocument' 'Last issued document' 'המסמך האחרון שהופק' 'Latest issued PayPlus document number or summary.' 'מספר או תקציר המסמך האחרון שהופק ב-PayPlus.' 300) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_documentstatussummary' (New-StringAttribute 'alex_DocumentStatusSummary' 'Document status summary' 'סיכום סטטוס מסמכים' 'Human-readable summary of expected and produced documents.' 'סיכום קריא של מסמכים צפויים ומסמכים שהופקו.' 500) | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_lastvalidatedon' (New-DateTimeAttribute 'alex_LastValidatedOn' 'Last validated on' 'אומת לאחרונה בתאריך' 'Last server-side validation time for the Workbench state.' 'מועד האימות האחרון בצד השרת של מצב שולחן העבודה.') | Out-Null
    Add-AttributeIfMissing $billingCaseEntity 'alex_lastsourceversion' (New-StringAttribute 'alex_LastSourceVersion' 'Last source version' 'גרסת מקור אחרונה' 'Source row version observed during the last validation.' 'גרסת רשומת המקור שנצפתה באימות האחרון.' 100) | Out-Null
}

function Ensure-PaymentLineV1Attributes {
    $statusOptions = @(
        (New-Option 100000000 'Draft' 'טיוטה'),
        (New-Option 100000001 'Pending execution' 'ממתין לביצוע'),
        (New-Option 100000002 'Cleared' 'נפרע'),
        (New-Option 100000003 'Cancelled' 'בוטל'),
        (New-Option 100000004 'Failed' 'נכשל'),
        (New-Option 100000005 'Processing' 'בעיבוד'),
        (New-Option 100000006 'Approved' 'אושר'),
        (New-Option 100000007 'Declined' 'נדחה'),
        (New-Option 100000008 'Pending verification' 'ממתין לאימות'),
        (New-Option 100000009 'Verified' 'אומת'),
        (New-Option 100000010 'Unknown result' 'תוצאה לא ידועה'),
        (New-Option 100000011 'Returned' 'חזר')
    )
    Ensure-LocalPicklistOptions $paymentLineEntity 'alex_status' $statusOptions

    $bankVerificationOptions = @(
        (New-Option 100000000 'Reported' 'דווח'),
        (New-Option 100000001 'Found in account' 'נמצא בחשבון'),
        (New-Option 100000002 'Matched to customer' 'הותאם ללקוח'),
        (New-Option 100000003 'Verified' 'אומת'),
        (New-Option 100000004 'Rejected' 'נדחה'),
        (New-Option 100000005 'Unknown' 'לא ידוע')
    )
    $clearingStatusOptions = @(
        (New-Option 100000000 'Received' 'התקבל'),
        (New-Option 100000001 'Deposited' 'הופקד'),
        (New-Option 100000002 'Cleared' 'נפרע'),
        (New-Option 100000003 'Returned' 'חזר'),
        (New-Option 100000004 'Cancelled' 'בוטל')
    )

    Add-AttributeIfMissing $paymentLineEntity 'alex_processingstartedon' (New-DateTimeAttribute 'alex_ProcessingStartedOn' 'Processing started on' 'תחילת עיבוד' 'Date and time this payment line entered processing.' 'תאריך ושעה שבהם שורת התשלום נכנסה לעיבוד.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_processingendedon' (New-DateTimeAttribute 'alex_ProcessingEndedOn' 'Processing ended on' 'סיום עיבוד' 'Date and time this payment line left processing.' 'תאריך ושעה שבהם שורת התשלום יצאה מעיבוד.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_requestid' (New-StringAttribute 'alex_RequestId' 'Request ID' 'מזהה בקשה' 'Unique request ID for this payment execution.' 'מזהה בקשה ייחודי לביצוע התשלום.' 100) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_idempotencykey' (New-StringAttribute 'alex_IdempotencyKey' 'Idempotency key' 'מפתח אידמפוטנטיות' 'Key used to prevent duplicate payment execution.' 'מפתח למניעת ביצוע תשלום כפול.' 200) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_islocked' (New-BooleanAttribute 'alex_IsLocked' 'Processing lock' 'נעילת עיבוד' 'Indicates that the line is locked by an execution flow.' 'מציין שהשורה נעולה על ידי תהליך ביצוע.' $false) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_lockuntil' (New-DateTimeAttribute 'alex_LockUntil' 'Lock until' 'נעול עד' 'Date and time until which the payment line is locked.' 'תאריך ושעה שעד אליהם שורת התשלום נעולה.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_retryblocked' (New-BooleanAttribute 'alex_RetryBlocked' 'Retry blocked' 'ניסיון חוזר חסום' 'Blocks automatic or user-triggered retry for this line.' 'חוסם ניסיון חוזר אוטומטי או יזום משתמש לשורה זו.' $false) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_unknownresult' (New-BooleanAttribute 'alex_UnknownResult' 'Unknown result' 'תוצאה לא ידועה' 'Indicates that the external result is ambiguous and must be checked manually.' 'מציין שהתוצאה החיצונית אינה חד משמעית ונדרש בירור ידני.' $false) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_resultcode' (New-StringAttribute 'alex_ResultCode' 'Result code' 'קוד תוצאה' 'External or internal payment result code.' 'קוד תוצאת תשלום חיצוני או פנימי.' 100) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_resultdescription' (New-StringAttribute 'alex_ResultDescription' 'Result description' 'תיאור תוצאה' 'Business-readable payment result description.' 'תיאור קריא של תוצאת התשלום.' 500) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_failurereason' (New-StringAttribute 'alex_FailureReason' 'Failure reason' 'סיבת כשל' 'Failure or decline reason.' 'סיבת כשל או דחייה.' 500) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_performedby' (New-StringAttribute 'alex_PerformedBy' 'Performed by' 'בוצע על ידי' 'User or process that performed this payment action.' 'משתמש או תהליך שביצע את פעולת התשלום.' 300) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_verifiedby' (New-StringAttribute 'alex_VerifiedBy' 'Verified by' 'אומת על ידי' 'User or process that verified this payment line.' 'משתמש או תהליך שאימת את שורת התשלום.' 300) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_verifiedon' (New-DateTimeAttribute 'alex_VerifiedOn' 'Verified on' 'אומת בתאריך' 'Date and time this payment line was verified.' 'תאריך ושעה שבהם שורת התשלום אומתה.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_laststatetransitionreason' (New-StringAttribute 'alex_LastStateTransitionReason' 'Last state transition reason' 'סיבת שינוי סטטוס אחרון' 'Reason for the latest payment lifecycle transition.' 'סיבה לשינוי מחזור החיים האחרון של התשלום.' 500) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_transferdate' (New-DateOnlyAttribute 'alex_TransferDate' 'Transfer date' 'תאריך העברה' 'Reported bank transfer date.' 'תאריך העברה בנקאית שדווח.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_valuedate' (New-DateOnlyAttribute 'alex_ValueDate' 'Value date' 'תאריך ערך' 'Bank value date for the transfer.' 'תאריך ערך בנקאי של ההעברה.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_payername' (New-StringAttribute 'alex_PayerName' 'Payer name' 'שם משלם' 'Name reported by the payer or bank statement.' 'שם שדווח על ידי המשלם או בדף הבנק.' 300) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_reportedamount' (New-DecimalAttribute 'alex_ReportedAmount' 'Reported amount' 'סכום מדווח' 'Amount reported by the user or payer.' 'סכום שדווח על ידי המשתמש או המשלם.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_verifiedamount' (New-DecimalAttribute 'alex_VerifiedAmount' 'Verified amount' 'סכום מאומת' 'Amount verified in the bank account.' 'סכום שאומת בחשבון הבנק.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_bankverificationstatus' (New-PicklistAttribute 'alex_BankVerificationStatus' 'Bank verification status' 'סטטוס אימות בנקאי' 'Bank-transfer verification lifecycle.' 'מחזור חיים של אימות העברה בנקאית.' $bankVerificationOptions 100000000) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_bankverificationnotes' (New-MemoAttribute 'alex_BankVerificationNotes' 'Bank verification notes' 'הערות אימות בנקאי' 'Notes from bank transfer verification.' 'הערות מתהליך אימות העברה בנקאית.' 4000) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_proofurl' (New-StringAttribute 'alex_ProofUrl' 'Proof URL' 'קישור לאסמכתה' 'Link to payment proof or attachment.' 'קישור לאסמכתת תשלום או קובץ מצורף.' 2000 'None' 'Url') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_checkseriesid' (New-StringAttribute 'alex_CheckSeriesId' 'Check series ID' 'מזהה סדרת צ׳קים' 'Shared identifier for payment lines that belong to the same check series.' 'מזהה משותף לשורות תשלום השייכות לאותה סדרת צ׳קים.' 100) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_checkseriesindex' (New-IntegerAttribute 'alex_CheckSeriesIndex' 'Check series index' 'מספר צ׳ק בסדרה' 'Position of this check in the series.' 'המיקום של צ׳ק זה בסדרה.' 1 120) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_checkseriescount' (New-IntegerAttribute 'alex_CheckSeriesCount' 'Check series count' 'כמות צ׳קים בסדרה' 'Total number of checks in the series.' 'מספר הצ׳קים הכולל בסדרה.' 1 120) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_depositdate' (New-DateOnlyAttribute 'alex_DepositDate' 'Deposit date' 'תאריך הפקדה' 'Date the check was deposited.' 'התאריך שבו הצ׳ק הופקד.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_clearedon' (New-DateTimeAttribute 'alex_ClearedOn' 'Cleared on' 'נפרע בתאריך' 'Date and time this payment line cleared.' 'תאריך ושעה שבהם שורת התשלום נפרעה.') | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_clearingstatus' (New-PicklistAttribute 'alex_ClearingStatus' 'Clearing status' 'סטטוס פירעון' 'Check or transfer clearing status.' 'סטטוס פירעון של צ׳ק או העברה.' $clearingStatusOptions 100000000) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_returnreason' (New-StringAttribute 'alex_ReturnReason' 'Return reason' 'סיבת החזרה' 'Reason a check or payment was returned.' 'סיבה להחזרת צ׳ק או תשלום.' 500) | Out-Null
    Add-AttributeIfMissing $paymentLineEntity 'alex_proofreference' (New-StringAttribute 'alex_ProofReference' 'Proof reference' 'מספר אסמכתה' 'External proof, deposit, or file reference.' 'אסמכתה חיצונית, הפקדה או מזהה קובץ.' 200) | Out-Null
}

function Ensure-AllocationV1Attributes {
    $statusOptions = @(
        (New-Option 100000000 'Draft' 'טיוטה'),
        (New-Option 100000001 'Applied / active' 'שויך / פעיל'),
        (New-Option 100000002 'Reversed' 'הופך'),
        (New-Option 100000003 'Proposed' 'מוצע'),
        (New-Option 100000004 'Failed' 'נכשל'),
        (New-Option 100000005 'Cancelled' 'בוטל'),
        (New-Option 100000006 'Returned' 'חזר')
    )
    Ensure-LocalPicklistOptions $receiptAllocationEntity 'alex_status' $statusOptions

    $activationSourceOptions = @(
        (New-Option 100000000 'Workbench' 'שולחן עבודה'),
        (New-Option 100000001 'Saved-card flow' 'תהליך כרטיס שמור'),
        (New-Option 100000002 'Payment poll flow' 'תהליך קליטת תשלומים'),
        (New-Option 100000003 'Manual verification' 'אימות ידני'),
        (New-Option 100000004 'Import' 'ייבוא')
    )
    $allocationTypeOptions = @(
        (New-Option 100000000 'Source balance' 'יתרת מקור'),
        (New-Option 100000001 'Source line' 'שורת מקור'),
        (New-Option 100000002 'Deferred to future billing' 'דחייה לחיוב עתידי'),
        (New-Option 100000003 'Unallocated remainder' 'יתרה לא משויכת')
    )
    $reasonOptions = @(
        (New-Option 100000000 'None' 'ללא'),
        (New-Option 100000001 'Payment failed' 'תשלום נכשל'),
        (New-Option 100000002 'Payment cancelled' 'תשלום בוטל'),
        (New-Option 100000003 'Source changed' 'המקור השתנה'),
        (New-Option 100000004 'Manual override' 'שינוי ידני'),
        (New-Option 100000005 'Returned payment' 'תשלום חזר')
    )

    Add-AttributeIfMissing $receiptAllocationEntity 'alex_proposedamount' (New-DecimalAttribute 'alex_ProposedAmount' 'Proposed amount' 'סכום מוצע' 'Amount proposed before payment success or verification.' 'סכום מוצע לפני הצלחת התשלום או אימותו.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_actualallocatedamount' (New-DecimalAttribute 'alex_ActualAllocatedAmount' 'Actual allocated amount' 'סכום שיוך בפועל' 'Amount activated after payment success or verification.' 'סכום שהופעל לאחר הצלחת התשלום או אימותו.' 0 100000000000 4) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_activatedon' (New-DateTimeAttribute 'alex_ActivatedOn' 'Activated on' 'הופעל בתאריך' 'Date and time the allocation became active.' 'תאריך ושעה שבהם השיוך הפך לפעיל.') | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_activatedby' (New-StringAttribute 'alex_ActivatedBy' 'Activated by' 'הופעל על ידי' 'User or process that activated the allocation.' 'משתמש או תהליך שהפעיל את השיוך.' 300) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_failedon' (New-DateTimeAttribute 'alex_FailedOn' 'Failed on' 'נכשל בתאריך' 'Date and time the allocation failed.' 'תאריך ושעה שבהם השיוך נכשל.') | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_cancelledon' (New-DateTimeAttribute 'alex_CancelledOn' 'Cancelled on' 'בוטל בתאריך' 'Date and time the allocation was cancelled.' 'תאריך ושעה שבהם השיוך בוטל.') | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_reversedon' (New-DateTimeAttribute 'alex_ReversedOn' 'Reversed on' 'הופך בתאריך' 'Date and time the allocation was reversed.' 'תאריך ושעה שבהם השיוך הופך.') | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_reasoncode' (New-PicklistAttribute 'alex_ReasonCode' 'Reason code' 'קוד סיבה' 'Reason for allocation failure, cancellation, reversal, or override.' 'סיבה לכשל, ביטול, היפוך או שינוי ידני של השיוך.' $reasonOptions 100000000) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_reasonmessage' (New-StringAttribute 'alex_ReasonMessage' 'Reason message' 'פירוט סיבה' 'Business-readable reason message.' 'פירוט קריא של הסיבה.' 500) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_activationsource' (New-PicklistAttribute 'alex_ActivationSource' 'Activation source' 'מקור הפעלה' 'Process that activated the allocation.' 'התהליך שהפעיל את השיוך.' $activationSourceOptions 100000000) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_sourceentitylogicalname' (New-StringAttribute 'alex_SourceEntityLogicalName' 'Source table logical name' 'שם לוגי של טבלת מקור' 'Logical name of the allocated source table.' 'שם לוגי של טבלת המקור המשויכת.' 100) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_sourcerecordid' (New-StringAttribute 'alex_SourceRecordId' 'Source row ID' 'מזהה רשומת מקור' 'Source row ID being allocated.' 'מזהה רשומת המקור המשויכת.' 100) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_sourcelineid' (New-StringAttribute 'alex_SourceLineId' 'Source line ID' 'מזהה שורת מקור' 'Source line ID when allocation is line-level.' 'מזהה שורת מקור כאשר השיוך הוא ברמת שורה.' 100) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_sourceitemname' (New-StringAttribute 'alex_SourceItemName' 'Source item name' 'שם פריט מקור' 'Item or line name snapshot.' 'תצלום שם הפריט או השורה.' 300) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_sourcedocumentnumber' (New-StringAttribute 'alex_SourceDocumentNumber' 'Source document number' 'מספר מסמך מקור' 'Source document number snapshot.' 'תצלום מספר מסמך המקור.' 100) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_sourcelinenumber' (New-StringAttribute 'alex_SourceLineNumber' 'Source line number' 'מספר שורת מקור' 'Source line number snapshot.' 'תצלום מספר שורת המקור.' 100) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_originalamount' (New-DecimalAttribute 'alex_OriginalAmount' 'Original amount' 'סכום מקורי' 'Original source item amount at snapshot time.' 'סכום פריט המקור המקורי בזמן התצלום.' -100000000000 100000000000 4) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_openamountsnapshot' (New-DecimalAttribute 'alex_OpenAmountSnapshot' 'Open amount snapshot' 'יתרה פתוחה בתצלום' 'Open amount observed when allocation was proposed.' 'יתרה פתוחה שנצפתה בעת הצעת השיוך.' -100000000000 100000000000 4) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_snapshotcurrencycode' (New-StringAttribute 'alex_SnapshotCurrencyCode' 'Snapshot currency code' 'קוד מטבע בתצלום' 'Currency code captured with the source snapshot.' 'קוד מטבע שנשמר עם תצלום המקור.' 3) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_remainingafterallocation' (New-DecimalAttribute 'alex_RemainingAfterAllocation' 'Remaining after allocation' 'יתרה לאחר שיוך' 'Expected remaining source amount after this allocation.' 'יתרת מקור צפויה לאחר שיוך זה.' -100000000000 100000000000 4) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_allocationtype' (New-PicklistAttribute 'alex_AllocationType' 'Allocation type' 'סוג שיוך' 'Allocation target type.' 'סוג יעד השיוך.' $allocationTypeOptions 100000000) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_snapshottimestamp' (New-DateTimeAttribute 'alex_SnapshotTimestamp' 'Snapshot timestamp' 'מועד תצלום' 'Date and time the source snapshot was captured.' 'תאריך ושעה שבהם תצלום המקור נשמר.') | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_sourcemodifiedon' (New-DateTimeAttribute 'alex_SourceModifiedOn' 'Source modified on' 'מועד שינוי מקור' 'Modified-on timestamp observed on the source row.' 'מועד שינוי שנצפה ברשומת המקור.') | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_sourceversion' (New-StringAttribute 'alex_SourceVersion' 'Source version' 'גרסת מקור' 'Row version or source version captured for concurrency validation.' 'גרסת רשומה או מקור שנשמרה לאימות מקביליות.' 100) | Out-Null
    Add-AttributeIfMissing $receiptAllocationEntity 'alex_deferredtofuture' (New-BooleanAttribute 'alex_DeferredToFuture' 'Deferred to future billing' 'נדחה לחיוב עתידי' 'Marks that the amount remains open for a future billing event.' 'מסמן שהסכום נשאר פתוח לאירוע חיוב עתידי.' $false) | Out-Null
}

function Ensure-CompanyBankAccountModel {
    Ensure-Entity $companyBankAccountEntity 'Company Bank Account' 'חשבון בנק ארגוני' 'Company Bank Accounts' 'חשבונות בנק ארגוניים' 'Bank account owned by the organization and used as a transfer target.' 'חשבון בנק של הארגון המשמש יעד להעברות בנקאיות.' 'OrganizationOwned' $false | Out-Null

    $activityTypeOptions = @(
        (New-Option 100000000 'Collections' 'גבייה'),
        (New-Option 100000001 'Refunds' 'החזרים'),
        (New-Option 100000002 'General' 'כללי')
    )

    Add-AttributeIfMissing $companyBankAccountEntity 'alex_legalcompany' (New-StringAttribute 'alex_LegalCompany' 'Legal company' 'חברה משפטית' 'Legal company or owning entity for this bank account.' 'החברה המשפטית או הגוף המחזיק בחשבון זה.' 200) | Out-Null
    Add-AttributeIfMissing $companyBankAccountEntity 'alex_accountnumber' (New-StringAttribute 'alex_AccountNumber' 'Account number' 'מספר חשבון' 'Bank account number.' 'מספר חשבון הבנק.' 50) | Out-Null
    Add-AttributeIfMissing $companyBankAccountEntity 'alex_iban' (New-StringAttribute 'alex_IBAN' 'IBAN' 'IBAN' 'International Bank Account Number.' 'מספר חשבון בנק בינלאומי.' 50) | Out-Null
    Add-AttributeIfMissing $companyBankAccountEntity 'alex_swift' (New-StringAttribute 'alex_SWIFT' 'SWIFT/BIC' 'SWIFT/BIC' 'SWIFT or BIC code.' 'קוד SWIFT או BIC.' 20) | Out-Null
    Add-AttributeIfMissing $companyBankAccountEntity 'alex_currencycode' (New-StringAttribute 'alex_CurrencyCode' 'Currency code' 'קוד מטבע' 'ISO currency code for transfers into this account.' 'קוד מטבע ISO להעברות לחשבון זה.' 3) | Out-Null
    Add-AttributeIfMissing $companyBankAccountEntity 'alex_activitytype' (New-PicklistAttribute 'alex_ActivityType' 'Activity type' 'סוג פעילות' 'Business activity this account supports.' 'סוג הפעילות העסקית שהחשבון תומך בה.' $activityTypeOptions 100000000) | Out-Null
    Add-AttributeIfMissing $companyBankAccountEntity 'alex_businessunitorbrand' (New-StringAttribute 'alex_BusinessUnitOrBrand' 'Business unit or brand' 'יחידה עסקית או מותג' 'Optional business unit, brand, or branch qualifier.' 'יחידה עסקית, מותג או סניף אופציונליים.' 200) | Out-Null
    Add-AttributeIfMissing $companyBankAccountEntity 'alex_isdefault' (New-BooleanAttribute 'alex_IsDefault' 'Default account' 'חשבון ברירת מחדל' 'Indicates this account is the default target for its selection rules.' 'מציין שזה חשבון ברירת המחדל לפי כללי הבחירה שלו.' $false) | Out-Null
    Add-AttributeIfMissing $companyBankAccountEntity 'alex_isactive' (New-BooleanAttribute 'alex_IsActive' 'Active' 'פעיל' 'Controls whether this bank account is selectable.' 'קובע האם חשבון הבנק ניתן לבחירה.' $true) | Out-Null

    Ensure-Lookup 'alex_bank_alex_companybankaccount' 'alex_bank' $companyBankAccountEntity 'alex_bankid' 'Bank' 'בנק' 'Bank for this organization account.' 'הבנק של החשבון הארגוני.'
    Ensure-Lookup 'alex_bankbranch_alex_companybankaccount' 'alex_bankbranch' $companyBankAccountEntity 'alex_bankbranchid' 'Bank Branch' 'סניף בנק' 'Bank branch for this organization account.' 'סניף הבנק של החשבון הארגוני.'
    Ensure-Lookup 'alex_customerbankaccount_alex_paypluspaymentline_source' 'alex_customerbankaccount' $paymentLineEntity 'alex_customerbankaccountid' 'Customer Bank Account' 'חשבון בנק לקוח' 'Customer source bank account for transfer or check payments.' 'חשבון בנק לקוח כמקור להעברה או צ׳ק.'
    Ensure-Lookup 'alex_companybankaccount_alex_paypluspaymentline_target' $companyBankAccountEntity $paymentLineEntity 'alex_companybankaccountid' 'Target Company Bank Account' 'חשבון בנק יעד ארגוני' 'Organization bank account selected as transfer target.' 'חשבון בנק ארגוני שנבחר כיעד להעברה.'
}

function Ensure-DocumentV1Attributes {
    $documentRoleOptions = @(
        (New-Option 100000000 'Receipt' 'קבלה'),
        (New-Option 100000001 'Partial receipt' 'קבלה חלקית'),
        (New-Option 100000002 'Transfer report confirmation' 'אישור דיווח העברה'),
        (New-Option 100000003 'Check intake confirmation' 'אישור קליטת צ׳קים'),
        (New-Option 100000004 'Saved payment method confirmation' 'אישור שמירת אמצעי תשלום'),
        (New-Option 100000005 'No document' 'ללא מסמך')
    )
    $documentStatusOptions = @(
        (New-Option 100000000 'Expected' 'צפוי'),
        (New-Option 100000001 'Queued' 'בתור'),
        (New-Option 100000002 'Issued' 'הופק'),
        (New-Option 100000003 'Failed' 'נכשל'),
        (New-Option 100000004 'Not required' 'לא נדרש')
    )

    Add-AttributeIfMissing $documentEntity 'alex_expecteddocumentrole' (New-PicklistAttribute 'alex_ExpectedDocumentRole' 'Expected document role' 'תפקיד מסמך צפוי' 'Expected collection document role for this payment result.' 'תפקיד מסמך הגבייה הצפוי לתוצאת תשלום זו.' $documentRoleOptions 100000000) | Out-Null
    Add-AttributeIfMissing $documentEntity 'alex_workbenchdocumentstatus' (New-PicklistAttribute 'alex_WorkbenchDocumentStatus' 'Workbench document status' 'סטטוס מסמך ב-Workbench' 'Document production status from the Workbench perspective.' 'סטטוס הפקת מסמך מנקודת מבט שולחן העבודה.' $documentStatusOptions 100000000) | Out-Null
    Add-AttributeIfMissing $documentEntity 'alex_documentdecisionreason' (New-StringAttribute 'alex_DocumentDecisionReason' 'Document decision reason' 'סיבת החלטת מסמך' 'Reason used by Workbench document-decision logic.' 'הסיבה ששימשה את לוגיקת החלטת המסמך של שולחן העבודה.' 500) | Out-Null
    Add-AttributeIfMissing $documentEntity 'alex_documentfailuremessage' (New-StringAttribute 'alex_DocumentFailureMessage' 'Document failure message' 'הודעת כשל מסמך' 'Business-readable document production failure message.' 'הודעת כשל קריאה של הפקת המסמך.' 500) | Out-Null
    Ensure-Lookup 'alex_paypluspaymentline_alex_payplusdocument_originating' $paymentLineEntity $documentEntity 'alex_paymentlineid' 'Originating Payment Line' 'שורת תשלום מקורית' 'Payment line that produced or expects this document.' 'שורת התשלום שהפיקה או מצפה למסמך זה.'
}

function Publish-Entities {
    param([string[]]$Entities)
    if ($SkipPublish) { Write-Host 'Skipping publish by request.'; return }
    $entityXml = ($Entities | ForEach-Object { "<entity>$_</entity>" }) -join ''
    Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = "<importexportxml><entities>$entityXml</entities></importexportxml>" } | Out-Null
}

foreach ($entity in @($billingCaseEntity, $paymentLineEntity, $receiptAllocationEntity, $documentEntity)) {
    if (-not (Test-EntityExists $entity)) { throw "Required base table does not exist: $entity. Run _poc_deploy_billing_core.ps1 first." }
}

Ensure-BillingCaseV1Attributes
Ensure-PaymentLineV1Attributes
Ensure-AllocationV1Attributes
Ensure-CompanyBankAccountModel
Ensure-DocumentV1Attributes
Publish-Entities @($billingCaseEntity, $paymentLineEntity, $receiptAllocationEntity, $documentEntity, $companyBankAccountEntity)

[pscustomobject]@{
    Solution = $SolutionUniqueName
    Scope = 'Payment Workbench V1 base metadata'
    BillingCaseEntity = $billingCaseEntity
    PaymentLineEntity = $paymentLineEntity
    ReceiptAllocationEntity = $receiptAllocationEntity
    DocumentEntity = $documentEntity
    CompanyBankAccountEntity = $companyBankAccountEntity
    Published = (-not $SkipPublish)
} | ConvertTo-Json -Depth 10