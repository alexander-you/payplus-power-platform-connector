# Deploy PayPlus Terminal + Payment Page data model to Dataverse.
# Creates two OrganizationOwned tables (terminal 1:N payment page), scoped to
# configuration + environment, with business/policy fields, relationships,
# alternate keys, bilingual main forms (terminal form hosts a payment-page
# subgrid), and Hebrew-primary public views. No connector changes.
#
# Mirrors the pattern of _poc_deploy_document_types.ps1.

param(
    [string]$Org = 'https://demo-contact-center-en.crm4.dynamics.com',
    [string]$SolutionUniqueName = 'alex_d365_payplus',
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'

$terminalEntity = 'alex_payplus_terminal'
$pageEntity = 'alex_payplus_paymentpage'
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
    if (-not $response) { return $false }
    return ([int]$response.StatusCode -eq 404)
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
    return @{ LocalizedLabels = @(
            @{ Label = $English; LanguageCode = 1033 },
            @{ Label = $Hebrew; LanguageCode = 1037 }
        )
    }
}

function New-RequiredLevel {
    param([string]$Value = 'None')
    return @{ Value = $Value; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
}

function New-Option {
    param([int]$Value, [string]$English, [string]$Hebrew)
    return @{ Value = $Value; Label = (New-Label $English $Hebrew) }
}

# --- attribute builders --------------------------------------------------
function New-StringAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [int]$MaxLength = 100, [string]$RequiredLevel = 'None')
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

function New-BooleanAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [bool]$DefaultValue = $false)
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
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [array]$Options, [string]$RequiredLevel = 'None')
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

# --- generic entity/attribute helpers -----------------------------------
function Get-EntityMeta {
    param([string]$Entity)
    return Try-GetDv "$base/EntityDefinitions(LogicalName='$Entity')?`$select=MetadataId,LogicalName,EntitySetName"
}

function Test-AttributeExists {
    param([string]$Entity, [string]$LogicalName)
    $attr = Try-GetDv "$base/EntityDefinitions(LogicalName='$Entity')/Attributes(LogicalName='$LogicalName')?`$select=MetadataId,LogicalName"
    return ($null -ne $attr)
}

function Add-AttributeIfMissing {
    param([string]$Entity, [string]$LogicalName, [hashtable]$Metadata)
    if (Test-AttributeExists $Entity $LogicalName) { Write-Host "  attr exists: $Entity.$LogicalName"; return }
    Write-Host "  create attr: $Entity.$LogicalName"
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$Entity')/Attributes" -Body $Metadata | Out-Null
}

function Ensure-Entity {
    param([string]$Entity, [hashtable]$DisplayName, [hashtable]$CollectionName, [hashtable]$Description)
    $meta = Get-EntityMeta $Entity
    if ($meta) { Write-Host "Entity exists: $Entity ($($meta.MetadataId))"; return $meta }
    Write-Host "Creating entity: $Entity"
    $body = @{
        '@odata.type'         = 'Microsoft.Dynamics.CRM.EntityMetadata'
        SchemaName            = $Entity
        DisplayName           = $DisplayName
        DisplayCollectionName = $CollectionName
        Description           = $Description
        OwnershipType         = 'OrganizationOwned'
        HasActivities         = $false
        HasNotes              = $false
        IsActivity            = $false
        Attributes            = @(
            @{
                '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
                SchemaName    = 'alex_name'
                DisplayName   = New-Label 'Name' 'שם'
                Description   = New-Label 'Primary business display name.' 'שם תצוגה עסקי ראשי.'
                RequiredLevel = New-RequiredLevel 'ApplicationRequired'
                MaxLength     = 200
                FormatName    = @{ Value = 'Text' }
                IsPrimaryName = $true
            }
        )
    }
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions" -Body $body | Out-Null
    $meta = Get-EntityMeta $Entity
    if (-not $meta) { throw "Entity created but metadata not available yet: $Entity" }
    return $meta
}

function Ensure-Lookup {
    param(
        [string]$SchemaName, [string]$ReferencedEntity, [string]$ReferencingEntity,
        [string]$LookupSchema, [hashtable]$DisplayName, [hashtable]$Description,
        [string]$RequiredLevel = 'None'
    )
    $rel = Try-GetDv "$base/RelationshipDefinitions(SchemaName='$SchemaName')?`$select=MetadataId,SchemaName"
    if ($rel) { Write-Host "  rel exists: $SchemaName"; return }
    Write-Host "  create rel: $SchemaName"
    $body = @{
        '@odata.type'        = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
        SchemaName           = $SchemaName
        ReferencedEntity     = $ReferencedEntity
        ReferencingEntity    = $ReferencingEntity
        CascadeConfiguration = @{
            Assign = 'NoCascade'; Delete = 'RemoveLink'; Merge = 'NoCascade'
            Reparent = 'NoCascade'; Share = 'NoCascade'; Unshare = 'NoCascade'; RollupView = 'NoCascade'
        }
        Lookup               = @{
            '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'
            SchemaName    = $LookupSchema
            DisplayName   = $DisplayName
            Description   = $Description
            RequiredLevel = New-RequiredLevel $RequiredLevel
            Targets       = @($ReferencedEntity)
        }
    }
    Invoke-Dv -Method Post -Uri "$base/RelationshipDefinitions" -Body $body | Out-Null
}

function Ensure-AlternateKey {
    param([string]$Entity, [string]$KeySchema, [hashtable]$DisplayName, [string[]]$KeyAttributes)
    $keys = Invoke-Dv -Method Get -Uri "$base/EntityDefinitions(LogicalName='$Entity')/Keys?`$select=SchemaName"
    if ($keys.value | Where-Object { $_.SchemaName -eq $KeySchema }) { Write-Host "  key exists: $KeySchema"; return }
    Write-Host "  create key: $KeySchema"
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$Entity')/Keys" -Body @{
        SchemaName = $KeySchema; DisplayName = $DisplayName; KeyAttributes = $KeyAttributes
    } | Out-Null
}

function Update-EnvOptionLabels {
    param([string]$Entity)
    foreach ($o in @(@{v = 100000000; en = 'Production'; he = 'Production (ייצור)' }, @{v = 100000001; en = 'Sandbox'; he = 'Sandbox (בדיקות)' })) {
        Invoke-Dv -Method Post -Uri "$base/UpdateOptionValue" -Body @{
            EntityLogicalName = $Entity; AttributeLogicalName = 'alex_environment'
            Value = $o.v; Label = (New-Label $o.en $o.he); MergeLabels = $true
            ParentValues = @(); SolutionUniqueName = $SolutionUniqueName
        } | Out-Null
    }
}

# --- form / view xml helpers --------------------------------------------
$FormClass = @{
    String   = '{4273EDBD-AC1D-40d3-9FB2-095C621B552D}'
    Memo     = '{E0DECE4B-6FC8-4a8f-A065-082708572369}'
    Picklist = '{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}'
    Boolean  = '{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}'
    Integer  = '{C6D124CA-7EDA-4A60-AEA9-7FB8D318B68F}'
    DateTime = '{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}'
    Lookup   = '{270BD3DB-D9AF-4782-9025-509E298DEC0A}'
    Subgrid  = '{E7A81278-8635-4D9E-8D4D-59480B391C5B}'
}

function New-GuidText { return "{$([guid]::NewGuid().ToString())}" }
function ConvertTo-XmlText { param([string]$Text) return [System.Security.SecurityElement]::Escape($Text) }

function New-FormCellXml {
    param([string]$Field, [string]$EnglishLabel, [string]$HebrewLabel, [string]$ClassId)
    $cellId = New-GuidText
    $en = ConvertTo-XmlText $EnglishLabel
    $he = ConvertTo-XmlText $HebrewLabel
    return '<row><cell id="{0}" showlabel="true"><labels><label description="{1}" languagecode="1033" /><label description="{2}" languagecode="1037" /></labels><control id="{3}" classid="{4}" datafieldname="{3}" /></cell></row>' -f $cellId, $en, $he, $Field, $ClassId
}

function New-FormSectionXml {
    param([string]$EnglishLabel, [string]$HebrewLabel, [array]$Rows, [int]$Columns = 1)
    $sectionId = New-GuidText
    $en = ConvertTo-XmlText $EnglishLabel
    $he = ConvertTo-XmlText $HebrewLabel
    $rowsXml = ($Rows -join '')
    return '<section showlabel="true" showbar="true" IsUserDefined="1" id="{0}" columns="{4}"><labels><label description="{1}" languagecode="1033" /><label description="{2}" languagecode="1037" /></labels><rows>{3}</rows></section>' -f $sectionId, $en, $he, $rowsXml, $Columns
}

function New-SubgridRowXml {
    param([string]$ControlId, [string]$TargetEntity, [string]$RelationshipName, [string]$ViewId, [string]$EnglishLabel, [string]$HebrewLabel)
    $cellId = New-GuidText
    $uid = New-GuidText
    $en = ConvertTo-XmlText $EnglishLabel
    $he = ConvertTo-XmlText $HebrewLabel
    $p = "<ViewId>$ViewId</ViewId><IsUserView>false</IsUserView><RelationshipName>$RelationshipName</RelationshipName><TargetEntityType>$TargetEntity</TargetEntityType><AutoExpand>Fixed</AutoExpand><RecordsPerPage>8</RecordsPerPage><EnableQuickFind>false</EnableQuickFind><EnableJumpBar>false</EnableJumpBar><EnableViewPicker>false</EnableViewPicker>"
    return '<row><cell id="{0}" showlabel="true" rowspan="10" colspan="1" auto="false"><labels><label description="{1}" languagecode="1033" /><label description="{2}" languagecode="1037" /></labels><control id="{3}" classid="{4}" indicationOfSubgrid="true" uniqueid="{5}"><parameters>{6}</parameters></control></cell></row>' -f $cellId, $en, $he, $ControlId, $FormClass.Subgrid, $uid, $p
}

function Ensure-Form {
    param([string]$Entity, [string]$FormXml)
    $existing = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name&`$filter=objecttypecode eq '$Entity' and type eq 2 and name eq 'מידע'"
    if ($existing.value.Count -gt 0) { Write-Host "  form exists: $Entity"; return }
    Write-Host "  create form: $Entity"
    Invoke-Dv -Method Post -Uri "$base/systemforms" -Body @{ name = 'מידע'; type = 2; objecttypecode = $Entity; formxml = $FormXml } | Out-Null
}

function New-ViewLayoutXml {
    param([string]$PkField, [array]$Columns)
    $cells = ($Columns | ForEach-Object { "<cell name='$($_.Name)' width='$($_.Width)' />" }) -join ''
    return "<grid name='resultset' object='1' jump='alex_name' select='1' icon='1' preview='1'><row name='result' id='$PkField'>$cells</row></grid>"
}

function Ensure-View {
    param([string]$Entity, [string]$Name, [string]$FetchXml, [string]$LayoutXml, [bool]$IsDefault = $false)
    $nameEsc = $Name.Replace("'", "''")
    $existing = Invoke-Dv -Method Get -Uri "$base/savedqueries?`$select=savedqueryid,name&`$filter=returnedtypecode eq '$Entity' and querytype eq 0 and name eq '$nameEsc'"
    if ($existing.value.Count -gt 0) { Write-Host "  view exists: $Name"; return $existing.value[0].savedqueryid }
    Write-Host "  create view: $Name"
    $r = Invoke-Dv -Method Post -Uri "$base/savedqueries" -Body @{
        name = $Name; returnedtypecode = $Entity; querytype = 0
        fetchxml = $FetchXml; layoutxml = $LayoutXml; isdefault = $IsDefault; isquickfindquery = $false
    }
    $q = Invoke-Dv -Method Get -Uri "$base/savedqueries?`$select=savedqueryid&`$filter=returnedtypecode eq '$Entity' and querytype eq 0 and name eq '$nameEsc'"
    return $q.value[0].savedqueryid
}

function Publish-All {
    if ($SkipPublish) { Write-Host 'Skipping PublishAllXml.'; return }
    Write-Host 'Publishing customizations...'
    Invoke-Dv -Method Post -Uri "$base/PublishAllXml" -Body @{} | Out-Null
}

$envOptions = @(
    (New-Option 100000000 'Production' 'Production (ייצור)'),
    (New-Option 100000001 'Sandbox' 'Sandbox (בדיקות)')
)

# =========================================================================
# TERMINAL entity
# =========================================================================
Write-Host "`n== Terminal table =="
Ensure-Entity $terminalEntity `
    (New-Label 'PayPlus Terminal' 'מסוף PayPlus') `
    (New-Label 'PayPlus Terminals' 'מסופי PayPlus') `
    (New-Label 'A PayPlus clearing terminal: the financial and commercial context in which clearing is performed.' 'מסוף סליקה של PayPlus: ההקשר הפיננסי והמסחרי שבו מבוצעת הסליקה.') | Out-Null

# technical (synced from MyTerminals)
Add-AttributeIfMissing $terminalEntity 'alex_terminaluid' (New-StringAttribute 'alex_terminaluid' 'Terminal UID' 'מזהה מסוף' 'PayPlus terminal_uid. Managed by PayPlus; do not edit after sync.' 'המזהה terminal_uid של PayPlus. מנוהל על ידי PayPlus; אין לערוך לאחר סנכרון.' 100 'ApplicationRequired')
Add-AttributeIfMissing $terminalEntity 'alex_merchantnumber' (New-StringAttribute 'alex_merchantnumber' 'Merchant Number' 'מספר בית עסק' 'Merchant number returned by PayPlus MyTerminals.' 'מספר בית העסק שחוזר מ-PayPlus.' 100)
Add-AttributeIfMissing $terminalEntity 'alex_terminaltypeid' (New-IntegerAttribute 'alex_terminaltypeid' 'Terminal Type Id' 'קוד סוג מסוף' 'Numeric terminal type id returned by PayPlus.' 'קוד סוג המסוף המספרי שחוזר מ-PayPlus.' 0 2147483647)
Add-AttributeIfMissing $terminalEntity 'alex_rawjson' (New-MemoAttribute 'alex_rawjson' 'Raw JSON' 'JSON גולמי' 'Raw MyTerminals response item stored for diagnostics.' 'פריט התגובה הגולמי מ-MyTerminals לצורכי אבחון.' 1048576)
Add-AttributeIfMissing $terminalEntity 'alex_lastsyncon' (New-DateTimeAttribute 'alex_lastsyncon' 'Last Synced On' 'סונכרן לאחרונה' 'When this terminal was last refreshed from PayPlus.' 'מועד הסנכרון האחרון של המסוף מול PayPlus.')
# business
Add-AttributeIfMissing $terminalEntity 'alex_activitytype' (New-PicklistAttribute 'alex_activitytype' 'Activity Type' 'סוג פעילות' 'Business activity the terminal serves.' 'סוג הפעילות העסקית שהמסוף משרת.' @(
    (New-Option 100000000 'Website' 'אתר'),
    (New-Option 100000001 'Call Center' 'מוקד'),
    (New-Option 100000002 'Retail' 'קמעונאות'),
    (New-Option 100000003 'Donations' 'תרומות'),
    (New-Option 100000004 'Other' 'אחר')
))
Add-AttributeIfMissing $terminalEntity 'alex_primarycurrency' (New-PicklistAttribute 'alex_primarycurrency' 'Primary Currency' 'מטבע עיקרי' 'Primary currency of the terminal.' 'המטבע המרכזי של המסוף.' @(
    (New-Option 100000000 'ILS' 'ILS (שקל)'),
    (New-Option 100000001 'USD' 'USD (דולר)'),
    (New-Option 100000002 'EUR' 'EUR (אירו)'),
    (New-Option 100000003 'GBP' 'GBP (ליש"ט)')
))
Add-AttributeIfMissing $terminalEntity 'alex_legalentity' (New-StringAttribute 'alex_legalentity' 'Legal Entity' 'ישות משפטית' 'Legal entity that receives the settlements.' 'הישות המשפטית שאליה מזוכים התקבולים.' 200)
Add-AttributeIfMissing $terminalEntity 'alex_description' (New-MemoAttribute 'alex_description' 'Description' 'תיאור עסקי' 'When to use this terminal.' 'הסבר מתי יש לבחור במסוף.' 4000)
Add-AttributeIfMissing $terminalEntity 'alex_isdefault' (New-BooleanAttribute 'alex_isdefault' 'Is Default' 'מסוף ברירת מחדל' 'Whether this is the primary terminal for its environment.' 'האם זהו המסוף הראשי בסביבה.' $false)
Add-AttributeIfMissing $terminalEntity 'alex_isactive' (New-BooleanAttribute 'alex_isactive' 'Is Active' 'פעיל' 'Whether the terminal may be used.' 'האם מותר להשתמש במסוף.' $true)
Add-AttributeIfMissing $terminalEntity 'alex_environment' (New-PicklistAttribute 'alex_environment' 'Environment' 'סביבה' 'PayPlus environment for this terminal.' 'סביבת PayPlus של המסוף.' $envOptions 'ApplicationRequired')
# policy (manual, not returned by API)
Add-AttributeIfMissing $terminalEntity 'alex_tokenization_enabled' (New-BooleanAttribute 'alex_tokenization_enabled' 'Tokenization Enabled' 'טוקניזציה פעילה' 'Whether the terminal is permitted to create tokens.' 'האם המסוף מורשה ליצור טוקנים.' $false)
Add-AttributeIfMissing $terminalEntity 'alex_recurring_enabled' (New-BooleanAttribute 'alex_recurring_enabled' 'Recurring Enabled' 'חיובים מחזוריים פעילים' 'Whether the terminal may manage recurring payment mandates.' 'האם המסוף מורשה לנהל הוראות חיוב מחזוריות.' $false)
Add-AttributeIfMissing $terminalEntity 'alex_cvv_policy' (New-PicklistAttribute 'alex_cvv_policy' 'CVV Policy' 'מדיניות CVV' 'CVV requirement policy at the terminal level.' 'מדיניות דרישת CVV ברמת המסוף.' @(
    (New-Option 100000000 'Required' 'נדרש'),
    (New-Option 100000001 'Not Required' 'לא נדרש'),
    (New-Option 100000002 'Conditional' 'מותנה'),
    (New-Option 100000003 'Unknown' 'לא ידוע')
))
Add-AttributeIfMissing $terminalEntity 'alex_cvv_policy_source' (New-PicklistAttribute 'alex_cvv_policy_source' 'CVV Policy Source' 'מקור מדיניות CVV' 'Where the CVV policy was determined.' 'מהיכן נקבעה מדיניות ה-CVV.' @(
    (New-Option 100000000 'Credit Company' 'חברת אשראי'),
    (New-Option 100000001 'Terminal' 'מסוף'),
    (New-Option 100000002 'PayPlus' 'PayPlus'),
    (New-Option 100000003 'Manual Check' 'בדיקה ידנית')
))
Add-AttributeIfMissing $terminalEntity 'alex_cvv_required_recurring_init' (New-PicklistAttribute 'alex_cvv_required_recurring_init' 'CVV Required at Recurring Init' 'CVV נדרש באתחול מחזורי' 'Whether CVV is required when creating a new recurring mandate.' 'האם נדרש CVV בהקמת הרשאת חיוב מחזורית חדשה.' @(
    (New-Option 100000000 'Yes' 'כן'),
    (New-Option 100000001 'No' 'לא'),
    (New-Option 100000002 'Unknown' 'לא ידוע')
))
Add-AttributeIfMissing $terminalEntity 'alex_cvv_required_j5' (New-PicklistAttribute 'alex_cvv_required_j5' 'CVV Required for J5 Completion' 'CVV נדרש בהשלמת J5' 'Whether CVV is required when charging a previously approved (J5) transaction.' 'האם נדרש CVV בחיוב עסקה שאושרה קודם (J5).' @(
    (New-Option 100000000 'Yes' 'כן'),
    (New-Option 100000001 'No' 'לא'),
    (New-Option 100000002 'Unknown' 'לא ידוע')
))
Add-AttributeIfMissing $terminalEntity 'alex_threeds_policy' (New-PicklistAttribute 'alex_threeds_policy' '3D Secure Policy' 'מדיניות 3D Secure' '3D Secure policy at the terminal level.' 'מדיניות 3D Secure ברמת המסוף.' @(
    (New-Option 100000000 'Default' 'ברירת מחדל'),
    (New-Option 100000001 'On' 'פעיל'),
    (New-Option 100000002 'Off' 'לא פעיל'),
    (New-Option 100000003 'Conditional' 'מותנה')
))
Add-AttributeIfMissing $terminalEntity 'alex_settings_verified_on' (New-DateTimeAttribute 'alex_settings_verified_on' 'Settings Verified On' 'מועד אימות ההגדרות' 'When the policy settings were last verified with PayPlus.' 'מועד האימות האחרון של ההגדרות מול PayPlus.')

# =========================================================================
# PAYMENT PAGE entity
# =========================================================================
Write-Host "`n== Payment Page table =="
Ensure-Entity $pageEntity `
    (New-Label 'PayPlus Payment Page' 'עמוד תשלום PayPlus') `
    (New-Label 'PayPlus Payment Pages' 'עמודי תשלום PayPlus') `
    (New-Label 'A PayPlus payment page: a fixed configuration of the payment experience used to generate payment links.' 'עמוד תשלום של PayPlus: תצורה קבועה של חוויית התשלום המשמשת ליצירת קישורי תשלום.') | Out-Null

# technical (synced from ListPaymentPages)
Add-AttributeIfMissing $pageEntity 'alex_paymentpageuid' (New-StringAttribute 'alex_paymentpageuid' 'Payment Page UID' 'מזהה עמוד תשלום' 'PayPlus payment_page_uid. Managed by PayPlus; do not edit after sync.' 'המזהה payment_page_uid של PayPlus. מנוהל על ידי PayPlus; אין לערוך לאחר סנכרון.' 100 'ApplicationRequired')
Add-AttributeIfMissing $pageEntity 'alex_cashieruid' (New-StringAttribute 'alex_cashieruid' 'Cashier UID' 'מזהה קופה' 'Cashier uid returned by PayPlus for this page.' 'מזהה הקופה שחוזר מ-PayPlus עבור העמוד.' 100)
Add-AttributeIfMissing $pageEntity 'alex_cashiername' (New-StringAttribute 'alex_cashiername' 'Cashier Name' 'שם קופה' 'Cashier name returned by PayPlus.' 'שם הקופה שחוזר מ-PayPlus.' 200)
Add-AttributeIfMissing $pageEntity 'alex_chargemethod' (New-IntegerAttribute 'alex_chargemethod' 'Charge Method' 'סוג פעולה מספרי' 'Numeric charge_method configured on the page in PayPlus.' 'ערך charge_method המספרי שמוגדר בעמוד ב-PayPlus.' 0 2147483647)
Add-AttributeIfMissing $pageEntity 'alex_defaultcurrency' (New-StringAttribute 'alex_defaultcurrency' 'Default Currency' 'מטבע ברירת מחדל' 'default_currency_code returned by PayPlus.' 'קוד מטבע ברירת המחדל שחוזר מ-PayPlus.' 20)
Add-AttributeIfMissing $pageEntity 'alex_language' (New-StringAttribute 'alex_language' 'Language' 'שפה' 'Language configured on the page.' 'השפה שמוגדרת בעמוד.' 20)
Add-AttributeIfMissing $pageEntity 'alex_valid' (New-BooleanAttribute 'alex_valid' 'Valid In PayPlus' 'תקין ב-PayPlus' 'Whether PayPlus reports the page as valid.' 'האם PayPlus מדווח שהעמוד תקין.' $true)
Add-AttributeIfMissing $pageEntity 'alex_rawjson' (New-MemoAttribute 'alex_rawjson' 'Raw JSON' 'JSON גולמי' 'Raw ListPaymentPages response item stored for diagnostics.' 'פריט התגובה הגולמי מ-ListPaymentPages לצורכי אבחון.' 1048576)
Add-AttributeIfMissing $pageEntity 'alex_lastsyncon' (New-DateTimeAttribute 'alex_lastsyncon' 'Last Synced On' 'סונכרן לאחרונה' 'When this page was last refreshed from PayPlus.' 'מועד הסנכרון האחרון של העמוד מול PayPlus.')
# business
Add-AttributeIfMissing $pageEntity 'alex_purpose' (New-PicklistAttribute 'alex_purpose' 'Purpose' 'מטרת העמוד' 'Business purpose of the page.' 'המטרה העסקית של העמוד.' @(
    (New-Option 100000000 'Call Center' 'מוקד'),
    (New-Option 100000001 'Website' 'אתר'),
    (New-Option 100000002 'Donation' 'תרומה'),
    (New-Option 100000003 'Invoice' 'חשבונית'),
    (New-Option 100000004 'QR' 'QR'),
    (New-Option 100000005 'Subscription' 'מנוי'),
    (New-Option 100000006 'Card Update' 'עדכון כרטיס'),
    (New-Option 100000007 'Event' 'אירוע'),
    (New-Option 100000008 'Approval' 'אישור מסגרת'),
    (New-Option 100000009 'Brand' 'מותג'),
    (New-Option 100000010 'Business Customer' 'לקוח עסקי'),
    (New-Option 100000011 'Private Customer' 'לקוח פרטי')
))
Add-AttributeIfMissing $pageEntity 'alex_processtype' (New-PicklistAttribute 'alex_processtype' 'Process Type' 'סוג תהליך' 'Payment process the page performs.' 'סוג תהליך התשלום שהעמוד מבצע.' @(
    (New-Option 100000000 'Charge' 'חיוב'),
    (New-Option 100000001 'Approval' 'אישור'),
    (New-Option 100000002 'Check' 'בדיקה'),
    (New-Option 100000003 'Token Only' 'טוקן בלבד'),
    (New-Option 100000004 'Recurring' 'חיוב מחזורי')
))
Add-AttributeIfMissing $pageEntity 'alex_channel' (New-PicklistAttribute 'alex_channel' 'Channel' 'ערוץ עיקרי' 'Primary channel the page is used through.' 'הערוץ העיקרי שבו נעשה שימוש בעמוד.' @(
    (New-Option 100000000 'Website' 'אתר'),
    (New-Option 100000001 'Call Center' 'מוקד'),
    (New-Option 100000002 'WhatsApp' 'WhatsApp'),
    (New-Option 100000003 'Email' 'דואר אלקטרוני'),
    (New-Option 100000004 'QR' 'QR')
))
Add-AttributeIfMissing $pageEntity 'alex_audience' (New-PicklistAttribute 'alex_audience' 'Audience' 'קהל יעד' 'Target audience for the page.' 'קהל היעד של העמוד.' @(
    (New-Option 100000000 'New Customer' 'לקוח חדש'),
    (New-Option 100000001 'Existing Customer' 'לקוח קיים'),
    (New-Option 100000002 'Subscriber' 'מנוי'),
    (New-Option 100000003 'Business' 'עסקי'),
    (New-Option 100000004 'Donor' 'תורם'),
    (New-Option 100000005 'Private' 'פרטי')
))
Add-AttributeIfMissing $pageEntity 'alex_isdefault' (New-BooleanAttribute 'alex_isdefault' 'Is Default' 'עמוד ברירת מחדל' 'Whether this is the default page for its terminal and process type.' 'האם זהו עמוד ברירת המחדל של המסוף עבור סוג התהליך.' $false)
Add-AttributeIfMissing $pageEntity 'alex_selectionpriority' (New-IntegerAttribute 'alex_selectionpriority' 'Selection Priority' 'עדיפות בחירה' 'Priority order when several pages match.' 'סדר קדימות במקרה של מספר התאמות.' 0 100000)
Add-AttributeIfMissing $pageEntity 'alex_startdate' (New-DateTimeAttribute 'alex_startdate' 'Start Date' 'תאריך התחלה' 'Business validity start date.' 'תחילת תוקף עסקי.')
Add-AttributeIfMissing $pageEntity 'alex_enddate' (New-DateTimeAttribute 'alex_enddate' 'End Date' 'תאריך סיום' 'Business validity end date.' 'סיום תוקף עסקי.')
Add-AttributeIfMissing $pageEntity 'alex_isactive' (New-BooleanAttribute 'alex_isactive' 'Is Active' 'פעיל' 'Whether the page may be selected.' 'האם ניתן לבחור בעמוד.' $true)
Add-AttributeIfMissing $pageEntity 'alex_description' (New-MemoAttribute 'alex_description' 'Description' 'תיאור למשתמש' 'Short note describing when to use the page.' 'הסבר קצר מתי להשתמש בעמוד.' 4000)
Add-AttributeIfMissing $pageEntity 'alex_environment' (New-PicklistAttribute 'alex_environment' 'Environment' 'סביבה' 'PayPlus environment for this page.' 'סביבת PayPlus של העמוד.' $envOptions 'ApplicationRequired')
# policy / token
Add-AttributeIfMissing $pageEntity 'alex_tokenbehavior' (New-PicklistAttribute 'alex_tokenbehavior' 'Token Behavior' 'התנהגות טוקן' 'How the page handles tokenization.' 'כיצד העמוד מטפל בטוקניזציה.' @(
    (New-Option 100000000 'No Token' 'ללא טוקן'),
    (New-Option 100000001 'Optional' 'טוקן אופציונלי'),
    (New-Option 100000002 'Required' 'טוקן חובה'),
    (New-Option 100000003 'Token Only' 'טוקן בלבד')
))
Add-AttributeIfMissing $pageEntity 'alex_createtoken_default' (New-BooleanAttribute 'alex_createtoken_default' 'Create Token By Default' 'יצירת טוקן כברירת מחדל' 'Whether the page creates a token by default.' 'האם העמוד יוצר טוקן כברירת מחדל.' $false)
Add-AttributeIfMissing $pageEntity 'alex_for_card_update' (New-BooleanAttribute 'alex_for_card_update' 'For Card Update' 'מיועד לעדכון כרטיס' 'Whether the page is used to renew or replace a card.' 'האם העמוד מיועד לחידוש או החלפת כרטיס.' $false)
Add-AttributeIfMissing $pageEntity 'alex_for_subscription' (New-BooleanAttribute 'alex_for_subscription' 'For Subscription' 'מיועד להצטרפות למנוי' 'Whether the page is used to set up a recurring mandate.' 'האם העמוד מיועד להקמת הוראת חיוב.' $false)
Add-AttributeIfMissing $pageEntity 'alex_cvv_policy_displayed' (New-PicklistAttribute 'alex_cvv_policy_displayed' 'CVV Policy (Displayed)' 'מדיניות CVV מוצגת' 'Operational CVV value shown to administrators.' 'ערך CVV תפעולי המוצג למנהלי המערכת.' @(
    (New-Option 100000000 'Required' 'נדרש'),
    (New-Option 100000001 'Not Required' 'לא נדרש'),
    (New-Option 100000002 'Conditional' 'מותנה'),
    (New-Option 100000003 'Unknown' 'לא ידוע')
))
Add-AttributeIfMissing $pageEntity 'alex_cvv_inherit_terminal' (New-BooleanAttribute 'alex_cvv_inherit_terminal' 'Inherit CVV From Terminal' 'ירושת CVV מהמסוף' 'Whether the page uses the terminal CVV policy.' 'האם העמוד משתמש במדיניות ה-CVV של המסוף.' $true)
Add-AttributeIfMissing $pageEntity 'alex_threeds_policy' (New-PicklistAttribute 'alex_threeds_policy' '3D Secure Policy' 'מדיניות 3D Secure' '3D Secure policy at the page level.' 'מדיניות 3D Secure ברמת העמוד.' @(
    (New-Option 100000000 'Inherit' 'ירושה'),
    (New-Option 100000001 'On' 'פעיל'),
    (New-Option 100000002 'Off' 'לא פעיל'),
    (New-Option 100000003 'Conditional' 'מותנה')
))
Add-AttributeIfMissing $pageEntity 'alex_openamount' (New-BooleanAttribute 'alex_openamount' 'Open Amount' 'סכום פתוח' 'Whether the customer may enter the amount.' 'האם הלקוח רשאי להזין סכום.' $false)
Add-AttributeIfMissing $pageEntity 'alex_maxpayments' (New-IntegerAttribute 'alex_maxpayments' 'Max Payments' 'מספר תשלומים מרבי' 'Maximum number of installments.' 'מגבלת פריסת התשלומים.' 0 100000)
Add-AttributeIfMissing $pageEntity 'alex_identification_required' (New-BooleanAttribute 'alex_identification_required' 'Identification Required' 'שדה זיהוי נדרש' 'Whether the customer must enter an identification number.' 'האם הלקוח נדרש להזין מספר מזהה.' $false)

# =========================================================================
# Relationships
# =========================================================================
Write-Host "`n== Relationships =="
# terminal -> configuration / syncprofile / approvedby
Ensure-Lookup 'alex_payplusconfiguration_alex_payplus_terminal' 'alex_payplusconfiguration' $terminalEntity 'alex_configurationid' (New-Label 'Configuration' 'קונפיגורציה') (New-Label 'PayPlus configuration that scopes this terminal.' 'קונפיגורציית PayPlus שאליה משויך המסוף.')
Ensure-Lookup 'alex_payplussyncprofile_alex_payplus_terminal' 'alex_payplus_syncprofile' $terminalEntity 'alex_syncprofileid' (New-Label 'Sync Profile' 'פרופיל סנכרון') (New-Label 'Sync profile through which this terminal was refreshed.' 'פרופיל הסנכרון שדרכו רוענן המסוף.')
Ensure-Lookup 'alex_systemuser_alex_payplus_terminal_approvedby' 'systemuser' $terminalEntity 'alex_approvedby' (New-Label 'Approved By' 'אושר על ידי') (New-Label 'Administrator or financial owner who verified the terminal policy settings.' 'מנהל המערכת או הגורם הפיננסי שאישר את הגדרות המסוף.')
# page -> configuration / syncprofile / terminal (parent, required)
Ensure-Lookup 'alex_payplusconfiguration_alex_payplus_paymentpage' 'alex_payplusconfiguration' $pageEntity 'alex_configurationid' (New-Label 'Configuration' 'קונפיגורציה') (New-Label 'PayPlus configuration that scopes this payment page.' 'קונפיגורציית PayPlus שאליה משויך עמוד התשלום.')
Ensure-Lookup 'alex_payplussyncprofile_alex_payplus_paymentpage' 'alex_payplus_syncprofile' $pageEntity 'alex_syncprofileid' (New-Label 'Sync Profile' 'פרופיל סנכרון') (New-Label 'Sync profile through which this page was refreshed.' 'פרופיל הסנכרון שדרכו רוענן העמוד.')
Ensure-Lookup 'alex_payplus_terminal_alex_payplus_paymentpage' $terminalEntity $pageEntity 'alex_terminalid' (New-Label 'Terminal' 'מסוף') (New-Label 'Parent terminal that owns this payment page.' 'מסוף האב שאליו שייך עמוד התשלום.') 'ApplicationRequired'

# =========================================================================
# Alternate keys + option labels
# =========================================================================
Write-Host "`n== Alternate keys =="
Ensure-AlternateKey $terminalEntity 'alex_TerminalEnvironmentUidKey' (New-Label 'Environment and Terminal UID Key' 'מפתח סביבה ומזהה מסוף') @('alex_environment', 'alex_terminaluid')
Ensure-AlternateKey $pageEntity 'alex_PaymentPageEnvironmentUidKey' (New-Label 'Environment and Payment Page UID Key' 'מפתח סביבה ומזהה עמוד תשלום') @('alex_environment', 'alex_paymentpageuid')

Publish-All

Write-Host "`n== Option labels =="
Update-EnvOptionLabels $terminalEntity
Update-EnvOptionLabels $pageEntity

# =========================================================================
# Views
# =========================================================================
Write-Host "`n== Views =="
# Payment page views (need the active view id for the terminal subgrid)
$pagePk = 'alex_payplus_paymentpageid'
$pageColumns = @(
    @{ Name = 'alex_name'; Width = 200 },
    @{ Name = 'alex_purpose'; Width = 140 },
    @{ Name = 'alex_processtype'; Width = 120 },
    @{ Name = 'alex_channel'; Width = 120 },
    @{ Name = 'alex_terminalid'; Width = 180 },
    @{ Name = 'alex_environment'; Width = 110 },
    @{ Name = 'alex_isdefault'; Width = 110 },
    @{ Name = 'alex_isactive'; Width = 90 }
)
$pageLayout = New-ViewLayoutXml $pagePk $pageColumns
$pageAttrs = '<attribute name="alex_name" /><attribute name="alex_purpose" /><attribute name="alex_processtype" /><attribute name="alex_channel" /><attribute name="alex_terminalid" /><attribute name="alex_environment" /><attribute name="alex_isdefault" /><attribute name="alex_isactive" />'
$pageOrder = '<order attribute="alex_selectionpriority" descending="false" /><order attribute="alex_name" descending="false" />'
$pageActiveViewId = Ensure-View $pageEntity 'עמודי תשלום פעילים' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /><condition attribute="alex_isactive" operator="eq" value="1" /></filter></entity></fetch>' -f $pageEntity, $pageAttrs, $pageOrder) $pageLayout $true
Ensure-View $pageEntity 'כל עמודי התשלום' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter></entity></fetch>' -f $pageEntity, $pageAttrs, $pageOrder) $pageLayout | Out-Null

# Terminal views
$terminalPk = 'alex_payplus_terminalid'
$terminalColumns = @(
    @{ Name = 'alex_name'; Width = 200 },
    @{ Name = 'alex_activitytype'; Width = 140 },
    @{ Name = 'alex_primarycurrency'; Width = 110 },
    @{ Name = 'alex_legalentity'; Width = 160 },
    @{ Name = 'alex_environment'; Width = 110 },
    @{ Name = 'alex_isdefault'; Width = 120 },
    @{ Name = 'alex_isactive'; Width = 90 }
)
$terminalLayout = New-ViewLayoutXml $terminalPk $terminalColumns
$terminalAttrs = '<attribute name="alex_name" /><attribute name="alex_activitytype" /><attribute name="alex_primarycurrency" /><attribute name="alex_legalentity" /><attribute name="alex_environment" /><attribute name="alex_isdefault" /><attribute name="alex_isactive" />'
$terminalOrder = '<order attribute="alex_name" descending="false" />'
Ensure-View $terminalEntity 'מסופים פעילים' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /><condition attribute="alex_isactive" operator="eq" value="1" /></filter></entity></fetch>' -f $terminalEntity, $terminalAttrs, $terminalOrder) $terminalLayout $true | Out-Null
Ensure-View $terminalEntity 'כל המסופים' ('<fetch version="1.0" mapping="logical"><entity name="{0}">{1}{2}<filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter></entity></fetch>' -f $terminalEntity, $terminalAttrs, $terminalOrder) $terminalLayout | Out-Null

# =========================================================================
# Forms
# =========================================================================
Write-Host "`n== Forms =="
# Payment page form
$pageTech = New-FormSectionXml 'Technical (PayPlus)' 'טכני (PayPlus)' @(
    (New-FormCellXml 'alex_paymentpageuid' 'Payment Page UID' 'מזהה עמוד תשלום' $FormClass.String),
    (New-FormCellXml 'alex_terminalid' 'Terminal' 'מסוף' $FormClass.Lookup),
    (New-FormCellXml 'alex_cashieruid' 'Cashier UID' 'מזהה קופה' $FormClass.String),
    (New-FormCellXml 'alex_cashiername' 'Cashier Name' 'שם קופה' $FormClass.String),
    (New-FormCellXml 'alex_chargemethod' 'Charge Method' 'סוג פעולה מספרי' $FormClass.Integer),
    (New-FormCellXml 'alex_defaultcurrency' 'Default Currency' 'מטבע ברירת מחדל' $FormClass.String),
    (New-FormCellXml 'alex_language' 'Language' 'שפה' $FormClass.String),
    (New-FormCellXml 'alex_valid' 'Valid In PayPlus' 'תקין ב-PayPlus' $FormClass.Boolean),
    (New-FormCellXml 'alex_environment' 'Environment' 'סביבה' $FormClass.Picklist),
    (New-FormCellXml 'alex_configurationid' 'Configuration' 'קונפיגורציה' $FormClass.Lookup),
    (New-FormCellXml 'alex_syncprofileid' 'Sync Profile' 'פרופיל סנכרון' $FormClass.Lookup),
    (New-FormCellXml 'alex_lastsyncon' 'Last Synced On' 'סונכרן לאחרונה' $FormClass.DateTime)
)
$pageBusiness = New-FormSectionXml 'Business' 'עסקי' @(
    (New-FormCellXml 'alex_name' 'Name' 'שם' $FormClass.String),
    (New-FormCellXml 'alex_purpose' 'Purpose' 'מטרת העמוד' $FormClass.Picklist),
    (New-FormCellXml 'alex_processtype' 'Process Type' 'סוג תהליך' $FormClass.Picklist),
    (New-FormCellXml 'alex_channel' 'Channel' 'ערוץ עיקרי' $FormClass.Picklist),
    (New-FormCellXml 'alex_audience' 'Audience' 'קהל יעד' $FormClass.Picklist),
    (New-FormCellXml 'alex_isdefault' 'Is Default' 'עמוד ברירת מחדל' $FormClass.Boolean),
    (New-FormCellXml 'alex_selectionpriority' 'Selection Priority' 'עדיפות בחירה' $FormClass.Integer),
    (New-FormCellXml 'alex_startdate' 'Start Date' 'תאריך התחלה' $FormClass.DateTime),
    (New-FormCellXml 'alex_enddate' 'End Date' 'תאריך סיום' $FormClass.DateTime),
    (New-FormCellXml 'alex_isactive' 'Is Active' 'פעיל' $FormClass.Boolean),
    (New-FormCellXml 'alex_description' 'Description' 'תיאור למשתמש' $FormClass.Memo)
)
$pagePolicy = New-FormSectionXml 'Payment Policy' 'מדיניות תשלום' @(
    (New-FormCellXml 'alex_tokenbehavior' 'Token Behavior' 'התנהגות טוקן' $FormClass.Picklist),
    (New-FormCellXml 'alex_createtoken_default' 'Create Token By Default' 'יצירת טוקן כברירת מחדל' $FormClass.Boolean),
    (New-FormCellXml 'alex_for_card_update' 'For Card Update' 'מיועד לעדכון כרטיס' $FormClass.Boolean),
    (New-FormCellXml 'alex_for_subscription' 'For Subscription' 'מיועד להצטרפות למנוי' $FormClass.Boolean),
    (New-FormCellXml 'alex_cvv_policy_displayed' 'CVV Policy (Displayed)' 'מדיניות CVV מוצגת' $FormClass.Picklist),
    (New-FormCellXml 'alex_cvv_inherit_terminal' 'Inherit CVV From Terminal' 'ירושת CVV מהמסוף' $FormClass.Boolean),
    (New-FormCellXml 'alex_threeds_policy' '3D Secure Policy' 'מדיניות 3D Secure' $FormClass.Picklist),
    (New-FormCellXml 'alex_openamount' 'Open Amount' 'סכום פתוח' $FormClass.Boolean),
    (New-FormCellXml 'alex_maxpayments' 'Max Payments' 'מספר תשלומים מרבי' $FormClass.Integer),
    (New-FormCellXml 'alex_identification_required' 'Identification Required' 'שדה זיהוי נדרש' $FormClass.Boolean),
    (New-FormCellXml 'alex_rawjson' 'Raw JSON' 'JSON גולמי' $FormClass.Memo)
)
$pageTabId = New-GuidText
$pageFormXml = '<form><tabs><tab verticallayout="true" id="{0}" IsUserDefined="1"><labels><label description="Information" languagecode="1033" /><label description="מידע" languagecode="1037" /></labels><columns><column width="100%"><sections>{1}{2}{3}</sections></column></columns></tab></tabs></form>' -f $pageTabId, $pageBusiness, $pagePolicy, $pageTech
Ensure-Form $pageEntity $pageFormXml

# Terminal form (with payment-page subgrid)
$terminalTech = New-FormSectionXml 'Technical (PayPlus)' 'טכני (PayPlus)' @(
    (New-FormCellXml 'alex_terminaluid' 'Terminal UID' 'מזהה מסוף' $FormClass.String),
    (New-FormCellXml 'alex_merchantnumber' 'Merchant Number' 'מספר בית עסק' $FormClass.String),
    (New-FormCellXml 'alex_terminaltypeid' 'Terminal Type Id' 'קוד סוג מסוף' $FormClass.Integer),
    (New-FormCellXml 'alex_environment' 'Environment' 'סביבה' $FormClass.Picklist),
    (New-FormCellXml 'alex_configurationid' 'Configuration' 'קונפיגורציה' $FormClass.Lookup),
    (New-FormCellXml 'alex_syncprofileid' 'Sync Profile' 'פרופיל סנכרון' $FormClass.Lookup),
    (New-FormCellXml 'alex_lastsyncon' 'Last Synced On' 'סונכרן לאחרונה' $FormClass.DateTime),
    (New-FormCellXml 'alex_rawjson' 'Raw JSON' 'JSON גולמי' $FormClass.Memo)
)
$terminalBusiness = New-FormSectionXml 'Business' 'עסקי' @(
    (New-FormCellXml 'alex_name' 'Name' 'שם' $FormClass.String),
    (New-FormCellXml 'alex_activitytype' 'Activity Type' 'סוג פעילות' $FormClass.Picklist),
    (New-FormCellXml 'alex_primarycurrency' 'Primary Currency' 'מטבע עיקרי' $FormClass.Picklist),
    (New-FormCellXml 'alex_legalentity' 'Legal Entity' 'ישות משפטית' $FormClass.String),
    (New-FormCellXml 'alex_isdefault' 'Is Default' 'מסוף ברירת מחדל' $FormClass.Boolean),
    (New-FormCellXml 'alex_isactive' 'Is Active' 'פעיל' $FormClass.Boolean),
    (New-FormCellXml 'alex_description' 'Description' 'תיאור עסקי' $FormClass.Memo)
)
$terminalPolicy = New-FormSectionXml 'Clearing Policy' 'מדיניות סליקה' @(
    (New-FormCellXml 'alex_tokenization_enabled' 'Tokenization Enabled' 'טוקניזציה פעילה' $FormClass.Boolean),
    (New-FormCellXml 'alex_recurring_enabled' 'Recurring Enabled' 'חיובים מחזוריים פעילים' $FormClass.Boolean),
    (New-FormCellXml 'alex_cvv_policy' 'CVV Policy' 'מדיניות CVV' $FormClass.Picklist),
    (New-FormCellXml 'alex_cvv_policy_source' 'CVV Policy Source' 'מקור מדיניות CVV' $FormClass.Picklist),
    (New-FormCellXml 'alex_cvv_required_recurring_init' 'CVV Required at Recurring Init' 'CVV נדרש באתחול מחזורי' $FormClass.Picklist),
    (New-FormCellXml 'alex_cvv_required_j5' 'CVV Required for J5 Completion' 'CVV נדרש בהשלמת J5' $FormClass.Picklist),
    (New-FormCellXml 'alex_threeds_policy' '3D Secure Policy' 'מדיניות 3D Secure' $FormClass.Picklist),
    (New-FormCellXml 'alex_settings_verified_on' 'Settings Verified On' 'מועד אימות ההגדרות' $FormClass.DateTime),
    (New-FormCellXml 'alex_approvedby' 'Approved By' 'אושר על ידי' $FormClass.Lookup)
)
$pagesSubgridRow = New-SubgridRowXml 'Subgrid_pages' $pageEntity 'alex_payplus_terminal_alex_payplus_paymentpage' $pageActiveViewId 'Payment Pages' 'עמודי תשלום'
$terminalPages = New-FormSectionXml 'Payment Pages' 'עמודי תשלום' @($pagesSubgridRow)
$terminalTabId = New-GuidText
$terminalFormXml = '<form><tabs><tab verticallayout="true" id="{0}" IsUserDefined="1"><labels><label description="Information" languagecode="1033" /><label description="מידע" languagecode="1037" /></labels><columns><column width="100%"><sections>{1}{2}{3}{4}</sections></column></columns></tab></tabs></form>' -f $terminalTabId, $terminalBusiness, $terminalPolicy, $terminalPages, $terminalTech
Ensure-Form $terminalEntity $terminalFormXml

Publish-All
Write-Host "`nDone."
