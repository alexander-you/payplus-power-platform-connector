# Deploy PayPlus Document Preview host field and dedicated form on alex_payplusdocument.

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus'
$entityLogicalName = 'alex_payplusdocument'
$hostField = 'alex_documentpreviewhost'
$hostSchema = 'alex_DocumentPreviewHost'
$formName = 'תצוגה מקדימה PayPlus'
$pcfName = 'alex_PayPlus.DocumentPreview'

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get Dataverse access token.' }

$headers = @{
    Authorization       = "Bearer $token"
    'OData-Version'     = '4.0'
    'OData-MaxVersion'  = '4.0'
    Accept              = 'application/json'
    'Content-Type'      = 'application/json; charset=utf-8'
}
$solutionHeaders = $headers.Clone()
$solutionHeaders['MSCRM.SolutionUniqueName'] = $solution
$base = "$org/api/data/v9.2"

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Uri,
        $Body = $null,
        [hashtable]$Headers = $headers
    )
    if ($null -eq $Body) { return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers }
    $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 100 -Compress }
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body ([Text.Encoding]::UTF8.GetBytes($json))
}

function ConvertTo-XmlText([string]$Value) {
    if ($null -eq $Value) { return '' }
    return [Security.SecurityElement]::Escape($Value)
}

function New-GuidText { return '{' + ([guid]::NewGuid().ToString()).ToUpperInvariant() + '}' }

function Get-EntityIdFromHeader($ResponseHeaders, [string]$EntitySet) {
    $entityHeader = $ResponseHeaders['OData-EntityId']
    if ($entityHeader -is [array]) { $entityHeader = $entityHeader[0] }
    if ($entityHeader -match "$EntitySet\(([0-9a-fA-F-]{36})\)") { return $Matches[1] }
    return $null
}

function Ensure-HostField {
    try {
        Invoke-Dv -Method Get -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes(LogicalName='$hostField')?`$select=LogicalName" | Out-Null
        Write-Host "Host field exists: $hostField"
        return
    }
    catch {
        Write-Host "Creating host field: $hostField"
    }

    $body = @{
        '@odata.type' = '#Microsoft.Dynamics.CRM.StringAttributeMetadata'
        SchemaName = $hostSchema
        DisplayName = @{
            LocalizedLabels = @(
                @{ Label = 'Document Preview Host'; LanguageCode = 1033 },
                @{ Label = 'מארח תצוגה מקדימה'; LanguageCode = 1037 }
            )
        }
        Description = @{
            LocalizedLabels = @(
                @{ Label = 'Host field for the PayPlus document preview PCF control.'; LanguageCode = 1033 },
                @{ Label = 'שדה מארח לפקד תצוגת מסמך PayPlus.'; LanguageCode = 1037 }
            )
        }
        RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
        MaxLength = 100
        FormatName = @{ Value = 'Text' }
    }
    Invoke-Dv -Method Post -Uri "$base/EntityDefinitions(LogicalName='$entityLogicalName')/Attributes" -Body $body -Headers $solutionHeaders | Out-Null
}

function New-PreviewFormXml {
    $tabId = New-GuidText
    $sectionId = New-GuidText
    $cellId = New-GuidText
    $controlUniqueId = New-GuidText
    $headerId = New-GuidText
    $footerId = New-GuidText

    $formXml = @"
<form>
  <tabs>
    <tab name="tab_payplus_preview" verticallayout="true" id="$tabId" IsUserDefined="1" expanded="true" showlabel="true">
      <labels>
        <label description="PayPlus Preview" languagecode="1033" />
        <label description="תצוגה מקדימה PayPlus" languagecode="1037" />
      </labels>
      <columns>
        <column width="100%">
          <sections>
            <section name="sec_payplus_preview" showlabel="false" showbar="false" IsUserDefined="1" id="$sectionId" columns="1">
              <labels>
                <label description="Preview" languagecode="1033" />
                <label description="תצוגה מקדימה" languagecode="1037" />
              </labels>
              <rows>
                <row>
                  <cell id="$cellId" showlabel="false" rowspan="18" colspan="1" auto="false">
                    <labels>
                      <label description="Document Preview" languagecode="1033" />
                      <label description="תצוגת מסמך" languagecode="1037" />
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
  </tabs>
  <controlDescriptions>
    <controlDescription forControl="$controlUniqueId">
      <customControl name="$pcfName" formFactor="0"><parameters><hostValue type="SingleLine.Text">$hostField</hostValue></parameters></customControl>
      <customControl name="$pcfName" formFactor="1"><parameters><hostValue type="SingleLine.Text">$hostField</hostValue></parameters></customControl>
      <customControl name="$pcfName" formFactor="2"><parameters><hostValue type="SingleLine.Text">$hostField</hostValue></parameters></customControl>
    </controlDescription>
  </controlDescriptions>
  <header id="$headerId" celllabelposition="Top" columns="111" labelwidth="115" celllabelalignment="Left"><rows /></header>
  <footer id="$footerId" celllabelposition="Top" columns="111" labelwidth="115" celllabelalignment="Left"><rows /></footer>
  <DisplayConditions Order="0" FallbackForm="false"><Everyone /></DisplayConditions>
</form>
"@
    return $formXml -replace "`r|`n\s*", ''
}

function Ensure-PreviewForm {
    $nameEsc = $formName.Replace("'", "''")
    $existing = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid,name&`$filter=objecttypecode eq '$entityLogicalName' and type eq 2 and name eq '$nameEsc'&`$top=1"
    $formXml = New-PreviewFormXml
    $body = @{
        name = $formName
        type = 2
        objecttypecode = $entityLogicalName
        formxml = $formXml
        description = 'Dedicated PayPlus document preview form hosting alex_PayPlus.DocumentPreview.'
    }

    if ($existing.value.Count -gt 0) {
        $formId = $existing.value[0].formid
        Write-Host "Updating preview form: $formName ($formId)"
        Invoke-Dv -Method Patch -Uri "$base/systemforms($formId)" -Body @{ formxml = $formXml; description = $body.description } | Out-Null
    }
    else {
        Write-Host "Creating preview form: $formName"
        $json = $body | ConvertTo-Json -Depth 100 -Compress
        $response = Invoke-WebRequest -Method Post -Uri "$base/systemforms" -Headers $solutionHeaders -Body ([Text.Encoding]::UTF8.GetBytes($json))
        $formId = Get-EntityIdFromHeader $response.Headers 'systemforms'
        if (-not $formId) {
            $created = Invoke-Dv -Method Get -Uri "$base/systemforms?`$select=formid&`$filter=objecttypecode eq '$entityLogicalName' and type eq 2 and name eq '$nameEsc'&`$top=1"
            if ($created.value.Count -gt 0) { $formId = $created.value[0].formid }
        }
    }
    if (-not $formId) { throw 'Could not determine preview form id.' }

    $addBody = @{ ComponentType = 60; ComponentId = $formId; SolutionUniqueName = $solution; AddRequiredComponents = $false }
    try { Invoke-Dv -Method Post -Uri "$base/AddSolutionComponent" -Body $addBody | Out-Null } catch { Write-Warning "AddSolutionComponent form: $($_.Exception.Message)" }
    return $formId
}

Ensure-HostField
$formId = Ensure-PreviewForm

$publishBody = @{ ParameterXml = "<importexportxml><entities><entity>$entityLogicalName</entity></entities></importexportxml>" }
Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body $publishBody | Out-Null

Write-Host "DONE. Preview form id: $formId"