# Deploy PayPlus Document Ledger PCF onto invoice, contact and account main forms.
# Adds a host field + a dedicated "PayPlus Documents" tab hosting alex_PayPlus.DocumentLedger.
# Idempotent: re-running replaces the tab/controlDescription instead of duplicating.

param([switch]$ValidateOnly)

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus'
$hostField = 'alex_documentledgerhost'
$hostSchema = 'alex_DocumentLedgerHost'
$pcfName = 'alex_PayPlus.DocumentLedger'
$pcfClassId = '{4273EDBD-AC1D-40d3-9FB2-095C621B552D}'
$targets = @('invoice', 'contact', 'account')

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get Dataverse access token.' }

$headers = @{
    Authorization      = "Bearer $token"
    'OData-Version'    = '4.0'
    'OData-MaxVersion' = '4.0'
    Accept             = 'application/json'
    'Content-Type'     = 'application/json; charset=utf-8'
}
$solutionHeaders = $headers.Clone()
$solutionHeaders['MSCRM.SolutionUniqueName'] = $solution
$base = "$org/api/data/v9.2"

function Invoke-Dv {
    param([string]$Method, [string]$Uri, $Body = $null, [hashtable]$Headers = $headers)
    if ($null -eq $Body) { return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers }
    $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 100 -Compress }
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body ([Text.Encoding]::UTF8.GetBytes($json))
}

function New-GuidText { return '{' + ([guid]::NewGuid().ToString()).ToUpperInvariant() + '}' }

function Ensure-HostField([string]$entity) {
    try {
        Invoke-Dv -Method Get -Uri "$base/EntityDefinitions(LogicalName='$entity')/Attributes(LogicalName='$hostField')?`$select=LogicalName" | Out-Null
        Write-Host "  Host field exists on $entity"
        return
    }
    catch { Write-Host "  Creating host field on $entity" }

    $body = @{
        '@odata.type' = '#Microsoft.Dynamics.CRM.StringAttributeMetadata'
        SchemaName    = $hostSchema
        DisplayName   = @{ LocalizedLabels = @(
                @{ Label = 'Document Ledger Host'; LanguageCode = 1033 },
                @{ Label = 'מארח ריכוז מסמכים'; LanguageCode = 1037 }) }
        Description   = @{ LocalizedLabels = @(
                @{ Label = 'Host field for the PayPlus document ledger PCF control.'; LanguageCode = 1033 },
                @{ Label = 'שדה מארח לפקד ריכוז מסמכי PayPlus.'; LanguageCode = 1037 }) }
        RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
        MaxLength     = 100
        FormatName    = @{ Value = 'Text' }
    }
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$entity')/Attributes" -Body $body -Headers $solutionHeaders | Out-Null
}

function New-LedgerTabXml([string]$controlUniqueId) {
    $tabId = New-GuidText; $sectionId = New-GuidText; $cellId = New-GuidText
    return @"
<tab name="tab_payplus_ledger" verticallayout="true" id="$tabId" IsUserDefined="1" expanded="true" showlabel="true">
  <labels><label description="PayPlus Documents" languagecode="1033" /><label description="מסמכי PayPlus" languagecode="1037" /></labels>
  <columns><column width="100%"><sections>
    <section name="sec_payplus_ledger" showlabel="false" showbar="false" IsUserDefined="1" id="$sectionId" columns="1">
      <labels><label description="Documents" languagecode="1033" /><label description="מסמכים" languagecode="1037" /></labels>
      <rows><row>
        <cell id="$cellId" showlabel="false" rowspan="24" colspan="1" auto="false">
          <labels><label description="Documents" languagecode="1033" /><label description="מסמכים" languagecode="1037" /></labels>
          <control id="$hostField" uniqueid="$controlUniqueId" classid="$pcfClassId" datafieldname="$hostField" />
        </cell>
      </row></rows>
    </section>
  </sections></column></columns>
</tab>
"@
}

function New-ControlDescriptionXml([string]$controlUniqueId) {
    return @"
<controlDescription forControl="$controlUniqueId">
  <customControl name="$pcfName" formFactor="0"><parameters><hostValue type="SingleLine.Text">$hostField</hostValue></parameters></customControl>
  <customControl name="$pcfName" formFactor="1"><parameters><hostValue type="SingleLine.Text">$hostField</hostValue></parameters></customControl>
  <customControl name="$pcfName" formFactor="2"><parameters><hostValue type="SingleLine.Text">$hostField</hostValue></parameters></customControl>
</controlDescription>
"@
}

function Get-DefaultMainForm([string]$entity) {
    $forms = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name,isdefault,formactivationstate&`$filter=objecttypecode eq '$entity' and type eq 2"
    if ($forms.value.Count -eq 0) { throw "No main form found for $entity" }
    $active = $forms.value | Where-Object { $_.formactivationstate -eq 1 }
    if (-not $active) { $active = $forms.value }
    $def = $active | Where-Object { $_.isdefault -eq $true } | Select-Object -First 1
    if (-not $def) { $def = $active | Select-Object -First 1 }
    return $def
}

function Update-Form([string]$entity) {
    $form = Get-DefaultMainForm $entity
    Write-Host "  Target form: $($form.name) ($($form.formid))"
    $full = Invoke-Dv -Method Get -Uri "$base/systemforms($($form.formid))?`$select=formxml"
    [xml]$doc = $full.formxml

    # Remove any prior ledger tab (idempotent)
    $tabsNode = $doc.form.SelectSingleNode('tabs')
    if (-not $tabsNode) { throw "Form for $entity has no <tabs> node" }
    foreach ($t in @($tabsNode.SelectNodes("tab[@name='tab_payplus_ledger']"))) { [void]$tabsNode.RemoveChild($t) }

    # Remove any prior ledger controlDescription
    $cdNode = $doc.form.SelectSingleNode('controlDescriptions')
    if ($cdNode) {
        foreach ($cd in @($cdNode.SelectNodes('controlDescription'))) {
            $cc = $cd.SelectSingleNode("customControl[@name='$pcfName']")
            if ($cc) { [void]$cdNode.RemoveChild($cd) }
        }
    }

    $controlUniqueId = New-GuidText

    # Append new tab
    [xml]$tabDoc = New-LedgerTabXml $controlUniqueId
    [void]$tabsNode.AppendChild($doc.ImportNode($tabDoc.DocumentElement, $true))

    # Ensure controlDescriptions node exists (must follow <tabs>)
    if (-not $cdNode) {
        $cdNode = $doc.CreateElement('controlDescriptions')
        if ($tabsNode.NextSibling) { [void]$doc.form.InsertBefore($cdNode, $tabsNode.NextSibling) }
        else { [void]$doc.form.AppendChild($cdNode) }
    }
    [xml]$cdDoc = New-ControlDescriptionXml $controlUniqueId
    [void]$cdNode.AppendChild($doc.ImportNode($cdDoc.DocumentElement, $true))

    $newXml = $doc.OuterXml
    if ($ValidateOnly) {
        Write-Host "  [ValidateOnly] Prepared formxml ($($newXml.Length) chars) - not saved."
        return
    }

    Invoke-Dv -Method Patch -Uri "$base/systemforms($($form.formid))" -Body @{ formxml = $newXml } | Out-Null
    try {
        Invoke-Dv -Method Post -Uri "$base/AddSolutionComponent" -Body @{ ComponentType = 60; ComponentId = $form.formid; SolutionUniqueName = $solution; AddRequiredComponents = $false } | Out-Null
    }
    catch { Write-Warning "  AddSolutionComponent: $($_.Exception.Message)" }
    Write-Host "  Form updated."
}

foreach ($entity in $targets) {
    Write-Host "== $entity =="
    Ensure-HostField $entity
    Update-Form $entity
}

if (-not $ValidateOnly) {
    $entitiesXml = ($targets | ForEach-Object { "<entity>$_</entity>" }) -join ''
    Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = "<importexportxml><entities>$entitiesXml</entities></importexportxml>" } | Out-Null
    Write-Host 'Published.'
}

Write-Host 'DONE.'
