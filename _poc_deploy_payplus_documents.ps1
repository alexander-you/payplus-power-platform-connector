# Deploy PayPlus Document central ledger table to Dataverse.
# Creates the core PayPlus document table without dependencies on Dynamics Sales tables.

param(
    [string]$Org = 'https://demo-contact-center-en.crm4.dynamics.com',
    [string]$SolutionUniqueName = 'alex_d365_payplus',
    [switch]$SkipPublish,
    [switch]$SkipViewsAndForms
)

$ErrorActionPreference = 'Stop'

$entityLogicalName = 'alex_payplusdocument'
$entitySchemaName = 'alex_payplusdocument'
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
    if (-not $response) { return $false }
    return ([int]$response.StatusCode -eq 404)
}

function Invoke-Dv {
    param(
        [ValidateSet('Get', 'Post', 'Patch', 'Put', 'Delete')]
        [string]$Method,
        [string]$Uri,
        [object]$Body = $null
    )

    $params = @{
        Method  = $Method
        Uri     = $Uri
        Headers = $headers
    }

    if ($null -ne $Body) {
        if ($Body -is [string]) {
            $json = $Body
        }
        else {
            $json = $Body | ConvertTo-Json -Depth 100 -Compress
        }
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
    }

    try {
        return Invoke-RestMethod @params
    }
    catch {
        $content = Get-ErrorContent $_
        throw "Dataverse $Method failed: $Uri`n$content"
    }
}

function Try-GetDv {
    param([string]$Uri)

    try {
        return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers
    }
    catch {
        if (Test-NotFound $_) { return $null }
        throw
    }
}

function Test-EntityExists {
    param([string]$LogicalName)
    $entity = Try-GetDv "$base/EntityDefinitions(LogicalName='$LogicalName')?`$select=MetadataId,LogicalName"
    return ($null -ne $entity)
}

function New-Label {
    param(
        [string]$English,
        [string]$Hebrew
    )

    return @{
        LocalizedLabels = @(
            @{ Label = $English; LanguageCode = 1033 },
            @{ Label = $Hebrew; LanguageCode = 1037 }
        )
    }
}

function New-RequiredLevel {
    param([string]$Value = 'None')

    return @{
        Value                              = $Value
        CanBeChanged                       = $true
        ManagedPropertyLogicalName         = 'canmodifyrequirementlevelsettings'
    }
}

function New-Option {
    param(
        [int]$Value,
        [string]$English,
        [string]$Hebrew
    )

    return @{ Value = $Value; Label = (New-Label $English $Hebrew) }
}

function Get-EntityMetadata {
    return Try-GetDv "$base/EntityDefinitions(LogicalName='$entityLogicalName')?`$select=MetadataId,LogicalName,EntitySetName"
}

function Test-AttributeExists {
    param([string]$LogicalName)

    $attr = Try-GetDv "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes(LogicalName='$LogicalName')?`$select=MetadataId,LogicalName"
    return ($null -ne $attr)
}

function Add-AttributeIfMissing {
    param(
        [string]$LogicalName,
        [hashtable]$Metadata
    )

    if (Test-AttributeExists $LogicalName) {
        Write-Host "Attribute exists: $LogicalName"
        return
    }

    Write-Host "Creating attribute: $LogicalName"
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes" -Body $Metadata | Out-Null
}

function New-StringAttribute {
    param(
        [string]$SchemaName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [int]$MaxLength = 100,
        [string]$RequiredLevel = 'None',
        [string]$FormatName = 'Text'
    )

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
    param(
        [string]$SchemaName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [int]$MaxLength = 1048576
    )

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
    param(
        [string]$SchemaName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [int]$MinValue = -2147483648,
        [int]$MaxValue = 2147483647
    )

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
    param(
        [string]$SchemaName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [decimal]$MinValue = -100000000000,
        [decimal]$MaxValue = 100000000000,
        [int]$Precision = 4
    )

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
        RequiredLevel = New-RequiredLevel 'None'
        DefaultValue  = $DefaultValue
        OptionSet     = @{
            TrueOption  = @{ Value = 1; Label = New-Label 'Yes' 'כן' }
            FalseOption = @{ Value = 0; Label = New-Label 'No' 'לא' }
        }
    }
}

function New-PicklistAttribute {
    param(
        [string]$SchemaName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [array]$Options,
        [string]$RequiredLevel = 'None'
    )

    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = New-RequiredLevel $RequiredLevel
        OptionSet     = @{
            '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'
            IsGlobal      = $false
            OptionSetType = 'Picklist'
            Options       = $Options
        }
    }
}

function New-DateTimeAttribute {
    param(
        [string]$SchemaName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription
    )

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
    param(
        [string]$SchemaName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription
    )

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

function Ensure-Entity {
    $entity = Get-EntityMetadata
    if ($entity) {
        Write-Host "Entity exists: $entityLogicalName ($($entity.MetadataId))"
        return $entity
    }

    Write-Host "Creating entity: $entityLogicalName"
    $body = @{
        '@odata.type'         = 'Microsoft.Dynamics.CRM.EntityMetadata'
        SchemaName            = $entitySchemaName
        DisplayName           = New-Label 'PayPlus Document' 'מסמך PayPlus'
        DisplayCollectionName = New-Label 'PayPlus Documents' 'מסמכי PayPlus'
        Description           = New-Label 'Central ledger of PayPlus Invoice+ documents linked to Dataverse business records.' 'יומן מרכזי של מסמכי PayPlus Invoice+ המקושרים לרשומות עסקיות ב-Dataverse.'
        OwnershipType         = 'UserOwned'
        HasActivities         = $false
        HasNotes              = $true
        IsActivity            = $false
        Attributes            = @(
            @{
                '@odata.type'  = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
                SchemaName     = 'alex_name'
                DisplayName    = New-Label 'Name' 'שם'
                Description    = New-Label 'Primary display value for the PayPlus document.' 'ערך תצוגה ראשי של מסמך PayPlus.'
                RequiredLevel  = New-RequiredLevel 'ApplicationRequired'
                MaxLength      = 300
                FormatName     = @{ Value = 'Text' }
                IsPrimaryName  = $true
            }
        )
    }
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions" -Body $body | Out-Null
    $entity = Get-EntityMetadata
    if (-not $entity) { throw "Entity was created but metadata is not available yet: $entityLogicalName" }
    return $entity
}

function Ensure-EntityLabels {
    Write-Host "Updating entity labels: $entityLogicalName"
    $labelHeaders = $headers.Clone()
    $labelHeaders['MSCRM.MergeLabels'] = 'true'
    $body = @{
        '@odata.type'         = 'Microsoft.Dynamics.CRM.EntityMetadata'
        SchemaName            = $entitySchemaName
        DisplayName           = New-Label 'PayPlus Document' 'מסמך PayPlus'
        DisplayCollectionName = New-Label 'PayPlus Documents' 'מסמכי PayPlus'
        Description           = New-Label 'Central ledger of PayPlus Invoice+ documents linked to Dataverse business records.' 'יומן מרכזי של מסמכי PayPlus Invoice+ המקושרים לרשומות עסקיות ב-Dataverse.'
        OwnershipType         = 'UserOwned'
        HasActivities         = $false
        HasNotes              = $true
        IsActivity            = $false
    } | ConvertTo-Json -Depth 100 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    try {
        Invoke-RestMethod -Method Put -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')" -Headers $labelHeaders -Body $bytes | Out-Null
    }
    catch {
        $content = Get-ErrorContent $_
        throw "Dataverse Put failed: $base/EntityDefinitions(LogicalName='$entityLogicalName')`n$content"
    }
}

function Update-StringAttributeLabels {
    param(
        [string]$LogicalName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [int]$MaxLength = 100,
        [string]$RequiredLevel = 'None',
        [string]$FormatName = 'Text'
    )

    if (-not (Test-AttributeExists $LogicalName)) { return }

    Write-Host "Updating attribute labels: $LogicalName"
    $labelHeaders = $headers.Clone()
    $labelHeaders['MSCRM.MergeLabels'] = 'true'
    $body = New-StringAttribute $LogicalName $EnglishLabel $HebrewLabel $EnglishDescription $HebrewDescription $MaxLength $RequiredLevel $FormatName
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 100 -Compress))
    try {
        Invoke-RestMethod -Method Put -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes(LogicalName='$LogicalName')" -Headers $labelHeaders -Body $bytes | Out-Null
    }
    catch {
        $content = Get-ErrorContent $_
        throw "Dataverse Put failed: $base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes(LogicalName='$LogicalName')`n$content"
    }
}

function Ensure-Lookup {
    param(
        [string]$SchemaName,
        [string]$ReferencedEntity,
        [string]$ReferencingAttribute,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription,
        [string]$RequiredLevel = 'None'
    )

    if (-not (Test-EntityExists $ReferencedEntity)) {
        Write-Warning "Skipping lookup $ReferencingAttribute because target entity does not exist: $ReferencedEntity"
        return
    }

    $relationship = Try-GetDv "$base/RelationshipDefinitions(SchemaName='$SchemaName')?`$select=MetadataId,SchemaName"
    if ($relationship) {
        Write-Host "Relationship exists: $SchemaName"
        return
    }

    Write-Host "Creating relationship: $SchemaName"
    $body = @{
        '@odata.type'        = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
        SchemaName           = $SchemaName
        ReferencedEntity     = $ReferencedEntity
        ReferencingEntity    = $entityLogicalName
        CascadeConfiguration = @{
            Assign     = 'NoCascade'
            Delete     = 'RemoveLink'
            Merge      = 'NoCascade'
            Reparent   = 'NoCascade'
            Share      = 'NoCascade'
            Unshare    = 'NoCascade'
            RollupView = 'NoCascade'
        }
        Lookup               = @{
            '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'
            SchemaName    = $ReferencingAttribute
            DisplayName   = New-Label $EnglishLabel $HebrewLabel
            Description   = New-Label $EnglishDescription $HebrewDescription
            RequiredLevel = New-RequiredLevel $RequiredLevel
            Targets       = @($ReferencedEntity)
        }
    }
    Invoke-Dv -Method Post -Uri "$base/RelationshipDefinitions" -Body $body | Out-Null
}

function Ensure-CoreRelationships {
    Ensure-Lookup 'alex_payplusconfiguration_alex_payplusdocument' 'alex_payplusconfiguration' 'alex_configurationid' 'Configuration' 'קונפיגורציה' 'PayPlus configuration that created, owns, or refreshed this document.' 'קונפיגורציית PayPlus שיצרה, מנהלת או ריעננה את המסמך.' 'ApplicationRequired'
    Ensure-Lookup 'alex_payplus_documenttype_alex_payplusdocument' 'alex_payplus_documenttype' 'alex_documenttypeid' 'Document Type' 'סוג מסמך' 'PayPlus document type catalog row used for this document.' 'רשומת קטלוג סוג מסמך PayPlus ששימשה למסמך זה.'
    Ensure-Lookup 'alex_account_alex_payplusdocument' 'account' 'alex_accountid' 'Account' 'לקוח' 'Dynamics account related to the PayPlus document.' 'לקוח Dynamics המקושר למסמך PayPlus.'
    Ensure-Lookup 'alex_contact_alex_payplusdocument' 'contact' 'alex_contactid' 'Contact' 'איש קשר' 'Dynamics contact related to the PayPlus document.' 'איש קשר Dynamics המקושר למסמך PayPlus.'
    Ensure-Lookup 'alex_creditcard_alex_payplusdocument' 'alex_creditcard' 'alex_creditcardid' 'Saved Card' 'כרטיס שמור' 'Saved PayPlus card related to the document payment context.' 'כרטיס PayPlus שמור המקושר להקשר התשלום של המסמך.'
    Ensure-Lookup 'alex_payplusterminal_alex_payplusdocument' 'alex_payplus_terminal' 'alex_terminalid' 'Terminal' 'מסוף' 'PayPlus terminal related to the document.' 'מסוף PayPlus המקושר למסמך.'
    Ensure-Lookup 'alex_paypluspaymentpage_alex_payplusdocument' 'alex_payplus_paymentpage' 'alex_paymentpageid' 'Payment Page' 'עמוד תשלום' 'PayPlus payment page related to the document or request.' 'עמוד תשלום PayPlus המקושר למסמך או לבקשת התשלום.'
}

function Ensure-Attributes {
    Add-AttributeIfMissing 'alex_environment' (New-PicklistAttribute 'alex_environment' 'Environment' 'סביבה' 'PayPlus environment where the document exists.' 'סביבת PayPlus שבה המסמך קיים.' @(
        (New-Option 100000000 'Production' 'Production (ייצור)'),
        (New-Option 100000001 'Sandbox' 'Sandbox (בדיקות)')
    ) 'ApplicationRequired')
    Add-AttributeIfMissing 'alex_origin' (New-PicklistAttribute 'alex_origin' 'Origin' 'מקור יצירה' 'How the PayPlus document row entered Dataverse.' 'האופן שבו רשומת מסמך PayPlus נכנסה ל-Dataverse.' @(
        (New-Option 100000000 'Created from Dynamics' 'נוצר מ-Dynamics'),
        (New-Option 100000001 'Imported from PayPlus' 'יובא מ-PayPlus'),
        (New-Option 100000002 'Callback' 'Callback'),
        (New-Option 100000003 'Manual' 'ידני')
    ))
    Add-AttributeIfMissing 'alex_lastsyncstatus' (New-PicklistAttribute 'alex_lastsyncstatus' 'Last Sync Status' 'סטטוס סנכרון אחרון' 'Last integration status for this PayPlus document.' 'סטטוס האינטגרציה האחרון עבור מסמך PayPlus זה.' @(
        (New-Option 100000000 'Pending' 'ממתין'),
        (New-Option 100000001 'Success' 'הצליח'),
        (New-Option 100000002 'Failed' 'נכשל'),
        (New-Option 100000003 'Needs Review' 'דורש בדיקה')
    ))

    Add-AttributeIfMissing 'alex_documenttypecode' (New-StringAttribute 'alex_documenttypecode' 'Document Type Code' 'קוד סוג מסמך' 'PayPlus docType code, such as dc_quote or inv_tax_receipt.' 'קוד docType של PayPlus, לדוגמה dc_quote או inv_tax_receipt.' 100 'ApplicationRequired')
    Add-AttributeIfMissing 'alex_documenttypenumber' (New-IntegerAttribute 'alex_documenttypenumber' 'Document Type Number' 'מספר סוג מסמך' 'Numeric document type code returned by PayPlus when available.' 'קוד מספרי של סוג המסמך כפי שחוזר מ-PayPlus, כאשר קיים.' 0 2147483647)
    Add-AttributeIfMissing 'alex_payplusdocumentuuid' (New-StringAttribute 'alex_payplusdocumentuuid' 'PayPlus Document UUID' 'מזהה מסמך PayPlus' 'Unique PayPlus UUID of the document.' 'UUID ייחודי של המסמך ב-PayPlus.' 100)
    Add-AttributeIfMissing 'alex_uniqueidentifier' (New-StringAttribute 'alex_uniqueidentifier' 'Unique Identifier' 'מזהה ייחודי' 'Idempotency and correlation key sent to PayPlus during creation.' 'מפתח אידמפוטנטיות וקורלציה שנשלח ל-PayPlus בזמן יצירה.' 200)
    Add-AttributeIfMissing 'alex_documentnumber' (New-StringAttribute 'alex_documentnumber' 'Document Number' 'מספר מסמך' 'Formal PayPlus document number when issued.' 'מספר המסמך הרשמי ב-PayPlus לאחר הפקה.' 100)
    Add-AttributeIfMissing 'alex_series' (New-StringAttribute 'alex_series' 'Series' 'סדרה' 'PayPlus document series or prefix.' 'סדרה או קידומת של המסמך ב-PayPlus.' 100)
    Add-AttributeIfMissing 'alex_documentstatus' (New-StringAttribute 'alex_documentstatus' 'Document Status' 'סטטוס מסמך' 'Business status of the document as returned by PayPlus.' 'סטטוס עסקי של המסמך כפי שחוזר מ-PayPlus.' 100)
    Add-AttributeIfMissing 'alex_businessstatus' (New-PicklistAttribute 'alex_businessstatus' 'Business Status' 'סטטוס עסקי' 'PayPlus document business lifecycle status in Dynamics.' 'סטטוס מחזור חיים עסקי של מסמך PayPlus ב-Dynamics.' @(
        (New-Option 100000000 'Preview Pending' 'תצוגה מקדימה ממתינה'),
        (New-Option 100000001 'Preview Ready' 'תצוגה מקדימה מוכנה'),
        (New-Option 100000002 'Issue Pending' 'הפקה ממתינה'),
        (New-Option 100000003 'Issued' 'הופק'),
        (New-Option 100000004 'Action Requested' 'פעולה התבקשה'),
        (New-Option 100000005 'Action Composed' 'פעולה נרשמה'),
        (New-Option 100000006 'Failed' 'נכשל'),
        (New-Option 100000007 'Cancelled' 'בוטל'),
        (New-Option 100000008 'Closed' 'נסגר')
    ))
    Add-AttributeIfMissing 'alex_language' (New-StringAttribute 'alex_language' 'Language' 'שפה' 'Document language code.' 'קוד שפת המסמך.' 10)
    Add-AttributeIfMissing 'alex_branduuid' (New-StringAttribute 'alex_branduuid' 'Brand UUID' 'מזהה מותג' 'PayPlus brand UUID when the document is brand-scoped.' 'מזהה מותג PayPlus כאשר המסמך משויך למותג.' 100)

    Add-AttributeIfMissing 'alex_documentdate' (New-DateOnlyAttribute 'alex_documentdate' 'Document Date' 'תאריך מסמך' 'Official document date.' 'התאריך הרשמי של המסמך.')
    Add-AttributeIfMissing 'alex_issuedon' (New-DateTimeAttribute 'alex_issuedon' 'Issued On' 'הופק בתאריך' 'Date and time when the document was issued.' 'תאריך ושעה שבהם המסמך הופק.')
    Add-AttributeIfMissing 'alex_createdonpayplus' (New-DateTimeAttribute 'alex_createdonpayplus' 'Created On in PayPlus' 'נוצר ב-PayPlus בתאריך' 'Creation date and time returned by PayPlus.' 'תאריך ושעת יצירה כפי שחזרו מ-PayPlus.')
    Add-AttributeIfMissing 'alex_updatedonpayplus' (New-DateTimeAttribute 'alex_updatedonpayplus' 'Updated On in PayPlus' 'עודכן ב-PayPlus בתאריך' 'Last update date and time returned by PayPlus.' 'תאריך ושעת עדכון אחרון כפי שחזרו מ-PayPlus.')
    Add-AttributeIfMissing 'alex_lastrefreshedon' (New-DateTimeAttribute 'alex_lastrefreshedon' 'Last Refreshed On' 'רוענן לאחרונה בתאריך' 'Date and time when the document was last refreshed from PayPlus.' 'תאריך ושעה שבהם המסמך רוענן לאחרונה מ-PayPlus.')
    Add-AttributeIfMissing 'alex_lastoperationon' (New-DateTimeAttribute 'alex_lastoperationon' 'Last Operation On' 'פעולה אחרונה בתאריך' 'Date and time of the last integration operation for this document.' 'תאריך ושעה של פעולת האינטגרציה האחרונה עבור מסמך זה.')
    Add-AttributeIfMissing 'alex_lastdistributedon' (New-DateTimeAttribute 'alex_lastdistributedon' 'Last Distributed On' 'הופץ לאחרונה בתאריך' 'Date and time of the last distribution attempt.' 'תאריך ושעה של ניסיון ההפצה האחרון.')

    Add-AttributeIfMissing 'alex_currencycode' (New-StringAttribute 'alex_currencycode' 'Currency Code' 'קוד מטבע' 'ISO currency code returned by or sent to PayPlus.' 'קוד מטבע ISO שנשלח ל-PayPlus או חזר ממנו.' 3)
    Add-AttributeIfMissing 'alex_totalamount' (New-DecimalAttribute 'alex_totalamount' 'Total Amount' 'סכום כולל' 'Total document amount.' 'סכום כולל של המסמך.' 0 100000000000 4)
    Add-AttributeIfMissing 'alex_vatamount' (New-DecimalAttribute 'alex_vatamount' 'VAT Amount' 'סכום מע"מ' 'VAT amount for the document.' 'סכום המע"מ במסמך.' 0 100000000000 4)
    Add-AttributeIfMissing 'alex_paidamount' (New-DecimalAttribute 'alex_paidamount' 'Paid Amount' 'סכום ששולם' 'Amount paid against the document.' 'סכום ששולם כנגד המסמך.' 0 100000000000 4)
    Add-AttributeIfMissing 'alex_balanceamount' (New-DecimalAttribute 'alex_balanceamount' 'Balance Amount' 'יתרה לתשלום' 'Open balance for the document.' 'יתרת תשלום פתוחה למסמך.' -100000000000 100000000000 4)
    Add-AttributeIfMissing 'alex_conversionrate' (New-DecimalAttribute 'alex_conversionrate' 'Conversion Rate' 'שער המרה' 'Currency conversion rate returned by PayPlus when available.' 'שער המרה כפי שחזר מ-PayPlus, כאשר קיים.' 0 100000000000 6)
    Add-AttributeIfMissing 'alex_vatpercentage' (New-DecimalAttribute 'alex_vatpercentage' 'VAT Percentage' 'אחוז מע"מ' 'VAT percentage used for the document.' 'אחוז המע"מ ששימש במסמך.' 0 100 4)

    Add-AttributeIfMissing 'alex_paypluscustomeruid' (New-StringAttribute 'alex_paypluscustomeruid' 'PayPlus Customer UID' 'מזהה לקוח PayPlus' 'PayPlus customer UID related to the document.' 'מזהה לקוח PayPlus המקושר למסמך.' 100)
    Add-AttributeIfMissing 'alex_customername' (New-StringAttribute 'alex_customername' 'Customer Name' 'שם לקוח' 'Customer name snapshot from the document.' 'תצלום שם הלקוח מתוך המסמך.' 300)
    Add-AttributeIfMissing 'alex_customeremail' (New-StringAttribute 'alex_customeremail' 'Customer Email' 'דוא"ל לקוח' 'Customer email snapshot from the document.' 'תצלום דוא"ל הלקוח מתוך המסמך.' 200 'None' 'Email')
    Add-AttributeIfMissing 'alex_customerphone' (New-StringAttribute 'alex_customerphone' 'Customer Phone' 'טלפון לקוח' 'Customer phone snapshot from the document.' 'תצלום טלפון הלקוח מתוך המסמך.' 100 'None' 'Phone')
    Add-AttributeIfMissing 'alex_customervatnumber' (New-StringAttribute 'alex_customervatnumber' 'Customer VAT Number' 'מספר עוסק/ח.פ לקוח' 'Customer VAT, tax, company, or identity number snapshot.' 'תצלום מספר עוסק, ח.פ או ת.ז של הלקוח.' 100)
    Add-AttributeIfMissing 'alex_customeraddress' (New-StringAttribute 'alex_customeraddress' 'Customer Address' 'כתובת לקוח' 'Customer address snapshot from the document.' 'תצלום כתובת הלקוח מתוך המסמך.' 500)
    Add-AttributeIfMissing 'alex_customercity' (New-StringAttribute 'alex_customercity' 'Customer City' 'עיר לקוח' 'Customer city snapshot from the document.' 'תצלום עיר הלקוח מתוך המסמך.' 100)
    Add-AttributeIfMissing 'alex_customerpostalcode' (New-StringAttribute 'alex_customerpostalcode' 'Customer Postal Code' 'מיקוד לקוח' 'Customer postal code snapshot from the document.' 'תצלום מיקוד הלקוח מתוך המסמך.' 50)
    Add-AttributeIfMissing 'alex_customercountryiso' (New-StringAttribute 'alex_customercountryiso' 'Customer Country ISO' 'מדינת לקוח ISO' 'Customer country ISO code snapshot.' 'תצלום קוד מדינת הלקוח לפי ISO.' 10)

    Add-AttributeIfMissing 'alex_transactionuid' (New-StringAttribute 'alex_transactionuid' 'Transaction UID' 'מזהה עסקה' 'PayPlus transaction UID related to this document.' 'מזהה עסקת PayPlus המקושרת למסמך זה.' 100)
    Add-AttributeIfMissing 'alex_paymentrequestuid' (New-StringAttribute 'alex_paymentrequestuid' 'Payment Request UID' 'מזהה בקשת תשלום' 'PayPlus payment request UID related to this document.' 'מזהה בקשת תשלום PayPlus המקושרת למסמך זה.' 100)
    Add-AttributeIfMissing 'alex_terminaluid' (New-StringAttribute 'alex_terminaluid' 'Terminal UID' 'מזהה מסוף' 'PayPlus terminal UID snapshot.' 'תצלום מזהה מסוף PayPlus.' 100)
    Add-AttributeIfMissing 'alex_paymentpageuid' (New-StringAttribute 'alex_paymentpageuid' 'Payment Page UID' 'מזהה עמוד תשלום' 'PayPlus payment page UID snapshot.' 'תצלום מזהה עמוד תשלום PayPlus.' 100)
    Add-AttributeIfMissing 'alex_paymentpagelink' (New-StringAttribute 'alex_paymentpagelink' 'Payment Page Link' 'קישור לתשלום' 'Hosted PayPlus payment page link generated for this document, when applicable.' 'קישור עמוד תשלום PayPlus שנוצר עבור מסמך זה, כאשר רלוונטי.' 2000 'None' 'Url')
    Add-AttributeIfMissing 'alex_moreinfo' (New-MemoAttribute 'alex_moreinfo' 'More Info' 'מידע נוסף' 'Additional information shown on or linked to the document.' 'מידע נוסף המוצג במסמך או מקושר אליו.' 4000)

    Add-AttributeIfMissing 'alex_documenturl' (New-StringAttribute 'alex_documenturl' 'Document URL' 'קישור למסמך' 'PayPlus document view URL.' 'כתובת צפייה במסמך PayPlus.' 2000 'None' 'Url')
    Add-AttributeIfMissing 'alex_pdfurl' (New-StringAttribute 'alex_pdfurl' 'Original PDF URL' 'קישור PDF מקור' 'PayPlus original PDF URL.' 'כתובת PDF מקור מ-PayPlus.' 2000 'None' 'Url')
    Update-StringAttributeLabels 'alex_pdfurl' 'Original PDF URL' 'קישור PDF מקור' 'PayPlus original PDF URL.' 'כתובת PDF מקור מ-PayPlus.' 2000 'None' 'Url'
    Add-AttributeIfMissing 'alex_copypdfurl' (New-StringAttribute 'alex_copypdfurl' 'Copy PDF URL' 'קישור PDF עותק' 'PayPlus copy PDF URL used for redistributing the document.' 'כתובת PDF עותק מ-PayPlus לשימוש בשליחה חוזרת של המסמך.' 2000 'None' 'Url')
    Add-AttributeIfMissing 'alex_sourceentitylogicalname' (New-StringAttribute 'alex_sourceentitylogicalname' 'Source Table Logical Name' 'שם לוגי של טבלת מקור' 'Logical name of the Dataverse source table.' 'שם לוגי של טבלת המקור ב-Dataverse.' 100)
    Add-AttributeIfMissing 'alex_sourceentityid' (New-StringAttribute 'alex_sourceentityid' 'Source Row ID' 'מזהה רשומת מקור' 'Dataverse source row ID stored generically for non-Sales extensions.' 'מזהה רשומת המקור ב-Dataverse, נשמר גנרית עבור הרחבות שאינן Sales.' 100)
    Add-AttributeIfMissing 'alex_sourcedisplayname' (New-StringAttribute 'alex_sourcedisplayname' 'Source Display Name' 'שם תצוגת מקור' 'Display name or number of the source record.' 'שם תצוגה או מספר של רשומת המקור.' 300)
    Add-AttributeIfMissing 'alex_sourceurl' (New-StringAttribute 'alex_sourceurl' 'Source URL' 'קישור למקור' 'URL to the source Dataverse record when available.' 'כתובת לרשומת המקור ב-Dataverse, כאשר זמינה.' 2000 'None' 'Url')

    Add-AttributeIfMissing 'alex_payplusresultstatus' (New-StringAttribute 'alex_payplusresultstatus' 'PayPlus Result Status' 'סטטוס תוצאת PayPlus' 'Status value from the PayPlus results envelope.' 'ערך סטטוס מתוך מעטפת results של PayPlus.' 50)
    Add-AttributeIfMissing 'alex_payplusresultcode' (New-IntegerAttribute 'alex_payplusresultcode' 'PayPlus Result Code' 'קוד תוצאת PayPlus' 'Code value from the PayPlus results envelope.' 'ערך קוד מתוך מעטפת results של PayPlus.')
    Add-AttributeIfMissing 'alex_payplusresultdescription' (New-MemoAttribute 'alex_payplusresultdescription' 'PayPlus Result Description' 'תיאור תוצאת PayPlus' 'Description value from the PayPlus results envelope.' 'ערך תיאור מתוך מעטפת results של PayPlus.' 4000)
    Add-AttributeIfMissing 'alex_lastoperation' (New-StringAttribute 'alex_lastoperation' 'Last Operation' 'פעולה אחרונה' 'Last integration operation name, such as CreateQuote or GetDocument.' 'שם פעולת האינטגרציה האחרונה, לדוגמה CreateQuote או GetDocument.' 100)
    Add-AttributeIfMissing 'alex_lasterror' (New-MemoAttribute 'alex_lasterror' 'Last Error' 'שגיאה אחרונה' 'Last integration error message.' 'הודעת השגיאה האחרונה של האינטגרציה.' 4000)

    Add-AttributeIfMissing 'alex_sourcemodifiedon' (New-DateTimeAttribute 'alex_sourcemodifiedon' 'Source Modified On' 'מקור עודכן בתאריך' 'Source record modified timestamp captured when the PayPlus document request was created.' 'תאריך ושעת עדכון רשומת המקור שנשמרו בעת יצירת בקשת מסמך PayPlus.')
    Add-AttributeIfMissing 'alex_sourceversionnumber' (New-StringAttribute 'alex_sourceversionnumber' 'Source Version Number' 'מספר גרסת מקור' 'Source record version number captured when the PayPlus document request was created.' 'מספר גרסת רשומת המקור שנשמר בעת יצירת בקשת מסמך PayPlus.' 100)
    Add-AttributeIfMissing 'alex_sourcedetailmodifiedon' (New-DateTimeAttribute 'alex_sourcedetailmodifiedon' 'Source Detail Modified On' 'שורות מקור עודכנו בתאריך' 'Latest source detail row modified timestamp captured when the PayPlus document request was created.' 'תאריך ושעת העדכון האחרונים של שורת מקור שנשמרו בעת יצירת בקשת מסמך PayPlus.')
    Add-AttributeIfMissing 'alex_sourcedetailversionnumber' (New-StringAttribute 'alex_sourcedetailversionnumber' 'Source Detail Version Number' 'מספר גרסת שורות מקור' 'Latest source detail row version number captured when the PayPlus document request was created.' 'מספר הגרסה האחרון של שורת מקור שנשמר בעת יצירת בקשת מסמך PayPlus.' 100)
    Add-AttributeIfMissing 'alex_sourcedetailcount' (New-IntegerAttribute 'alex_sourcedetailcount' 'Source Detail Count' 'מספר שורות מקור' 'Source detail row count captured when the PayPlus document request was created.' 'מספר שורות המקור שנשמר בעת יצירת בקשת מסמך PayPlus.' 0 2147483647)
    Add-AttributeIfMissing 'alex_sourcefingerprint' (New-StringAttribute 'alex_sourcefingerprint' 'Source Fingerprint' 'טביעת מקור' 'Compact source snapshot used to detect whether the source record changed after the PayPlus document was generated.' 'תצלום מקור מקוצר המשמש לזיהוי שינוי ברשומת המקור אחרי הפקת מסמך PayPlus.' 500)

    Add-AttributeIfMissing 'alex_requestedaction' (New-PicklistAttribute 'alex_requestedaction' 'Requested Action' 'פעולה מבוקשת' 'Pending business action requested for this PayPlus document.' 'פעולה עסקית מבוקשת עבור מסמך PayPlus זה.' @(
        (New-Option 100000000 'Send document' 'שליחת מסמך'),
        (New-Option 100000001 'Cancel document' 'ביטול מסמך'),
        (New-Option 100000002 'Close document' 'סגירת מסמך')
    ))
    Add-AttributeIfMissing 'alex_requestedchannel' (New-PicklistAttribute 'alex_requestedchannel' 'Requested Channel' 'ערוץ מבוקש' 'Requested delivery channel for a document action.' 'ערוץ הפצה מבוקש עבור פעולת מסמך.' @(
        (New-Option 100000000 'Email' 'דוא"ל'),
        (New-Option 100000001 'SMS' 'SMS'),
        (New-Option 100000002 'WhatsApp' 'WhatsApp')
    ))
    Add-AttributeIfMissing 'alex_requestedlinktype' (New-PicklistAttribute 'alex_requestedlinktype' 'Requested Link Type' 'סוג קישור מבוקש' 'Requested document link type for distribution.' 'סוג קישור המסמך המבוקש להפצה.' @(
        (New-Option 100000000 'Original' 'מקור'),
        (New-Option 100000001 'Copy' 'עותק')
    ))
    Add-AttributeIfMissing 'alex_requestedactionstatus' (New-PicklistAttribute 'alex_requestedactionstatus' 'Requested Action Status' 'סטטוס פעולה מבוקשת' 'Processing status of the requested document action.' 'סטטוס עיבוד של פעולת המסמך המבוקשת.' @(
        (New-Option 100000000 'Pending' 'ממתין'),
        (New-Option 100000001 'Composed' 'נוצר Compose'),
        (New-Option 100000002 'Failed' 'נכשל'),
        (New-Option 100000003 'Completed' 'הושלם')
    ))
    Add-AttributeIfMissing 'alex_requestedactionon' (New-DateTimeAttribute 'alex_requestedactionon' 'Requested Action On' 'פעולה התבקשה בתאריך' 'Date and time when the document action was requested.' 'תאריך ושעה שבהם התבקשה פעולת המסמך.')
    Add-AttributeIfMissing 'alex_requestedactionby' (New-StringAttribute 'alex_requestedactionby' 'Requested Action By' 'פעולה התבקשה על ידי' 'User ID or name that requested the document action.' 'מזהה או שם המשתמש שביקש את פעולת המסמך.' 300)
    Add-AttributeIfMissing 'alex_requestedactionmessage' (New-MemoAttribute 'alex_requestedactionmessage' 'Requested Action Message' 'הודעת פעולה מבוקשת' 'Message or payload summary for the requested document action.' 'הודעה או תקציר payload עבור פעולת המסמך המבוקשת.' 4000)

    Add-AttributeIfMissing 'alex_sentbyemail' (New-BooleanAttribute 'alex_sentbyemail' 'Sent by Email' 'נשלח בדוא"ל' 'Indicates whether the document was sent by email.' 'מציין האם המסמך נשלח בדוא"ל.' $false)
    Add-AttributeIfMissing 'alex_sentbysms' (New-BooleanAttribute 'alex_sentbysms' 'Sent by SMS' 'נשלח ב-SMS' 'Indicates whether the document was sent by SMS.' 'מציין האם המסמך נשלח ב-SMS.' $false)
    Add-AttributeIfMissing 'alex_sentbywhatsapp' (New-BooleanAttribute 'alex_sentbywhatsapp' 'Sent by WhatsApp' 'נשלח ב-WhatsApp' 'Indicates whether the document was sent by WhatsApp.' 'מציין האם המסמך נשלח ב-WhatsApp.' $false)

    Add-AttributeIfMissing 'alex_rawrequest' (New-MemoAttribute 'alex_rawrequest' 'Raw Request JSON' 'JSON בקשה גולמי' 'Full request JSON sent to PayPlus, without secrets.' 'JSON בקשה מלא שנשלח ל-PayPlus, ללא סודות.' 1048576)
    Add-AttributeIfMissing 'alex_rawresponse' (New-MemoAttribute 'alex_rawresponse' 'Raw Response JSON' 'JSON תגובה גולמי' 'Full response JSON returned by PayPlus.' 'JSON תגובה מלא שחזר מ-PayPlus.' 1048576)
    Add-AttributeIfMissing 'alex_rawdocumentjson' (New-MemoAttribute 'alex_rawdocumentjson' 'Raw Document JSON' 'JSON מסמך גולמי' 'Raw document data payload returned by GetDocument.' 'Payload גולמי של נתוני המסמך כפי שחזר מ-GetDocument.' 1048576)
    Add-AttributeIfMissing 'alex_itemsjson' (New-MemoAttribute 'alex_itemsjson' 'Items JSON' 'JSON שורות' 'Raw document items array.' 'מערך שורות המסמך כ-JSON גולמי.' 1048576)
    Add-AttributeIfMissing 'alex_paymentsjson' (New-MemoAttribute 'alex_paymentsjson' 'Payments JSON' 'JSON תשלומים' 'Raw document payments array.' 'מערך תשלומי המסמך כ-JSON גולמי.' 1048576)
    Add-AttributeIfMissing 'alex_tagsjson' (New-MemoAttribute 'alex_tagsjson' 'Tags JSON' 'JSON תגיות' 'Raw document tags array.' 'מערך תגיות המסמך כ-JSON גולמי.' 1048576)
}

function Ensure-AlternateKey {
    param(
        [string]$SchemaName,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [array]$KeyAttributes
    )

    $keys = Invoke-Dv -Method Get -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Keys?`$select=SchemaName"
    if ($keys.value | Where-Object { $_.SchemaName -eq $SchemaName }) {
        Write-Host "Alternate key exists: $SchemaName"
        return
    }

    Write-Host "Creating alternate key: $SchemaName"
    $body = @{
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        KeyAttributes = $KeyAttributes
    }
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Keys" -Body $body | Out-Null
}

function Ensure-AlternateKeys {
    Ensure-AlternateKey 'alex_DocumentEnvironmentUuidKey' 'Environment and PayPlus Document UUID Key' 'מפתח סביבה ומזהה מסמך PayPlus' @('alex_environment', 'alex_payplusdocumentuuid')
    Ensure-AlternateKey 'alex_DocumentEnvironmentUniqueIdentifierTypeKey' 'Environment, Unique Identifier and Document Type Key' 'מפתח סביבה, מזהה ייחודי וסוג מסמך' @('alex_environment', 'alex_uniqueidentifier', 'alex_documenttypecode')
}

function Publish-All {
    if ($SkipPublish) {
        Write-Host 'Skipping PublishAllXml by request.'
        return
    }

    Write-Host 'Publishing customizations...'
    Invoke-Dv -Method Post -Uri "$base/PublishAllXml" -Body @{} | Out-Null
}

function New-GuidText {
    return "{$([guid]::NewGuid().ToString())}"
}

function ConvertTo-XmlText {
    param([string]$Text)
    return [System.Security.SecurityElement]::Escape($Text)
}

function New-FormCellXml {
    param(
        [string]$Field,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$ClassId
    )

    $cellId = New-GuidText
    $en = ConvertTo-XmlText $EnglishLabel
    $he = ConvertTo-XmlText $HebrewLabel
    return '<row><cell id="{0}" showlabel="true"><labels><label description="{1}" languagecode="1033" /><label description="{2}" languagecode="1037" /></labels><control id="{3}" classid="{4}" datafieldname="{3}" /></cell></row>' -f $cellId, $en, $he, $Field, $ClassId
}

function New-FormSectionXml {
    param(
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [array]$Rows
    )

    $sectionId = New-GuidText
    $en = ConvertTo-XmlText $EnglishLabel
    $he = ConvertTo-XmlText $HebrewLabel
    $rowsXml = ($Rows -join '')
    return '<section showlabel="true" showbar="false" IsUserDefined="1" id="{0}"><labels><label description="{1}" languagecode="1033" /><label description="{2}" languagecode="1037" /></labels><rows>{3}</rows></section>' -f $sectionId, $en, $he, $rowsXml
}

function Ensure-MainForm {
    $existing = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq '$entityLogicalName' and type eq 2 and name eq 'מידע'"
    $existingForm = $null
    if ($existing.value.Count -gt 0) { $existingForm = $existing.value[0] }

    if ($existingForm) { Write-Host 'Main form exists: מידע' }
    else { Write-Host 'Creating main form: מידע' }

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

    $generalRows = @(
        (New-FormCellXml 'alex_name' 'Name' 'שם' $classes.String),
        (New-FormCellXml 'alex_configurationid' 'Configuration' 'קונפיגורציה' $classes.Lookup),
        (New-FormCellXml 'alex_environment' 'Environment' 'סביבה' $classes.Picklist),
        (New-FormCellXml 'alex_documenttypeid' 'Document Type' 'סוג מסמך' $classes.Lookup),
        (New-FormCellXml 'alex_documenttypecode' 'Document Type Code' 'קוד סוג מסמך' $classes.String),
        (New-FormCellXml 'alex_payplusdocumentuuid' 'PayPlus Document UUID' 'מזהה מסמך PayPlus' $classes.String),
        (New-FormCellXml 'alex_uniqueidentifier' 'Unique Identifier' 'מזהה ייחודי' $classes.String),
        (New-FormCellXml 'alex_documentnumber' 'Document Number' 'מספר מסמך' $classes.String),
        (New-FormCellXml 'alex_series' 'Series' 'סדרה' $classes.String),
        (New-FormCellXml 'alex_documentstatus' 'Document Status' 'סטטוס מסמך' $classes.String),
        (New-FormCellXml 'alex_businessstatus' 'Business Status' 'סטטוס עסקי' $classes.Picklist)
    )
    $amountRows = @(
        (New-FormCellXml 'alex_documentdate' 'Document Date' 'תאריך מסמך' $classes.DateTime),
        (New-FormCellXml 'alex_issuedon' 'Issued On' 'הופק בתאריך' $classes.DateTime),
        (New-FormCellXml 'alex_currencycode' 'Currency Code' 'קוד מטבע' $classes.String),
        (New-FormCellXml 'alex_totalamount' 'Total Amount' 'סכום כולל' $classes.Decimal),
        (New-FormCellXml 'alex_vatamount' 'VAT Amount' 'סכום מע"מ' $classes.Decimal),
        (New-FormCellXml 'alex_paidamount' 'Paid Amount' 'סכום ששולם' $classes.Decimal),
        (New-FormCellXml 'alex_balanceamount' 'Balance Amount' 'יתרה לתשלום' $classes.Decimal)
    )
    $customerRows = @(
        (New-FormCellXml 'alex_accountid' 'Account' 'לקוח' $classes.Lookup),
        (New-FormCellXml 'alex_contactid' 'Contact' 'איש קשר' $classes.Lookup),
        (New-FormCellXml 'alex_paypluscustomeruid' 'PayPlus Customer UID' 'מזהה לקוח PayPlus' $classes.String),
        (New-FormCellXml 'alex_customername' 'Customer Name' 'שם לקוח' $classes.String),
        (New-FormCellXml 'alex_customeremail' 'Customer Email' 'דוא"ל לקוח' $classes.String),
        (New-FormCellXml 'alex_customerphone' 'Customer Phone' 'טלפון לקוח' $classes.String),
        (New-FormCellXml 'alex_customervatnumber' 'Customer VAT Number' 'מספר עוסק/ח.פ לקוח' $classes.String)
    )
    $contextRows = @(
        (New-FormCellXml 'alex_creditcardid' 'Saved Card' 'כרטיס שמור' $classes.Lookup),
        (New-FormCellXml 'alex_terminalid' 'Terminal' 'מסוף' $classes.Lookup),
        (New-FormCellXml 'alex_paymentpageid' 'Payment Page' 'עמוד תשלום' $classes.Lookup),
        (New-FormCellXml 'alex_transactionuid' 'Transaction UID' 'מזהה עסקה' $classes.String),
        (New-FormCellXml 'alex_paymentrequestuid' 'Payment Request UID' 'מזהה בקשת תשלום' $classes.String),
        (New-FormCellXml 'alex_paymentpagelink' 'Payment Page Link' 'קישור לתשלום' $classes.String),
        (New-FormCellXml 'alex_documenturl' 'Document URL' 'קישור למסמך' $classes.String),
        (New-FormCellXml 'alex_pdfurl' 'Original PDF URL' 'קישור PDF מקור' $classes.String),
        (New-FormCellXml 'alex_copypdfurl' 'Copy PDF URL' 'קישור PDF עותק' $classes.String)
    )
    $sourceRows = @(
        (New-FormCellXml 'alex_sourceentitylogicalname' 'Source Table Logical Name' 'שם לוגי של טבלת מקור' $classes.String),
        (New-FormCellXml 'alex_sourceentityid' 'Source Row ID' 'מזהה רשומת מקור' $classes.String),
        (New-FormCellXml 'alex_sourcedisplayname' 'Source Display Name' 'שם תצוגת מקור' $classes.String),
        (New-FormCellXml 'alex_sourceurl' 'Source URL' 'קישור למקור' $classes.String)
    )
    $operationRows = @(
        (New-FormCellXml 'alex_origin' 'Origin' 'מקור יצירה' $classes.Picklist),
        (New-FormCellXml 'alex_lastsyncstatus' 'Last Sync Status' 'סטטוס סנכרון אחרון' $classes.Picklist),
        (New-FormCellXml 'alex_lastoperation' 'Last Operation' 'פעולה אחרונה' $classes.String),
        (New-FormCellXml 'alex_lastoperationon' 'Last Operation On' 'פעולה אחרונה בתאריך' $classes.DateTime),
        (New-FormCellXml 'alex_lastrefreshedon' 'Last Refreshed On' 'רוענן לאחרונה בתאריך' $classes.DateTime),
        (New-FormCellXml 'alex_requestedaction' 'Requested Action' 'פעולה מבוקשת' $classes.Picklist),
        (New-FormCellXml 'alex_requestedchannel' 'Requested Channel' 'ערוץ מבוקש' $classes.Picklist),
        (New-FormCellXml 'alex_requestedlinktype' 'Requested Link Type' 'סוג קישור מבוקש' $classes.Picklist),
        (New-FormCellXml 'alex_requestedactionstatus' 'Requested Action Status' 'סטטוס פעולה מבוקשת' $classes.Picklist),
        (New-FormCellXml 'alex_requestedactionon' 'Requested Action On' 'פעולה התבקשה בתאריך' $classes.DateTime),
        (New-FormCellXml 'alex_lasterror' 'Last Error' 'שגיאה אחרונה' $classes.Memo)
    )
    $freshnessRows = @(
        (New-FormCellXml 'alex_sourcefingerprint' 'Source Fingerprint' 'טביעת מקור' $classes.String),
        (New-FormCellXml 'alex_sourcemodifiedon' 'Source Modified On' 'מקור עודכן בתאריך' $classes.DateTime),
        (New-FormCellXml 'alex_sourceversionnumber' 'Source Version Number' 'מספר גרסת מקור' $classes.String),
        (New-FormCellXml 'alex_sourcedetailmodifiedon' 'Source Detail Modified On' 'שורות מקור עודכנו בתאריך' $classes.DateTime),
        (New-FormCellXml 'alex_sourcedetailversionnumber' 'Source Detail Version Number' 'מספר גרסת שורות מקור' $classes.String),
        (New-FormCellXml 'alex_sourcedetailcount' 'Source Detail Count' 'מספר שורות מקור' $classes.Integer)
    )
    $diagnosticRows = @(
        (New-FormCellXml 'alex_rawdocumentjson' 'Raw Document JSON' 'JSON מסמך גולמי' $classes.Memo),
        (New-FormCellXml 'alex_rawrequest' 'Raw Request JSON' 'JSON בקשה גולמי' $classes.Memo),
        (New-FormCellXml 'alex_rawresponse' 'Raw Response JSON' 'JSON תגובה גולמי' $classes.Memo),
        (New-FormCellXml 'alex_requestedactionmessage' 'Requested Action Message' 'הודעת פעולה מבוקשת' $classes.Memo),
        (New-FormCellXml 'alex_itemsjson' 'Items JSON' 'JSON שורות' $classes.Memo),
        (New-FormCellXml 'alex_paymentsjson' 'Payments JSON' 'JSON תשלומים' $classes.Memo)
    )

    $tabId = New-GuidText
    $sections = @(
        (New-FormSectionXml 'General' 'כללי' $generalRows),
        (New-FormSectionXml 'Amounts and Dates' 'סכומים ותאריכים' $amountRows),
        (New-FormSectionXml 'Customer Snapshot' 'תצלום לקוח' $customerRows),
        (New-FormSectionXml 'Payment Context' 'הקשר תשלום' $contextRows),
        (New-FormSectionXml 'Source Record' 'רשומת מקור' $sourceRows),
        (New-FormSectionXml 'Operations' 'תפעול' $operationRows),
        (New-FormSectionXml 'Source Freshness' 'עדכניות מקור' $freshnessRows),
        (New-FormSectionXml 'Diagnostics' 'אבחון' $diagnosticRows)
    )
    $formXml = '<form><tabs><tab verticallayout="true" id="{0}" IsUserDefined="1"><labels><label description="Information" languagecode="1033" /><label description="מידע" languagecode="1037" /></labels><columns><column width="100%"><sections>{1}</sections></column></columns></tab></tabs></form>' -f $tabId, ($sections -join '')

    $body = @{
        name           = 'מידע'
        type           = 2
        objecttypecode = $entityLogicalName
        formxml        = $formXml
    }

    if ($existingForm) {
        $requiredFormFields = @('alex_paymentpagelink', 'alex_copypdfurl', 'alex_requestedaction', 'alex_sourcefingerprint', 'alex_businessstatus')
        $missingFormFields = @($requiredFormFields | Where-Object { $existingForm.formxml -notlike "*$_*" })
        if ($missingFormFields.Count -eq 0) {
            Write-Host 'Main form already includes latest PayPlus document fields.'
            return
        }

        Write-Host "Updating main form: מידע (missing: $($missingFormFields -join ', '))"
        Invoke-Dv -Method Patch -Uri "$base/systemforms($($existingForm.formid))" -Body @{ formxml = $formXml } | Out-Null
        return
    }

    Invoke-Dv -Method Post -Uri "$base/systemforms" -Body $body | Out-Null
}

function New-ViewLayoutXml {
    param([array]$Columns)

    $cells = ($Columns | ForEach-Object { "<cell name='$($_.Name)' width='$($_.Width)' />" }) -join ''
    return "<grid name='resultset' object='1' jump='alex_name' select='1' icon='1' preview='1'><row name='result' id='alex_payplusdocumentid'>$cells</row></grid>"
}

function Ensure-View {
    param(
        [string]$Name,
        [string]$FetchXml,
        [string]$LayoutXml
    )

    $nameEsc = $Name.Replace("'", "''")
    $existing = Invoke-Dv -Method Get -Uri "$base/savedqueries?`$select=savedqueryid,name&`$filter=returnedtypecode eq '$entityLogicalName' and querytype eq 0 and name eq '$nameEsc'"
    if ($existing.value.Count -gt 0) {
        Write-Host "View exists: $Name"
        return
    }

    Write-Host "Creating view: $Name"
    $body = @{
        name             = $Name
        returnedtypecode = $entityLogicalName
        querytype        = 0
        fetchxml         = $FetchXml
        layoutxml        = $LayoutXml
        isdefault        = $false
        isquickfindquery = $false
    }
    Invoke-Dv -Method Post -Uri "$base/savedqueries" -Body $body | Out-Null
}

function Ensure-Views {
    $columns = @(
        @{ Name = 'alex_name'; Width = 220 },
        @{ Name = 'alex_documenttypecode'; Width = 130 },
        @{ Name = 'alex_documentnumber'; Width = 120 },
        @{ Name = 'alex_documentstatus'; Width = 120 },
        @{ Name = 'alex_businessstatus'; Width = 140 },
        @{ Name = 'alex_customername'; Width = 180 },
        @{ Name = 'alex_totalamount'; Width = 120 },
        @{ Name = 'alex_currencycode'; Width = 80 },
        @{ Name = 'alex_environment'; Width = 110 },
        @{ Name = 'alex_configurationid'; Width = 180 },
        @{ Name = 'alex_lastsyncstatus'; Width = 140 },
        @{ Name = 'alex_lastrefreshedon'; Width = 160 }
    )
    $layout = New-ViewLayoutXml $columns
    $baseAttrs = '<attribute name="alex_name" /><attribute name="alex_documenttypecode" /><attribute name="alex_documentnumber" /><attribute name="alex_documentstatus" /><attribute name="alex_businessstatus" /><attribute name="alex_customername" /><attribute name="alex_totalamount" /><attribute name="alex_currencycode" /><attribute name="alex_environment" /><attribute name="alex_configurationid" /><attribute name="alex_lastsyncstatus" /><attribute name="alex_lastrefreshedon" />'
    $order = '<order attribute="modifiedon" descending="true" />'

    Ensure-View 'מסמכי PayPlus פעילים' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter></entity></fetch>' -f $entityLogicalName, $baseAttrs, $order) $layout
    Ensure-View 'מסמכי PayPlus שנכשלו' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /><condition attribute="alex_lastsyncstatus" operator="eq" value="100000002" /></filter></entity></fetch>' -f $entityLogicalName, $baseAttrs, $order) $layout
    Ensure-View 'מסמכי PayPlus לפי מקור' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}<attribute name="alex_sourceentitylogicalname" /><attribute name="alex_sourcedisplayname" />{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter></entity></fetch>' -f $entityLogicalName, $baseAttrs, $order) $layout
    Ensure-View 'מסמכי PayPlus לפי סוג' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter></entity></fetch>' -f $entityLogicalName, $baseAttrs, '<order attribute="alex_documenttypecode" descending="false" /><order attribute="modifiedon" descending="true" />') $layout
}

Ensure-Entity | Out-Null
Ensure-EntityLabels
Ensure-CoreRelationships
Ensure-Attributes
Ensure-AlternateKeys
Publish-All

if (-not $SkipViewsAndForms) {
    Ensure-MainForm
    Ensure-Views
    Publish-All
}

$entity = Get-EntityMetadata
$rowCount = 0
if ($entity -and $entity.EntitySetName) {
    $rowCount = (Invoke-Dv -Method Get -Uri "$base/$($entity.EntitySetName)?`$select=alex_payplusdocumentid&`$count=true").'@odata.count'
}

Write-Host "Done. EntitySet=$($entity.EntitySetName); RowCount=$rowCount; Solution=$SolutionUniqueName"