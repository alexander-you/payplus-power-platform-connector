# Deploy "PayPlus - Poll Invoice Payments" cloud flow.
# Polls Dataverse PayPlus invoice documents that have a stored payment page link, then reconciles paid PayPlus transactions by more_info.

param(
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus_sales_extended_data_model'
$flowName = 'PayPlus - Poll Invoice Payments'

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

function DvHost([string]$OperationId) {
    return [ordered]@{
        apiId = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
        operationId = $OperationId
        connectionName = 'alex_payplus_dataverse'
    }
}

function PayPlusHost([string]$Environment, [string]$OperationId) {
    if ($Environment -eq 'Production') {
        return [ordered]@{
            apiId = '/providers/Microsoft.PowerApps/apis/shared_alex-5fpayplus-5f5849d39a0feaf28d'
            operationId = $OperationId
            connectionName = 'shared_alex-5fpayplus-5f5849d39a0feaf28d-1'
        }
    }
    return [ordered]@{
        apiId = '/providers/Microsoft.PowerApps/apis/shared_alex-5fpayplus-20sandbox-5f5849d39a0feaf28d'
        operationId = $OperationId
        connectionName = 'shared_alex-5fpayplus-20sandbox-5f5849d39a0feaf28d-1'
    }
}

function DvAction([string]$OperationId, [hashtable]$Parameters, [object]$RunAfter = $null) {
    if ($null -eq $RunAfter) { $RunAfter = [ordered]@{} }
    return [ordered]@{
        runAfter = $RunAfter
        type = 'OpenApiConnection'
        inputs = [ordered]@{
            host = DvHost $OperationId
            parameters = $Parameters
            authentication = "@parameters('`$authentication')"
        }
    }
}

function PayPlusAction([string]$Environment, [string]$OperationId, [hashtable]$Parameters, [object]$RunAfter = $null) {
    if ($null -eq $RunAfter) { $RunAfter = [ordered]@{} }
    return [ordered]@{
        runAfter = $RunAfter
        type = 'OpenApiConnection'
        inputs = [ordered]@{
            host = PayPlusHost $Environment $OperationId
            parameters = $Parameters
            retryPolicy = [ordered]@{ type = 'none' }
            authentication = "@parameters('`$authentication')"
        }
    }
}

function New-ClientData {
    $connectionReferences = [ordered]@{
        alex_payplus_dataverse = [ordered]@{
            runtimeSource = 'embedded'
            connection = [ordered]@{ connectionReferenceLogicalName = 'alex_payplus_dataverse' }
            api = [ordered]@{ name = 'shared_commondataserviceforapps' }
        }
        'shared_alex-5fpayplus-5f5849d39a0feaf28d-1' = [ordered]@{
            runtimeSource = 'embedded'
            connection = [ordered]@{ connectionReferenceLogicalName = 'alex_payplusprod' }
            api = [ordered]@{ name = 'shared_alex-5fpayplus-5f5849d39a0feaf28d'; logicalName = 'alex_5Fpayplus' }
        }
        'shared_alex-5fpayplus-20sandbox-5f5849d39a0feaf28d-1' = [ordered]@{
            runtimeSource = 'embedded'
            connection = [ordered]@{ connectionReferenceLogicalName = 'alex_payplussandbox' }
            api = [ordered]@{ name = 'shared_alex-5fpayplus-20sandbox-5f5849d39a0feaf28d'; logicalName = 'alex_5Fpayplus-20sandbox' }
        }
    }

    $currency = "@coalesce(items('For_each_invoice_document')?['alex_currencycode'], 'ILS')"
    $amount = "@coalesce(items('For_each_invoice_document')?['alex_balanceamount'], items('For_each_invoice_document')?['alex_totalamount'], 0)"
    $transactionUid = "@coalesce(outputs('Compose_first_transaction')?['transaction_uid'], outputs('Compose_first_transaction')?['transaction_uuid'], outputs('Compose_first_transaction')?['uid'], outputs('Compose_first_transaction')?['uuid'], outputs('Compose_first_transaction')?['transaction']?['uid'], outputs('Compose_first_transaction')?['transaction']?['uuid'], outputs('Compose_first_transaction')?['transaction']?['transaction_uid'], outputs('Compose_first_transaction')?['transaction']?['transaction_uuid'], outputs('Compose_first_transaction')?['data']?['transaction_uid'], outputs('Compose_first_transaction')?['data']?['transaction_uuid'], '')"
    $cardLast4 = "@coalesce(outputs('Compose_first_transaction')?['card_information']?['four_digits'], outputs('Compose_first_transaction')?['data']?['card_information']?['four_digits'], '')"
    $cardBrand = "@coalesce(outputs('Compose_first_transaction')?['card_information']?['brand_name'], outputs('Compose_first_transaction')?['data']?['card_information']?['brand_name'], outputs('Compose_first_transaction')?['brand_name'], '')"

    $createReceiptParameters = [ordered]@{
        docType = 'inv_receipt'
        'body/unique_identifier' = "@concat(items('For_each_invoice_document')?['alex_uniqueidentifier'], '-receipt')"
        'body/doc_date' = "@formatDateTime(utcNow(),'yyyy-MM-dd')"
        'body/language' = 'he'
        'body/currency_code' = $currency
        'body/totalAmount' = $amount
        'body/more_info' = "@items('For_each_invoice_document')?['alex_uniqueidentifier']"
        'body/close_doc' = "@if(equals(outputs('Compose_receipt_closes_invoice'), true), items('For_each_invoice_document')?['alex_payplusdocumentuuid'], null)"
        'body/transaction_uuid' = "@outputs('Compose_transaction_uid')"
        'body/prevent_email' = $true
        'body/customer/name' = "@coalesce(items('For_each_invoice_document')?['alex_customername'], 'Customer')"
        'body/customer/email' = "@items('For_each_invoice_document')?['alex_customeremail']"
        'body/customer/phone' = "@items('For_each_invoice_document')?['alex_customerphone']"
        'body/customer/vat_number' = "@items('For_each_invoice_document')?['alex_customervatnumber']"
        'body/items' = "@if(equals(outputs('Compose_receipt_closes_invoice'), true), body('Select_receipt_items'), null)"
        'body/payments' = @([ordered]@{
            payment_type = 'credit-card'
            amount = "@outputs('Compose_paid_amount')"
            date = "@formatDateTime(utcNow(),'yyyy-MM-dd')"
            currency = $currency
            transaction_uid = "@outputs('Compose_transaction_uid')"
            four_digits = $cardLast4
            card_type = $cardBrand
        })
    }

    $actions = [ordered]@{
        Get_config_row = DvAction 'ListRecords' ([ordered]@{
            entityName = 'alex_payplusconfigurations'
            '$select' = 'alex_payplusconfigurationid,alex_environment,alex_billing_auto_receipt_after_payment,alex_billing_auto_close_invoice_when_receipts_match'
            '$top' = 1
        })
        List_waiting_invoice_documents = DvAction 'ListRecords' ([ordered]@{
            entityName = 'alex_payplusdocuments'
            '$select' = 'alex_payplusdocumentid,alex_name,alex_uniqueidentifier,alex_payplusdocumentuuid,alex_documentnumber,alex_paymentrequestuid,alex_paymentpagelink,alex_paymentpageuid,alex_totalamount,alex_balanceamount,alex_currencycode,alex_customername,alex_customeremail,alex_customerphone,alex_customervatnumber,alex_paypluscustomeruid,_alex_billingcaseid_value,_alex_invoiceid_value'
            '$filter' = "alex_sourceentitylogicalname eq 'invoice' and alex_documenttypecode eq 'inv_tax' and alex_lastoperation eq 'Generate' and alex_lastsyncstatus eq 100000001 and alex_businessstatus eq 100000003 and alex_paymentpagelink ne null and alex_paymentrequestuid ne null and alex_uniqueidentifier ne null and alex_payplusdocumentuuid ne null"
            '$top' = 25
        }) ([ordered]@{ Get_config_row = @('Succeeded') })
        For_each_invoice_document = [ordered]@{
            runAfter = [ordered]@{ List_waiting_invoice_documents = @('Succeeded') }
            type = 'Foreach'
            foreach = "@outputs('List_waiting_invoice_documents')?['body/value']"
            runtimeConfiguration = [ordered]@{ concurrency = [ordered]@{ repetitions = 1 } }
            actions = [ordered]@{
                Condition_auto_receipt_enabled = [ordered]@{
                    runAfter = [ordered]@{}
                    type = 'If'
                    expression = [ordered]@{ equals = @("@first(outputs('Get_config_row')?['body/value'])?['alex_billing_auto_receipt_after_payment']", $true) }
                    actions = [ordered]@{
                        Get_current_billing_case = DvAction 'GetItem' ([ordered]@{
                            entityName = 'alex_payplusbillingcases'
                            recordId = "@items('For_each_invoice_document')?['_alex_billingcaseid_value']"
                            '$select' = 'alex_status,alex_paidamount,alex_openbalance'
                        })
                        Switch_view_transactions = [ordered]@{
                            runAfter = [ordered]@{ Get_current_billing_case = @('Succeeded') }
                            type = 'Switch'
                            expression = "@if(or(equals(body('Get_current_billing_case')?['alex_status'], 100000005), equals(body('Get_current_billing_case')?['alex_status'], 100000007)), -1, first(outputs('Get_config_row')?['body/value'])?['alex_environment'])"
                            cases = [ordered]@{
                                Production = [ordered]@{
                                    case = 100000000
                                    actions = [ordered]@{
                                        View_transactions_Production = PayPlusAction 'Production' 'ViewTransactions' ([ordered]@{ 'body/more_info' = "@items('For_each_invoice_document')?['alex_uniqueidentifier']" })
                                    }
                                }
                                Sandbox = [ordered]@{
                                    case = 100000001
                                    actions = [ordered]@{
                                        View_transactions_Sandbox = PayPlusAction 'Sandbox' 'ViewTransactions' ([ordered]@{ 'body/more_info' = "@items('For_each_invoice_document')?['alex_uniqueidentifier']" })
                                    }
                                }
                            }
                            default = [ordered]@{ actions = [ordered]@{} }
                        }
                        Compose_transaction_result = [ordered]@{
                            runAfter = [ordered]@{ Switch_view_transactions = @('Succeeded') }
                            type = 'Compose'
                            inputs = "@coalesce(body('View_transactions_Production'), body('View_transactions_Sandbox'))"
                        }
                        Condition_transaction_found = [ordered]@{
                            runAfter = [ordered]@{ Compose_transaction_result = @('Succeeded') }
                            type = 'If'
                            expression = [ordered]@{
                                and = @(
                                    [ordered]@{ equals = @("@toLower(coalesce(outputs('Compose_transaction_result')?['results']?['status'], ''))", 'success') },
                                    [ordered]@{ not = [ordered]@{ equals = @("@empty(outputs('Compose_transaction_result')?['data'])", $true) } }
                                )
                            }
                            actions = [ordered]@{
                                Compose_first_transaction = [ordered]@{
                                    runAfter = [ordered]@{}
                                    type = 'Compose'
                                    inputs = "@first(outputs('Compose_transaction_result')?['data'])"
                                }
                                Compose_transaction_uid = [ordered]@{
                                    runAfter = [ordered]@{ Compose_first_transaction = @('Succeeded') }
                                    type = 'Compose'
                                    inputs = $transactionUid
                                }
                                Compose_paid_amount = [ordered]@{
                                    runAfter = [ordered]@{ Compose_transaction_uid = @('Succeeded') }
                                    type = 'Compose'
                                    inputs = "@coalesce(outputs('Compose_first_transaction')?['amount'], outputs('Compose_first_transaction')?['transaction']?['amount'], outputs('Compose_first_transaction')?['data']?['amount'], items('For_each_invoice_document')?['alex_balanceamount'], items('For_each_invoice_document')?['alex_totalamount'], 0)"
                                }
                                Compose_total_paid_after_receipt = [ordered]@{
                                    runAfter = [ordered]@{ Compose_paid_amount = @('Succeeded') }
                                    type = 'Compose'
                                    inputs = "@add(float(coalesce(items('For_each_invoice_document')?['alex_paidamount'], 0)), float(outputs('Compose_paid_amount')))"
                                }
                                Compose_receipt_closes_invoice = [ordered]@{
                                    runAfter = [ordered]@{ Compose_total_paid_after_receipt = @('Succeeded') }
                                    type = 'Compose'
                                    inputs = "@and(equals(first(outputs('Get_config_row')?['body/value'])?['alex_billing_auto_close_invoice_when_receipts_match'], true), greaterOrEquals(float(outputs('Compose_total_paid_after_receipt')), float(coalesce(items('For_each_invoice_document')?['alex_totalamount'], 0))))"
                                }
                                Select_receipt_items = [ordered]@{
                                    runAfter = [ordered]@{ Compose_receipt_closes_invoice = @('Succeeded') }
                                    type = 'Select'
                                    inputs = [ordered]@{
                                        from = "@if(equals(outputs('Compose_receipt_closes_invoice'), true), coalesce(outputs('Compose_first_transaction')?['data']?['items'], json('[]')), json('[]'))"
                                        select = [ordered]@{
                                            name = "@coalesce(item()?['name'], 'Payment item')"
                                            quantity = "@coalesce(item()?['quantity'], 1)"
                                            price = "@coalesce(item()?['quantity_price'], item()?['price'], item()?['amount_pay'], 0)"
                                            discount_type = 'amount'
                                            discount_value = "@coalesce(item()?['discount_amount'], item()?['discount_value'], 0)"
                                        }
                                    }
                                }
                                Condition_transaction_ready = [ordered]@{
                                    runAfter = [ordered]@{ Select_receipt_items = @('Succeeded') }
                                    type = 'If'
                                    expression = [ordered]@{ not = [ordered]@{ equals = @("@empty(outputs('Compose_transaction_uid'))", $true) } }
                                    actions = [ordered]@{
                                        Switch_create_receipt = [ordered]@{
                                            runAfter = [ordered]@{}
                                            type = 'Switch'
                                            expression = "@first(outputs('Get_config_row')?['body/value'])?['alex_environment']"
                                            cases = [ordered]@{
                                                Production = [ordered]@{
                                                    case = 100000000
                                                    actions = [ordered]@{ Create_receipt_Production = PayPlusAction 'Production' 'CreateDocument' $createReceiptParameters }
                                                }
                                                Sandbox = [ordered]@{
                                                    case = 100000001
                                                    actions = [ordered]@{ Create_receipt_Sandbox = PayPlusAction 'Sandbox' 'CreateDocument' $createReceiptParameters }
                                                }
                                            }
                                            default = [ordered]@{ actions = [ordered]@{} }
                                        }
                                        Compose_receipt_result = [ordered]@{
                                            runAfter = [ordered]@{ Switch_create_receipt = @('Succeeded') }
                                            type = 'Compose'
                                            inputs = "@coalesce(body('Create_receipt_Production'), body('Create_receipt_Sandbox'))"
                                        }
                                        Compose_receipt_data = [ordered]@{
                                            runAfter = [ordered]@{ Compose_receipt_result = @('Succeeded') }
                                            type = 'Compose'
                                            inputs = "@coalesce(outputs('Compose_receipt_result')?['data'], outputs('Compose_receipt_result')?['details'], json('{}'))"
                                        }
                                        Compose_receipt_status = [ordered]@{
                                            runAfter = [ordered]@{ Compose_receipt_data = @('Succeeded') }
                                            type = 'Compose'
                                            inputs = "@toLower(coalesce(outputs('Compose_receipt_result')?['results']?['status'], outputs('Compose_receipt_result')?['status'], outputs('Compose_receipt_data')?['status'], ''))"
                                        }
                                        Condition_receipt_success = [ordered]@{
                                            runAfter = [ordered]@{ Compose_receipt_status = @('Succeeded') }
                                            type = 'If'
                                            expression = [ordered]@{ equals = @("@outputs('Compose_receipt_status')", 'success') }
                                            actions = [ordered]@{
                                                List_receipt_document_type = DvAction 'ListRecords' ([ordered]@{
                                                    entityName = 'alex_payplus_documenttypes'
                                                    '$select' = 'alex_payplus_documenttypeid,alex_code,alex_environment'
                                                    '$filter' = "alex_environment eq @{first(outputs('Get_config_row')?['body/value'])?['alex_environment']} and alex_code eq 'inv_receipt'"
                                                    '$top' = 1
                                                })
                                                Create_receipt_payplus_document = DvAction 'CreateRecord' ([ordered]@{
                                                    entityName = 'alex_payplusdocuments'
                                                    'item/alex_name' = "@concat('PayPlus Receipt ', coalesce(outputs('Compose_receipt_data')?['number'], outputs('Compose_receipt_data')?['document_number'], outputs('Compose_transaction_uid')))"
                                                    'item/alex_configurationid@odata.bind' = "@concat('/alex_payplusconfigurations(', first(outputs('Get_config_row')?['body/value'])?['alex_payplusconfigurationid'], ')')"
                                                    'item/alex_environment' = "@first(outputs('Get_config_row')?['body/value'])?['alex_environment']"
                                                    'item/alex_documenttypeid@odata.bind' = "@if(empty(first(body('List_receipt_document_type')?['value'])?['alex_payplus_documenttypeid']), null, concat('/alex_payplus_documenttypes(', first(body('List_receipt_document_type')?['value'])?['alex_payplus_documenttypeid'], ')'))"
                                                    'item/alex_documenttypecode' = 'inv_receipt'
                                                    'item/alex_payplusdocumentuuid' = "@if(empty(coalesce(outputs('Compose_receipt_data')?['uuid'], outputs('Compose_receipt_data')?['document_uuid'], outputs('Compose_receipt_data')?['document_uid'], outputs('Compose_receipt_data')?['docUID'], outputs('Compose_receipt_data')?['doc_uid'], '')), null, coalesce(outputs('Compose_receipt_data')?['uuid'], outputs('Compose_receipt_data')?['document_uuid'], outputs('Compose_receipt_data')?['document_uid'], outputs('Compose_receipt_data')?['docUID'], outputs('Compose_receipt_data')?['doc_uid']))"
                                                    'item/alex_uniqueidentifier' = "@concat(items('For_each_invoice_document')?['alex_uniqueidentifier'], '-receipt')"
                                                    'item/alex_documentnumber' = "@if(empty(coalesce(outputs('Compose_receipt_data')?['number'], outputs('Compose_receipt_data')?['document_number'], '')), null, coalesce(outputs('Compose_receipt_data')?['number'], outputs('Compose_receipt_data')?['document_number']))"
                                                    'item/alex_documentdate' = "@formatDateTime(utcNow(),'yyyy-MM-dd')"
                                                    'item/alex_issuedon' = "@utcNow()"
                                                    'item/alex_lastoperationon' = "@utcNow()"
                                                    'item/alex_lastrefreshedon' = "@utcNow()"
                                                    'item/alex_currencycode' = $currency
                                                    'item/alex_totalamount' = "@outputs('Compose_paid_amount')"
                                                    'item/alex_paidamount' = "@outputs('Compose_paid_amount')"
                                                    'item/alex_balanceamount' = 0
                                                    'item/alex_customername' = "@items('For_each_invoice_document')?['alex_customername']"
                                                    'item/alex_customeremail' = "@items('For_each_invoice_document')?['alex_customeremail']"
                                                    'item/alex_customerphone' = "@items('For_each_invoice_document')?['alex_customerphone']"
                                                    'item/alex_customervatnumber' = "@items('For_each_invoice_document')?['alex_customervatnumber']"
                                                    'item/alex_transactionuid' = "@outputs('Compose_transaction_uid')"
                                                    'item/alex_paymentrequestuid' = "@items('For_each_invoice_document')?['alex_paymentrequestuid']"
                                                    'item/alex_paymentpagelink' = "@items('For_each_invoice_document')?['alex_paymentpagelink']"
                                                    'item/alex_paymentpageuid' = "@items('For_each_invoice_document')?['alex_paymentpageuid']"
                                                    'item/alex_moreinfo' = "@items('For_each_invoice_document')?['alex_uniqueidentifier']"
                                                    'item/alex_parentdocumentid@odata.bind' = "@concat('/alex_payplusdocuments(', items('For_each_invoice_document')?['alex_payplusdocumentid'], ')')"
                                                    'item/alex_relatedinvoicedocumentid@odata.bind' = "@concat('/alex_payplusdocuments(', items('For_each_invoice_document')?['alex_payplusdocumentid'], ')')"
                                                    'item/alex_billingcaseid@odata.bind' = "@if(empty(items('For_each_invoice_document')?['_alex_billingcaseid_value']), null, concat('/alex_payplusbillingcases(', items('For_each_invoice_document')?['_alex_billingcaseid_value'], ')'))"
                                                    'item/alex_invoiceid@odata.bind' = "@if(empty(items('For_each_invoice_document')?['_alex_invoiceid_value']), null, concat('/invoices(', items('For_each_invoice_document')?['_alex_invoiceid_value'], ')'))"
                                                    'item/alex_documentrole' = 100000002
                                                    'item/alex_lastoperation' = 'Generate'
                                                    'item/alex_lastsyncstatus' = 100000001
                                                    'item/alex_businessstatus' = 100000003
                                                    'item/alex_origin' = 100000000
                                                    'item/alex_payplusresultstatus' = "@outputs('Compose_receipt_status')"
                                                    'item/alex_rawrequest' = "@string(outputs('Compose_first_transaction'))"
                                                    'item/alex_rawresponse' = "@string(outputs('Compose_receipt_result'))"
                                                    'item/alex_rawdocumentjson' = "@string(outputs('Compose_receipt_data'))"
                                                    'item/alex_paymentsjson' = "@string(createArray(outputs('Compose_first_transaction')))"
                                                }) ([ordered]@{ List_receipt_document_type = @('Succeeded') })
                                                Create_payment_line = DvAction 'CreateRecord' ([ordered]@{
                                                    entityName = 'alex_paypluspaymentlines'
                                                    'item/alex_name' = "@concat('PayPlus transaction ', outputs('Compose_transaction_uid'))"
                                                    'item/alex_billingcaseid@odata.bind' = "@if(empty(items('For_each_invoice_document')?['_alex_billingcaseid_value']), null, concat('/alex_payplusbillingcases(', items('For_each_invoice_document')?['_alex_billingcaseid_value'], ')'))"
                                                    'item/alex_receiptdocumentid@odata.bind' = "@concat('/alex_payplusdocuments(', body('Create_receipt_payplus_document')?['alex_payplusdocumentid'], ')')"
                                                    'item/alex_sequence' = 1
                                                    'item/alex_chargemode' = 100000003
                                                    'item/alex_paymentmethod' = 100000004
                                                    'item/alex_status' = 100000002
                                                    'item/alex_amount' = "@outputs('Compose_paid_amount')"
                                                    'item/alex_currencycode' = $currency
                                                    'item/alex_paymentdate' = "@utcNow()"
                                                    'item/alex_reference' = "@items('For_each_invoice_document')?['alex_paymentrequestuid']"
                                                    'item/alex_externaltransactionid' = "@outputs('Compose_transaction_uid')"
                                                    'item/alex_cardlast4' = $cardLast4
                                                    'item/alex_cardbrand' = $cardBrand
                                                    'item/alex_rawpaymentjson' = "@string(outputs('Compose_first_transaction'))"
                                                }) ([ordered]@{ Create_receipt_payplus_document = @('Succeeded') })
                                                Create_receipt_allocation = DvAction 'CreateRecord' ([ordered]@{
                                                    entityName = 'alex_payplusreceiptallocations'
                                                    'item/alex_name' = "@concat('Allocation ', outputs('Compose_transaction_uid'))"
                                                    'item/alex_billingcaseid@odata.bind' = "@if(empty(items('For_each_invoice_document')?['_alex_billingcaseid_value']), null, concat('/alex_payplusbillingcases(', items('For_each_invoice_document')?['_alex_billingcaseid_value'], ')'))"
                                                    'item/alex_paymentlineid@odata.bind' = "@concat('/alex_paypluspaymentlines(', body('Create_payment_line')?['alex_paypluspaymentlineid'], ')')"
                                                    'item/alex_invoicedocumentid@odata.bind' = "@concat('/alex_payplusdocuments(', items('For_each_invoice_document')?['alex_payplusdocumentid'], ')')"
                                                    'item/alex_receiptdocumentid@odata.bind' = "@concat('/alex_payplusdocuments(', body('Create_receipt_payplus_document')?['alex_payplusdocumentid'], ')')"
                                                    'item/alex_allocatedamount' = "@outputs('Compose_paid_amount')"
                                                    'item/alex_currencycode' = $currency
                                                    'item/alex_status' = 100000001
                                                    'item/alex_allocatedon' = "@utcNow()"
                                                }) ([ordered]@{ Create_payment_line = @('Succeeded') })
                                                Update_invoice_document_closed = DvAction 'UpdateRecord' ([ordered]@{
                                                    entityName = 'alex_payplusdocuments'
                                                    recordId = "@items('For_each_invoice_document')?['alex_payplusdocumentid']"
                                                    'item/alex_paidamount' = "@outputs('Compose_total_paid_after_receipt')"
                                                    'item/alex_balanceamount' = "@if(greaterOrEquals(float(outputs('Compose_total_paid_after_receipt')), float(coalesce(items('For_each_invoice_document')?['alex_totalamount'], 0))), 0, sub(float(coalesce(items('For_each_invoice_document')?['alex_totalamount'], 0)), float(outputs('Compose_total_paid_after_receipt'))))"
                                                    'item/alex_transactionuid' = "@outputs('Compose_transaction_uid')"
                                                    'item/alex_businessstatus' = "@if(equals(outputs('Compose_receipt_closes_invoice'), true), 100000008, 100000003)"
                                                    'item/alex_lastrefreshedon' = "@utcNow()"
                                                }) ([ordered]@{ Create_receipt_allocation = @('Succeeded') })
                                                Update_billing_case_closed = DvAction 'UpdateRecord' ([ordered]@{
                                                    entityName = 'alex_payplusbillingcases'
                                                    recordId = "@items('For_each_invoice_document')?['_alex_billingcaseid_value']"
                                                    'item/alex_paidamount' = "@outputs('Compose_total_paid_after_receipt')"
                                                    'item/alex_openbalance' = "@if(greaterOrEquals(float(outputs('Compose_total_paid_after_receipt')), float(coalesce(items('For_each_invoice_document')?['alex_totalamount'], 0))), 0, sub(float(coalesce(items('For_each_invoice_document')?['alex_totalamount'], 0)), float(outputs('Compose_total_paid_after_receipt'))))"
                                                    'item/alex_status' = "@if(equals(outputs('Compose_receipt_closes_invoice'), true), 100000005, 100000004)"
                                                    'item/alex_closedon' = "@if(equals(outputs('Compose_receipt_closes_invoice'), true), utcNow(), null)"
                                                }) ([ordered]@{ Update_invoice_document_closed = @('Succeeded') })
                                                Condition_close_dynamics_invoice = [ordered]@{
                                                    runAfter = [ordered]@{ Update_billing_case_closed = @('Succeeded') }
                                                    type = 'If'
                                                    expression = [ordered]@{ equals = @("@outputs('Compose_receipt_closes_invoice')", $true) }
                                                    actions = [ordered]@{
                                                        Update_dynamics_invoice_paid = DvAction 'UpdateRecord' ([ordered]@{
                                                            entityName = 'invoices'
                                                            recordId = "@items('For_each_invoice_document')?['_alex_invoiceid_value']"
                                                            'item/statecode' = 2
                                                            'item/statuscode' = 100001
                                                        })
                                                    }
                                                    else = [ordered]@{ actions = [ordered]@{} }
                                                }
                                            }
                                            else = [ordered]@{
                                                actions = [ordered]@{
                                                    Update_invoice_document_receipt_failed = DvAction 'UpdateRecord' ([ordered]@{
                                                        entityName = 'alex_payplusdocuments'
                                                        recordId = "@items('For_each_invoice_document')?['alex_payplusdocumentid']"
                                                        'item/alex_lastsyncstatus' = 100000003
                                                        'item/alex_lasterror' = "@coalesce(outputs('Compose_receipt_result')?['results']?['description'], outputs('Compose_receipt_result')?['description'], outputs('Compose_receipt_result')?['error'], outputs('Compose_receipt_result')?['message'], 'Receipt creation failed')"
                                                    })
                                                }
                                            }
                                        }
                                    }
                                    else = [ordered]@{ actions = [ordered]@{} }
                                }
                            }
                            else = [ordered]@{ actions = [ordered]@{} }
                        }
                    }
                    else = [ordered]@{ actions = [ordered]@{} }
                }
            }
        }
    }

    $definition = [ordered]@{
        '$schema' = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
        contentVersion = '1.0.0.0'
        parameters = [ordered]@{
            '$connections' = [ordered]@{ defaultValue = [ordered]@{}; type = 'Object' }
            '$authentication' = [ordered]@{ defaultValue = [ordered]@{}; type = 'SecureObject' }
        }
        triggers = [ordered]@{
            Every_5_minutes = [ordered]@{
                type = 'Recurrence'
                recurrence = [ordered]@{ frequency = 'Minute'; interval = 5 }
            }
        }
        actions = $actions
    }

    $client = [ordered]@{
        schemaVersion = '1.0.0.0'
        properties = [ordered]@{
            connectionReferences = $connectionReferences
            definition = $definition
        }
    }
    return ($client | ConvertTo-Json -Depth 100 -Compress)
}

if ($ValidateOnly) {
    $clientData = New-ClientData
    $client = $clientData | ConvertFrom-Json -Depth 100
    [pscustomobject]@{
        FlowName = $flowName
        Trigger = ($client.properties.definition.triggers.PSObject.Properties.Name -join ',')
        HasViewTransactions = ($clientData -match 'ViewTransactions')
        HasCreateReceipt = ($clientData -match 'inv_receipt')
        HasCloseDoc = ($clientData -match 'body/close_doc')
        HasDataverseFilter = ($clientData -match 'alex_paymentrequestuid ne null')
        ParseOk = $true
    } | ConvertTo-Json -Depth 5
    return
}

$clientData = New-ClientData
$null = $clientData | ConvertFrom-Json -Depth 100

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

function Get-EntityIdFromHeader($ResponseHeaders, [string]$EntitySet) {
    $entityHeader = $ResponseHeaders['OData-EntityId']
    if ($entityHeader -is [array]) { $entityHeader = $entityHeader[0] }
    if ($entityHeader -match "$EntitySet\(([0-9a-fA-F-]{36})\)") { return $Matches[1] }
    return $null
}

$nameEsc = $flowName.Replace("'", "''")
$existing = Invoke-Dv -Method Get -Uri "$base/workflows?`$select=workflowid,statecode,statuscode&`$filter=name eq '$nameEsc' and category eq 5&`$top=1"
$workflowId = $null
if ($existing.value.Count -gt 0) { $workflowId = $existing.value[0].workflowid }

if ($workflowId) {
    Write-Host "Updating existing flow $workflowId ..."
    $patch = @{ clientdata = $clientData; description = 'Polls Dataverse PayPlus invoice documents waiting for payment, reconciles paid PayPlus transactions, creates receipts, and closes billing cases.' } | ConvertTo-Json -Depth 5 -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($patch)) | Out-Null
}
else {
    Write-Host 'Creating new DRAFT flow ...'
    $body = @{
        name = $flowName
        description = 'Polls Dataverse PayPlus invoice documents waiting for payment, reconciles paid PayPlus transactions, creates receipts, and closes billing cases.'
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
if (-not $workflowId) { throw 'Could not determine invoice payment poll workflow id.' }

$addBody = @{ ComponentType = 29; ComponentId = $workflowId; SolutionUniqueName = $solution; AddRequiredComponents = $false } | ConvertTo-Json -Compress
try { Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($addBody)) | Out-Null }
catch { Write-Warning "AddSolutionComponent: $($_.Exception.Message)" }

try {
    $activate = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($activate)) | Out-Null
}
catch { Write-Warning "Flow saved but could not be activated via API: $($_.Exception.Message)" }

Write-Host "DONE. Flow '$flowName' = $workflowId."