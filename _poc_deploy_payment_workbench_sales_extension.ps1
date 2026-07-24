# Deploy Payment Workbench V1 Sales-extension metadata.
# Scope: Sales extended solution only. Keeps invoice/invoicedetail dependencies out of the base PayPlus solution.

param(
    [string]$Org = 'https://demo-contact-center-en.crm4.dynamics.com',
    [string]$SolutionUniqueName = 'alex_d365_payplus_sales_extended_data_model',
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'

$receiptAllocationEntity = 'alex_payplusreceiptallocation'
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
        [ValidateSet('Get', 'Post', 'Patch')][string]$Method,
        [string]$Uri,
        [object]$Body = $null
    )
    $params = @{ Method = $Method; Uri = $Uri; Headers = $headers }
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 100 -Compress
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

function Test-EntityExists {
    param([string]$LogicalName)
    $entity = Try-GetDv "$base/EntityDefinitions(LogicalName='$LogicalName')?`$select=MetadataId,LogicalName"
    return ($null -ne $entity)
}

function New-Label {
    param([string]$English, [string]$Hebrew)
    return @{ LocalizedLabels = @(@{ Label = $English; LanguageCode = 1033 }, @{ Label = $Hebrew; LanguageCode = 1037 }) }
}

function New-RequiredLevel {
    param([string]$Value = 'None')
    return @{ Value = $Value; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
}

function Ensure-Lookup {
    param(
        [string]$SchemaName,
        [string]$ReferencedEntity,
        [string]$LookupSchema,
        [string]$EnglishLabel,
        [string]$HebrewLabel,
        [string]$EnglishDescription,
        [string]$HebrewDescription
    )

    if (-not (Test-EntityExists $receiptAllocationEntity)) { throw "Core table does not exist: $receiptAllocationEntity" }
    if (-not (Test-EntityExists $ReferencedEntity)) {
        Write-Warning "Skipping lookup $LookupSchema because target entity does not exist: $ReferencedEntity"
        return
    }

    $relationship = Try-GetDv "$base/RelationshipDefinitions(SchemaName='$SchemaName')?`$select=MetadataId,SchemaName"
    if ($relationship) { Write-Host "Relationship exists: $SchemaName"; return }

    Write-Host "Creating relationship: $SchemaName"
    $body = @{
        '@odata.type'        = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
        SchemaName           = $SchemaName
        ReferencedEntity     = $ReferencedEntity
        ReferencingEntity    = $receiptAllocationEntity
        CascadeConfiguration = @{ Assign = 'NoCascade'; Delete = 'RemoveLink'; Merge = 'NoCascade'; Reparent = 'NoCascade'; Share = 'NoCascade'; Unshare = 'NoCascade'; RollupView = 'NoCascade' }
        Lookup               = @{
            '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'
            SchemaName    = $LookupSchema
            DisplayName   = New-Label $EnglishLabel $HebrewLabel
            Description   = New-Label $EnglishDescription $HebrewDescription
            RequiredLevel = New-RequiredLevel 'None'
            Targets       = @($ReferencedEntity)
        }
    }
    Invoke-Dv -Method Post -Uri "$base/RelationshipDefinitions" -Body $body | Out-Null
}

function ConvertTo-XmlText {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Security.SecurityElement]::Escape($Value)
}

function New-GuidText { return ([guid]::NewGuid().ToString('B')).ToUpperInvariant() }

function New-FormCellXml {
    param([string]$Field, [string]$EnglishLabel, [string]$HebrewLabel, [string]$ClassId)
    return '<row><cell id="{0}" showlabel="true"><labels><label description="{1}" languagecode="1033" /><label description="{2}" languagecode="1037" /></labels><control id="{3}" classid="{4}" datafieldname="{3}" /></cell></row>' -f (New-GuidText), (ConvertTo-XmlText $EnglishLabel), (ConvertTo-XmlText $HebrewLabel), $Field, $ClassId
}

function Ensure-SalesLookupsVisibleOnAllocationForms {
    $lookupClass = '{270BD3DB-D9AF-4782-9025-509E298DEC0A}'
    $forms = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq '$receiptAllocationEntity' and type eq 2"
    foreach ($form in $forms.value) {
        $rows = @()
        if ($form.formxml -notlike '*datafieldname="alex_invoiceid"*' -and $form.formxml -notlike '*datafieldname=''alex_invoiceid''*') {
            $rows += New-FormCellXml 'alex_invoiceid' 'Invoice' 'חשבונית' $lookupClass
        }
        if ($form.formxml -notlike '*datafieldname="alex_invoicedetailid"*' -and $form.formxml -notlike '*datafieldname=''alex_invoicedetailid''*') {
            $rows += New-FormCellXml 'alex_invoicedetailid' 'Invoice Line' 'שורת חשבונית' $lookupClass
        }
        if ($rows.Count -eq 0) { Write-Host "Form already shows Sales allocation lookups: $($form.name)"; continue }

        $sectionXml = '<section name="sec_sales_allocation" showlabel="true" showbar="false" IsUserDefined="1" id="{0}"><labels><label description="Sales Allocation" languagecode="1033" /><label description="שיוך מכירה" languagecode="1037" /></labels><rows>{1}</rows></section>' -f (New-GuidText), ($rows -join '')
        $newFormXml = ([regex]'</sections>').Replace($form.formxml, "$sectionXml</sections>", 1)
        if ($newFormXml -eq $form.formxml) { Write-Warning "Could not find sections node on allocation form: $($form.name)"; continue }

        Write-Host "Updating allocation form: $($form.name)"
        Invoke-Dv -Method Patch -Uri "$base/systemforms($($form.formid))" -Body @{ formxml = $newFormXml } | Out-Null
    }
}

function Ensure-SalesLookupsVisibleOnAllocationViews {
    $views = Invoke-Dv -Method Get -Uri "$base/savedqueries?`$select=savedqueryid,name,fetchxml,layoutxml&`$filter=returnedtypecode eq '$receiptAllocationEntity' and querytype eq 0"
    foreach ($view in $views.value) {
        $fetchXml = $view.fetchxml
        $layoutXml = $view.layoutxml
        $changed = $false

        foreach ($field in @('alex_invoiceid', 'alex_invoicedetailid')) {
            if (($fetchXml -notlike ('*name="{0}"*' -f $field)) -and ($fetchXml -notlike ("*name='{0}'*" -f $field))) {
                $fetchXml = ([regex]'<order ').Replace($fetchXml, ('<attribute name="{0}" /><order ' -f $field), 1)
                $changed = $true
            }
            if (($layoutXml -notlike ('*name="{0}"*' -f $field)) -and ($layoutXml -notlike ("*name='{0}'*" -f $field))) {
                $layoutXml = ([regex]'</row>').Replace($layoutXml, ("<cell name='$field' width='180' /></row>"), 1)
                $changed = $true
            }
        }

        if (-not $changed) { Write-Host "View already shows Sales allocation lookups: $($view.name)"; continue }
        Write-Host "Updating allocation view: $($view.name)"
        Invoke-Dv -Method Patch -Uri "$base/savedqueries($($view.savedqueryid))" -Body @{ fetchxml = $fetchXml; layoutxml = $layoutXml } | Out-Null
    }
}

function Publish-Entities {
    if ($SkipPublish) { Write-Host 'Skipping publish by request.'; return }
    Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = "<importexportxml><entities><entity>$receiptAllocationEntity</entity></entities></importexportxml>" } | Out-Null
}

Ensure-Lookup 'alex_invoice_alex_payplusreceiptallocation' 'invoice' 'alex_invoiceid' 'Invoice' 'חשבונית' 'Dynamics 365 Sales invoice allocated by this Workbench allocation.' 'חשבונית Dynamics 365 Sales המשויכת על ידי שיוך Workbench זה.'
Ensure-Lookup 'alex_invoicedetail_alex_payplusreceiptallocation' 'invoicedetail' 'alex_invoicedetailid' 'Invoice Line' 'שורת חשבונית' 'Dynamics 365 Sales invoice line allocated by this Workbench allocation.' 'שורת חשבונית Dynamics 365 Sales המשויכת על ידי שיוך Workbench זה.'
Ensure-SalesLookupsVisibleOnAllocationForms
Ensure-SalesLookupsVisibleOnAllocationViews
Publish-Entities

[pscustomobject]@{
    Solution = $SolutionUniqueName
    Scope = 'Payment Workbench V1 Sales allocation lookups'
    ReceiptAllocationEntity = $receiptAllocationEntity
    InvoiceLookup = 'alex_invoiceid'
    InvoiceLineLookup = 'alex_invoicedetailid'
    Published = (-not $SkipPublish)
} | ConvertTo-Json -Depth 10