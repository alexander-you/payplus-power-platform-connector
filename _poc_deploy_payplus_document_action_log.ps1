# Deploy PayPlus Document Action Log table to Dataverse.

param(
    [string]$Org = 'https://demo-contact-center-en.crm4.dynamics.com',
    [string]$SolutionUniqueName = 'alex_d365_payplus'
)

$ErrorActionPreference = 'Stop'

$entityLogicalName = 'alex_payplusdocumentactionlog'
$entitySchemaName = 'alex_payplusdocumentactionlog'
$documentEntity = 'alex_payplusdocument'

$token = (az account get-access-token --resource $Org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get access token.' }

$headers = @{
    Authorization              = "Bearer $token"
    'OData-Version'            = '4.0'
    'OData-MaxVersion'         = '4.0'
    Accept                     = 'application/json'
    'Content-Type'             = 'application/json; charset=utf-8'
    'MSCRM.SolutionUniqueName' = $SolutionUniqueName
}
$base = "$Org/api/data/v9.2"

function Get-ErrorContent {
    param([object]$ErrorRecord)
    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) { return $ErrorRecord.ErrorDetails.Message }
    $response = $ErrorRecord.Exception.Response
    if ($response -and $response.Content) { try { return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() } catch { } }
    return $ErrorRecord.Exception.Message
}

function Invoke-Dv {
    param(
        [ValidateSet('Get', 'Post', 'Patch', 'Put')]
        [string]$Method,
        [string]$Uri,
        [object]$Body = $null
    )
    $params = @{ Method = $Method; Uri = $Uri; Headers = $headers }
    if ($null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 100 -Compress }
        $params.Body = [Text.Encoding]::UTF8.GetBytes($json)
    }
    try { return Invoke-RestMethod @params }
    catch { throw "Dataverse $Method failed: $Uri`n$(Get-ErrorContent $_)" }
}

function Try-GetDv {
    param([string]$Uri)
    try { return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers }
    catch { if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { return $null }; throw }
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

function Test-EntityExists {
    param([string]$LogicalName)
    return $null -ne (Try-GetDv "$base/EntityDefinitions(LogicalName='$LogicalName')?`$select=MetadataId")
}

function Test-AttributeExists {
    param([string]$LogicalName)
    return $null -ne (Try-GetDv "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes(LogicalName='$LogicalName')?`$select=MetadataId")
}

function Add-AttributeIfMissing {
    param([string]$LogicalName, [hashtable]$Metadata)
    if (Test-AttributeExists $LogicalName) { Write-Host "Attribute exists: $LogicalName"; return }
    Write-Host "Creating attribute: $LogicalName"
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes" -Body $Metadata | Out-Null
}

function New-StringAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [int]$MaxLength = 100, [string]$FormatName = 'Text')
    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = New-RequiredLevel 'None'
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

function New-PicklistAttribute {
    param([string]$SchemaName, [string]$EnglishLabel, [string]$HebrewLabel, [string]$EnglishDescription, [string]$HebrewDescription, [array]$Options)
    return @{
        '@odata.type' = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
        SchemaName    = $SchemaName
        DisplayName   = New-Label $EnglishLabel $HebrewLabel
        Description   = New-Label $EnglishDescription $HebrewDescription
        RequiredLevel = New-RequiredLevel 'None'
        OptionSet     = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'; IsGlobal = $false; OptionSetType = 'Picklist'; Options = $Options }
    }
}

function Ensure-Entity {
    if (Test-EntityExists $entityLogicalName) { Write-Host "Entity exists: $entityLogicalName"; return }
    Write-Host "Creating entity: $entityLogicalName"
    $body = @{
        '@odata.type'         = 'Microsoft.Dynamics.CRM.EntityMetadata'
        SchemaName            = $entitySchemaName
        DisplayName           = New-Label 'PayPlus Document Action Log' 'יומן פעולות מסמך PayPlus'
        DisplayCollectionName = New-Label 'PayPlus Document Action Logs' 'יומני פעולות מסמכי PayPlus'
        Description           = New-Label 'Audit log of requested and processed PayPlus document actions.' 'יומן ביקורת של פעולות שהתבקשו ועובדו עבור מסמכי PayPlus.'
        OwnershipType         = 'UserOwned'
        HasActivities         = $false
        HasNotes              = $true
        IsActivity            = $false
        Attributes            = @(@{
            '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
            SchemaName    = 'alex_name'
            DisplayName   = New-Label 'Name' 'שם'
            Description   = New-Label 'Action log display name.' 'שם תצוגה של יומן הפעולה.'
            RequiredLevel = New-RequiredLevel 'ApplicationRequired'
            MaxLength     = 300
            FormatName    = @{ Value = 'Text' }
            IsPrimaryName = $true
        })
    }
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions" -Body $body | Out-Null
}

function Ensure-DocumentLookup {
    $schemaName = 'alex_payplusdocument_alex_payplusdocumentactionlog'
    if (Try-GetDv "$base/RelationshipDefinitions(SchemaName='$schemaName')?`$select=MetadataId") { Write-Host "Relationship exists: $schemaName"; return }
    Write-Host "Creating relationship: $schemaName"
    $body = @{
        '@odata.type'        = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
        SchemaName           = $schemaName
        ReferencedEntity     = $documentEntity
        ReferencingEntity    = $entityLogicalName
        CascadeConfiguration = @{ Assign='NoCascade'; Delete='Cascade'; Merge='NoCascade'; Reparent='NoCascade'; Share='NoCascade'; Unshare='NoCascade'; RollupView='NoCascade' }
        Lookup               = @{
            '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'
            SchemaName    = 'alex_payplusdocumentid'
            DisplayName   = New-Label 'PayPlus Document' 'מסמך PayPlus'
            Description   = New-Label 'PayPlus document related to this action log row.' 'מסמך PayPlus המקושר לשורת יומן פעולה זו.'
            RequiredLevel = New-RequiredLevel 'ApplicationRequired'
            Targets       = @($documentEntity)
        }
    }
    Invoke-Dv -Method Post -Uri "$base/RelationshipDefinitions" -Body $body | Out-Null
}

function Ensure-Attributes {
    Add-AttributeIfMissing 'alex_action' (New-PicklistAttribute 'alex_action' 'Action' 'פעולה' 'Requested document action.' 'פעולת המסמך שהתבקשה.' @((New-Option 100000000 'Send document' 'שליחת מסמך'), (New-Option 100000001 'Cancel document' 'ביטול מסמך'), (New-Option 100000002 'Close document' 'סגירת מסמך')))
    Add-AttributeIfMissing 'alex_channel' (New-PicklistAttribute 'alex_channel' 'Channel' 'ערוץ' 'Requested delivery channel.' 'ערוץ ההפצה שהתבקש.' @((New-Option 100000000 'Email' 'דוא"ל'), (New-Option 100000001 'SMS' 'SMS'), (New-Option 100000002 'WhatsApp' 'WhatsApp')))
    Add-AttributeIfMissing 'alex_linktype' (New-PicklistAttribute 'alex_linktype' 'Link Type' 'סוג קישור' 'Document link type selected for this action.' 'סוג קישור המסמך שנבחר לפעולה זו.' @((New-Option 100000000 'Original' 'מקור'), (New-Option 100000001 'Copy' 'עותק')))
    Add-AttributeIfMissing 'alex_status' (New-PicklistAttribute 'alex_status' 'Status' 'סטטוס' 'Processing status of this action log row.' 'סטטוס עיבוד של שורת יומן פעולה זו.' @((New-Option 100000000 'Pending' 'ממתין'), (New-Option 100000001 'Composed' 'נוצר Compose'), (New-Option 100000002 'Failed' 'נכשל'), (New-Option 100000003 'Completed' 'הושלם')))
    Add-AttributeIfMissing 'alex_requestedon' (New-DateTimeAttribute 'alex_requestedon' 'Requested On' 'התבקש בתאריך' 'Date and time the action was requested.' 'תאריך ושעה שבהם הפעולה התבקשה.')
    Add-AttributeIfMissing 'alex_requestedby' (New-StringAttribute 'alex_requestedby' 'Requested By' 'התבקש על ידי' 'User that requested the action.' 'המשתמש שביקש את הפעולה.' 300)
    Add-AttributeIfMissing 'alex_resolvedlink' (New-StringAttribute 'alex_resolvedlink' 'Resolved Link' 'קישור שנבחר' 'Resolved document link for the action.' 'קישור המסמך שנבחר עבור הפעולה.' 2000 'Url')
    Add-AttributeIfMissing 'alex_payloadjson' (New-MemoAttribute 'alex_payloadjson' 'Payload JSON' 'JSON פעולה' 'Composed action payload.' 'Payload הפעולה שנוצר ב-Compose.' 1048576)
    Add-AttributeIfMissing 'alex_message' (New-MemoAttribute 'alex_message' 'Message' 'הודעה' 'Action processing message.' 'הודעת עיבוד הפעולה.' 4000)
}

function Publish-Entity {
    Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = "<importexportxml><entities><entity>$entityLogicalName</entity></entities></importexportxml>" } | Out-Null
}

Ensure-Entity
Ensure-DocumentLookup
Ensure-Attributes
Publish-Entity

$entity = Invoke-Dv -Method Get -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')?`$select=EntitySetName"
[pscustomobject]@{ Entity = $entityLogicalName; EntitySet = $entity.EntitySetName; Solution = $SolutionUniqueName } | ConvertTo-Json -Depth 5