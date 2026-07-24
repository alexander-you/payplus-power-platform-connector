# Removes the abandoned invoice-hosted PayPlus Billing Wizard tab/host field.
# Invoice PayPlus actions should be ribbon-driven, not embedded on the invoice form.

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$entityLogicalName = 'invoice'
$tabName = 'tab_payplus_billing'
$hostField = 'alex_payplusbillinghost'

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get Dataverse access token.' }

$headers = @{
    Authorization      = "Bearer $token"
    'OData-Version'    = '4.0'
    'OData-MaxVersion' = '4.0'
    Accept             = 'application/json'
    'Content-Type'     = 'application/json; charset=utf-8'
}
$base = "$org/api/data/v9.2"

function Get-ErrorContent {
    param([object]$ErrorRecord)
    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) { return $ErrorRecord.ErrorDetails.Message }
    $response = $ErrorRecord.Exception.Response
    if ($response -and $response.Content) { try { return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() } catch { } }
    return $ErrorRecord.Exception.Message
}

function Invoke-Dv {
    param(
        [ValidateSet('Get', 'Post', 'Patch', 'Delete')][string]$Method,
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

function Try-GetDv([string]$Uri) {
    try { return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers }
    catch { if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { return $null }; throw }
}

$forms = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq '$entityLogicalName' and type eq 2"
$summary = @()
foreach ($form in $forms.value) {
    [xml]$xml = $form.formxml
    $tabs = @($xml.SelectNodes("//tab[@name='$tabName']"))
    if ($tabs.Count -eq 0 -and $form.formxml -notlike "*$hostField*") {
        $summary += [pscustomobject]@{ Form = $form.name; RemovedTabs = 0; RemovedRows = 0; Updated = $false }
        continue
    }

    $controlIds = @()
    foreach ($tab in $tabs) {
        $controls = @($tab.SelectNodes(".//control[@uniqueid]"))
        foreach ($control in $controls) { $controlIds += [string]$control.uniqueid }
        $tab.ParentNode.RemoveChild($tab) | Out-Null
    }

    $rows = @($xml.SelectNodes("//row[.//control[@datafieldname='$hostField']]"))
    foreach ($row in $rows) {
        $controls = @($row.SelectNodes(".//control[@uniqueid]"))
        foreach ($control in $controls) { $controlIds += [string]$control.uniqueid }
        $row.ParentNode.RemoveChild($row) | Out-Null
    }

    foreach ($controlId in ($controlIds | Where-Object { $_ } | Select-Object -Unique)) {
        $desc = $xml.SelectSingleNode("//controlDescription[@forControl='$controlId']")
        if ($desc) { $desc.ParentNode.RemoveChild($desc) | Out-Null }
    }

    Invoke-Dv -Method Patch -Uri "$base/systemforms($($form.formid))" -Body @{ formxml = $xml.OuterXml } | Out-Null
    $summary += [pscustomObject]@{ Form = $form.name; RemovedTabs = $tabs.Count; RemovedRows = $rows.Count; Updated = $true }
}

Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = '<importexportxml><entities><entity>invoice</entity></entities></importexportxml>' } | Out-Null

$attributeDeleted = $false
$attr = Try-GetDv "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes(LogicalName='$hostField')?`$select=MetadataId,LogicalName"
if ($attr) {
    Invoke-Dv -Method Delete -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes(LogicalName='$hostField')" | Out-Null
    $attributeDeleted = $true
    Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = '<importexportxml><entities><entity>invoice</entity></entities></importexportxml>' } | Out-Null
}

[pscustomobject]@{ Entity = 'invoice'; RemovedTabName = $tabName; HostFieldDeleted = $attributeDeleted; Forms = $summary } | ConvertTo-Json -Depth 6