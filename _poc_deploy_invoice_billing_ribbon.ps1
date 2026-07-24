# Deploy Invoice PayPlus billing command bar resources and RibbonDiffXml to the Sales extension solution.

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus_sales_extended_data_model'
$root = $PSScriptRoot
$ribbonFile = Join-Path $root 'ribbon\invoice\RibbonDiff.xml'
$work = Join-Path $root '_tmp_invoice_ribbon'
$exportZip = Join-Path $work 'sales_ext_export.zip'
$importZip = Join-Path $work 'sales_ext_invoice_ribbon.zip'
$unpack = Join-Path $work 'sales_ext'

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

function ConvertTo-ODataEscapedString([string]$value) { return $value.Replace("'", "''") }

function Get-EntityIdFromHeader($headers, [string]$entitySet) {
    $entityHeader = $headers['OData-EntityId']
    if ($entityHeader -is [array]) { $entityHeader = $entityHeader[0] }
    if ($entityHeader -match "$entitySet\(([0-9a-fA-F-]{36})\)") { return $Matches[1] }
    return $null
}

function Set-WebResource([string]$name, [string]$file, [int]$type, [string]$displayName) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing webresource source file: $file" }
    $content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file))
    $nameEsc = ConvertTo-ODataEscapedString $name
    $existing = Invoke-RestMethod -Method Get -Uri "$base/webresourceset?`$select=webresourceid,name&`$filter=name eq '$nameEsc'&`$top=1" -Headers $headers

    $body = @{
        name = $name
        displayname = $displayName
        webresourcetype = $type
        content = $content
        description = 'PayPlus invoice billing command bar resource.'
    } | ConvertTo-Json -Depth 5 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($body)

    if ($existing.value.Count -gt 0) {
        $id = $existing.value[0].webresourceid
        Write-Host "Updating webresource $name ($id) ..."
        Invoke-RestMethod -Method Patch -Uri "$base/webresourceset($id)" -Headers $headers -Body $bytes | Out-Null
    }
    else {
        Write-Host "Creating webresource $name ..."
        $response = Invoke-WebRequest -Method Post -Uri "$base/webresourceset" -Headers $solutionHeaders -ContentType 'application/json; charset=utf-8' -Body $body
        $id = Get-EntityIdFromHeader $response.Headers 'webresourceset'
        if (-not $id) {
            $created = Invoke-RestMethod -Method Get -Uri "$base/webresourceset?`$select=webresourceid&`$filter=name eq '$nameEsc'&`$top=1" -Headers $headers
            if ($created.value.Count -gt 0) { $id = $created.value[0].webresourceid }
        }
        if (-not $id) { throw "Could not determine webresource id for $name" }
    }

    $addBody = @{ ComponentType = 61; ComponentId = $id; SolutionUniqueName = $solution; AddRequiredComponents = $false } | ConvertTo-Json -Compress
    try { Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($addBody)) | Out-Null }
    catch { Write-Warning "AddSolutionComponent for ${name}: $($_.Exception.Message)" }

    return $id
}

function Add-EntityToSolutionIfNeeded([string]$logicalName) {
    $entity = Invoke-RestMethod -Method Get -Uri "$base/EntityDefinitions(LogicalName='$logicalName')?`$select=MetadataId,LogicalName" -Headers $headers
    $addBody = @{ ComponentType = 1; ComponentId = $entity.MetadataId; SolutionUniqueName = $solution; AddRequiredComponents = $false } | ConvertTo-Json -Compress
    try {
        Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($addBody)) | Out-Null
        Write-Host "Ensured entity in solution: $logicalName"
    }
    catch {
        Write-Warning "AddSolutionComponent entity ${logicalName}: $($_.Exception.Message)"
    }
}

[xml](Get-Content -Raw -LiteralPath $ribbonFile) | Out-Null

$webResources = @(
    @{ Name = 'alex_payplus_quote_commands.js'; Type = 3; File = 'webresources\alex_payplus_quote_commands.js'; DisplayName = 'PayPlus Sales Commands' },
    @{ Name = 'alex_payplus_quote_icon.svg'; Type = 11; File = 'webresources\alex_payplus_quote_icon.svg'; DisplayName = 'PayPlus Sales Icon' },
    @{ Name = 'alex_payplus_document_icon.svg'; Type = 11; File = 'webresources\alex_payplus_document_icon.svg'; DisplayName = 'PayPlus Document Icon' },
    @{ Name = 'alex_payplus_preview_icon.svg'; Type = 11; File = 'webresources\alex_payplus_preview_icon.svg'; DisplayName = 'PayPlus Preview Icon' },
    @{ Name = 'alex_payplus_send_icon.svg'; Type = 11; File = 'webresources\alex_payplus_send_icon.svg'; DisplayName = 'PayPlus Send Icon' },
    @{ Name = 'alex_payplus_email_icon.svg'; Type = 11; File = 'webresources\alex_payplus_email_icon.svg'; DisplayName = 'PayPlus Email Icon' },
    @{ Name = 'alex_payplus_sms_icon.svg'; Type = 11; File = 'webresources\alex_payplus_sms_icon.svg'; DisplayName = 'PayPlus SMS Icon' },
    @{ Name = 'alex_payplus_whatsapp_icon.svg'; Type = 11; File = 'webresources\alex_payplus_whatsapp_icon.svg'; DisplayName = 'PayPlus WhatsApp Icon' }
)

$publishedIds = @()
foreach ($wr in $webResources) {
    $publishedIds += Set-WebResource $wr.Name (Join-Path $root $wr.File) $wr.Type $wr.DisplayName
}

$webResourceXml = ($publishedIds | ForEach-Object { "<webresource>$_</webresource>" }) -join ''
$publishBody = @{ ParameterXml = "<importexportxml><webresources>$webResourceXml</webresources></importexportxml>" } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Post -Uri "$base/PublishXml" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($publishBody)) | Out-Null
Write-Host 'Webresources published.'

Add-EntityToSolutionIfNeeded 'invoice'

if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Force -Path $work | Out-Null

Write-Host "Exporting solution $solution ..."
pac solution export --name $solution --path $exportZip --managed false --overwrite true

Write-Host 'Unpacking solution ...'
pac solution unpack --zipfile $exportZip --folder $unpack --packagetype Unmanaged --allowDelete true --allowWrite true

$entitiesFolder = Join-Path $unpack 'Entities'
$targetFolder = Join-Path $entitiesFolder 'Invoice'
if (-not (Test-Path -LiteralPath $targetFolder)) {
    $targetFolder = Get-ChildItem -LiteralPath $entitiesFolder -Directory | Where-Object { $_.Name -ieq 'invoice' -or $_.Name -ieq 'Invoice' } | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $targetFolder -or -not (Test-Path -LiteralPath $targetFolder)) {
    throw "Unpacked solution does not contain an Invoice entity folder. Is invoice in $solution?"
}

$targetRibbon = Join-Path $targetFolder 'RibbonDiff.xml'
Copy-Item -LiteralPath $ribbonFile -Destination $targetRibbon -Force

[xml]$ribbonXml = Get-Content -Raw -LiteralPath $targetRibbon
$sendIconMap = @{
    '.Send.Email.Button' = '$webresource:alex_payplus_email_icon.svg'
    '.Send.Sms.Button' = '$webresource:alex_payplus_sms_icon.svg'
    '.Send.Whatsapp.Button' = '$webresource:alex_payplus_whatsapp_icon.svg'
}
foreach ($button in @($ribbonXml.SelectNodes('//Button[@Id]'))) {
    foreach ($suffix in $sendIconMap.Keys) {
        if ([string]$button.Id -like "*$suffix") {
            $button.SetAttribute('ModernImage', $sendIconMap[$suffix])
        }
    }
}
$ribbonXml.Save($targetRibbon)

Write-Host 'Packing ribbon solution ...'
pac solution pack --zipfile $importZip --folder $unpack --packagetype Unmanaged --allowDelete true --allowWrite true

Write-Host 'Importing ribbon solution ...'
pac solution import --path $importZip --publish-changes --force-overwrite

Write-Host ''
Write-Host 'DONE. Invoice PayPlus billing command bar was imported and published.'
Write-Host 'Open an Invoice form and hard refresh if the command bar cache is stale.'