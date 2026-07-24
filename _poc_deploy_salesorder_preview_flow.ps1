# Deploy "PayPlus - Preview Sales Order Document" cloud flow.
# Dedicated Sales Order flow derived from the Quote document flow source.

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus_sales_extended_data_model'
$flowName = 'PayPlus - Preview Sales Order Document'
$sourceFlowFile = Join-Path $PSScriptRoot '_conn\flow_create_quote.json'
$documentTypeCode = 'purchase'

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

function New-SalesOrderClientData {
    $raw = Get-Content -Raw -LiteralPath $sourceFlowFile
    $raw = $raw.Replace("triggerOutputs()?['body/quoteid']", "outputs('Compose_trigger_salesorder_id')")
    $raw = $raw.Replace("alex_doc_quote_issue_send_email", "alex_doc_salesorder_issue_send_email")
    $raw = $raw.Replace("alex_doc_quote_issue_send_sms", "alex_doc_salesorder_issue_send_sms")
    $raw = $raw.Replace("Quote ", "Sales Order ")
    $raw = $raw.Replace("PayPlus Quote", "PayPlus Sales Order")
    $raw = $raw.Replace("quotenumber", "ordernumber")
    $raw = $raw.Replace("dc_quote", $documentTypeCode)

    $client = $raw | ConvertFrom-Json -Depth 100
    $client = ConvertTo-Hashtable $client
    $definition = $client.properties.definition

    $definition.triggers = [ordered]@{
        When_a_payplus_sales_order_document_is_requested = [ordered]@{
            metadata = [ordered]@{ operationMetadataId = 'c0000000-0000-4000-8000-000000000070' }
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
                    'subscriptionRequest/filterexpression' = "alex_documenttypecode eq '$documentTypeCode' and alex_lastsyncstatus eq 100000000"
                }
                authentication = "@parameters('`$authentication')"
            }
        }
    }

    $actions = $definition.actions

    $actions.Get_quote.inputs.parameters.entityName = 'salesorders'
    $actions.Get_quote.inputs.parameters.recordId = "@outputs('Compose_trigger_salesorder_id')"
    $actions.Get_quote.inputs.parameters.'$select' = 'name,ordernumber,description,emailaddress,totalamount,totallineitemamount,totallineitemdiscountamount,totaldiscountamount,discountamount,discountpercentage,totaltax,totalamountlessfreight,freightamount,billto_name,billto_line1,billto_city,billto_postalcode,billto_country,billto_telephone,_customerid_value,ispricelocked,statecode,statuscode'
    $actions.Get_quote.inputs.parameters.'$expand' = 'customerid_account,customerid_contact,transactioncurrencyid($select=isocurrencycode,currencyname,currencysymbol,exchangerate)'

    $actions.Get_quote_lines.inputs.parameters.entityName = 'salesorderdetails'
    $actions.Get_quote_lines.inputs.parameters.'$filter' = "_salesorderid_value eq @{outputs('Compose_trigger_salesorder_id')}"

    $definition.actions['Compose_trigger_salesorder_id'] = [ordered]@{
        runAfter = [ordered]@{}
        metadata = [ordered]@{ operationMetadataId = 'c0000000-0000-4000-8000-000000000071' }
        type = 'Compose'
        inputs = "@coalesce(triggerOutputs()?['body/_alex_salesorderid_value'], triggerOutputs()?['body/alex_sourceentityid'])"
    }
    $definition.actions['Compose_preview_unique_identifier'] = [ordered]@{
        runAfter = [ordered]@{ Compose_trigger_salesorder_id = @('Succeeded') }
        metadata = [ordered]@{ operationMetadataId = 'c0000000-0000-4000-8000-000000000072' }
        type = 'Compose'
        inputs = "@coalesce(triggerOutputs()?['body/alex_uniqueidentifier'], triggerOutputs()?['body/alex_payplusdocumentid'], outputs('Compose_trigger_salesorder_id'))"
    }
    $actions.Initialize_items.runAfter = [ordered]@{ Compose_preview_unique_identifier = @('Succeeded') }

    $createByEnv = $actions.Create_quote_by_env
    $actions.Remove('Create_quote_by_env')
    $actions['Create_sales_order_by_env'] = $createByEnv

    $prod = $createByEnv.cases.Production.actions.Create_quote_Production
    $createByEnv.cases.Production.actions.Remove('Create_quote_Production')
    $createByEnv.cases.Production.actions['Create_sales_order_Production'] = $prod

    $sandbox = $createByEnv.cases.Sandbox.actions.Create_quote_Sandbox
    $createByEnv.cases.Sandbox.actions.Remove('Create_quote_Sandbox')
    $createByEnv.cases.Sandbox.actions['Create_sales_order_Sandbox'] = $sandbox

    foreach ($action in @($prod, $sandbox)) {
        $action.inputs.host.operationId = 'CreatePurchaseCertificate'
        $action.inputs.parameters['body/unique_identifier'] = "@outputs('Compose_preview_unique_identifier')"
        $action.inputs.parameters['body/preview'] = "@not(equals(triggerOutputs()?['body/alex_lastoperation'], 'Generate'))"
    }
    $actions.Compose_document_result.runAfter = [ordered]@{ Create_sales_order_by_env = @('Succeeded', 'Failed') }
    $actions.Compose_document_result.inputs = "@coalesce(body('Create_sales_order_Production'), body('Create_sales_order_Sandbox'))"
    $actions.Compose_document_request_snapshot.inputs.unique_identifier = "@outputs('Compose_preview_unique_identifier')"
    $actions.Compose_document_request_snapshot.inputs.preview = "@not(equals(triggerOutputs()?['body/alex_lastoperation'], 'Generate'))"
    $actions.Compose_document_status.inputs = "@if(not(empty(outputs('Compose_document_result')?['`$content'])), 'success', toLower(coalesce(outputs('Compose_document_result')?['results']?['status'], outputs('Compose_document_result')?['status'], outputs('Compose_document_data')?['status'], '')))"

    $documentTypeActionName = @($actions.Keys | Where-Object { $_ -like 'List_document_type_*' } | Select-Object -First 1)[0]
    if (-not $documentTypeActionName) { throw 'Could not find List_document_type_* action in source flow.' }
    $actions[$documentTypeActionName].inputs.parameters.'$filter' = "alex_environment eq @{first(outputs('Get_config_row')?['body/value'])?['alex_environment']} and alex_code eq '$documentTypeCode'"

    $update = $actions.Upsert_payplus_document_row.actions.Update_payplus_document
    $update.runAfter = [ordered]@{ $documentTypeActionName = @('Succeeded') }
    $update.inputs.parameters.recordId = "@triggerOutputs()?['body/alex_payplusdocumentid']"
    $update.inputs.parameters['item/alex_uniqueidentifier'] = "@outputs('Compose_preview_unique_identifier')"
    $update.inputs.parameters['item/alex_name'] = "@concat('PayPlus Sales Order ', coalesce(outputs('Compose_document_data')?['number'], outputs('Compose_document_data')?['document_number'], body('Get_quote')?['ordernumber'], body('Get_quote')?['name'], outputs('Compose_trigger_salesorder_id')))"
    $update.inputs.parameters['item/alex_documenttypecode'] = $documentTypeCode
    $update.inputs.parameters['item/alex_lastoperation'] = "@if(equals(triggerOutputs()?['body/alex_lastoperation'], 'Generate'), 'Generate', 'Preview')"
    $update.inputs.parameters['item/alex_sourceentitylogicalname'] = 'salesorder'
    $update.inputs.parameters['item/alex_sourceentityid'] = "@outputs('Compose_trigger_salesorder_id')"
    $update.inputs.parameters['item/alex_sourcedisplayname'] = "@coalesce(body('Get_quote')?['ordernumber'], body('Get_quote')?['name'], outputs('Compose_trigger_salesorder_id'))"
    if ($update.inputs.parameters.Contains('item/alex_quoteid@odata.bind')) { $update.inputs.parameters.Remove('item/alex_quoteid@odata.bind') }
    $update.inputs.parameters['item/alex_salesorderid@odata.bind'] = "@concat('/salesorders(', outputs('Compose_trigger_salesorder_id'), ')')"

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
    $actions['Update_payplus_sales_order_document'] = $update
    $actions['Condition_payplus_sales_order_document_success'] = [ordered]@{
        runAfter = [ordered]@{ Update_payplus_sales_order_document = @('Succeeded') }
        metadata = [ordered]@{ operationMetadataId = 'c0000000-0000-4000-8000-000000000073' }
        type = 'If'
        expression = [ordered]@{ equals = @("@outputs('Compose_document_status')", 'success') }
        actions = [ordered]@{}
        else = [ordered]@{
            actions = [ordered]@{
                Terminate_payplus_sales_order_document_business_error = [ordered]@{
                    runAfter = [ordered]@{}
                    type = 'Terminate'
                    inputs = [ordered]@{
                        runStatus = 'Failed'
                        runError = [ordered]@{
                            code = 'PayPlusBusinessError'
                            message = "@coalesce(outputs('Compose_document_result')?['results']?['description'], outputs('Compose_document_result')?['description'], outputs('Compose_document_result')?['error'], outputs('Compose_document_result')?['message'], 'PayPlus sales order document operation returned an error.')"
                        }
                    }
                }
            }
        }
    }

    $orderedActions = [ordered]@{}
    foreach ($name in @('Compose_trigger_salesorder_id', 'Compose_preview_unique_identifier')) { $orderedActions[$name] = $actions[$name] }
    foreach ($name in $actions.Keys) { if (-not $orderedActions.Contains($name)) { $orderedActions[$name] = $actions[$name] } }
    $definition.actions = $orderedActions

    return ($client | ConvertTo-Json -Depth 100 -Compress)
}

$clientData = New-SalesOrderClientData
$null = $clientData | ConvertFrom-Json -Depth 100

$nameEsc = $flowName.Replace("'", "''")
$existing = Invoke-RestMethod -Method Get -Uri "$base/workflows?`$select=workflowid,statecode,statuscode&`$filter=name eq '$nameEsc' and category eq 5&`$top=1" -Headers $headers
$workflowId = $null
if ($existing.value.Count -gt 0) { $workflowId = $existing.value[0].workflowid }

if ($workflowId) {
    Write-Host "Updating existing flow $workflowId ..."
    $patch = @{ clientdata = $clientData; description = 'Creates a PayPlus sales order preview/payment request document from a pending alex_payplusdocument row and updates that row for the preview PCF.' } | ConvertTo-Json -Depth 5 -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($patch)) | Out-Null
}
else {
    Write-Host 'Creating new DRAFT flow ...'
    $body = @{
        name = $flowName
        description = 'Creates a PayPlus sales order preview/payment request document from a pending alex_payplusdocument row and updates that row for the preview PCF.'
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
if (-not $workflowId) { throw 'Could not determine sales order preview workflow id.' }

$addBody = @{ ComponentType = 29; ComponentId = $workflowId; SolutionUniqueName = $solution; AddRequiredComponents = $false } | ConvertTo-Json -Compress
try { Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($addBody)) | Out-Null }
catch { Write-Warning "AddSolutionComponent: $($_.Exception.Message)" }

try {
    $activate = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($activate)) | Out-Null
}
catch { Write-Warning "Flow saved but could not be activated via API: $($_.Exception.Message)" }

Write-Host "DONE. Flow '$flowName' = $workflowId."
