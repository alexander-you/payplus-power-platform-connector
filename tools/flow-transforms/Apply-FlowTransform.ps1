# Applies a flow transform (a Node.js script under tools/flow-transforms) to cloud flows in a Dataverse environment.
# For each flow: backs up clientdata, runs the transform, saves it and re-activates the flow (activation validates the
# definition). If saving or activation fails, the original definition and state are restored.
# Requires: Azure CLI signed in (az login) and Node.js.
# Example:
#   ./Apply-FlowTransform.ps1 -Org https://contoso.crm4.dynamics.com -Transform hfsession-currency.js -FlowNames 'PayPlus HF Session'
param(
    [Parameter(Mandatory)][string]$Org,
    [Parameter(Mandatory)][string]$Transform,
    [Parameter(Mandatory)][string[]]$FlowNames,
    [string]$BackupRoot = (Join-Path ([IO.Path]::GetTempPath()) 'payplus-flow-transform-backups'),
    [switch]$ValidateOnly,
    [switch]$KeepState
)
$ErrorActionPreference = 'Stop'
$Org = $Org.TrimEnd('/')
$transformPath = if ([IO.Path]::IsPathRooted($Transform)) { $Transform } else { Join-Path $PSScriptRoot $Transform }
if (-not (Test-Path $transformPath)) { throw "Transform not found: $transformPath" }
$backupDir = Join-Path $BackupRoot ((Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + ([Uri]$Org).Host.Split('.')[0])
New-Item -ItemType Directory -Force $backupDir | Out-Null

$token = az account get-access-token --resource $Org --query accessToken -o tsv
if (-not $token) { throw 'Failed to get a Dataverse access token (run az login).' }
$headers = @{ Authorization = "Bearer $token"; 'OData-Version' = '4.0'; 'OData-MaxVersion' = '4.0'; Accept = 'application/json'; 'Content-Type' = 'application/json; charset=utf-8' }
$base = "$Org/api/data/v9.2"
function Send-Patch([string]$Uri, [hashtable]$Body) {
    Invoke-RestMethod -Method Patch -Uri $Uri -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 5 -Compress))) | Out-Null
}

foreach ($flowName in $FlowNames) {
    $nameEsc = $flowName.Replace("'", "''")
    $wf = (Invoke-RestMethod -Uri "$base/workflows?`$select=workflowid,name,statecode,clientdata&`$filter=name eq '$nameEsc' and category eq 5&`$top=1" -Headers $headers).value | Select-Object -First 1
    if (-not $wf) { Write-Warning "Flow not found: $flowName"; continue }
    $safe = ($flowName -replace '[^A-Za-z0-9]+', '_').Trim('_')
    $before = Join-Path $backupDir "$safe.before.json"
    $after = Join-Path $backupDir "$safe.after.json"
    [IO.File]::WriteAllText($before, $wf.clientdata, [Text.UTF8Encoding]::new($false))
    node $transformPath $before $after
    if ($LASTEXITCODE -ne 0) { throw "Transform failed for $flowName" }
    if ($ValidateOnly) { Write-Host "[$flowName] validated only -> $after"; continue }

    $wasActive = $wf.statecode -eq 1
    if ($wasActive) { Send-Patch "$base/workflows($($wf.workflowid))" @{ statecode = 0; statuscode = 1 } }
    try { Send-Patch "$base/workflows($($wf.workflowid))" @{ clientdata = [IO.File]::ReadAllText($after) } }
    catch {
        $detail = $_.ErrorDetails.Message
        if ($wasActive) { Send-Patch "$base/workflows($($wf.workflowid))" @{ statecode = 1; statuscode = 2 } }
        throw "Saving the patched definition failed for ${flowName}: $detail"
    }
    if ($wasActive -or -not $KeepState) {
        try { Send-Patch "$base/workflows($($wf.workflowid))" @{ statecode = 1; statuscode = 2 } }
        catch {
            $detail = $_.ErrorDetails.Message
            Write-Warning "[$flowName] activation failed, restoring backup: $detail"
            Send-Patch "$base/workflows($($wf.workflowid))" @{ clientdata = [IO.File]::ReadAllText($before) }
            if ($wasActive) { Send-Patch "$base/workflows($($wf.workflowid))" @{ statecode = 1; statuscode = 2 } }
            throw "Activation failed for $flowName"
        }
    }
    $state = (Invoke-RestMethod -Uri "$base/workflows($($wf.workflowid))?`$select=statecode" -Headers $headers).statecode
    Write-Host "[$flowName] patched. state=$state backup=$before"
}
