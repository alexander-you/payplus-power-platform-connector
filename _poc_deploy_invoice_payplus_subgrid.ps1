# Add PayPlus Documents subgrid to Dynamics invoice main forms.

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus_sales_extended_data_model'
$token = az account get-access-token --resource $org --query accessToken -o tsv
if (-not $token) { throw 'Failed to get Dataverse token.' }

$headers = @{
    Authorization = "Bearer $token"
    'OData-Version' = '4.0'
    'OData-MaxVersion' = '4.0'
    Accept = 'application/json'
    'Content-Type' = 'application/json; charset=utf-8'
}
$base = "$org/api/data/v9.2"

function Invoke-Dv {
    param([string]$Method, [string]$Uri, [object]$Body = $null)
    if ($null -eq $Body) { return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers }
    $json = $Body | ConvertTo-Json -Depth 30 -Compress
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($json))
}

function New-GuidText { return ([guid]::NewGuid().ToString('B')).ToUpperInvariant() }
function Escape-XmlAttribute { param([AllowNull()][string]$Value) if ($null -eq $Value) { return '' } return [System.Security.SecurityElement]::Escape($Value) }

function New-SubgridRowXml {
    param([string]$ControlId, [string]$TargetEntity, [string]$RelationshipName, [string]$ViewId, [string]$EnglishLabel, [string]$HebrewLabel)
    $cellId = New-GuidText
    $uniqueId = New-GuidText
    $en = Escape-XmlAttribute $EnglishLabel
    $he = Escape-XmlAttribute $HebrewLabel
    $parameters = "<ViewId>{$ViewId}</ViewId><IsUserView>false</IsUserView><RelationshipName>$RelationshipName</RelationshipName><TargetEntityType>$TargetEntity</TargetEntityType><AutoExpand>Fixed</AutoExpand><RecordsPerPage>8</RecordsPerPage><EnableQuickFind>false</EnableQuickFind><EnableJumpBar>false</EnableJumpBar><EnableViewPicker>false</EnableViewPicker>"
    return '<row><cell id="{0}" showlabel="true" rowspan="10" colspan="1" auto="false"><labels><label description="{1}" languagecode="1033" /><label description="{2}" languagecode="1037" /></labels><control id="{3}" classid="{4}" indicationOfSubgrid="true" uniqueid="{5}"><parameters>{6}</parameters></control></cell></row>' -f $cellId, $en, $he, $ControlId, '{E7A81278-8635-4D9E-8D4D-59480B391C5B}', $uniqueId, $parameters
}

function New-SectionXml {
    param([string]$Name, [string]$EnglishLabel, [string]$HebrewLabel, [string]$Rows)
    return '<section name="{0}" showlabel="true" showbar="false" IsUserDefined="1" id="{1}"><labels><label description="{2}" languagecode="1033" /><label description="{3}" languagecode="1037" /></labels><rows>{4}</rows></section>' -f $Name, (New-GuidText), (Escape-XmlAttribute $EnglishLabel), (Escape-XmlAttribute $HebrewLabel), $Rows
}

function New-TabXml {
    param([string]$SectionXml)
    return '<tab name="tab_payplus_documents" verticallayout="true" id="{0}" IsUserDefined="1"><labels><label description="PayPlus Documents" languagecode="1033" /><label description="מסמכי PayPlus" languagecode="1037" /></labels><columns><column width="100%"><sections>{1}</sections></column></columns></tab>' -f (New-GuidText), $SectionXml
}

$view = (Invoke-Dv Get "$base/savedqueries?`$select=savedqueryid,name&`$filter=returnedtypecode eq 'alex_payplusdocument' and name eq 'Active PayPlus Documents'&`$top=1").value | Select-Object -First 1
if (-not $view) {
    $view = (Invoke-Dv Get "$base/savedqueries?`$select=savedqueryid,name&`$filter=returnedtypecode eq 'alex_payplusdocument'&`$top=1").value | Select-Object -First 1
}
if (-not $view) { throw 'Could not find PayPlus Document view.' }

$forms = (Invoke-Dv Get "$base/systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq 'invoice' and type eq 2&`$top=20").value
$updated = @()
foreach ($form in @($forms)) {
    if ($form.formxml -match 'tab_payplus_documents' -or $form.formxml -match 'alex_invoice_alex_payplusdocument') { continue }
    [xml]$xml = $form.formxml
    $tabs = $xml.SelectSingleNode('//tabs')
    if (-not $tabs) { continue }
    $row = New-SubgridRowXml 'subgrid_payplusdocuments' 'alex_payplusdocument' 'alex_invoice_alex_payplusdocument' $view.savedqueryid 'PayPlus documents and receipts' 'מסמכי PayPlus וקבלות'
    $section = New-SectionXml 'sec_payplus_documents' 'PayPlus documents and receipts' 'מסמכי PayPlus וקבלות' $row
    $tab = New-TabXml $section
    $fragment = $xml.CreateDocumentFragment()
    $fragment.InnerXml = $tab
    $tabs.AppendChild($fragment.FirstChild) | Out-Null
    Invoke-Dv Patch "$base/systemforms($($form.formid))" @{ formxml = $xml.OuterXml } | Out-Null
    $updated += [pscustomobject]@{ FormId = $form.formid; Name = $form.name }
}

Invoke-Dv Post "$base/PublishXml" @{ ParameterXml = '<importexportxml><entities><entity>invoice</entity><entity>alex_payplusdocument</entity></entities></importexportxml>' } | Out-Null

[pscustomobject]@{
    ViewId = $view.savedqueryid
    ViewName = $view.name
    UpdatedForms = $updated
} | ConvertTo-Json -Depth 5