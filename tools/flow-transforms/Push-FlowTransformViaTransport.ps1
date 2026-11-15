# Applies a flow transform in an environment where the flow cannot be saved through the workflows API
# (for example a Sales-free build environment whose connection references have no connections).
# Uses a temporary unmanaged transport solution: export -> transform the workflow JSON -> import -> delete transport.
# The flow keeps its solution membership and state. Requires: Azure CLI signed in (az login) and Node.js.
# Example:
#   ./Push-FlowTransformViaTransport.ps1 -Org https://build.crm4.dynamics.com -WorkflowId <guid> -Transform hfsession-currency.js
param(
    [Parameter(Mandatory)][string]$Org,
    [Parameter(Mandatory)][string]$WorkflowId,
    [Parameter(Mandatory)][string]$Transform,
    [string]$PublisherPrefix = 'alex',
    [string]$WorkRoot = (Join-Path ([IO.Path]::GetTempPath()) 'payplus-flow-transport')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Org = $Org.TrimEnd('/')
$transformPath = if ([IO.Path]::IsPathRooted($Transform)) { $Transform } else { Join-Path $PSScriptRoot $Transform }
if (-not (Test-Path $transformPath)) { throw "Transform not found: $transformPath" }
$transportUnique = "${PublisherPrefix}_flow_transform_transport"
$token = az account get-access-token --resource $Org --query accessToken -o tsv
if (-not $token) { throw 'Failed to get a Dataverse access token (run az login).' }
$get = @{ Authorization = "Bearer $token"; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0'; Accept = 'application/json' }
$post = $get + @{ 'Content-Type' = 'application/json; charset=utf-8'; Prefer = 'return=representation' }
$api = "$Org/api/data/v9.2"
function G($p) { Invoke-RestMethod -Headers $get -Uri "$api/$p" }
function P($p, $b) { Invoke-RestMethod -Method Post -Headers $post -Uri "$api/$p" -Body ([Text.Encoding]::UTF8.GetBytes(($b | ConvertTo-Json -Depth 6 -Compress))) -TimeoutSec 600 }

$work = Join-Path $WorkRoot ((Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + ([Uri]$Org).Host.Split('.')[0])
New-Item -ItemType Directory -Force $work | Out-Null

$pubId = (G "publishers?`$select=publisherid&`$filter=customizationprefix eq '$PublisherPrefix'").value[0].publisherid
if (-not $pubId) { throw "Publisher with prefix '$PublisherPrefix' not found." }
$sol = (G "solutions?`$select=solutionid&`$filter=uniquename eq '$transportUnique'").value
if (-not $sol.Count) {
    P 'solutions' @{ uniquename = $transportUnique; friendlyname = 'Flow Transform Transport'; version = '1.0.0.0'; description = 'Temporary: carries a transformed flow. Deleted after use.'; 'publisherid@odata.bind' = "/publishers($pubId)" } | Out-Null
}
try {
    P 'AddSolutionComponent' @{ ComponentType = 29; ComponentId = $WorkflowId; SolutionUniqueName = $transportUnique; AddRequiredComponents = $false } | Out-Null
    $export = P 'ExportSolution' @{ SolutionName = $transportUnique; Managed = $false }
    $zip = Join-Path $work 'transport.zip'
    [IO.File]::WriteAllBytes($zip, [Convert]::FromBase64String($export.ExportSolutionFile))
    $unpacked = Join-Path $work 'unpacked'
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $unpacked)
    $wfFile = Get-ChildItem (Join-Path $unpacked 'Workflows') -Filter '*.json' | Where-Object Name -like "*-$($WorkflowId.ToUpperInvariant()).json" | Select-Object -First 1
    if (-not $wfFile) { throw 'Workflow JSON not found in transport export.' }
    Copy-Item $wfFile.FullName (Join-Path $work 'workflow.before.json')
    node $transformPath $wfFile.FullName $wfFile.FullName
    if ($LASTEXITCODE -ne 0) { throw 'Transform failed.' }
    Copy-Item $wfFile.FullName (Join-Path $work 'workflow.after.json')
    $patchedZip = Join-Path $work 'transport.patched.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($unpacked, $patchedZip)
    P 'ImportSolution' @{ CustomizationFile = [Convert]::ToBase64String([IO.File]::ReadAllBytes($patchedZip)); OverwriteUnmanagedCustomizations = $true; PublishWorkflows = $false; ImportJobId = [guid]::NewGuid().ToString() } | Out-Null
    $check = G "workflows($WorkflowId)?`$select=statecode,clientdata"
    $verifyIn = Join-Path $work 'verify.in.json'; $verifyOut = Join-Path $work 'verify.out.json'
    [IO.File]::WriteAllText($verifyIn, $check.clientdata, [Text.UTF8Encoding]::new($false))
    $verify = node $transformPath $verifyIn $verifyOut
    Write-Host "Imported. state=$($check.statecode) transform re-run: $($verify -join ' ')"
}
finally {
    $sol = (G "solutions?`$select=solutionid&`$filter=uniquename eq '$transportUnique'").value
    if ($sol.Count) { Invoke-RestMethod -Method Delete -Headers $get -Uri "$api/solutions($($sol[0].solutionid))" | Out-Null; Write-Host 'Transport solution deleted (components kept).' }
    foreach ($z in 'transport.zip', 'transport.patched.zip', 'unpacked') { Remove-Item -Recurse -Force (Join-Path $work $z) -ErrorAction SilentlyContinue }
}
