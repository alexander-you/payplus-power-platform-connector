# Deploy PayPlus Billing Wizard tab on invoice forms in the Sales extension solution.

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus_sales_extended_data_model'
$entityLogicalName = 'invoice'
$hostField = 'alex_payplusbillinghost'
$hostSchema = 'alex_PayPlusBillingHost'
$pcfName = 'alex_PayPlus.BillingWizard'

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

function Get-ErrorContent {
    param([object]$ErrorRecord)
    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) { return $ErrorRecord.ErrorDetails.Message }
    $response = $ErrorRecord.Exception.Response
    if ($response -and $response.Content) { try { return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() } catch { } }
    return $ErrorRecord.Exception.Message
}

function Invoke-Dv {
    param(
        [ValidateSet('Get', 'Post', 'Patch')][string]$Method,
        [string]$Uri,
        [object]$Body = $null,
        [hashtable]$Headers = $headers
    )
    $params = @{ Method = $Method; Uri = $Uri; Headers = $Headers }
    if ($null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 100 -Compress }
        $params.Body = [Text.Encoding]::UTF8.GetBytes($json)
    }
    try { return Invoke-RestMethod @params }
    catch { throw "Dataverse $Method failed: $Uri`n$(Get-ErrorContent $_)" }
}

function New-GuidText { return '{' + ([guid]::NewGuid().ToString()).ToUpperInvariant() + '}' }
function Escape-XmlAttribute([string]$Value) { if ($null -eq $Value) { return '' }; return [Security.SecurityElement]::Escape($Value) }

function Ensure-HostField {
    try {
        Invoke-Dv -Method Get -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes(LogicalName='$hostField')?`$select=LogicalName" | Out-Null
        Write-Host "Host field exists: $hostField"
        return
    }
    catch { Write-Host "Creating invoice host field: $hostField" }

    $body = @{
        '@odata.type' = '#Microsoft.Dynamics.CRM.StringAttributeMetadata'
        SchemaName    = $hostSchema
        DisplayName   = @{ LocalizedLabels = @(@{ Label = 'PayPlus Billing Host'; LanguageCode = 1033 }, @{ Label = 'מארח יצירה ב-PayPlus'; LanguageCode = 1037 }) }
        Description   = @{ LocalizedLabels = @(@{ Label = 'Host field for the PayPlus Billing Wizard PCF on invoice forms.'; LanguageCode = 1033 }, @{ Label = 'שדה מארח לפקד יצירה ב-PayPlus בטופס חשבונית.'; LanguageCode = 1037 }) }
        RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
        MaxLength     = 100
        FormatName    = @{ Value = 'Text' }
    }
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes" -Body $body -Headers $solutionHeaders | Out-Null
}

function New-BillingTabXml([xml]$Document) {
    $tabId = New-GuidText
    $sectionId = New-GuidText
    $cellId = New-GuidText
    $controlUniqueId = New-GuidText
    $fragment = $Document.CreateDocumentFragment()
    $fragment.InnerXml = @"
<tab name="tab_payplus_billing" verticallayout="true" id="$tabId" IsUserDefined="1" expanded="true" showlabel="true">
  <labels>
    <label description="PayPlus" languagecode="1033" />
    <label description="PayPlus" languagecode="1037" />
  </labels>
  <columns>
    <column width="100%">
      <sections>
        <section name="sec_payplus_billing_wizard" showlabel="false" showbar="false" IsUserDefined="1" id="$sectionId" columns="1">
          <labels>
            <label description="Create in PayPlus" languagecode="1033" />
            <label description="יצירה ב-PayPlus" languagecode="1037" />
          </labels>
          <rows>
            <row>
              <cell id="$cellId" showlabel="false" rowspan="16" colspan="1" auto="false">
                <labels>
                  <label description="Create in PayPlus" languagecode="1033" />
                  <label description="יצירה ב-PayPlus" languagecode="1037" />
                </labels>
                <control id="$hostField" uniqueid="$controlUniqueId" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="$hostField" />
              </cell>
            </row>
          </rows>
        </section>
      </sections>
    </column>
  </columns>
</tab>
"@
    return @{ Tab = $fragment.FirstChild; ControlId = $controlUniqueId }
}

function Ensure-ControlDescription([xml]$Document, [string]$ControlId) {
    $controlDescriptions = $Document.SelectSingleNode('//controlDescriptions')
    if (-not $controlDescriptions) {
        $controlDescriptions = $Document.CreateElement('controlDescriptions')
        $form = $Document.SelectSingleNode('/form')
        $form.AppendChild($controlDescriptions) | Out-Null
    }
    if ($controlDescriptions.SelectSingleNode("./controlDescription[@forControl='$ControlId']")) { return }
    $fragment = $Document.CreateDocumentFragment()
    $fragment.InnerXml = @"
<controlDescription forControl="$ControlId">
  <customControl name="$pcfName" formFactor="0"><parameters><hostValue type="SingleLine.Text">$hostField</hostValue></parameters></customControl>
  <customControl name="$pcfName" formFactor="1"><parameters><hostValue type="SingleLine.Text">$hostField</hostValue></parameters></customControl>
  <customControl name="$pcfName" formFactor="2"><parameters><hostValue type="SingleLine.Text">$hostField</hostValue></parameters></customControl>
</controlDescription>
"@
    $controlDescriptions.AppendChild($fragment.FirstChild) | Out-Null
}

function Ensure-InvoiceForms {
    $forms = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name,formxml&`$filter=objecttypecode eq '$entityLogicalName' and type eq 2"
    $summary = @()
    foreach ($form in $forms.value) {
        [xml]$xml = $form.formxml
        $tab = $xml.SelectSingleNode("//tab[@name='tab_payplus_billing']")
        if ($tab) {
            $control = $tab.SelectSingleNode(".//control[@datafieldname='$hostField']")
            if ($control -and $control.uniqueid) { Ensure-ControlDescription $xml $control.uniqueid }
            $changed = $xml.OuterXml -ne $form.formxml
            if ($changed) { Invoke-Dv -Method Patch -Uri "$base/systemforms($($form.formid))" -Body @{ formxml = $xml.OuterXml } | Out-Null }
            $summary += [pscustomobject]@{ Form=$form.name; Updated=$changed; Action='Existing tab' }
            continue
        }

        $tabs = $xml.SelectSingleNode('//tabs')
        if (-not $tabs) { Write-Warning "Form has no tabs node: $($form.name)"; continue }
        $tabInfo = New-BillingTabXml $xml
        $tabs.AppendChild($tabInfo.Tab) | Out-Null
        Ensure-ControlDescription $xml $tabInfo.ControlId
        Invoke-Dv -Method Patch -Uri "$base/systemforms($($form.formid))" -Body @{ formxml = $xml.OuterXml } | Out-Null
        $summary += [pscustomobject]@{ Form=$form.name; Updated=$true; Action='Added tab' }
    }
    return $summary
}

Ensure-HostField
$summary = Ensure-InvoiceForms
Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = '<importexportxml><entities><entity>invoice</entity></entities></importexportxml>' } | Out-Null

[pscustomobject]@{ Entity='invoice'; HostField=$hostField; Pcf=$pcfName; Forms=$summary } | ConvertTo-Json -Depth 6