# Deploy Dynamics 365 Sales extension relationships for PayPlus documents.
# Adds Sales-table lookups to the core alex_payplusdocument table without moving
# the core table out of the base PayPlus solution.

param(
    [string]$Org = 'https://demo-contact-center-en.crm4.dynamics.com',
    [string]$SolutionUniqueName = 'alex_d365_payplus_sales_extended_data_model',
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'

$documentEntity = 'alex_payplusdocument'
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
        [ValidateSet('Get', 'Post', 'Patch')]
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
        $json = $Body | ConvertTo-Json -Depth 100 -Compress
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

function ConvertTo-XmlText {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Security.SecurityElement]::Escape($Value)
}

function New-GuidText {
    return ([guid]::NewGuid().ToString('B')).ToUpperInvariant()
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

function Ensure-SalesLookupsVisibleOnForms {
    $classes = @{
        Lookup = '{270BD3DB-D9AF-4782-9025-509E298DEC0A}'
        Memo   = '{E0DECE4B-6FC8-4a8f-A065-082708572369}'
    }

    $forms = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq '$documentEntity' and type eq 2"
    foreach ($form in $forms.value) {
        $rows = @()
        if ($form.formxml -notlike '*datafieldname="alex_quoteid"*' -and $form.formxml -notlike '*datafieldname=''alex_quoteid''*') {
            $rows += (New-FormCellXml 'alex_quoteid' 'Quote' 'הצעת מחיר' $classes.Lookup)
        }
        if ($form.formxml -notlike '*datafieldname="alex_salesorderid"*' -and $form.formxml -notlike '*datafieldname=''alex_salesorderid''*') {
            $rows += (New-FormCellXml 'alex_salesorderid' 'Sales Order' 'הזמנה' $classes.Lookup)
        }
        if ($form.formxml -notlike '*datafieldname="alex_moreinfo"*' -and $form.formxml -notlike '*datafieldname=''alex_moreinfo''*') {
            $rows += (New-FormCellXml 'alex_moreinfo' 'More Info' 'מידע נוסף' $classes.Memo)
        }
        if ($rows.Count -eq 0) {
            Write-Host "Form already shows sales lookups/more info: $($form.name)"
            continue
        }

        $sectionId = New-GuidText
        $sectionXml = '<section showlabel="true" showbar="false" IsUserDefined="1" id="{0}"><labels><label description="Sales Context" languagecode="1033" /><label description="הקשר מכירה" languagecode="1037" /></labels><rows>{1}</rows></section>' -f $sectionId, ($rows -join '')
        $newFormXml = ([regex]'</sections>').Replace($form.formxml, "$sectionXml</sections>", 1)
        if ($newFormXml -eq $form.formxml) {
            Write-Warning "Could not find a sections node on form: $($form.name)"
            continue
        }

        Write-Host "Updating form: $($form.name)"
        Invoke-Dv -Method Patch -Uri "$base/systemforms($($form.formid))" -Body @{ formxml = $newFormXml } | Out-Null
    }
}

function Ensure-SalesLookupsVisibleOnViews {
    $targetViewNames = @(
        'מסמכי PayPlus פעילים',
        'מסמכי PayPlus לפי מקור',
        'My PayPlus Documents',
        'Active PayPlus Documents'
    )

    $views = Invoke-Dv -Method Get -Uri "$base/savedqueries?`$select=savedqueryid,name,fetchxml,layoutxml&`$filter=returnedtypecode eq '$documentEntity' and querytype eq 0"
    foreach ($view in $views.value) {
        if ($targetViewNames -notcontains $view.name) { continue }

        $fetchXml = $view.fetchxml
        $layoutXml = $view.layoutxml
        $changed = $false

        foreach ($field in @('alex_quoteid', 'alex_salesorderid', 'alex_moreinfo')) {
            if (($fetchXml -notlike ('*name="{0}"*' -f $field)) -and ($fetchXml -notlike ("*name='{0}'*" -f $field))) {
                $fetchXml = ([regex]'<order ').Replace($fetchXml, ('<attribute name="{0}" /><order ' -f $field), 1)
                $changed = $true
            }
        }

        if ($layoutXml -notlike '*name="alex_quoteid"*' -and $layoutXml -notlike "*name='alex_quoteid'*") {
            $layoutXml = ([regex]'</row>').Replace($layoutXml, "<cell name='alex_quoteid' width='180' /></row>", 1)
            $changed = $true
        }
        if ($layoutXml -notlike '*name="alex_salesorderid"*' -and $layoutXml -notlike "*name='alex_salesorderid'*") {
            $layoutXml = ([regex]'</row>').Replace($layoutXml, "<cell name='alex_salesorderid' width='180' /></row>", 1)
            $changed = $true
        }
        if ($layoutXml -notlike '*name="alex_moreinfo"*' -and $layoutXml -notlike "*name='alex_moreinfo'*") {
            $layoutXml = ([regex]'</row>').Replace($layoutXml, "<cell name='alex_moreinfo' width='220' /></row>", 1)
            $changed = $true
        }

        if (-not $changed) {
            Write-Host "View already shows sales lookups/more info: $($view.name)"
            continue
        }

        Write-Host "Updating view: $($view.name)"
        Invoke-Dv -Method Patch -Uri "$base/savedqueries($($view.savedqueryid))" -Body @{ fetchxml = $fetchXml; layoutxml = $layoutXml } | Out-Null
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
        [string]$HebrewDescription
    )

    if (-not (Test-EntityExists $documentEntity)) {
        throw "Core table does not exist: $documentEntity"
    }
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
        ReferencingEntity    = $documentEntity
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
            RequiredLevel = New-RequiredLevel 'None'
            Targets       = @($ReferencedEntity)
        }
    }
    Invoke-Dv -Method Post -Uri "$base/RelationshipDefinitions" -Body $body | Out-Null
}

function Publish-All {
    if ($SkipPublish) {
        Write-Host 'Skipping PublishAllXml by request.'
        return
    }

    Write-Host 'Publishing customizations...'
    Invoke-Dv -Method Post -Uri "$base/PublishAllXml" -Body @{} | Out-Null
}

Ensure-Lookup 'alex_quote_alex_payplusdocument' 'quote' 'alex_quoteid' 'Quote' 'הצעת מחיר' 'Dynamics 365 Sales quote related to this PayPlus document.' 'הצעת מחיר ב-Dynamics 365 Sales המקושרת למסמך PayPlus זה.'
Ensure-Lookup 'alex_salesorder_alex_payplusdocument' 'salesorder' 'alex_salesorderid' 'Sales Order' 'הזמנה' 'Dynamics 365 Sales order related to this PayPlus document.' 'הזמנה ב-Dynamics 365 Sales המקושרת למסמך PayPlus זה.'
Ensure-Lookup 'alex_invoice_alex_payplusdocument' 'invoice' 'alex_invoiceid' 'Invoice' 'חשבונית' 'Dynamics 365 Sales invoice related to this PayPlus document.' 'חשבונית ב-Dynamics 365 Sales המקושרת למסמך PayPlus זה.'
Ensure-SalesLookupsVisibleOnForms
Ensure-SalesLookupsVisibleOnViews
Publish-All

Write-Host "Done. Sales extension relationship deployed. Solution=$SolutionUniqueName"