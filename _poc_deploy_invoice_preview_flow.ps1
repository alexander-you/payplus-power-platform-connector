# Deploy "PayPlus - Preview Invoice Document" cloud flow.
# Handles generic Invoice billing documents: inv_tax, inv_proforma, inv_pay_request, inv_refund.
# Tax invoice receipt (inv_tax_receipt) is intentionally excluded because it needs a separate receipt/payment process.

param(
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus_sales_extended_data_model'
$flowName = 'PayPlus - Preview Invoice Document'
$sourceFlowFile = Join-Path $PSScriptRoot '_conn\flow_create_quote.json'
$invoiceDocTypes = @('inv_tax', 'inv_proforma', 'inv_pay_request', 'inv_refund')

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

function New-InvoiceClientData {
    $raw = Get-Content -Raw -LiteralPath $sourceFlowFile
    $raw = $raw.Replace("triggerOutputs()?['body/quoteid']", "outputs('Compose_trigger_invoice_id')")
    $raw = $raw.Replace('Get_quote_lines', 'Get_invoice_lines')
    $raw = $raw.Replace('Get_quote', 'Get_invoice')
    $raw = $raw.Replace('Create_quote_by_env', 'Create_invoice_by_env')
    $raw = $raw.Replace('Create_quote_Production', 'Create_invoice_Production')
    $raw = $raw.Replace('Create_quote_Sandbox', 'Create_invoice_Sandbox')
    $raw = $raw.Replace('List_document_type_dc_quote', 'List_document_type_invoice')
    $raw = $raw.Replace('quotedetails', 'invoicedetails')
    $raw = $raw.Replace('quotedetailid', 'invoicedetailid')
    $raw = $raw.Replace('_quoteid_value', '_invoiceid_value')
    $raw = $raw.Replace('alex_quoteid', 'alex_invoiceid')
    $raw = $raw.Replace('/quotes(', '/invoices(')
    $raw = $raw.Replace('quotenumber', 'invoicenumber')
    $raw = $raw.Replace('PayPlus Quote', 'PayPlus Invoice')
    $raw = $raw.Replace('Quote ', 'Invoice ')

    $client = $raw | ConvertFrom-Json -Depth 100
    $client = ConvertTo-Hashtable $client
    $definition = $client.properties.definition

    $filterExpression = "(alex_documenttypecode eq 'inv_tax' or alex_documenttypecode eq 'inv_proforma' or alex_documenttypecode eq 'inv_pay_request' or alex_documenttypecode eq 'inv_refund') and alex_lastsyncstatus eq 100000000"
    $definition.triggers = [ordered]@{
        When_a_payplus_invoice_document_is_requested = [ordered]@{
            metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000070' }
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
                    'subscriptionRequest/filterexpression' = $filterExpression
                }
                authentication = "@parameters('`$authentication')"
            }
        }
    }

    $actions = $definition.actions
    $actions.Get_config_row.inputs.parameters.'$select' = 'alex_payplusconfigurationid,alex_environment,alex_document_vat_mode,alex_paymentpageuidref,alex_terminaluidref,alex_billing_payment_page_policy,alex_billing_create_payment_page_with_document,alex_billing_payment_page_create_token'
    $actions['Initialize_payment_link_items'] = [ordered]@{
        runAfter = [ordered]@{ Initialize_items = @('Succeeded') }
        metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000080' }
        type = 'InitializeVariable'
        inputs = [ordered]@{ variables = @([ordered]@{ name = 'varPaymentLinkItems'; type = 'array'; value = @() }) }
    }
    $actions.Initialize_customer_uid.runAfter = [ordered]@{ Initialize_payment_link_items = @('Succeeded') }

    $actions.Get_invoice.inputs.parameters.entityName = 'invoices'
    $actions.Get_invoice.inputs.parameters.recordId = "@outputs('Compose_trigger_invoice_id')"
    $actions.Get_invoice.inputs.parameters.'$select' = 'name,invoicenumber,description,emailaddress,totalamount,totallineitemamount,totallineitemdiscountamount,totaldiscountamount,discountamount,discountpercentage,totaltax,totalamountlessfreight,freightamount,billto_name,billto_line1,billto_city,billto_postalcode,billto_country,billto_telephone,_customerid_value,statecode,statuscode'
    $actions.Get_invoice.inputs.parameters.'$expand' = 'customerid_account,customerid_contact,transactioncurrencyid($select=isocurrencycode,currencyname,currencysymbol,exchangerate)'
    $actions.Compose_document_more_info.inputs = "@if(or(empty(body('Get_invoice')?['description']), startsWith(trim(body('Get_invoice')?['description']), '{'), startsWith(trim(body('Get_invoice')?['description']), '[')), concat('Invoice ', coalesce(body('Get_invoice')?['invoicenumber'], body('Get_invoice')?['name'], '')), body('Get_invoice')?['description'])"

    $actions.Compose_document_send_email.inputs = $false
    $actions.Compose_document_send_sms.inputs = $false

    $actions.Get_invoice_lines.inputs.parameters.entityName = 'invoicedetails'
    $actions.Get_invoice_lines.inputs.parameters.'$filter' = "_invoiceid_value eq @{outputs('Compose_trigger_invoice_id')}"
    $actions.For_each_line.actions['Append_payment_link_item'] = [ordered]@{
        runAfter = [ordered]@{ Compose_item_vat_type = @('Succeeded') }
        metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000081' }
        type = 'AppendToArrayVariable'
        inputs = [ordered]@{
            name = 'varPaymentLinkItems'
            value = [ordered]@{
                name = "@coalesce(items('For_each_line')?['productname'], items('For_each_line')?['productdescription'], 'פריט')"
                quantity = "@coalesce(items('For_each_line')?['quantity'], 1)"
                price = "@outputs('Compose_item_unit_price')"
                discount_type = 'amount'
                discount_value = "@if(or(lessOrEquals(float(coalesce(body('Get_invoice')?['totaldiscountamount'], 0)), 0), lessOrEquals(float(coalesce(body('Get_invoice')?['totallineitemamount'], 0)), 0)), outputs('Compose_item_discount_amount'), add(float(outputs('Compose_item_discount_amount')), div(mul(float(outputs('Compose_item_net_line_amount')), float(coalesce(body('Get_invoice')?['totaldiscountamount'], 0))), float(coalesce(body('Get_invoice')?['totallineitemamount'], 1)))))"
            }
        }
    }

    $actions['Compose_trigger_invoice_id'] = [ordered]@{
        runAfter = [ordered]@{}
        metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000071' }
        type = 'Compose'
        inputs = "@coalesce(triggerOutputs()?['body/_alex_invoiceid_value'], triggerOutputs()?['body/alex_sourceentityid'])"
    }
    $actions['Compose_preview_unique_identifier'] = [ordered]@{
        runAfter = [ordered]@{ Compose_trigger_invoice_id = @('Succeeded') }
        metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000072' }
        type = 'Compose'
        inputs = "@coalesce(triggerOutputs()?['body/alex_uniqueidentifier'], triggerOutputs()?['body/alex_payplusdocumentid'], outputs('Compose_trigger_invoice_id'))"
    }
    $actions.Initialize_items.runAfter = [ordered]@{ Compose_preview_unique_identifier = @('Succeeded') }

    foreach ($createAction in @($actions.Create_invoice_by_env.cases.Production.actions.Create_invoice_Production, $actions.Create_invoice_by_env.cases.Sandbox.actions.Create_invoice_Sandbox)) {
        $createAction.inputs.host.operationId = 'CreateDocument'
        $createAction.inputs.parameters['docType'] = "@triggerOutputs()?['body/alex_documenttypecode']"
        $createAction.inputs.parameters['body/unique_identifier'] = "@outputs('Compose_preview_unique_identifier')"
        $createAction.inputs.parameters['body/preview'] = "@not(equals(triggerOutputs()?['body/alex_lastoperation'], 'Generate'))"
        $createAction.inputs.parameters['body/prevent_email'] = $true
        $createAction.inputs.parameters['body/cancel_doc'] = "@if(equals(triggerOutputs()?['body/alex_documenttypecode'], 'inv_refund'), json(coalesce(triggerOutputs()?['body/alex_moreinfo'], '{}'))?['cancelDoc'], null)"
    }
    $actions.Compose_document_result.runAfter = [ordered]@{ Create_invoice_by_env = @('Succeeded', 'Failed') }
    $actions.Compose_document_result.inputs = "@coalesce(body('Create_invoice_Production'), body('Create_invoice_Sandbox'))"
    $actions.Compose_document_request_snapshot.inputs.docType = "@triggerOutputs()?['body/alex_documenttypecode']"
    $actions.Compose_document_request_snapshot.inputs.unique_identifier = "@outputs('Compose_preview_unique_identifier')"
    $actions.Compose_document_request_snapshot.inputs.preview = "@not(equals(triggerOutputs()?['body/alex_lastoperation'], 'Generate'))"
    $actions.Compose_document_request_snapshot.inputs.prevent_email = $true
    $actions.Compose_document_request_snapshot.inputs.cancel_doc = "@if(equals(triggerOutputs()?['body/alex_documenttypecode'], 'inv_refund'), json(coalesce(triggerOutputs()?['body/alex_moreinfo'], '{}'))?['cancelDoc'], null)"
    $actions.Compose_document_status.inputs = "@if(not(empty(outputs('Compose_document_result')?['`$content'])), 'success', toLower(coalesce(outputs('Compose_document_result')?['results']?['status'], outputs('Compose_document_result')?['status'], outputs('Compose_document_data')?['status'], '')))"

    $actions.List_document_type_invoice.inputs.parameters.'$filter' = "alex_environment eq @{first(outputs('Get_config_row')?['body/value'])?['alex_environment']} and alex_code eq '@{triggerOutputs()?['body/alex_documenttypecode']}'"

    $update = $actions.Upsert_payplus_document_row.actions.Update_payplus_document
    $update.runAfter = [ordered]@{ List_document_type_invoice = @('Succeeded') }
    $update.inputs.parameters.recordId = "@triggerOutputs()?['body/alex_payplusdocumentid']"
    $update.inputs.parameters['item/alex_uniqueidentifier'] = "@outputs('Compose_preview_unique_identifier')"
    $update.inputs.parameters['item/alex_name'] = "@concat('PayPlus Invoice ', coalesce(outputs('Compose_document_data')?['number'], outputs('Compose_document_data')?['document_number'], body('Get_invoice')?['invoicenumber'], body('Get_invoice')?['name'], outputs('Compose_trigger_invoice_id')))"
    $update.inputs.parameters['item/alex_documenttypeid@odata.bind'] = "@if(empty(first(body('List_document_type_invoice')?['value'])?['alex_payplus_documenttypeid']), null, concat('/alex_payplus_documenttypes(', first(body('List_document_type_invoice')?['value'])?['alex_payplus_documenttypeid'], ')'))"
    $update.inputs.parameters['item/alex_documenttypecode'] = "@triggerOutputs()?['body/alex_documenttypecode']"
    $update.inputs.parameters['item/alex_lastoperation'] = "@if(equals(triggerOutputs()?['body/alex_lastoperation'], 'Generate'), 'Generate', 'Preview')"
    $update.inputs.parameters['item/alex_sourceentitylogicalname'] = 'invoice'
    $update.inputs.parameters['item/alex_sourceentityid'] = "@outputs('Compose_trigger_invoice_id')"
    $update.inputs.parameters['item/alex_sourcedisplayname'] = "@coalesce(body('Get_invoice')?['invoicenumber'], body('Get_invoice')?['name'], outputs('Compose_trigger_invoice_id'))"
    $update.inputs.parameters['item/alex_invoiceid@odata.bind'] = "@concat('/invoices(', outputs('Compose_trigger_invoice_id'), ')')"
    $update.inputs.parameters['item/alex_moreinfo'] = "@if(equals(triggerOutputs()?['body/alex_documenttypecode'], 'inv_refund'), triggerOutputs()?['body/alex_moreinfo'], outputs('Compose_document_more_info'))"
    # Account lookup: bind the customer account, and when the customer is a contact fall back to its parent company (parentcustomerid) if that parent is an account.
    $update.inputs.parameters['item/alex_accountid@odata.bind'] = "@if(equals(outputs('Compose_source_table'), 'account'), concat('/accounts(', body('Get_invoice')?['_customerid_value'], ')'), if(and(not(empty(body('Get_invoice')?['customerid_contact']?['_parentcustomerid_value'])), equals(body('Get_invoice')?['customerid_contact']?['_parentcustomerid_value@Microsoft.Dynamics.CRM.lookuplogicalname'], 'account')), concat('/accounts(', body('Get_invoice')?['customerid_contact']?['_parentcustomerid_value'], ')'), null))"
    # Reversal link: when issuing a credit document (inv_refund) that reverses an original document, point alex_reversesdocumentid at the original.
    $update.inputs.parameters['item/alex_reversesdocumentid@odata.bind'] = "@if(and(equals(triggerOutputs()?['body/alex_documenttypecode'], 'inv_refund'), not(empty(json(coalesce(triggerOutputs()?['body/alex_moreinfo'], '{}'))?['originalDocumentId']))), concat('/alex_payplusdocuments(', json(coalesce(triggerOutputs()?['body/alex_moreinfo'], '{}'))?['originalDocumentId'], ')'), null)"
    if ($update.inputs.parameters.Contains('item/alex_quoteid@odata.bind')) { $update.inputs.parameters.Remove('item/alex_quoteid@odata.bind') }
    if ($update.inputs.parameters.Contains('item/alex_salesorderid@odata.bind')) { $update.inputs.parameters.Remove('item/alex_salesorderid@odata.bind') }

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
    $actions['Update_payplus_invoice_document'] = $update
    $actions['Condition_payplus_invoice_document_success'] = [ordered]@{
        runAfter = [ordered]@{ Update_payplus_invoice_document = @('Succeeded') }
        metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000073' }
        type = 'If'
        expression = [ordered]@{ equals = @("@outputs('Compose_document_status')", 'success') }
        actions = [ordered]@{
            Condition_mark_reversed_invoice_document_cancelled = [ordered]@{
                runAfter = [ordered]@{}
                metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000083' }
                type = 'If'
                expression = [ordered]@{
                    and = @(
                        [ordered]@{ equals = @("@triggerOutputs()?['body/alex_documenttypecode']", 'inv_refund') },
                        [ordered]@{ equals = @("@empty(json(coalesce(triggerOutputs()?['body/alex_moreinfo'], '{}'))?['originalDocumentId'])", $false) }
                    )
                }
                actions = [ordered]@{
                    Update_reversed_invoice_document_cancelled = [ordered]@{
                        runAfter = [ordered]@{}
                        metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000084' }
                        type = 'OpenApiConnection'
                        inputs = [ordered]@{
                            host = [ordered]@{
                                apiId = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                                operationId = 'UpdateRecord'
                                connectionName = 'alex_payplus_dataverse'
                            }
                            parameters = [ordered]@{
                                entityName = 'alex_payplusdocuments'
                                recordId = "@json(coalesce(triggerOutputs()?['body/alex_moreinfo'], '{}'))?['originalDocumentId']"
                                'item/alex_businessstatus' = 100000007
                                'item/alex_relatedinvoicedocumentid@odata.bind' = "@concat('/alex_payplusdocuments(', triggerOutputs()?['body/alex_payplusdocumentid'], ')')"
                            }
                            authentication = "@parameters('`$authentication')"
                        }
                    }
                }
                else = [ordered]@{ actions = [ordered]@{} }
            }
        }
        else = [ordered]@{
            actions = [ordered]@{
                Terminate_payplus_invoice_document_business_error = [ordered]@{
                    runAfter = [ordered]@{}
                    type = 'Terminate'
                    inputs = [ordered]@{
                        runStatus = 'Failed'
                        runError = [ordered]@{
                            code = 'PayPlusBusinessError'
                            message = "@coalesce(outputs('Compose_document_result')?['results']?['description'], outputs('Compose_document_result')?['description'], outputs('Compose_document_result')?['error'], outputs('Compose_document_result')?['message'], 'PayPlus invoice document operation returned an error.')"
                        }
                    }
                }
            }
        }
    }
    $actions['Condition_create_invoice_payment_link'] = [ordered]@{
        runAfter = [ordered]@{ Condition_payplus_invoice_document_success = @('Succeeded') }
        metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000074' }
        type = 'If'
        expression = [ordered]@{
            and = @(
                [ordered]@{ equals = @("@triggerOutputs()?['body/alex_lastoperation']", 'Generate') },
                [ordered]@{ not = [ordered]@{ equals = @("@triggerOutputs()?['body/alex_documenttypecode']", 'inv_refund') } },
                [ordered]@{ equals = @("@first(outputs('Get_config_row')?['body/value'])?['alex_billing_create_payment_page_with_document']", $true) },
                [ordered]@{ not = [ordered]@{ equals = @("@first(outputs('Get_config_row')?['body/value'])?['alex_billing_payment_page_policy']", 100000000) } },
                [ordered]@{ equals = @("@empty(first(outputs('Get_config_row')?['body/value'])?['alex_paymentpageuidref'])", $false) },
                [ordered]@{
                    or = @(
                        [ordered]@{ not = [ordered]@{ equals = @("@first(outputs('Get_config_row')?['body/value'])?['alex_billing_payment_page_policy']", 100000003) } },
                        [ordered]@{ greater = @("@float(coalesce(body('Get_invoice')?['totalamount'], triggerOutputs()?['body/alex_totalamount'], 0))", 0) }
                    )
                }
            )
        }
        actions = [ordered]@{
            Create_invoice_payment_link_by_env = [ordered]@{
                runAfter = [ordered]@{}
                metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000075' }
                type = 'Switch'
                expression = "@first(outputs('Get_config_row')?['body/value'])?['alex_environment']"
                cases = [ordered]@{
                    Production = [ordered]@{
                        case = 100000000
                        actions = [ordered]@{
                            Generate_invoice_payment_link_Production = [ordered]@{
                                runAfter = [ordered]@{}
                                metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000076' }
                                type = 'OpenApiConnection'
                                inputs = [ordered]@{
                                    host = [ordered]@{
                                        apiId = '/providers/Microsoft.PowerApps/apis/shared_alex-5fpayplus-5f5849d39a0feaf28d'
                                        operationId = 'GeneratePaymentLink'
                                        connectionName = 'shared_alex-5fpayplus-5f5849d39a0feaf28d-1'
                                    }
                                    parameters = [ordered]@{
                                        'body/payment_page_uid' = "@first(outputs('Get_config_row')?['body/value'])?['alex_paymentpageuidref']"
                                        'body/terminal_uid' = "@first(outputs('Get_config_row')?['body/value'])?['alex_terminaluidref']"
                                        'body/charge_method' = 1
                                        'body/amount' = "@coalesce(body('Get_invoice')?['totalamount'], triggerOutputs()?['body/alex_totalamount'], 0)"
                                        'body/currency_code' = "@outputs('Compose_document_currency_code')"
                                        'body/more_info' = "@coalesce(triggerOutputs()?['body/alex_uniqueidentifier'], triggerOutputs()?['body/alex_payplusdocumentid'])"
                                        'body/initial_invoice' = $false
                                        'body/sendEmailApproval' = $false
                                        'body/sendEmailFailure' = $false
                                        'body/create_token' = "@coalesce(first(outputs('Get_config_row')?['body/value'])?['alex_billing_payment_page_create_token'], false)"
                                        'body/customer/customer_name' = "@outputs('Compose_customer_keys')?['name']"
                                        'body/customer/email' = "@outputs('Compose_customer_keys')?['email']"
                                        'body/customer/phone' = "@outputs('Compose_customer_keys')?['phone']"
                                        'body/customer/vat_number' = "@outputs('Compose_customer_keys')?['vat']"
                                        'body/items' = "@variables('varPaymentLinkItems')"
                                    }
                                    retryPolicy = [ordered]@{ type = 'none' }
                                    authentication = "@parameters('`$authentication')"
                                }
                            }
                        }
                    }
                    Sandbox = [ordered]@{
                        case = 100000001
                        actions = [ordered]@{
                            Generate_invoice_payment_link_Sandbox = [ordered]@{
                                runAfter = [ordered]@{}
                                metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000077' }
                                type = 'OpenApiConnection'
                                inputs = [ordered]@{
                                    host = [ordered]@{
                                        apiId = '/providers/Microsoft.PowerApps/apis/shared_alex-5fpayplus-20sandbox-5f5849d39a0feaf28d'
                                        operationId = 'GeneratePaymentLink'
                                        connectionName = 'shared_alex-5fpayplus-20sandbox-5f5849d39a0feaf28d-1'
                                    }
                                    parameters = [ordered]@{
                                        'body/payment_page_uid' = "@first(outputs('Get_config_row')?['body/value'])?['alex_paymentpageuidref']"
                                        'body/terminal_uid' = "@first(outputs('Get_config_row')?['body/value'])?['alex_terminaluidref']"
                                        'body/charge_method' = 1
                                        'body/amount' = "@coalesce(body('Get_invoice')?['totalamount'], triggerOutputs()?['body/alex_totalamount'], 0)"
                                        'body/currency_code' = "@outputs('Compose_document_currency_code')"
                                        'body/more_info' = "@coalesce(triggerOutputs()?['body/alex_uniqueidentifier'], triggerOutputs()?['body/alex_payplusdocumentid'])"
                                        'body/initial_invoice' = $false
                                        'body/sendEmailApproval' = $false
                                        'body/sendEmailFailure' = $false
                                        'body/create_token' = "@coalesce(first(outputs('Get_config_row')?['body/value'])?['alex_billing_payment_page_create_token'], false)"
                                        'body/customer/customer_name' = "@outputs('Compose_customer_keys')?['name']"
                                        'body/customer/email' = "@outputs('Compose_customer_keys')?['email']"
                                        'body/customer/phone' = "@outputs('Compose_customer_keys')?['phone']"
                                        'body/customer/vat_number' = "@outputs('Compose_customer_keys')?['vat']"
                                        'body/items' = "@variables('varPaymentLinkItems')"
                                    }
                                    retryPolicy = [ordered]@{ type = 'none' }
                                    authentication = "@parameters('`$authentication')"
                                }
                            }
                        }
                    }
                }
                default = [ordered]@{ actions = [ordered]@{} }
            }
            Compose_invoice_payment_link_result = [ordered]@{
                runAfter = [ordered]@{ Create_invoice_payment_link_by_env = @('Succeeded') }
                metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000078' }
                type = 'Compose'
                inputs = "@coalesce(body('Generate_invoice_payment_link_Production'), body('Generate_invoice_payment_link_Sandbox'))"
            }
            Update_invoice_payment_link = [ordered]@{
                runAfter = [ordered]@{ Compose_invoice_payment_link_result = @('Succeeded') }
                metadata = [ordered]@{ operationMetadataId = 'd0000000-0000-4000-8000-000000000079' }
                type = 'OpenApiConnection'
                inputs = [ordered]@{
                    host = [ordered]@{
                        apiId = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
                        operationId = 'UpdateRecord'
                        connectionName = 'alex_payplus_dataverse'
                    }
                    parameters = [ordered]@{
                        entityName = 'alex_payplusdocuments'
                        recordId = "@triggerOutputs()?['body/alex_payplusdocumentid']"
                        'item/alex_paymentpagelink' = "@if(empty(coalesce(outputs('Compose_invoice_payment_link_result')?['data']?['payment_page_link'], outputs('Compose_invoice_payment_link_result')?['payment_page_link'], '')), null, coalesce(outputs('Compose_invoice_payment_link_result')?['data']?['payment_page_link'], outputs('Compose_invoice_payment_link_result')?['payment_page_link']))"
                        'item/alex_paymentrequestuid' = "@if(empty(coalesce(outputs('Compose_invoice_payment_link_result')?['data']?['page_request_uid'], outputs('Compose_invoice_payment_link_result')?['page_request_uid'], outputs('Compose_document_data')?['payment_request_uid'], outputs('Compose_document_data')?['page_request_uid'], '')), null, coalesce(outputs('Compose_invoice_payment_link_result')?['data']?['page_request_uid'], outputs('Compose_invoice_payment_link_result')?['page_request_uid'], outputs('Compose_document_data')?['payment_request_uid'], outputs('Compose_document_data')?['page_request_uid']))"
                        'item/alex_paymentpageuid' = "@first(outputs('Get_config_row')?['body/value'])?['alex_paymentpageuidref']"
                    }
                    authentication = "@parameters('`$authentication')"
                }
            }
        }
        else = [ordered]@{ actions = [ordered]@{} }
    }

    $orderedActions = [ordered]@{}
    foreach ($name in @('Compose_trigger_invoice_id', 'Compose_preview_unique_identifier')) { $orderedActions[$name] = $actions[$name] }
    foreach ($name in $actions.Keys) { if (-not $orderedActions.Contains($name)) { $orderedActions[$name] = $actions[$name] } }
    $definition.actions = $orderedActions

    return ($client | ConvertTo-Json -Depth 100 -Compress)
}

if ($ValidateOnly) {
    $clientData = New-InvoiceClientData
    $client = $clientData | ConvertFrom-Json -Depth 100
    $definition = $client.properties.definition
    $prod = $definition.actions.Create_invoice_by_env.cases.Production.actions.Create_invoice_Production
    $sandbox = $definition.actions.Create_invoice_by_env.cases.Sandbox.actions.Create_invoice_Sandbox
    [pscustomobject]@{
        FlowName = $flowName
        TriggerFilter = $definition.triggers.When_a_payplus_invoice_document_is_requested.inputs.parameters.'subscriptionRequest/filterexpression'
        ProdOperation = $prod.inputs.host.operationId
        SandboxOperation = $sandbox.inputs.host.operationId
        ProdDocTypeParameter = $prod.inputs.parameters.docType
        IncludesCreditDocument = ($clientData -match 'inv_refund')
        ExcludesTaxInvoiceReceipt = ($clientData -notmatch 'inv_tax_receipt')
        ParseOk = $true
    } | ConvertTo-Json -Depth 5
    return
}

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

function Invoke-Dv {
    param([string]$Method, [string]$Uri, $Body = $null, [switch]$SolutionHeader)
    $h = @{} + $headers
    if ($SolutionHeader) { $h['MSCRM.SolutionUniqueName'] = $solution }
    if ($null -eq $Body) { return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $h }
    $json = $Body | ConvertTo-Json -Depth 100 -Compress
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $h -Body ([Text.Encoding]::UTF8.GetBytes($json))
}

function Try-GetDv([string]$Uri) {
    try { return Invoke-Dv -Method Get -Uri $Uri } catch { return $null }
}

function New-Label([string]$English, [string]$Hebrew) {
    return @{
        LocalizedLabels = @(
            @{ Label = $English; LanguageCode = 1033 },
            @{ Label = $Hebrew; LanguageCode = 1037 }
        )
    }
}

function New-RequiredLevel([string]$Value) {
    return @{ Value = $Value; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
}

function Get-EntityIdFromHeader($ResponseHeaders, [string]$EntitySet) {
    $entityHeader = $ResponseHeaders['OData-EntityId']
    if ($entityHeader -is [array]) { $entityHeader = $entityHeader[0] }
    if ($entityHeader -match "$EntitySet\(([0-9a-fA-F-]{36})\)") { return $Matches[1] }
    return $null
}

function Ensure-InvoiceLookup {
    $existing = Try-GetDv "$base/EntityDefinitions(LogicalName='alex_payplusdocument')/Attributes?`$select=LogicalName&`$filter=LogicalName eq 'alex_invoiceid'"
    if ($existing -and $existing.value.Count -gt 0) {
        Write-Host 'Lookup exists: alex_invoiceid'
        return
    }

    $relationship = Try-GetDv "$base/RelationshipDefinitions(SchemaName='alex_invoice_alex_payplusdocument')?`$select=MetadataId,SchemaName"
    if ($relationship) {
        Write-Host 'Relationship exists: alex_invoice_alex_payplusdocument'
        return
    }

    Write-Host 'Creating invoice lookup on PayPlus Document...'
    $body = @{
        '@odata.type'        = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
        SchemaName           = 'alex_invoice_alex_payplusdocument'
        ReferencedEntity     = 'invoice'
        ReferencingEntity    = 'alex_payplusdocument'
        CascadeConfiguration = @{
            Assign     = 'NoCascade'
            Delete     = 'RemoveLink'
            Merge      = 'NoCascade'
            Reparent   = 'NoCascade'
            Share      = 'NoCascade'
            Unshare    = 'NoCascade'
            RollupView = 'NoCascade'
        }
        Lookup               = @{
            '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'
            SchemaName    = 'alex_invoiceid'
            DisplayName   = New-Label 'Invoice' 'חשבונית'
            Description   = New-Label 'Dynamics 365 Sales invoice related to this PayPlus document.' 'חשבונית ב-Dynamics 365 Sales המקושרת למסמך PayPlus זה.'
            RequiredLevel = New-RequiredLevel 'None'
            Targets       = @('invoice')
        }
    }
    Invoke-Dv -Method Post -Uri "$base/RelationshipDefinitions" -Body $body -SolutionHeader | Out-Null
    Invoke-Dv -Method Post -Uri "$base/PublishXml" -Body @{ ParameterXml = '<importexportxml><entities><entity>alex_payplusdocument</entity><entity>invoice</entity></entities></importexportxml>' } | Out-Null
}

Ensure-InvoiceLookup

$clientData = New-InvoiceClientData
$null = $clientData | ConvertFrom-Json -Depth 100

$nameEsc = $flowName.Replace("'", "''")
$existing = Invoke-Dv -Method Get -Uri "$base/workflows?`$select=workflowid,statecode,statuscode&`$filter=name eq '$nameEsc' and category eq 5&`$top=1"
$workflowId = $null
if ($existing.value.Count -gt 0) { $workflowId = $existing.value[0].workflowid }

if ($workflowId) {
    Write-Host "Updating existing flow $workflowId ..."
    $patch = @{ clientdata = $clientData; description = 'Creates PayPlus invoice/proforma/payment-request preview or issue documents from pending alex_payplusdocument rows and updates those rows for the preview PCF.' } | ConvertTo-Json -Depth 5 -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($patch)) | Out-Null
}
else {
    Write-Host 'Creating new DRAFT flow ...'
    $body = @{
        name = $flowName
        description = 'Creates PayPlus invoice/proforma/payment-request preview or issue documents from pending alex_payplusdocument rows and updates those rows for the preview PCF.'
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
        $created = Invoke-Dv -Method Get -Uri "$base/workflows?`$select=workflowid&`$filter=name eq '$nameEsc' and category eq 5&`$top=1"
        if ($created.value.Count -gt 0) { $workflowId = $created.value[0].workflowid }
    }
}
if (-not $workflowId) { throw 'Could not determine invoice preview workflow id.' }

$addBody = @{ ComponentType = 29; ComponentId = $workflowId; SolutionUniqueName = $solution; AddRequiredComponents = $false } | ConvertTo-Json -Compress
try { Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($addBody)) | Out-Null }
catch { Write-Warning "AddSolutionComponent: $($_.Exception.Message)" }

try {
    $activate = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($activate)) | Out-Null
}
catch { Write-Warning "Flow saved but could not be activated via API: $($_.Exception.Message)" }

Write-Host "DONE. Flow '$flowName' = $workflowId."