# Registers the default-enforcement plugins (EnforceSingleDefaultTerminal /
# EnforceSingleDefaultPage) against the existing PayPlus.Plugins assembly in
# Dataverse: updates the assembly content, then registers the plugin types and
# synchronous Post-Operation steps (Create + Update) on each table.
#
# Idempotent: existing types/steps are reused, not duplicated.
# Run _after_ building: dotnet build -c Release (plugins\PayPlus.Plugins.csproj).
$ErrorActionPreference = 'Stop'
$org       = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution  = 'alex_d365_payplus'
$asmName   = 'PayPlus.Plugins'
$dllPath   = Join-Path $PSScriptRoot 'plugins\bin\Release\PayPlus.Plugins.dll'

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get access token.' }
$headers = @{
    Authorization              = "Bearer $token"
    'OData-Version'            = '4.0'
    'OData-MaxVersion'         = '4.0'
    Accept                     = 'application/json'
    'Content-Type'             = 'application/json; charset=utf-8'
    'MSCRM.SolutionUniqueName'  = $solution
}
$base = "$org/api/data/v9.2"

function Get-One { param([string]$Uri) $r = Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers; if ($r.value.Count -gt 0) { return $r.value[0] } return $null }
function Post-Ret { param([string]$Set, [object]$Body)
    $bytes = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 40 -Compress))
    $resp = Invoke-WebRequest -Method Post -Uri "$base/$Set" -Headers $headers -Body $bytes
    $h = $resp.Headers['OData-EntityId']; if ($h -is [array]) { $h = $h[0] }
    if ($h -match '\(([0-9a-fA-F-]{36})\)') { return $Matches[1] }
    throw "Could not read id from POST $Set"
}

# 1) locate + update the assembly content -------------------------------------
$asm = Get-One "$base/pluginassemblies?`$select=pluginassemblyid,name&`$filter=name eq '$asmName'"
if (-not $asm) { throw "Plugin assembly '$asmName' is not registered. Register it once with the Plugin Registration Tool, then re-run." }
$asmId = $asm.pluginassemblyid
Write-Host "Assembly $asmName = $asmId"
if (-not (Test-Path $dllPath)) { throw "DLL not found: $dllPath (build the project first)." }
$content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($dllPath))
Invoke-RestMethod -Method Patch -Uri "$base/pluginassemblies($asmId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes((@{ content = $content } | ConvertTo-Json))) | Out-Null
Write-Host 'Assembly content updated.'

# 2) message + filter ids ------------------------------------------------------
function Get-MessageId { param([string]$Name) (Get-One "$base/sdkmessages?`$select=sdkmessageid&`$filter=name eq '$Name'").sdkmessageid }
function Get-FilterId { param([string]$MessageId, [string]$Entity)
    (Get-One "$base/sdkmessagefilters?`$select=sdkmessagefilterid&`$filter=_sdkmessageid_value eq $MessageId and primaryobjecttypecode eq '$Entity'").sdkmessagefilterid
}
$msgCreate = Get-MessageId 'Create'
$msgUpdate = Get-MessageId 'Update'

function Ensure-PluginType { param([string]$TypeName, [string]$FriendlyName)
    $existing = Get-One "$base/plugintypes?`$select=plugintypeid&`$filter=typename eq '$TypeName' and _pluginassemblyid_value eq $asmId"
    if ($existing) { Write-Host "  type exists: $TypeName"; return $existing.plugintypeid }
    Write-Host "  create type: $TypeName"
    return Post-Ret 'plugintypes' @{
        typename = $TypeName; friendlyname = $FriendlyName; name = $TypeName
        'pluginassemblyid@odata.bind' = "/pluginassemblies($asmId)"
    }
}

function Ensure-Step { param([string]$StepName, [string]$TypeId, [string]$MessageId, [string]$Entity, [string]$FilterAttrs)
    $existing = Get-One "$base/sdkmessageprocessingsteps?`$select=sdkmessageprocessingstepid&`$filter=name eq '$StepName'"
    if ($existing) { Write-Host "    step exists: $StepName"; return $existing.sdkmessageprocessingstepid }
    $filterId = Get-FilterId $MessageId $Entity
    $body = @{
        name                            = $StepName
        mode                            = 0        # synchronous
        stage                           = 40       # post-operation
        rank                            = 1
        supporteddeployment             = 0        # server only
        invocationsource                = 0
        'sdkmessageid@odata.bind'       = "/sdkmessages($MessageId)"
        'plugintypeid@odata.bind'       = "/plugintypes($TypeId)"
    }
    if ($filterId) { $body['sdkmessagefilterid@odata.bind'] = "/sdkmessagefilters($filterId)" }
    if ($FilterAttrs) { $body['filteringattributes'] = $FilterAttrs }
    Write-Host "    create step: $StepName"
    return Post-Ret 'sdkmessageprocessingsteps' $body
}

# 3) register both plugins -----------------------------------------------------
$plugins = @(
    @{ Type = 'PayPlus.Plugins.EnforceSingleDefaultTerminal'; Friendly = 'Enforce Single Default Terminal'; Entity = 'alex_payplus_terminal' },
    @{ Type = 'PayPlus.Plugins.EnforceSingleDefaultPage';     Friendly = 'Enforce Single Default Page';     Entity = 'alex_payplus_paymentpage' }
)
foreach ($p in $plugins) {
    Write-Host "Plugin: $($p.Type)"
    $typeId = Ensure-PluginType $p.Type $p.Friendly
    Ensure-Step "$($p.Type): Create of $($p.Entity)" $typeId $msgCreate $p.Entity $null | Out-Null
    Ensure-Step "$($p.Type): Update of $($p.Entity)" $typeId $msgUpdate $p.Entity 'alex_isdefault' | Out-Null
}

Write-Host ''
Write-Host 'DONE. Default-enforcement plugins registered (synchronous Post-Operation).'
