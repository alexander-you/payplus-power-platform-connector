$org = "https://demo-contact-center-en.crm4.dynamics.com"
$token = az account get-access-token --resource $org --query accessToken -o tsv
$H = @{ Authorization = "Bearer $token"; Accept = "application/json"; "OData-MaxVersion"="4.0"; "OData-Version"="4.0" }
# confirm the binding landed and is valid on both forms
foreach($f in @(@{n="contact";id="e06af4d1-2812-45c7-a9c2-9fb73fee7bec"},@{n="account";id="8448b78f-8f42-454e-8e2a-f8196b0419af"})){
  $rec = Invoke-RestMethod -Method Get -Uri "$org/api/data/v9.2/systemforms($($f.id))?`$select=formxml" -Headers $H
  $x=$rec.formxml
  $hasCtl = $x.Contains("alex_PayPlus.BankAccountWallet")
  $hasTab = $x.Contains("tab_bankaccounts")
  try { [xml]$null=$x; $valid="VALID" } catch { $valid="INVALID: $($_.Exception.Message)" }
  Write-Host "$($f.n): control=$hasCtl tab=$hasTab xml=$valid"
}
# is the control in the main solution?
$comp = Invoke-RestMethod -Method Get -Uri "$org/api/data/v9.2/customcontrols?`$filter=name eq 'alex_PayPlus.BankAccountWallet'&`$select=customcontrolid,name" -Headers $H
Write-Host "customcontrol: $($comp.value | ConvertTo-Json -Compress)"
