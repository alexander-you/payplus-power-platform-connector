# Deploy Quote PayPlus command bar resources and RibbonDiffXml to the Sales extension solution.

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus_sales_extended_data_model'
$root = $PSScriptRoot
$ribbonFile = Join-Path $root 'ribbon\quote\RibbonDiff.xml'
$work = Join-Path $root '_tmp_quote_ribbon'
$exportZip = Join-Path $work 'sales_ext_export.zip'
$importZip = Join-Path $work 'sales_ext_quote_ribbon.zip'
$unpack = Join-Path $work 'sales_ext'

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

function Escape-ODataString([string]$value) {
    return $value.Replace("'", "''")
}

function Get-EntityIdFromHeader($headers, [string]$entitySet) {
    $entityHeader = $headers['OData-EntityId']
    if ($entityHeader -is [array]) { $entityHeader = $entityHeader[0] }
    if ($entityHeader -match "$entitySet\(([0-9a-fA-F-]{36})\)") { return $Matches[1] }
    return $null
}

function Ensure-WebResource([string]$name, [string]$file, [int]$type, [string]$displayName) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing webresource source file: $file" }
    $content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file))
    $nameEsc = Escape-ODataString $name
    $existing = Invoke-RestMethod -Method Get -Uri "$base/webresourceset?`$select=webresourceid,name&`$filter=name eq '$nameEsc'&`$top=1" -Headers $headers

    $body = @{
        name = $name
        displayname = $displayName
        webresourcetype = $type
        content = $content
        description = 'PayPlus Quote command bar resource.'
    } | ConvertTo-Json -Depth 5 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($body)

    if ($existing.value.Count -gt 0) {
        $id = $existing.value[0].webresourceid
        Write-Host "Updating webresource $name ($id) ..."
        Invoke-RestMethod -Method Patch -Uri "$base/webresourceset($id)" -Headers $headers -Body $bytes | Out-Null
    }
    else {
        Write-Host "Creating webresource $name ..."
        $response = Invoke-WebRequest -Method Post -Uri "$base/webresourceset" -Headers $solutionHeaders -Body $bytes
        $id = Get-EntityIdFromHeader $response.Headers 'webresourceset'
        if (-not $id) {
            $created = Invoke-RestMethod -Method Get -Uri "$base/webresourceset?`$select=webresourceid&`$filter=name eq '$nameEsc'&`$top=1" -Headers $headers
            if ($created.value.Count -gt 0) { $id = $created.value[0].webresourceid }
        }
        if (-not $id) { throw "Could not determine webresource id for $name" }
    }

    $addBody = @{
        ComponentType = 61
        ComponentId = $id
        SolutionUniqueName = $solution
        AddRequiredComponents = $false
    } | ConvertTo-Json -Compress
    try {
        Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($addBody)) | Out-Null
    }
    catch {
        Write-Warning "AddSolutionComponent for ${name}: $($_.Exception.Message)"
    }

    return $id
}

[xml](Get-Content -Raw -LiteralPath $ribbonFile) | Out-Null

$webResources = @(
    @{ Name = 'alex_payplus_quote_commands.js'; Type = 3; File = 'webresources\alex_payplus_quote_commands.js'; DisplayName = 'PayPlus Quote Commands' },
    @{ Name = 'alex_payplus_quote_icon.svg'; Type = 11; File = 'webresources\alex_payplus_quote_icon.svg'; DisplayName = 'PayPlus Quote Icon' },
    @{ Name = 'alex_payplus_preview_icon.svg'; Type = 11; File = 'webresources\alex_payplus_preview_icon.svg'; DisplayName = 'PayPlus Preview Icon' },
    @{ Name = 'alex_payplus_document_icon.svg'; Type = 11; File = 'webresources\alex_payplus_document_icon.svg'; DisplayName = 'PayPlus Document Icon' },
    @{ Name = 'alex_payplus_send_icon.svg'; Type = 11; File = 'webresources\alex_payplus_send_icon.svg'; DisplayName = 'PayPlus Send Icon' }
)

$publishedIds = @()
foreach ($wr in $webResources) {
    $publishedIds += Ensure-WebResource $wr.Name (Join-Path $root $wr.File) $wr.Type $wr.DisplayName
}

$webResourceXml = ($publishedIds | ForEach-Object { "<webresource>$_</webresource>" }) -join ''
$publishBody = @{ ParameterXml = "<importexportxml><webresources>$webResourceXml</webresources></importexportxml>" } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Post -Uri "$base/PublishXml" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($publishBody)) | Out-Null
Write-Host 'Webresources published.'

if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Force -Path $work | Out-Null

Write-Host "Exporting solution $solution ..."
pac solution export --name $solution --path $exportZip --managed false --overwrite true

Write-Host 'Unpacking solution ...'
pac solution unpack --zipfile $exportZip --folder $unpack --packagetype Unmanaged --allowDelete true --allowWrite true

$targetRibbon = Join-Path $unpack 'Entities\Quote\RibbonDiff.xml'
if (-not (Test-Path -LiteralPath (Split-Path $targetRibbon))) {
    throw "Unpacked solution does not contain Entities\Quote. Is quote still in $solution?"
}
Copy-Item -LiteralPath $ribbonFile -Destination $targetRibbon -Force

Write-Host 'Packing ribbon solution ...'
pac solution pack --zipfile $importZip --folder $unpack --packagetype Unmanaged --allowDelete true --allowWrite true

Write-Host 'Importing ribbon solution ...'
pac solution import --path $importZip --publish-changes --force-overwrite

Write-Host ''
Write-Host 'DONE. Quote PayPlus command bar draft was imported and published.'
Write-Host 'Open a Quote form or Quote view and hard refresh if the command bar cache is stale.'