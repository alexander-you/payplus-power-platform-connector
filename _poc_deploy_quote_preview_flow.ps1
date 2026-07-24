# Deploy "PayPlus - Preview Quote Document" cloud flow.
# The flow is derived from the activated Quote flow, but is triggered by creating a pending
# alex_payplusdocument row and updates that same row for the PCF preview dialog.

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus_sales_extended_data_model'
$flowName = 'PayPlus - Preview Quote Document'
$sourceFlowFile = Join-Path $PSScriptRoot '_conn\flow_create_quote.json'

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get Dataverse access token.' }

$headers = @{
    Authorization       = "Bearer $token"
    'OData-Version'     = '4.0'
    'OData-MaxVersion'  = '4.0'
    Accept              = 'application/json'
    'Content-Type'      = 'application/json; charset=utf-8'
}
$base = "$org/api/data/v9.2"

function Get-EntityIdFromHeader($ResponseHeaders, [string]$EntitySet) {
    $entityHeader = $ResponseHeaders['OData-EntityId']
    if ($entityHeader -is [array]) { $entityHeader = $entityHeader[0] }
    if ($entityHeader -match "$EntitySet\(([0-9a-fA-F-]{36})\)") { return $Matches[1] }
    return $null
}

function ConvertTo-Hashtable($InputObject) {
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $hash = [ordered]@{}
        foreach ($key in $InputObject.Keys) { $hash[$key] = ConvertTo-Hashtable $InputObject[$key] }
        return $hash
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @($InputObject | ForEach-Object { ConvertTo-Hashtable $_ })
        return ,$items
    }
    if ($InputObject.PSObject.Properties.Count -gt 0 -and $InputObject.GetType().Name -eq 'PSCustomObject') {
        $hash = [ordered]@{}
        foreach ($prop in $InputObject.PSObject.Properties) { $hash[$prop.Name] = ConvertTo-Hashtable $prop.Value }
        return $hash
    }
    return $InputObject
}

function New-PreviewClientData {
    $raw = Get-Content -Raw -LiteralPath $sourceFlowFile
    $raw = $raw.Replace("triggerOutputs()?['body/quoteid']", "outputs('Compose_trigger_quote_id')")
    $client = $raw | ConvertFrom-Json -Depth 100
    $client = ConvertTo-Hashtable $client
    $definition = $client.properties.definition

    $definition.triggers = [ordered]@{
        When_a_payplus_document_preview_is_requested = [ordered]@{
            metadata = [ordered]@{ operationMetadataId = 'b0000000-0000-4000-8000-000000000070' }
            type = 'OpenApiConnectionWebhook'
            inputs = [ordered]@{
                host = [ordered]@{
                    apiId = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                    operationId = 'SubscribeWebhookTrigger'
                    connectionName = 'alex_payplus_dataverse'
                }
                parameters = [ordered]@{
                    'subscriptionRequest/message' = 4
                    'subscriptionRequest/entityname' = 'alex_payplusdocument'
                    'subscriptionRequest/scope' = 4
                    'subscriptionRequest/filteringattributes' = 'alex_lastsyncstatus,alex_lastoperation'
                    'subscriptionRequest/filterexpression' = "alex_documenttypecode eq 'dc_quote' and alex_lastsyncstatus eq 100000000"
                }
                authentication = "@parameters('`$authentication')"
            }
        }
    }

    $actions = $definition.actions
    $actions['Compose_trigger_quote_id'] = [ordered]@{
        runAfter = [ordered]@{}
        metadata = [ordered]@{ operationMetadataId = 'b0000000-0000-4000-8000-000000000071' }
        type = 'Compose'
        inputs = "@coalesce(triggerOutputs()?['body/_alex_quoteid_value'], triggerOutputs()?['body/alex_sourceentityid'])"
    }
    $actions['Compose_preview_unique_identifier'] = [ordered]@{
        runAfter = [ordered]@{ Compose_trigger_quote_id = @('Succeeded') }
        metadata = [ordered]@{ operationMetadataId = 'b0000000-0000-4000-8000-000000000072' }
        type = 'Compose'
        inputs = "@coalesce(triggerOutputs()?['body/alex_uniqueidentifier'], triggerOutputs()?['body/alex_payplusdocumentid'], outputs('Compose_trigger_quote_id'))"
    }
    $actions.Initialize_items.runAfter = [ordered]@{ Compose_preview_unique_identifier = @('Succeeded') }

    $actions.Create_quote_by_env.cases.Production.actions.Create_quote_Production.inputs.parameters['body/unique_identifier'] = "@outputs('Compose_preview_unique_identifier')"
    $actions.Create_quote_by_env.cases.Sandbox.actions.Create_quote_Sandbox.inputs.parameters['body/unique_identifier'] = "@outputs('Compose_preview_unique_identifier')"
    $actions.Create_quote_by_env.cases.Production.actions.Create_quote_Production.inputs.parameters['body/preview'] = "@not(equals(triggerOutputs()?['body/alex_lastoperation'], 'Generate'))"
    $actions.Create_quote_by_env.cases.Sandbox.actions.Create_quote_Sandbox.inputs.parameters['body/preview'] = "@not(equals(triggerOutputs()?['body/alex_lastoperation'], 'Generate'))"
    $actions.Compose_document_request_snapshot.inputs.unique_identifier = "@outputs('Compose_preview_unique_identifier')"
    $actions.Compose_document_request_snapshot.inputs.preview = "@not(equals(triggerOutputs()?['body/alex_lastoperation'], 'Generate'))"
    $actions.Compose_document_status.inputs = "@if(not(empty(outputs('Compose_document_result')?['`$content'])), 'success', toLower(coalesce(outputs('Compose_document_result')?['results']?['status'], outputs('Compose_document_result')?['status'], outputs('Compose_document_data')?['status'], '')))"

    $update = $actions.Upsert_payplus_document_row.actions.Update_payplus_document
    $update.runAfter = [ordered]@{ List_document_type_dc_quote = @('Succeeded') }
    $update.inputs.parameters.recordId = "@triggerOutputs()?['body/alex_payplusdocumentid']"
    $update.inputs.parameters['item/alex_uniqueidentifier'] = "@outputs('Compose_preview_unique_identifier')"
    $update.inputs.parameters['item/alex_lastoperation'] = "@if(equals(triggerOutputs()?['body/alex_lastoperation'], 'Generate'), 'Generate', 'Preview')"
    $rawResponseExpression = @'
@if(not(empty(outputs('Compose_document_result')?['$content'])), concat('{"preview":true,"contentType":"', outputs('Compose_document_result')?['$content-type'], '"}'), replace(replace(string(outputs('Compose_document_result')), decodeUriComponent('%1A'), ''), decodeUriComponent('%00'), ''))
'@
    $rawDocumentExpression = @'
@if(not(empty(outputs('Compose_document_result')?['$content'])), concat('{"html":"<html><body style=\"margin:0;background:#f4f4f4;display:flex;justify-content:center;\"><img style=\"max-width:100%;height:auto;display:block;\" src=\"data:', outputs('Compose_document_result')?['$content-type'], ';base64,', outputs('Compose_document_result')?['$content'], '\" /></body></html>"}'), replace(replace(string(outputs('Compose_document_data')), decodeUriComponent('%1A'), ''), decodeUriComponent('%00'), ''))
'@
    $update.inputs.parameters['item/alex_rawresponse'] = $rawResponseExpression.Trim()
    $update.inputs.parameters['item/alex_rawdocumentjson'] = $rawDocumentExpression.Trim()

    $actions.Remove('List_existing_payplus_document')
    $actions.Remove('Upsert_payplus_document_row')
    $actions['Update_payplus_document_preview'] = $update
    $actions['Condition_payplus_document_success'] = [ordered]@{
        runAfter = [ordered]@{ Update_payplus_document_preview = @('Succeeded') }
        metadata = [ordered]@{ operationMetadataId = 'b0000000-0000-4000-8000-000000000073' }
        type = 'If'
        expression = [ordered]@{ equals = @("@outputs('Compose_document_status')", 'success') }
        actions = [ordered]@{}
        else = [ordered]@{
            actions = [ordered]@{
                Terminate_payplus_document_business_error = [ordered]@{
                    runAfter = [ordered]@{}
                    type = 'Terminate'
                    inputs = [ordered]@{
                        runStatus = 'Failed'
                        runError = [ordered]@{
                            code = 'PayPlusBusinessError'
                            message = "@coalesce(outputs('Compose_document_result')?['results']?['description'], outputs('Compose_document_result')?['description'], outputs('Compose_document_result')?['error'], outputs('Compose_document_result')?['message'], 'PayPlus document operation returned an error.')"
                        }
                    }
                }
            }
        }
    }

    $orderedActions = [ordered]@{}
    foreach ($name in @('Compose_trigger_quote_id', 'Compose_preview_unique_identifier')) {
        $orderedActions[$name] = $actions[$name]
    }
    foreach ($name in $actions.Keys) {
        if (-not $orderedActions.Contains($name)) { $orderedActions[$name] = $actions[$name] }
    }
    $definition.actions = $orderedActions

    return ($client | ConvertTo-Json -Depth 100 -Compress)
}

$clientData = New-PreviewClientData
$null = $clientData | ConvertFrom-Json -Depth 100

$nameEsc = $flowName.Replace("'", "''")
$existing = Invoke-RestMethod -Method Get -Uri "$base/workflows?`$select=workflowid,statecode,statuscode&`$filter=name eq '$nameEsc' and category eq 5" -Headers $headers
$workflowId = $null
if ($existing.value.Count -gt 0) { $workflowId = $existing.value[0].workflowid }

if ($workflowId) {
    Write-Host "Updating existing flow $workflowId ..."
    $patch = @{ clientdata = $clientData; description = 'Creates a PayPlus quote preview document from a pending alex_payplusdocument row and updates that row for the preview PCF.' } | ConvertTo-Json -Depth 5 -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($patch)) | Out-Null
}
else {
    Write-Host 'Creating new DRAFT flow ...'
    $body = @{
        name = $flowName
        description = 'Creates a PayPlus quote preview document from a pending alex_payplusdocument row and updates that row for the preview PCF.'
        category = 5
        type = 1
        primaryentity = 'none'
        statecode = 0
        statuscode = 1
        clientdata = $clientData
    } | ConvertTo-Json -Depth 5 -Compress
    $response = Invoke-WebRequest -Method Post -Uri "$base/workflows" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($body))
    $workflowId = Get-EntityIdFromHeader $response.Headers 'workflows'
    if (-not $workflowId) {
        $created = Invoke-RestMethod -Method Get -Uri "$base/workflows?`$select=workflowid&`$filter=name eq '$nameEsc' and category eq 5&`$top=1" -Headers $headers
        if ($created.value.Count -gt 0) { $workflowId = $created.value[0].workflowid }
    }
}
if (-not $workflowId) { throw 'Could not determine preview workflow id.' }

$addBody = @{ ComponentType = 29; ComponentId = $workflowId; SolutionUniqueName = $solution; AddRequiredComponents = $false } | ConvertTo-Json -Compress
try { Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($addBody)) | Out-Null }
catch { Write-Warning "AddSolutionComponent: $($_.Exception.Message)" }

Write-Host "DONE. Flow '$flowName' = $workflowId (DRAFT unless already active)."
Write-Host 'If the flow is not ON, activate it from the PayPlus extended data model solution in make.powerautomate.com.'