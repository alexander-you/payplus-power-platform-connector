# Bind PayPlus.BankAccountWallet to Contact + Account main forms as an alex_customerbankaccount subgrid.
# Mirrors the verified CreditCardWallet dataset-PCF binding pattern.
$ErrorActionPreference = "Stop"
$org = "https://demo-contact-center-en.crm4.dynamics.com"
$token = az account get-access-token --resource $org --query accessToken -o tsv
$H = @{ Authorization = "Bearer $token"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"; Accept = "application/json"; "Content-Type" = "application/json; charset=utf-8" }

$CONTROL   = "alex_PayPlus.BankAccountWallet"
$DATASET   = "accounts"
$ENTITY    = "alex_customerbankaccount"
$VIEWID    = "{6C0F729B-6D9C-45A2-AA85-06B9CB6FA48F}"   # Active Customer Bank Accounts
$SUBGRIDCC = "{E7A81278-8635-4D9E-8D4D-59480B391C5B}"    # plain subgrid customControl
$HOSTCLS   = "{F9A8A302-114E-466A-B582-6771B2AE0D92}"    # custom-control host classid
$HE = "חשבונות בנק"
$EN = "Bank Accounts"

$targets = @(
  @{ name = "contact e06af4d1"; formid = "e06af4d1-2812-45c7-a9c2-9fb73fee7bec"; rel = "alex_Contact_CustomerBankAccount" },
  @{ name = "account 8448b78f"; formid = "8448b78f-8f42-454e-8e2a-f8196b0419af"; rel = "alex_Account_CustomerBankAccount" }
)

function Lbl($he, $en) { "<labels><label description=""$he"" languagecode=""1037"" /><label description=""$en"" languagecode=""1033"" /></labels>" }

foreach ($t in $targets) {
  Write-Host "=== $($t.name) ===" -ForegroundColor Cyan
  $rec = Invoke-RestMethod -Method Get -Uri "$org/api/data/v9.2/systemforms($($t.formid))?`$select=formxml" -Headers $H
  $xml = $rec.formxml

  if ($xml.Contains("Subgrid_bankaccounts") -or $xml.Contains($CONTROL)) {
    Write-Host "  Already bound - skipping." -ForegroundColor Yellow
    continue
  }

  $u = "{" + ([guid]::NewGuid().ToString()) + "}"
  $tabId  = "{" + ([guid]::NewGuid().ToString()) + "}"
  $secId  = "{" + ([guid]::NewGuid().ToString()) + "}"
  $cellId = "{" + ([guid]::NewGuid().ToString()) + "}"

  $subParams = "<parameters><RecordsPerPage>6</RecordsPerPage><AutoExpand>Fixed</AutoExpand><EnableQuickFind>false</EnableQuickFind><EnableViewPicker>false</EnableViewPicker><EnableChartPicker>false</EnableChartPicker><ChartGridMode>Grid</ChartGridMode><RelationshipName>$($t.rel)</RelationshipName><TargetEntityType>$ENTITY</TargetEntityType><ViewId>$VIEWID</ViewId><ViewIds>$VIEWID</ViewIds></parameters>"

  # New tab with subgrid host control
  $hostControl = "<control indicationOfSubgrid=""true"" id=""Subgrid_bankaccounts"" classid=""$HOSTCLS"" uniqueid=""$u"">$subParams</control>"
  $cell = "<cell id=""$cellId"" showlabel=""false"" rowspan=""14"" colspan=""1"" auto=""false"">$(Lbl $HE $EN)$hostControl</cell>"
  $section = "<section name=""sec_bankaccounts"" id=""$secId"" IsUserDefined=""0"" locklevel=""0"" showlabel=""false"" showbar=""false"" columns=""1"" labelwidth=""115"" celllabelalignment=""Left"" celllabelposition=""Left"">$(Lbl $HE $EN)<rows><row>$cell</row></rows></section>"
  $tab = "<tab name=""tab_bankaccounts"" id=""$tabId"" IsUserDefined=""0"" locklevel=""0"" showlabel=""true"" expanded=""true"">$(Lbl $HE $EN)<columns><column width=""100%""><sections>$section</sections></column></columns></tab>"

  # controlDescription with the 3 form-factor custom-control bindings
  function DsFF($ff) { "<customControl name=""$CONTROL"" formFactor=""$ff""><parameters><data-set name=""$DATASET""><ViewId>$VIEWID</ViewId><TargetEntityType>$ENTITY</TargetEntityType><IsUserView>false</IsUserView><EnableViewPicker>false</EnableViewPicker><RelationshipName>$($t.rel)</RelationshipName><FilteredViewIds>$VIEWID</FilteredViewIds></data-set></parameters></customControl>" }
  $cd = "<controlDescription forControl=""$u""><customControl id=""$SUBGRIDCC"">$subParams</customControl>$(DsFF 0)$(DsFF 1)$(DsFF 2)</controlDescription>"

  # Insert tab before last </tabs>
  $ix = $xml.LastIndexOf("</tabs>")
  if ($ix -lt 0) { throw "no </tabs> in form $($t.name)" }
  $xml = $xml.Substring(0, $ix) + $tab + $xml.Substring($ix)

  # Insert controlDescription into (or create) controlDescriptions
  if ($xml.Contains("</controlDescriptions>")) {
    $ix2 = $xml.LastIndexOf("</controlDescriptions>")
    $xml = $xml.Substring(0, $ix2) + $cd + $xml.Substring($ix2)
  }
  else {
    # create a controlDescriptions block right after </tabs>
    $ix3 = $xml.IndexOf("</tabs>") + "</tabs>".Length
    $xml = $xml.Substring(0, $ix3) + "<controlDescriptions>$cd</controlDescriptions>" + $xml.Substring($ix3)
  }

  $body = @{ formxml = $xml } | ConvertTo-Json -Depth 5
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  Invoke-RestMethod -Method Patch -Uri "$org/api/data/v9.2/systemforms($($t.formid))" -Headers $H -Body $bytes | Out-Null
  Write-Host "  Patched. uniqueid=$u" -ForegroundColor Green
}

Write-Host "Publishing contact + account..." -ForegroundColor Cyan
$pub = '<importexportxml><entities><entity>contact</entity><entity>account</entity></entities></importexportxml>'
$pbody = @{ ParameterXml = $pub } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$org/api/data/v9.2/PublishXml" -Headers $H -Body $pbody | Out-Null
Write-Host "Done. Published." -ForegroundColor Green
