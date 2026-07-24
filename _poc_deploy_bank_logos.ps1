# Uploads the major commercial-bank logos (payplus\bank logo) as Dataverse web resources,
# so the Bank-Accounts PCF can render them by bank code.
#
#   webp -> converted to PNG in-memory via Windows Imaging Component
#   png  -> uploaded as-is (PNG web resource, type 5)
#   svg  -> uploaded as-is (Vector web resource, type 11)
#
# Web resource name pattern: alex_/banklogos/bank_<bankcode>.<ext>
# Fetch URL in the control:  /WebResources/alex_/banklogos/bank_<bankcode>.<ext>
# Idempotent: updates content if the web resource already exists.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore, WindowsBase

$org      = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus'
$logoDir  = 'C:\Users\ayurpolsky\GitHub\payplus\bank logo'

# file name (in bank logo folder) -> Israeli bank code + English display name
$logos = @(
    @{ File = 'logo_Hapoalim.png';                Code = 12; Name = 'Bank Hapoalim' }
    @{ File = 'logo_Leumi.png';                   Code = 10; Name = 'Bank Leumi' }
    @{ File = 'logo_Discount.webp';               Code = 11; Name = 'Israel Discount Bank' }
    @{ File = 'logo_Mizrahi_Tefahot.svg';         Code = 20; Name = 'Mizrahi Tefahot Bank' }
    @{ File = 'logo_First_International_Bank.webp';Code = 31; Name = 'First International Bank' }
    @{ File = 'logo_Mercantile.png';              Code = 17; Name = 'Mercantile Discount Bank' }
    @{ File = 'logo_Jerusalem.webp';              Code = 54; Name = 'Bank of Jerusalem' }
    @{ File = 'logo_Massad.webp';                 Code = 46; Name = 'Bank Massad' }
    @{ File = 'logo_Yahav.webp';                  Code = 4;  Name = 'Bank Yahav' }
    @{ File = 'logo_One_Zero.png';                Code = 18; Name = 'One Zero Digital Bank' }
)

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get access token.' }
$headers = @{
    Authorization              = "Bearer $token"
    'OData-Version'            = '4.0'
    'OData-MaxVersion'         = '4.0'
    Accept                     = 'application/json'
    'Content-Type'             = 'application/json; charset=utf-8'
    'MSCRM.SolutionUniqueName' = $solution
}
$base = "$org/api/data/v9.2"

function Convert-WebpToPngBase64 { param([string]$Path)
    $inStream = [System.IO.File]::OpenRead($Path)
    try {
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create($inStream, 'None', 'OnLoad')
        $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($decoder.Frames[0]))
        $outStream = New-Object System.IO.MemoryStream
        $encoder.Save($outStream)
        return [System.Convert]::ToBase64String($outStream.ToArray())
    } finally { $inStream.Close() }
}

$publishIds = @()
foreach ($logo in $logos) {
    $path = Join-Path $logoDir $logo.File
    if (-not (Test-Path $path)) { Write-Host "  MISSING: $($logo.File)"; continue }
    $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()

    switch ($ext) {
        '.webp' { $content = Convert-WebpToPngBase64 $path; $outExt = 'png'; $type = 5 }
        '.png'  { $content = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($path)); $outExt = 'png'; $type = 5 }
        '.svg'  { $content = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($path)); $outExt = 'svg'; $type = 11 }
        default { Write-Host "  SKIP unsupported ext: $($logo.File)"; continue }
    }

    $name    = "alex_/banklogos/bank_$($logo.Code).$outExt"
    $display = "Bank logo $($logo.Code) - $($logo.Name)"
    $body = @{ name = $name; displayname = $display; webresourcetype = $type; content = $content }

    $existing = Invoke-RestMethod -Method Get -Headers $headers -Uri "$base/webresourceset?`$select=webresourceid&`$filter=name eq '$name'"
    if ($existing.value.Count -gt 0) {
        $id = $existing.value[0].webresourceid
        Write-Host "  update: $name"
        Invoke-RestMethod -Method Patch -Headers $headers -Uri "$base/webresourceset($id)" -Body ([System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress))) | Out-Null
    } else {
        Write-Host "  create: $name"
        $resp = Invoke-WebRequest -Method Post -Headers $headers -Uri "$base/webresourceset" -Body ([System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress)))
        $id = ($resp.Headers['OData-EntityId'] -replace '.*webresourceset\(([0-9a-fA-F-]+)\).*', '$1')
    }
    $publishIds += $id
}

if ($publishIds.Count -gt 0) {
    $webresXml = ($publishIds | ForEach-Object { "<webresource>{$_}</webresource>" }) -join ''
    Write-Host 'Publishing web resources...'
    Invoke-RestMethod -Method Post -Headers $headers -Uri "$base/PublishXml" -Body ([System.Text.Encoding]::UTF8.GetBytes((@{ ParameterXml = "<importexportxml><webresources>$webresXml</webresources></importexportxml>" } | ConvertTo-Json -Compress))) | Out-Null
}
Write-Host "Done. Uploaded $($publishIds.Count) logos."
