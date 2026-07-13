# Deploy PayPlus Document Type reference table to Dataverse.
# Creates metadata, localized labels/descriptions, a main form, public views, and seed rows
# from the PayPlus GetDocumentTypes connector response.

param(
    [string]$Org = 'https://demo-contact-center-en.crm4.dynamics.com',
    [string]$SolutionUniqueName = 'alex_d365_payplus',
    [switch]$SkipPublish,
    [switch]$SkipViewsAndForms,
    [switch]$SkipSeed
)

$ErrorActionPreference = 'Stop'

$entityLogicalName = 'alex_payplus_documenttype'
$entitySchemaName = 'alex_payplus_documenttype'
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
        [string]$RequiredLevel = 'None'
    )

    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = New-RequiredLevel $RequiredLevel
        MaxLength     = $MaxLength
        FormatName    = @{ Value = 'Text' }
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
        DisplayName           = New-Label 'PayPlus Document Type' 'סוג מסמך PayPlus'
        DisplayCollectionName = New-Label 'PayPlus Document Types' 'סוגי מסמכים PayPlus'
        Description           = New-Label 'Local reference catalog of PayPlus document types returned by the Invoice+ API.' 'קטלוג מקומי של סוגי המסמכים ש-PayPlus מחזיר מממשק Invoice+.'
        OwnershipType         = 'OrganizationOwned'
        HasActivities         = $false
        HasNotes              = $false
        IsActivity            = $false
        Attributes            = @(
            @{
                '@odata.type'  = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
                SchemaName     = 'alex_name'
                DisplayName    = New-Label 'Name' 'שם'
                Description    = New-Label 'Primary display value for the document type record.' 'ערך תצוגה ראשי של רשומת סוג המסמך.'
                RequiredLevel  = New-RequiredLevel 'ApplicationRequired'
                MaxLength      = 200
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
        DisplayName           = New-Label 'PayPlus Document Type' 'סוג מסמך PayPlus'
        DisplayCollectionName = New-Label 'PayPlus Document Types' 'סוגי מסמכים PayPlus'
        Description           = New-Label 'Local reference catalog of PayPlus document types returned by the Invoice+ API.' 'קטלוג מקומי של סוגי המסמכים ש-PayPlus מחזיר מממשק Invoice+.'
        OwnershipType         = 'OrganizationOwned'
        HasActivities         = $false
        HasNotes              = $false
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

function Ensure-RelationshipToSyncProfile {
    $schemaName = 'alex_payplussyncprofile_alex_payplus_documenttype'
    $relationship = Try-GetDv "$base/RelationshipDefinitions(SchemaName='$schemaName')?`$select=MetadataId,SchemaName"
    if ($relationship) {
        Write-Host "Relationship exists: $schemaName"
        return
    }

    Write-Host "Creating relationship: $schemaName"
    $body = @{
        '@odata.type'        = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
        SchemaName           = $schemaName
        ReferencedEntity     = 'alex_payplus_syncprofile'
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
            SchemaName    = 'alex_syncprofileid'
            DisplayName   = New-Label 'Sync Profile' 'פרופיל סנכרון'
            Description   = New-Label 'Optional PayPlus sync profile that owns or refreshed this document type.' 'פרופיל סנכרון אופציונלי ששייך לסוג המסמך או שדרכו הוא רוענן.'
            RequiredLevel = New-RequiredLevel 'None'
            Targets       = @('alex_payplus_syncprofile')
        }
    }
    Invoke-Dv -Method Post -Uri "$base/RelationshipDefinitions" -Body $body | Out-Null
}

function Ensure-RelationshipToConfiguration {
    $schemaName = 'alex_payplusconfiguration_alex_payplus_documenttype'
    $relationship = Try-GetDv "$base/RelationshipDefinitions(SchemaName='$schemaName')?`$select=MetadataId,SchemaName"
    if ($relationship) {
        Write-Host "Relationship exists: $schemaName"
        return
    }

    Write-Host "Creating relationship: $schemaName"
    $body = @{
        '@odata.type'        = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
        SchemaName           = $schemaName
        ReferencedEntity     = 'alex_payplusconfiguration'
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
            SchemaName    = 'alex_configurationid'
            DisplayName   = New-Label 'Configuration' 'קונפיגורציה'
            Description   = New-Label 'PayPlus configuration that scopes this document type catalog row.' 'קונפיגורציית PayPlus שאליה משויכת רשומת סוג המסמך.'
            RequiredLevel = New-RequiredLevel 'None'
            Targets       = @('alex_payplusconfiguration')
        }
    }
    Invoke-Dv -Method Post -Uri "$base/RelationshipDefinitions" -Body $body | Out-Null
}

function Ensure-Attributes {
    Add-AttributeIfMissing 'alex_code' (New-StringAttribute 'alex_code' 'Code' 'קוד' 'PayPlus API code used as the docType parameter.' 'הקוד שנשלח ל-PayPlus בפרמטר docType.' 100 'ApplicationRequired')
    Add-AttributeIfMissing 'alex_typecode' (New-IntegerAttribute 'alex_typecode' 'Type Code' 'קוד סוג מספרי' 'Numeric document type code returned by PayPlus when available.' 'קוד מספרי של סוג המסמך כפי שחוזר מ-PayPlus, כאשר קיים.' 0 2147483647)
    Add-AttributeIfMissing 'alex_titlehe' (New-StringAttribute 'alex_titlehe' 'Hebrew Title' 'כותרת בעברית' 'Hebrew business title for the document type.' 'שם עסקי בעברית של סוג המסמך.' 200)
    Add-AttributeIfMissing 'alex_titleen' (New-StringAttribute 'alex_titleen' 'English Title' 'כותרת באנגלית' 'English business title for the document type.' 'שם עסקי באנגלית של סוג המסמך.' 200)
    Add-AttributeIfMissing 'alex_payplustitle' (New-StringAttribute 'alex_payplustitle' 'PayPlus Title' 'כותרת PayPlus' 'Original title returned by the PayPlus API.' 'הכותרת המקורית שחזרה מממשק PayPlus.' 200)
    Add-AttributeIfMissing 'alex_environment' (New-PicklistAttribute 'alex_environment' 'Environment' 'סביבה' 'PayPlus environment where this document type is available.' 'סביבת PayPlus שבה סוג המסמך זמין.' @(
        (New-Option 100000000 'Production' 'Production (ייצור)'),
        (New-Option 100000001 'Sandbox' 'Sandbox (בדיקות)')
    ) 'ApplicationRequired')
    Add-AttributeIfMissing 'alex_category' (New-PicklistAttribute 'alex_category' 'Category' 'קטגוריה' 'Functional category used for filtering and document creation UX.' 'קטגוריה פונקציונלית לסינון ולחוויית יצירת מסמכים.' @(
        (New-Option 100000000 'Sales Document' 'מסמך מכירה'),
        (New-Option 100000001 'Payment Document' 'מסמך תשלום'),
        (New-Option 100000002 'Credit Document' 'מסמך זיכוי'),
        (New-Option 100000003 'Inventory Document' 'מסמך מלאי'),
        (New-Option 100000004 'Purchasing Document' 'מסמך רכש'),
        (New-Option 100000005 'Other' 'אחר')
    ))
    Add-AttributeIfMissing 'alex_source' (New-PicklistAttribute 'alex_source' 'Source' 'מקור' 'Indicates whether the row came from PayPlus, built-in seed data, or manual maintenance.' 'מציין האם הרשומה הגיעה מ-PayPlus, מנתוני seed מובנים או מתחזוקה ידנית.' @(
        (New-Option 100000000 'PayPlus API' 'ממשק PayPlus'),
        (New-Option 100000001 'Built-In Seed' 'קטלוג מובנה'),
        (New-Option 100000002 'Manual' 'ידני')
    ))
    Add-AttributeIfMissing 'alex_declarable' (New-BooleanAttribute 'alex_declarable' 'Declarable' 'בר דיווח' 'Indicates whether the document type is declarable according to PayPlus.' 'מציין האם סוג המסמך מדווח לפי PayPlus.' $false)
    Add-AttributeIfMissing 'alex_caninitiate' (New-BooleanAttribute 'alex_caninitiate' 'Can Initiate' 'ניתן ליצירה' 'Indicates whether users can initiate this document type through the PayPlus API.' 'מציין האם ניתן ליצור את סוג המסמך דרך ממשק PayPlus.' $true)
    Add-AttributeIfMissing 'alex_hidden' (New-BooleanAttribute 'alex_hidden' 'Hidden' 'מוסתר' 'Indicates whether PayPlus marks this document type as hidden.' 'מציין האם PayPlus סימנה את סוג המסמך כמוסתר.' $false)
    Add-AttributeIfMissing 'alex_isactive' (New-BooleanAttribute 'alex_isactive' 'Is Active' 'פעיל' 'Controls whether this document type is available for selection in Dynamics.' 'קובע האם סוג המסמך זמין לבחירה ב-Dynamics.' $true)
    Add-AttributeIfMissing 'alex_sortorder' (New-IntegerAttribute 'alex_sortorder' 'Sort Order' 'סדר תצוגה' 'Display order for document type pickers and views.' 'סדר תצוגה עבור בחירת סוגי מסמכים ותצוגות.' 0 100000)
    Add-AttributeIfMissing 'alex_lastrefreshedon' (New-DateTimeAttribute 'alex_lastrefreshedon' 'Last Refreshed On' 'רוענן לאחרונה בתאריך' 'Date and time when this document type was last refreshed from PayPlus.' 'תאריך ושעה שבהם סוג המסמך רוענן לאחרונה מ-PayPlus.')
    Add-AttributeIfMissing 'alex_rawjson' (New-MemoAttribute 'alex_rawjson' 'Raw JSON' 'JSON גולמי' 'Raw PayPlus response item stored for diagnostics.' 'פריט התגובה הגולמי מ-PayPlus לצורכי אבחון.' 1048576)
    Add-AttributeIfMissing 'alex_description' (New-MemoAttribute 'alex_description' 'Description' 'תיאור' 'Operational note for administrators.' 'הערה תפעולית למנהלי מערכת.' 4000)
}

function Update-LocalOptionLabel {
    param(
        [int]$Value,
        [string]$English,
        [string]$Hebrew
    )

    $body = @{
        EntityLogicalName    = $entityLogicalName
        AttributeLogicalName = 'alex_environment'
        Value                = $Value
        Label                = New-Label $English $Hebrew
        MergeLabels          = $true
        ParentValues         = @()
        SolutionUniqueName   = $SolutionUniqueName
    }
    Invoke-Dv -Method Post -Uri "$base/UpdateOptionValue" -Body $body | Out-Null
}

function Ensure-EnvironmentOptionLabels {
    Write-Host 'Updating environment option labels.'
    Update-LocalOptionLabel 100000000 'Production' 'Production (ייצור)'
    Update-LocalOptionLabel 100000001 'Sandbox' 'Sandbox (בדיקות)'
}

function Ensure-AlternateKey {
    $keySchemaName = 'alex_DocumentTypeEnvironmentCodeKey'
    $keys = Invoke-Dv -Method Get -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Keys?`$select=SchemaName"
    if ($keys.value | Where-Object { $_.SchemaName -eq $keySchemaName }) {
        Write-Host "Alternate key exists: $keySchemaName"
        return
    }

    Write-Host "Creating alternate key: $keySchemaName"
    $body = @{
        SchemaName    = $keySchemaName
        DisplayName   = New-Label 'Environment and Code Key' 'מפתח סביבה וקוד'
        KeyAttributes = @('alex_environment', 'alex_code')
    }
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Keys" -Body $body | Out-Null
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
    $existing = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name&`$filter=objecttypecode eq '$entityLogicalName' and type eq 2 and name eq 'מידע'"
    if ($existing.value.Count -gt 0) {
        Write-Host 'Main form exists: מידע'
        return
    }

    Write-Host 'Creating main form: מידע'
    $classes = @{
        String   = '{4273EDBD-AC1D-40d3-9FB2-095C621B552D}'
        Memo     = '{E0DECE4B-6FC8-4a8f-A065-082708572369}'
        Picklist = '{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}'
        Boolean  = '{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}'
        Integer  = '{C6D124CA-7EDA-4A60-AEA9-7FB8D318B68F}'
        DateTime = '{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}'
        Lookup   = '{270BD3DB-D9AF-4782-9025-509E298DEC0A}'
    }

    $generalRows = @(
        (New-FormCellXml 'alex_name' 'Name' 'שם' $classes.String),
        (New-FormCellXml 'alex_code' 'Code' 'קוד' $classes.String),
        (New-FormCellXml 'alex_titlehe' 'Hebrew Title' 'כותרת בעברית' $classes.String),
        (New-FormCellXml 'alex_titleen' 'English Title' 'כותרת באנגלית' $classes.String),
        (New-FormCellXml 'alex_payplustitle' 'PayPlus Title' 'כותרת PayPlus' $classes.String),
        (New-FormCellXml 'alex_typecode' 'Type Code' 'קוד סוג מספרי' $classes.Integer),
        (New-FormCellXml 'alex_environment' 'Environment' 'סביבה' $classes.Picklist),
        (New-FormCellXml 'alex_configurationid' 'Configuration' 'קונפיגורציה' $classes.Lookup),
        (New-FormCellXml 'alex_syncprofileid' 'Sync Profile' 'פרופיל סנכרון' $classes.Lookup),
        (New-FormCellXml 'alex_category' 'Category' 'קטגוריה' $classes.Picklist)
    )
    $capabilityRows = @(
        (New-FormCellXml 'alex_caninitiate' 'Can Initiate' 'ניתן ליצירה' $classes.Boolean),
        (New-FormCellXml 'alex_declarable' 'Declarable' 'בר דיווח' $classes.Boolean),
        (New-FormCellXml 'alex_hidden' 'Hidden' 'מוסתר' $classes.Boolean),
        (New-FormCellXml 'alex_isactive' 'Is Active' 'פעיל' $classes.Boolean),
        (New-FormCellXml 'alex_source' 'Source' 'מקור' $classes.Picklist),
        (New-FormCellXml 'alex_sortorder' 'Sort Order' 'סדר תצוגה' $classes.Integer),
        (New-FormCellXml 'alex_lastrefreshedon' 'Last Refreshed On' 'רוענן לאחרונה בתאריך' $classes.DateTime)
    )
    $diagnosticRows = @(
        (New-FormCellXml 'alex_description' 'Description' 'תיאור' $classes.Memo),
        (New-FormCellXml 'alex_rawjson' 'Raw JSON' 'JSON גולמי' $classes.Memo)
    )

    $tabId = New-GuidText
    $generalSection = New-FormSectionXml 'General' 'כללי' $generalRows
    $capabilitySection = New-FormSectionXml 'Capabilities' 'יכולות' $capabilityRows
    $diagnosticSection = New-FormSectionXml 'Diagnostics' 'אבחון' $diagnosticRows
    $formXml = '<form><tabs><tab verticallayout="true" id="{0}" IsUserDefined="1"><labels><label description="Information" languagecode="1033" /><label description="מידע" languagecode="1037" /></labels><columns><column width="100%"><sections>{1}{2}{3}</sections></column></columns></tab></tabs></form>' -f $tabId, $generalSection, $capabilitySection, $diagnosticSection

    $body = @{
        name           = 'מידע'
        type           = 2
        objecttypecode = $entityLogicalName
        formxml        = $formXml
    }
    Invoke-Dv -Method Post -Uri "$base/systemforms" -Body $body | Out-Null
}

function New-ViewLayoutXml {
    param([array]$Columns)

    $cells = ($Columns | ForEach-Object { "<cell name='$($_.Name)' width='$($_.Width)' />" }) -join ''
    return "<grid name='resultset' object='1' jump='alex_name' select='1' icon='1' preview='1'><row name='result' id='alex_payplus_documenttypeid'>$cells</row></grid>"
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
        @{ Name = 'alex_titlehe'; Width = 180 },
        @{ Name = 'alex_titleen'; Width = 180 },
        @{ Name = 'alex_code'; Width = 150 },
        @{ Name = 'alex_typecode'; Width = 100 },
        @{ Name = 'alex_category'; Width = 150 },
        @{ Name = 'alex_environment'; Width = 120 },
        @{ Name = 'alex_configurationid'; Width = 180 },
        @{ Name = 'alex_caninitiate'; Width = 110 },
        @{ Name = 'alex_declarable'; Width = 110 },
        @{ Name = 'alex_hidden'; Width = 100 },
        @{ Name = 'alex_isactive'; Width = 100 }
    )
    $layout = New-ViewLayoutXml $columns

    $baseAttrs = '<attribute name="alex_titlehe" /><attribute name="alex_titleen" /><attribute name="alex_code" /><attribute name="alex_typecode" /><attribute name="alex_category" /><attribute name="alex_environment" /><attribute name="alex_configurationid" /><attribute name="alex_caninitiate" /><attribute name="alex_declarable" /><attribute name="alex_hidden" /><attribute name="alex_isactive" />'
    $order = '<order attribute="alex_sortorder" descending="false" /><order attribute="alex_titlehe" descending="false" />'

    Ensure-View 'סוגי מסמכים פעילים' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /><condition attribute="alex_isactive" operator="eq" value="1" /><condition attribute="alex_hidden" operator="eq" value="0" /></filter></entity></fetch>' -f $entityLogicalName, $baseAttrs, $order) $layout
    Ensure-View 'כל סוגי המסמכים' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter></entity></fetch>' -f $entityLogicalName, $baseAttrs, $order) $layout
    Ensure-View 'סוגים ברי דיווח' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /><condition attribute="alex_declarable" operator="eq" value="1" /></filter></entity></fetch>' -f $entityLogicalName, $baseAttrs, $order) $layout
    Ensure-View 'סוגים חסומים או מוסתרים' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /><filter type="or"><condition attribute="alex_hidden" operator="eq" value="1" /><condition attribute="alex_caninitiate" operator="eq" value="0" /><condition attribute="alex_isactive" operator="eq" value="0" /></filter></filter></entity></fetch>' -f $entityLogicalName, $baseAttrs, $order) $layout
}

function Get-CategoryValue {
    param([string]$Code)

    switch -Regex ($Code) {
        '^inv_refund$' { return 100000002 }
        '^inv_receipt$|^inv_tax_receipt$|^inv_pay_request$|^inv_don_receipt$|^inv_cancel_receipt$' { return 100000001 }
        '^crt_inv_|^crt_delivery$|^crt_return$' { return 100000003 }
        '^order_purchase$|^purchase$' { return 100000004 }
        '^inv_|^dc_quote$' { return 100000000 }
        default { return 100000005 }
    }
}

function Get-EnglishTitle {
    param([string]$Code)

    $titles = @{
        inv_proforma            = 'Proforma Invoice'
        inv_tax                 = 'Tax Invoice'
        inv_receipt             = 'Receipt'
        inv_tax_receipt         = 'Tax Invoice Receipt'
        inv_refund              = 'Credit Invoice'
        crt_delivery            = 'Delivery Certificate'
        crt_return              = 'Return Certificate'
        order_purchase          = 'Purchase Order'
        purchase                = 'Order'
        dc_quote                = 'Quote'
        inv_don_receipt         = 'Donation Receipt'
        inv_pay_request         = 'Payment Request'
        crt_inv_enters          = 'Inventory Entry'
        crt_inv_leaves          = 'Inventory Issue'
        crt_inv_moves_wh        = 'Warehouse Transfer'
        crt_inv_recount_update  = 'Stock Count Adjustment'
        inv_cancel_receipt      = 'Receipt Cancellation'
    }

    if ($titles.ContainsKey($Code)) { return $titles[$Code] }
    return $Code
}

function Get-DocumentTypeSeed {
    $raw = @(
        @{ code = 'inv_proforma'; type_code = 300; declarable = $false; can_initiate = $true; hidden = $false; title = 'חשבונית עסקה' },
        @{ code = 'inv_tax'; type_code = 305; declarable = $true; can_initiate = $true; hidden = $false; title = 'חשבונית מס' },
        @{ code = 'inv_receipt'; type_code = 400; declarable = $false; can_initiate = $true; hidden = $false; title = 'קבלה' },
        @{ code = 'inv_tax_receipt'; type_code = 320; declarable = $true; can_initiate = $true; hidden = $false; title = 'חשבונית מס קבלה' },
        @{ code = 'inv_refund'; type_code = 330; declarable = $false; can_initiate = $true; hidden = $false; title = 'חשבונית זיכוי' },
        @{ code = 'crt_delivery'; type_code = 200; declarable = $false; can_initiate = $true; hidden = $false; title = 'תעודת משלוח' },
        @{ code = 'crt_return'; type_code = 210; declarable = $false; can_initiate = $true; hidden = $false; title = 'תעודת החזרה' },
        @{ code = 'order_purchase'; type_code = 500; declarable = $false; can_initiate = $true; hidden = $false; title = 'הזמנת רכש' },
        @{ code = 'purchase'; type_code = 100; declarable = $false; can_initiate = $true; hidden = $false; title = 'הזמנה' },
        @{ code = 'dc_quote'; declarable = $false; can_initiate = $true; hidden = $false; title = 'הצעת מחיר' },
        @{ code = 'inv_don_receipt'; type_code = 405; declarable = $false; can_initiate = $true; hidden = $false; title = 'קבלה על תרומה' },
        @{ code = 'inv_pay_request'; declarable = $false; can_initiate = $true; hidden = $false; title = 'בקשת תשלום' },
        @{ code = 'crt_inv_enters'; type_code = 810; declarable = $false; can_initiate = $true; hidden = $false; title = 'כניסה כללית למלאי' },
        @{ code = 'crt_inv_leaves'; type_code = 820; declarable = $false; can_initiate = $true; hidden = $false; title = 'יציאה כללית מהמלאי' },
        @{ code = 'crt_inv_moves_wh'; type_code = 830; declarable = $false; can_initiate = $true; hidden = $false; title = 'העברה בין מחסנים' },
        @{ code = 'crt_inv_recount_update'; type_code = 840; declarable = $false; can_initiate = $true; hidden = $false; title = 'עדכון בעקבות ספירה' },
        @{ code = 'inv_cancel_receipt'; type_code = 410; declarable = $false; can_initiate = $false; hidden = $false; title = 'inv_cancel_receipt' }
    )

    $index = 10
    foreach ($item in $raw) {
        [pscustomobject]@{
            Code          = $item.code
            TypeCode      = if ($item.ContainsKey('type_code')) { $item.type_code } else { $null }
            Declarable    = [bool]$item.declarable
            CanInitiate   = [bool]$item.can_initiate
            Hidden        = [bool]$item.hidden
            TitleHe       = [string]$item.title
            TitleEn       = Get-EnglishTitle $item.code
            Category      = Get-CategoryValue $item.code
            SortOrder     = $index
            RawJson       = ($item | ConvertTo-Json -Compress -Depth 5)
        }
        $index += 10
    }
}

function Get-ODataString {
    param([string]$Value)
    return $Value.Replace("'", "''")
}

function Seed-DocumentTypes {
    if ($SkipSeed) {
        Write-Host 'Skipping seed rows by request.'
        return
    }

    $entity = Get-EntityMetadata
    $setName = $entity.EntitySetName
    if (-not $setName) { throw "Could not resolve EntitySetName for $entityLogicalName." }

    $environments = @(100000000, 100000001)
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $created = 0
    $updated = 0
    $configurationByEnvironment = @{}

    foreach ($environment in $environments) {
        $configs = Invoke-Dv -Method Get -Uri "$base/alex_payplusconfigurations?`$select=alex_payplusconfigurationid,alex_name&`$filter=statecode eq 0 and alex_environment eq $environment"
        if ($configs.value.Count -eq 1) {
            $configurationByEnvironment[$environment] = $configs.value[0].alex_payplusconfigurationid
            Write-Host "Configuration for environment $($environment): $($configs.value[0].alex_name) ($($configs.value[0].alex_payplusconfigurationid))"
        }
        elseif ($configs.value.Count -gt 1) {
            Write-Warning "Multiple PayPlus configuration rows found for environment $environment; seed rows will not be auto-linked."
        }
    }

    foreach ($environment in $environments) {
        foreach ($docType in Get-DocumentTypeSeed) {
            $codeEsc = Get-ODataString $docType.Code
            $existing = Invoke-Dv -Method Get -Uri "$base/$($setName)?`$select=alex_payplus_documenttypeid&`$filter=alex_environment eq $environment and alex_code eq '$codeEsc'&`$top=1"
            $body = @{
                alex_name            = $docType.Code
                alex_code            = $docType.Code
                alex_titlehe         = $docType.TitleHe
                alex_titleen         = $docType.TitleEn
                alex_payplustitle    = $docType.TitleHe
                alex_environment     = $environment
                alex_category        = $docType.Category
                alex_declarable      = $docType.Declarable
                alex_caninitiate     = $docType.CanInitiate
                alex_hidden          = $docType.Hidden
                alex_isactive        = (-not $docType.Hidden)
                alex_source          = 100000000
                alex_sortorder       = $docType.SortOrder
                alex_lastrefreshedon = $now
                alex_rawjson         = $docType.RawJson
                alex_description     = 'Seeded from the PayPlus GetDocumentTypes connector response supplied during implementation.'
            }
            if ($configurationByEnvironment.ContainsKey($environment)) {
                $body['alex_configurationid@odata.bind'] = "/alex_payplusconfigurations($($configurationByEnvironment[$environment]))"
            }
            if ($null -ne $docType.TypeCode) { $body.alex_typecode = $docType.TypeCode }

            if ($existing.value.Count -gt 0) {
                $id = $existing.value[0].alex_payplus_documenttypeid
                Invoke-Dv -Method Patch -Uri "$base/$($setName)($id)" -Body $body | Out-Null
                $updated++
            }
            else {
                Invoke-Dv -Method Post -Uri "$base/$($setName)" -Body $body | Out-Null
                $created++
            }
        }
    }

    Write-Host "Seed rows complete. Created=$created Updated=$updated"
}

$entity = Ensure-Entity
Ensure-EntityLabels
Ensure-Attributes
Ensure-EnvironmentOptionLabels
Ensure-RelationshipToSyncProfile
Ensure-RelationshipToConfiguration
Ensure-AlternateKey
Publish-All

if (-not $SkipViewsAndForms) {
    Ensure-MainForm
    Ensure-Views
    Publish-All
}
else {
    Write-Host 'Skipping views/forms by request.'
}

Seed-DocumentTypes

$resultEntity = Get-EntityMetadata
$setNameResult = $resultEntity.EntitySetName
$rowCount = if ($SkipSeed) { 0 } else { (Invoke-Dv -Method Get -Uri "$base/$($setNameResult)?`$select=alex_payplus_documenttypeid&`$count=true" ).'@odata.count' }

Write-Host ''
Write-Host 'DONE.'
Write-Host "Table: $entityLogicalName"
Write-Host "EntitySet: $setNameResult"
Write-Host "Seeded row count: $rowCount"