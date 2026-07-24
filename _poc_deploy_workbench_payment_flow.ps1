# Deploy "PayPlus - Process Workbench Payment" cloud flow.
# This flow processes Payment Workbench payment lines:
# - saved-card lines: performs the direct token charge through ChargeSavedCard
# - hosted-fields lines: verifies the PayPlus transaction through ViewTransactions

param(
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

$org = 'https://demo-contact-center-en.crm4.dynamics.com'
$solution = 'alex_d365_payplus'
$flowName = 'PayPlus - Process Workbench Payment'

function DvHost([string]$OperationId) {
    [ordered]@{
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
    [ordered]@{
        apiId = '/providers/Microsoft.PowerApps/apis/shared_alex-5fpayplus-20sandbox-5f5849d39a0feaf28d'
        operationId = $OperationId
        connectionName = 'shared_alex-5fpayplus-20sandbox-5f5849d39a0feaf28d-1'
    }
}

function DvAction([string]$OperationId, [object]$Parameters, [object]$RunAfter = $null) {
    if ($null -eq $RunAfter) { $RunAfter = [ordered]@{} }
    [ordered]@{
        runAfter = $RunAfter
        type = 'OpenApiConnection'
        inputs = [ordered]@{
            host = DvHost $OperationId
            parameters = $Parameters
            authentication = "@parameters('`$authentication')"
        }
    }
}

function PayPlusAction([string]$Environment, [string]$OperationId, [object]$Parameters, [object]$RunAfter = $null) {
    if ($null -eq $RunAfter) { $RunAfter = [ordered]@{} }
    [ordered]@{
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

function FinalizePaymentActions([string]$Prefix, [object]$RunAfter, [string]$TransactionObjectReference, [string]$RawJsonExpression, [string]$TransactionUidExpression, [string]$CardLast4Expression, [string]$CardBrandExpression, [string]$ApprovalExpression, [string]$PaymentType = 'credit-card', [string]$BankExpression = '', [string]$BranchExpression = '', [string]$AccountNumberExpression = '', [bool]$RequireTransactionUid = $true) {
    $updateLine = "Update_payment_line_cleared_$Prefix"
    $listAllocations = "List_allocations_$Prefix"
    $forEachAllocation = "For_each_allocation_$Prefix"
    $composePaid = "Compose_paid_after_$Prefix"
    $composeOpen = "Compose_open_after_$Prefix"
    $updateCase = "Update_billing_case_$Prefix"
    $composeReceiptTransactionUid = "Compose_receipt_transaction_uid_$Prefix"
    $composeReceiptCardLast4 = "Compose_receipt_card_last4_$Prefix"
    $composeReceiptCardBrand = "Compose_receipt_card_brand_$Prefix"
    $composeReceiptUnique = "Compose_receipt_unique_identifier_$Prefix"
    $listInvoiceDocument = "List_invoice_document_for_receipt_$Prefix"
    $composeEffectiveDocType = "Compose_effective_doctype_$Prefix"
    $selectReceiptItems = "Select_receipt_items_$Prefix"
    $conditionIssueReceipt = "Condition_issue_receipt_$Prefix"
    $switchCreateReceipt = "Switch_create_receipt_$Prefix"
    $createReceiptProduction = "Create_receipt_Production_$Prefix"
    $createReceiptSandbox = "Create_receipt_Sandbox_$Prefix"
    $composeReceiptResultPrimary = "Compose_receipt_result_primary_$Prefix"
    $composeReceiptStatusPrimary = "Compose_receipt_status_primary_$Prefix"
    $conditionRetryWithoutClose = "Condition_retry_without_close_$Prefix"
    $switchCreateReceiptRetry = "Switch_create_receipt_retry_$Prefix"
    $createReceiptRetryProduction = "Create_receipt_retry_Production_$Prefix"
    $createReceiptRetrySandbox = "Create_receipt_retry_Sandbox_$Prefix"
    $composeReceiptResult = "Compose_receipt_result_$Prefix"
    $composeReceiptData = "Compose_receipt_data_$Prefix"
    $composeReceiptStatus = "Compose_receipt_status_$Prefix"
    $conditionReceiptSuccess = "Condition_receipt_success_$Prefix"
    $listReceiptDocumentType = "List_receipt_document_type_$Prefix"
    $createReceiptDocument = "Create_receipt_payplus_document_$Prefix"
    $updateLineReceipt = "Update_payment_line_receipt_linked_$Prefix"
    $forEachAllocationReceipt = "For_each_allocation_receipt_$Prefix"
    $conditionHasInvoiceDocument = "Condition_has_invoice_document_$Prefix"
    $updateInvoiceDocument = "Update_invoice_document_receipted_$Prefix"
    $conditionCloseDynamicsInvoice = "Condition_close_dynamics_invoice_$Prefix"
    $updateDynamicsInvoice = "Update_dynamics_invoice_paid_$Prefix"
    $updateCaseReceiptIssued = "Update_billing_case_receipt_issued_$Prefix"
    $updateLineReceiptFailed = "Update_payment_line_receipt_failed_$Prefix"
    $updateCaseReceiptFailed = "Update_billing_case_receipt_failed_$Prefix"

    $currencyExpression = "@coalesce(body('Get_payment_line')?['alex_currencycode'], body('Get_billing_case')?['alex_currencycode'], 'ILS')"
    $amountExpression = "@coalesce(body('Get_payment_line')?['alex_amount'], 0)"
    $resolvedInvoiceIdRaw = "coalesce(first(outputs('$listInvoiceDocument')?['body/value'])?['_alex_invoiceid_value'], if(equals(body('Get_billing_case')?['alex_sourceentitylogicalname'], 'invoice'), body('Get_billing_case')?['alex_sourceentityid'], ''))"
    # Label used in the receipt-failure rollback messages for recorded (no online charge) payments.
    $recordedRollbackLabel = if ($PaymentType -eq 'cheque') { 'Checks' } else { 'Bank transfer' }
    if ($PaymentType -eq 'bank-transfer') {
        $paymentsArray = @([ordered]@{
            payment_type = 'bank-transfer'
            amount = $amountExpression
            date = "@formatDateTime(utcNow(),'yyyy-MM-dd')"
            currency = $currencyExpression
            bank = $BankExpression
            bank_number = $BankExpression
            branch = $BranchExpression
            branch_number = $BranchExpression
            account_number = $AccountNumberExpression
        })
    } elseif ($PaymentType -eq 'cheque') {
        # A check series produces one receipt listing every cheque. The PCF stores the fully
        # mapped PayPlus cheque array on the payment line notes; the flow passes it through as-is.
        # PayPlus support confirmed the correct token is "payment-check". Normalize legacy notes
        # that used "cheque" or "check" so previously-recorded lines also send "payment-check".
        $paymentsArray = "@json(replace(replace(body('Get_payment_line')?['alex_notes'], '`"payment_type`":`"cheque`"', '`"payment_type`":`"payment-check`"'), '`"payment_type`":`"check`"', '`"payment_type`":`"payment-check`"'))?['payplusPayments']"
    } else {
        $paymentsArray = @([ordered]@{
            payment_type = 'credit-card'
            amount = $amountExpression
            date = "@formatDateTime(utcNow(),'yyyy-MM-dd')"
            currency = $currencyExpression
            transaction_uid = "@outputs('$composeReceiptTransactionUid')"
            four_digits = "@outputs('$composeReceiptCardLast4')"
            card_type = "@outputs('$composeReceiptCardBrand')"
        })
    }
    # Effective accounting document for the paid part of a (possibly partial) payment.
    # Legal guard: if a tax invoice (inv_tax) already exists for this billing case/invoice we MUST
    # only issue a receipt (inv_receipt). Otherwise honour the payment-line override
    # (alex_requesteddocflow: 100000001 receipt / 100000002 tax invoice receipt) and fall back to
    # the billing case default flow (alex_defaultflow 100000003 = tax invoice receipt).
    $effectiveDocTypeExpression = "@if(not(empty(first(outputs('$listInvoiceDocument')?['body/value'])?['alex_payplusdocumentuuid'])), 'inv_receipt', if(equals(body('Get_payment_line')?['alex_requesteddocflow'], 100000002), 'inv_tax_receipt', if(equals(body('Get_payment_line')?['alex_requesteddocflow'], 100000001), 'inv_receipt', if(equals(body('Get_billing_case')?['alex_defaultflow'], 100000003), 'inv_tax_receipt', 'inv_receipt'))))"
    $createReceiptParameters = [ordered]@{
        docType = "@outputs('$composeEffectiveDocType')"
        'body/unique_identifier' = "@outputs('$composeReceiptUnique')"
        'body/doc_date' = "@formatDateTime(utcNow(),'yyyy-MM-dd')"
        'body/language' = 'he'
        'body/currency_code' = $currencyExpression
        'body/vatType' = 'vat-type-included'
        'body/totalAmount' = $amountExpression
        'body/more_info' = "@concat('Workbench payment ', body('Get_payment_line')?['alex_paypluspaymentlineid'])"
        'body/close_doc' = "@if(empty(first(outputs('$listInvoiceDocument')?['body/value'])?['alex_payplusdocumentuuid']), null, first(outputs('$listInvoiceDocument')?['body/value'])?['alex_payplusdocumentuuid'])"
        'body/transaction_uuid' = "@outputs('$composeReceiptTransactionUid')"
        'body/prevent_email' = $true
        'body/customer/name' = "@coalesce(first(outputs('$listInvoiceDocument')?['body/value'])?['alex_customername'], body('Get_billing_case')?['alex_customername'], 'Customer')"
        'body/customer/email' = "@first(outputs('$listInvoiceDocument')?['body/value'])?['alex_customeremail']"
        'body/customer/phone' = "@first(outputs('$listInvoiceDocument')?['body/value'])?['alex_customerphone']"
        'body/customer/vat_number' = "@first(outputs('$listInvoiceDocument')?['body/value'])?['alex_customervatnumber']"
        'body/items' = "@if(empty(body('$selectReceiptItems')), null, body('$selectReceiptItems'))"
        'body/payments' = $paymentsArray
    }
    # Fallback variant used when the primary attempt (which passes close_doc) is rejected because
    # the referenced invoice document is already closed/cancelled in PayPlus. Same body, no close_doc.
    $createReceiptParametersNoClose = [ordered]@{}
    foreach ($receiptParamKey in $createReceiptParameters.Keys) { if ($receiptParamKey -ne 'body/close_doc') { $createReceiptParametersNoClose[$receiptParamKey] = $createReceiptParameters[$receiptParamKey] } }

    [ordered]@{
        $updateLine = DvAction 'UpdateRecord' ([ordered]@{
            entityName = 'alex_paypluspaymentlines'
            recordId = "@body('Get_payment_line')?['alex_paypluspaymentlineid']"
            'item/alex_status' = 100000002
            'item/alex_externaltransactionid' = $TransactionUidExpression
            'item/alex_cardlast4' = $CardLast4Expression
            'item/alex_cardbrand' = $CardBrandExpression
            'item/alex_approvalnumber' = $ApprovalExpression
            'item/alex_resultdescription' = 'PayPlus payment approved by Workbench processing flow.'
            'item/alex_rawpaymentjson' = $RawJsonExpression
        }) $RunAfter
        $listAllocations = DvAction 'ListRecords' ([ordered]@{
            entityName = 'alex_payplusreceiptallocations'
            '$select' = 'alex_payplusreceiptallocationid,alex_name,alex_allocatedamount,alex_proposedamount,alex_actualallocatedamount,alex_sourceitemname'
            '$filter' = "_alex_paymentlineid_value eq @{body('Get_payment_line')?['alex_paypluspaymentlineid']}"
        }) ([ordered]@{ $updateLine = @('Succeeded') })
        $forEachAllocation = [ordered]@{
            runAfter = [ordered]@{ $listAllocations = @('Succeeded') }
            type = 'Foreach'
            foreach = "@outputs('$listAllocations')?['body/value']"
            runtimeConfiguration = [ordered]@{ concurrency = [ordered]@{ repetitions = 1 } }
            actions = [ordered]@{
                "Update_allocation_active_$Prefix" = DvAction 'UpdateRecord' ([ordered]@{
                    entityName = 'alex_payplusreceiptallocations'
                    recordId = "@items('$forEachAllocation')?['alex_payplusreceiptallocationid']"
                    'item/alex_status' = 100000001
                    'item/alex_actualallocatedamount' = "@coalesce(items('$forEachAllocation')?['alex_allocatedamount'], items('$forEachAllocation')?['alex_proposedamount'], body('Get_payment_line')?['alex_amount'])"
                    'item/alex_allocatedon' = '@utcNow()'
                })
            }
        }
        $composePaid = [ordered]@{
            runAfter = [ordered]@{ $forEachAllocation = @('Succeeded') }
            type = 'Compose'
            inputs = "@add(float(coalesce(body('Get_billing_case')?['alex_paidamount'], 0)), float(coalesce(body('Get_payment_line')?['alex_amount'], 0)))"
        }
        $composeOpen = [ordered]@{
            runAfter = [ordered]@{ $composePaid = @('Succeeded') }
            type = 'Compose'
            inputs = "@if(greaterOrEquals(float(outputs('$composePaid')), float(coalesce(body('Get_billing_case')?['alex_totalamount'], 0))), 0, sub(float(coalesce(body('Get_billing_case')?['alex_totalamount'], 0)), float(outputs('$composePaid'))))"
        }
        $updateCase = DvAction 'UpdateRecord' ([ordered]@{
            entityName = 'alex_payplusbillingcases'
            recordId = "@body('Get_billing_case')?['alex_payplusbillingcaseid']"
            'item/alex_paidamount' = "@outputs('$composePaid')"
            'item/alex_receivedamount' = "@outputs('$composePaid')"
            'item/alex_openbalance' = "@outputs('$composeOpen')"
            'item/alex_amountdue' = "@outputs('$composeOpen')"
            'item/alex_pendingverificationamount' = 0
            'item/alex_status' = "@if(equals(outputs('$composeOpen'), 0), 100000005, 100000004)"
            'item/alex_documentstatussummary' = 'Payment approved. Issuing PayPlus receipt.'
        }) ([ordered]@{ $composeOpen = @('Succeeded') })
        $composeReceiptTransactionUid = [ordered]@{
            runAfter = [ordered]@{ $updateCase = @('Succeeded') }
            type = 'Compose'
            inputs = $TransactionUidExpression
        }
        $composeReceiptCardLast4 = [ordered]@{
            runAfter = [ordered]@{ $composeReceiptTransactionUid = @('Succeeded') }
            type = 'Compose'
            inputs = $CardLast4Expression
        }
        $composeReceiptCardBrand = [ordered]@{
            runAfter = [ordered]@{ $composeReceiptCardLast4 = @('Succeeded') }
            type = 'Compose'
            inputs = $CardBrandExpression
        }
        $composeReceiptUnique = [ordered]@{
            runAfter = [ordered]@{ $composeReceiptCardBrand = @('Succeeded') }
            type = 'Compose'
            inputs = "@concat('workbench-payment-', body('Get_payment_line')?['alex_paypluspaymentlineid'], '-receipt')"
        }
        $listInvoiceDocument = DvAction 'ListRecords' ([ordered]@{
            entityName = 'alex_payplusdocuments'
            '$select' = 'alex_payplusdocumentid,alex_name,alex_uniqueidentifier,alex_payplusdocumentuuid,alex_documentnumber,alex_totalamount,alex_paidamount,alex_balanceamount,alex_currencycode,alex_customername,alex_customeremail,alex_customerphone,alex_customervatnumber,alex_paypluscustomeruid,alex_paymentrequestuid,alex_paymentpagelink,alex_paymentpageuid,_alex_billingcaseid_value,_alex_invoiceid_value'
            '$filter' = "alex_documenttypecode eq 'inv_tax' and alex_payplusdocumentuuid ne null and (_alex_billingcaseid_value eq @{body('Get_billing_case')?['alex_payplusbillingcaseid']} or _alex_invoiceid_value eq @{if(equals(body('Get_billing_case')?['alex_sourceentitylogicalname'], 'invoice'), body('Get_billing_case')?['alex_sourceentityid'], '00000000-0000-0000-0000-000000000000')})"
            '$orderby' = 'createdon desc'
            '$top' = 1
        }) ([ordered]@{ $composeReceiptUnique = @('Succeeded') })
        $composeEffectiveDocType = [ordered]@{
            runAfter = [ordered]@{ $listInvoiceDocument = @('Succeeded') }
            type = 'Compose'
            inputs = $effectiveDocTypeExpression
        }
        $selectReceiptItems = [ordered]@{
            runAfter = [ordered]@{ $composeEffectiveDocType = @('Succeeded') }
            type = 'Select'
            inputs = [ordered]@{
                from = "@if(empty(outputs('$listAllocations')?['body/value']), coalesce($($TransactionObjectReference)?['data']?['items'], $($TransactionObjectReference)?['data']?['data']?['items'], json('[]')), outputs('$listAllocations')?['body/value'])"
                select = [ordered]@{
                    name = "@coalesce(item()?['name'], item()?['alex_sourceitemname'], item()?['alex_name'], 'Payment item')"
                    quantity = "@coalesce(item()?['quantity'], 1)"
                    price = "@coalesce(if(greater(float(coalesce(item()?['amount_pay'], 0)), 0), item()?['amount_pay'], null), if(greater(float(coalesce(item()?['alex_actualallocatedamount'], 0)), 0), item()?['alex_actualallocatedamount'], null), if(greater(float(coalesce(item()?['alex_allocatedamount'], 0)), 0), item()?['alex_allocatedamount'], null), if(greater(float(coalesce(item()?['alex_proposedamount'], 0)), 0), item()?['alex_proposedamount'], null), item()?['price'], item()?['quantity_price'], 0)"
                    discount_type = 'amount'
                    discount_value = "@coalesce(item()?['discount_amount'], item()?['discount_value'], 0)"
                }
            }
        }
        $conditionIssueReceipt = [ordered]@{
            runAfter = [ordered]@{ $selectReceiptItems = @('Succeeded') }
            type = 'If'
            expression = $(if ($RequireTransactionUid) {
                [ordered]@{
                    and = @(
                        [ordered]@{ equals = @("@empty(body('Get_payment_line')?['_alex_receiptdocumentid_value'])", $true) },
                        [ordered]@{ not = [ordered]@{ equals = @("@empty(outputs('$composeReceiptTransactionUid'))", $true) } }
                    )
                }
            } else {
                [ordered]@{ equals = @("@empty(body('Get_payment_line')?['_alex_receiptdocumentid_value'])", $true) }
            })
            actions = [ordered]@{
                $switchCreateReceipt = [ordered]@{
                    runAfter = [ordered]@{}
                    type = 'Switch'
                    expression = "@first(outputs('Get_config_row')?['body/value'])?['alex_environment']"
                    cases = [ordered]@{
                        Production = [ordered]@{ case = 100000000; actions = [ordered]@{ $createReceiptProduction = PayPlusAction 'Production' 'CreateDocument' $createReceiptParameters } }
                        Sandbox = [ordered]@{ case = 100000001; actions = [ordered]@{ $createReceiptSandbox = PayPlusAction 'Sandbox' 'CreateDocument' $createReceiptParameters } }
                    }
                    default = [ordered]@{ actions = [ordered]@{} }
                }
                $composeReceiptResultPrimary = [ordered]@{
                    runAfter = [ordered]@{ $switchCreateReceipt = @('Succeeded', 'Failed', 'TimedOut') }
                    type = 'Compose'
                    inputs = "@coalesce(body('$createReceiptProduction'), body('$createReceiptSandbox'))"
                }
                $composeReceiptStatusPrimary = [ordered]@{
                    runAfter = [ordered]@{ $composeReceiptResultPrimary = @('Succeeded') }
                    type = 'Compose'
                    inputs = "@toLower(coalesce(outputs('$composeReceiptResultPrimary')?['results']?['status'], outputs('$composeReceiptResultPrimary')?['status'], outputs('$composeReceiptResultPrimary')?['data']?['status'], ''))"
                }
                # Resilience: PayPlus rejects the whole CreateDocument when close_doc targets an invoice
                # document already closed/cancelled (doc-already-cancelled-or-closed). If the primary
                # attempt (which sends close_doc) did not succeed AND we actually sent a close_doc,
                # retry once WITHOUT close_doc so the receipt is still issued.
                $conditionRetryWithoutClose = [ordered]@{
                    runAfter = [ordered]@{ $composeReceiptStatusPrimary = @('Succeeded') }
                    type = 'If'
                    expression = [ordered]@{
                        and = @(
                            [ordered]@{ not = [ordered]@{ equals = @("@outputs('$composeReceiptStatusPrimary')", 'success') } },
                            [ordered]@{ not = [ordered]@{ equals = @("@empty(first(outputs('$listInvoiceDocument')?['body/value'])?['alex_payplusdocumentuuid'])", $true) } }
                        )
                    }
                    actions = [ordered]@{
                        $switchCreateReceiptRetry = [ordered]@{
                            runAfter = [ordered]@{}
                            type = 'Switch'
                            expression = "@first(outputs('Get_config_row')?['body/value'])?['alex_environment']"
                            cases = [ordered]@{
                                Production = [ordered]@{ case = 100000000; actions = [ordered]@{ $createReceiptRetryProduction = PayPlusAction 'Production' 'CreateDocument' $createReceiptParametersNoClose } }
                                Sandbox = [ordered]@{ case = 100000001; actions = [ordered]@{ $createReceiptRetrySandbox = PayPlusAction 'Sandbox' 'CreateDocument' $createReceiptParametersNoClose } }
                            }
                            default = [ordered]@{ actions = [ordered]@{} }
                        }
                    }
                }
                $composeReceiptResult = [ordered]@{
                    runAfter = [ordered]@{ $conditionRetryWithoutClose = @('Succeeded', 'Failed', 'TimedOut', 'Skipped') }
                    type = 'Compose'
                    inputs = "@coalesce(body('$createReceiptRetryProduction'), body('$createReceiptRetrySandbox'), outputs('$composeReceiptResultPrimary'))"
                }
                $composeReceiptData = [ordered]@{
                    runAfter = [ordered]@{ $composeReceiptResult = @('Succeeded') }
                    type = 'Compose'
                    inputs = "@coalesce(outputs('$composeReceiptResult')?['data'], outputs('$composeReceiptResult')?['details'], json('{}'))"
                }
                $composeReceiptStatus = [ordered]@{
                    runAfter = [ordered]@{ $composeReceiptData = @('Succeeded') }
                    type = 'Compose'
                    inputs = "@toLower(coalesce(outputs('$composeReceiptResult')?['results']?['status'], outputs('$composeReceiptResult')?['status'], outputs('$composeReceiptData')?['status'], ''))"
                }
                $conditionReceiptSuccess = [ordered]@{
                    runAfter = [ordered]@{ $composeReceiptStatus = @('Succeeded') }
                    type = 'If'
                    expression = [ordered]@{ equals = @("@outputs('$composeReceiptStatus')", 'success') }
                    actions = [ordered]@{
                        $listReceiptDocumentType = DvAction 'ListRecords' ([ordered]@{
                            entityName = 'alex_payplus_documenttypes'
                            '$select' = 'alex_payplus_documenttypeid,alex_code,alex_environment'
                            '$filter' = "alex_environment eq @{first(outputs('Get_config_row')?['body/value'])?['alex_environment']} and alex_code eq '@{outputs('$composeEffectiveDocType')}'"
                            '$top' = 1
                        })
                        $createReceiptDocument = DvAction 'CreateRecord' ([ordered]@{
                            entityName = 'alex_payplusdocuments'
                            'item/alex_name' = "@concat('PayPlus Receipt ', coalesce(outputs('$composeReceiptData')?['number'], outputs('$composeReceiptData')?['document_number'], outputs('$composeReceiptTransactionUid')))"
                            'item/alex_configurationid@odata.bind' = "@concat('/alex_payplusconfigurations(', first(outputs('Get_config_row')?['body/value'])?['alex_payplusconfigurationid'], ')')"
                            'item/alex_environment' = "@first(outputs('Get_config_row')?['body/value'])?['alex_environment']"
                            'item/alex_documenttypeid@odata.bind' = "@if(empty(first(body('$listReceiptDocumentType')?['value'])?['alex_payplus_documenttypeid']), null, concat('/alex_payplus_documenttypes(', first(body('$listReceiptDocumentType')?['value'])?['alex_payplus_documenttypeid'], ')'))"
                            'item/alex_documenttypecode' = "@outputs('$composeEffectiveDocType')"
                            'item/alex_payplusdocumentuuid' = "@if(empty(coalesce(outputs('$composeReceiptData')?['uuid'], outputs('$composeReceiptData')?['document_uuid'], outputs('$composeReceiptData')?['document_uid'], outputs('$composeReceiptData')?['docUID'], outputs('$composeReceiptData')?['doc_uid'], '')), null, coalesce(outputs('$composeReceiptData')?['uuid'], outputs('$composeReceiptData')?['document_uuid'], outputs('$composeReceiptData')?['document_uid'], outputs('$composeReceiptData')?['docUID'], outputs('$composeReceiptData')?['doc_uid']))"
                            'item/alex_uniqueidentifier' = "@outputs('$composeReceiptUnique')"
                            'item/alex_documentnumber' = "@if(empty(coalesce(outputs('$composeReceiptData')?['number'], outputs('$composeReceiptData')?['document_number'], '')), null, coalesce(outputs('$composeReceiptData')?['number'], outputs('$composeReceiptData')?['document_number']))"
                            'item/alex_documenturl' = "@if(empty(coalesce(outputs('$composeReceiptData')?['document_url'], outputs('$composeReceiptData')?['url'], outputs('$composeReceiptData')?['link'], outputs('$composeReceiptData')?['docLink'], outputs('$composeReceiptData')?['doc_link'], '')), null, coalesce(outputs('$composeReceiptData')?['document_url'], outputs('$composeReceiptData')?['url'], outputs('$composeReceiptData')?['link'], outputs('$composeReceiptData')?['docLink'], outputs('$composeReceiptData')?['doc_link']))"
                            'item/alex_pdfurl' = "@if(empty(coalesce(outputs('$composeReceiptData')?['originalDocAddress'], outputs('$composeReceiptData')?['pdf_url'], outputs('$composeReceiptData')?['pdf'], outputs('$composeReceiptData')?['pdf_link'], outputs('$composeReceiptData')?['download_url'], '')), null, coalesce(outputs('$composeReceiptData')?['originalDocAddress'], outputs('$composeReceiptData')?['pdf_url'], outputs('$composeReceiptData')?['pdf'], outputs('$composeReceiptData')?['pdf_link'], outputs('$composeReceiptData')?['download_url']))"
                            'item/alex_copypdfurl' = "@if(empty(outputs('$composeReceiptData')?['copyDocAddress']), null, outputs('$composeReceiptData')?['copyDocAddress'])"
                            'item/alex_documentdate' = "@formatDateTime(utcNow(),'yyyy-MM-dd')"
                            'item/alex_issuedon' = "@utcNow()"
                            'item/alex_lastoperationon' = "@utcNow()"
                            'item/alex_lastrefreshedon' = "@utcNow()"
                            'item/alex_currencycode' = $currencyExpression
                            'item/alex_totalamount' = $amountExpression
                            'item/alex_paidamount' = $amountExpression
                            'item/alex_balanceamount' = 0
                            'item/alex_customername' = "@coalesce(first(outputs('$listInvoiceDocument')?['body/value'])?['alex_customername'], body('Get_billing_case')?['alex_customername'])"
                            'item/alex_customeremail' = "@first(outputs('$listInvoiceDocument')?['body/value'])?['alex_customeremail']"
                            'item/alex_customerphone' = "@first(outputs('$listInvoiceDocument')?['body/value'])?['alex_customerphone']"
                            'item/alex_customervatnumber' = "@first(outputs('$listInvoiceDocument')?['body/value'])?['alex_customervatnumber']"
                            'item/alex_transactionuid' = "@outputs('$composeReceiptTransactionUid')"
                            'item/alex_paymentrequestuid' = "@first(outputs('$listInvoiceDocument')?['body/value'])?['alex_paymentrequestuid']"
                            'item/alex_paymentpagelink' = "@first(outputs('$listInvoiceDocument')?['body/value'])?['alex_paymentpagelink']"
                            'item/alex_paymentpageuid' = "@first(outputs('$listInvoiceDocument')?['body/value'])?['alex_paymentpageuid']"
                            'item/alex_moreinfo' = "@concat('Workbench payment ', body('Get_payment_line')?['alex_paypluspaymentlineid'])"
                            'item/alex_parentdocumentid@odata.bind' = "@if(empty(first(outputs('$listInvoiceDocument')?['body/value'])?['alex_payplusdocumentid']), null, concat('/alex_payplusdocuments(', first(outputs('$listInvoiceDocument')?['body/value'])?['alex_payplusdocumentid'], ')'))"
                            'item/alex_relatedinvoicedocumentid@odata.bind' = "@if(empty(first(outputs('$listInvoiceDocument')?['body/value'])?['alex_payplusdocumentid']), null, concat('/alex_payplusdocuments(', first(outputs('$listInvoiceDocument')?['body/value'])?['alex_payplusdocumentid'], ')'))"
                            'item/alex_billingcaseid@odata.bind' = "@concat('/alex_payplusbillingcases(', body('Get_billing_case')?['alex_payplusbillingcaseid'], ')')"
                            'item/alex_invoiceid@odata.bind' = "@if(not(empty(first(outputs('$listInvoiceDocument')?['body/value'])?['_alex_invoiceid_value'])), concat('/invoices(', first(outputs('$listInvoiceDocument')?['body/value'])?['_alex_invoiceid_value'], ')'), if(equals(body('Get_billing_case')?['alex_sourceentitylogicalname'], 'invoice'), concat('/invoices(', body('Get_billing_case')?['alex_sourceentityid'], ')'), null))"
                            'item/alex_documentrole' = "@if(equals(outputs('$composeEffectiveDocType'), 'inv_tax_receipt'), 100000003, 100000002)"
                            'item/alex_lastoperation' = 'Generate'
                            'item/alex_lastsyncstatus' = 100000001
                            'item/alex_businessstatus' = 100000003
                            'item/alex_origin' = 100000000
                            'item/alex_payplusresultstatus' = "@outputs('$composeReceiptStatus')"
                            'item/alex_rawrequest' = $RawJsonExpression
                            'item/alex_rawresponse' = "@string(outputs('$composeReceiptResult'))"
                            'item/alex_rawdocumentjson' = "@string(outputs('$composeReceiptData'))"
                            'item/alex_paymentsjson' = "@string(createArray($($TransactionObjectReference)))"
                        }) ([ordered]@{ $listReceiptDocumentType = @('Succeeded') })
                        $updateLineReceipt = DvAction 'UpdateRecord' ([ordered]@{
                            entityName = 'alex_paypluspaymentlines'
                            recordId = "@body('Get_payment_line')?['alex_paypluspaymentlineid']"
                            'item/alex_receiptdocumentid@odata.bind' = "@concat('/alex_payplusdocuments(', body('$createReceiptDocument')?['alex_payplusdocumentid'], ')')"
                            'item/alex_resultdescription' = "@concat('Payment approved and PayPlus receipt issued', if(empty(coalesce(outputs('$composeReceiptData')?['number'], outputs('$composeReceiptData')?['document_number'], '')), '.', concat(': ', coalesce(outputs('$composeReceiptData')?['number'], outputs('$composeReceiptData')?['document_number']))))"
                        }) ([ordered]@{ $createReceiptDocument = @('Succeeded') })
                        $forEachAllocationReceipt = [ordered]@{
                            runAfter = [ordered]@{ $updateLineReceipt = @('Succeeded') }
                            type = 'Foreach'
                            foreach = "@outputs('$listAllocations')?['body/value']"
                            runtimeConfiguration = [ordered]@{ concurrency = [ordered]@{ repetitions = 1 } }
                            actions = [ordered]@{
                                "Update_allocation_receipt_$Prefix" = DvAction 'UpdateRecord' ([ordered]@{
                                    entityName = 'alex_payplusreceiptallocations'
                                    recordId = "@items('$forEachAllocationReceipt')?['alex_payplusreceiptallocationid']"
                                    'item/alex_receiptdocumentid@odata.bind' = "@concat('/alex_payplusdocuments(', body('$createReceiptDocument')?['alex_payplusdocumentid'], ')')"
                                    'item/alex_status' = 100000001
                                    'item/alex_allocatedon' = '@utcNow()'
                                })
                            }
                        }
                        $conditionHasInvoiceDocument = [ordered]@{
                            runAfter = [ordered]@{ $forEachAllocationReceipt = @('Succeeded') }
                            type = 'If'
                            expression = [ordered]@{ not = [ordered]@{ equals = @("@empty(first(outputs('$listInvoiceDocument')?['body/value'])?['alex_payplusdocumentid'])", $true) } }
                            actions = [ordered]@{
                                $updateInvoiceDocument = DvAction 'UpdateRecord' ([ordered]@{
                                    entityName = 'alex_payplusdocuments'
                                    recordId = "@first(outputs('$listInvoiceDocument')?['body/value'])?['alex_payplusdocumentid']"
                                    'item/alex_paidamount' = "@outputs('$composePaid')"
                                    'item/alex_balanceamount' = "@outputs('$composeOpen')"
                                    'item/alex_transactionuid' = "@outputs('$composeReceiptTransactionUid')"
                                    'item/alex_businessstatus' = "@if(equals(outputs('$composeOpen'), 0), 100000008, 100000003)"
                                    'item/alex_lastrefreshedon' = "@utcNow()"
                                })
                            }
                            else = [ordered]@{ actions = [ordered]@{} }
                        }
                        $conditionCloseDynamicsInvoice = [ordered]@{
                            runAfter = [ordered]@{ $conditionHasInvoiceDocument = @('Succeeded') }
                            type = 'If'
                            expression = [ordered]@{
                                and = @(
                                    [ordered]@{ equals = @("@outputs('$composeOpen')", 0) },
                                    [ordered]@{ not = [ordered]@{ equals = @("@empty($resolvedInvoiceIdRaw)", $true) } }
                                )
                            }
                            actions = [ordered]@{
                                $updateDynamicsInvoice = DvAction 'UpdateRecord' ([ordered]@{
                                    entityName = 'invoices'
                                    recordId = "@$resolvedInvoiceIdRaw"
                                    'item/statecode' = 2
                                    'item/statuscode' = 100001
                                })
                            }
                            else = [ordered]@{ actions = [ordered]@{} }
                        }
                        $updateCaseReceiptIssued = DvAction 'UpdateRecord' ([ordered]@{
                            entityName = 'alex_payplusbillingcases'
                            recordId = "@body('Get_billing_case')?['alex_payplusbillingcaseid']"
                            'item/alex_documentstatussummary' = "@concat('Payment approved and PayPlus receipt issued', if(empty(coalesce(outputs('$composeReceiptData')?['number'], outputs('$composeReceiptData')?['document_number'], '')), '.', concat(': ', coalesce(outputs('$composeReceiptData')?['number'], outputs('$composeReceiptData')?['document_number']))))"
                        }) ([ordered]@{ $conditionCloseDynamicsInvoice = @('Succeeded') })
                    }
                    else = [ordered]@{
                        actions = $(if ($PaymentType -in @('bank-transfer', 'cheque')) {
                            [ordered]@{
                                $updateLineReceiptFailed = DvAction 'UpdateRecord' ([ordered]@{
                                    entityName = 'alex_paypluspaymentlines'
                                    recordId = "@body('Get_payment_line')?['alex_paypluspaymentlineid']"
                                    'item/alex_status' = 100000004
                                    'item/alex_resultdescription' = "@concat('$recordedRollbackLabel recorded but PayPlus receipt creation failed: ', coalesce(outputs('$composeReceiptResult')?['results']?['description'], outputs('$composeReceiptResult')?['description'], outputs('$composeReceiptResult')?['error'], outputs('$composeReceiptResult')?['message'], 'unknown error'))"
                                })
                                $updateCaseReceiptFailed = DvAction 'UpdateRecord' ([ordered]@{
                                    entityName = 'alex_payplusbillingcases'
                                    recordId = "@body('Get_billing_case')?['alex_payplusbillingcaseid']"
                                    'item/alex_paidamount' = "@coalesce(body('Get_billing_case')?['alex_paidamount'], 0)"
                                    'item/alex_receivedamount' = "@coalesce(body('Get_billing_case')?['alex_paidamount'], 0)"
                                    'item/alex_openbalance' = "@coalesce(body('Get_billing_case')?['alex_openbalance'], body('Get_billing_case')?['alex_totalamount'], 0)"
                                    'item/alex_amountdue' = "@coalesce(body('Get_billing_case')?['alex_openbalance'], body('Get_billing_case')?['alex_totalamount'], 0)"
                                    'item/alex_pendingverificationamount' = 0
                                    'item/alex_status' = "@if(equals(coalesce(body('Get_billing_case')?['alex_openbalance'], body('Get_billing_case')?['alex_totalamount'], 0), 0), 100000005, 100000004)"
                                    'item/alex_documentstatussummary' = "@concat('$recordedRollbackLabel receipt failed and was rolled back: ', coalesce(outputs('$composeReceiptResult')?['results']?['description'], outputs('$composeReceiptResult')?['description'], outputs('$composeReceiptResult')?['error'], outputs('$composeReceiptResult')?['message'], 'unknown error'))"
                                }) ([ordered]@{ $updateLineReceiptFailed = @('Succeeded') })
                            }
                        } else {
                            [ordered]@{
                                $updateLineReceiptFailed = DvAction 'UpdateRecord' ([ordered]@{
                                    entityName = 'alex_paypluspaymentlines'
                                    recordId = "@body('Get_payment_line')?['alex_paypluspaymentlineid']"
                                    'item/alex_resultdescription' = "@concat('Payment approved; PayPlus receipt creation failed: ', coalesce(outputs('$composeReceiptResult')?['results']?['description'], outputs('$composeReceiptResult')?['description'], outputs('$composeReceiptResult')?['error'], outputs('$composeReceiptResult')?['message'], 'unknown error'))"
                                })
                                $updateCaseReceiptFailed = DvAction 'UpdateRecord' ([ordered]@{
                                    entityName = 'alex_payplusbillingcases'
                                    recordId = "@body('Get_billing_case')?['alex_payplusbillingcaseid']"
                                    'item/alex_documentstatussummary' = "@concat('Payment approved; PayPlus receipt creation failed: ', coalesce(outputs('$composeReceiptResult')?['results']?['description'], outputs('$composeReceiptResult')?['description'], outputs('$composeReceiptResult')?['error'], outputs('$composeReceiptResult')?['message'], 'unknown error'))"
                                }) ([ordered]@{ $updateLineReceiptFailed = @('Succeeded') })
                            }
                        })
                    }
                }
            }
            else = [ordered]@{ actions = [ordered]@{} }
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

    $savedChargeParams = [ordered]@{
        'body/terminal_uid' = "@first(outputs('Get_config_row')?['body/value'])?['alex_terminaluidref']"
        'body/cashier_uid' = "@first(outputs('List_payment_page')?['body/value'])?['alex_cashieruid']"
        'body/customer_uid' = "@body('Get_saved_card')?['alex_paypluscustomeruid']"
        'body/token' = "@body('Get_saved_card')?['alex_token']"
        'body/amount' = "@float(body('Get_payment_line')?['alex_amount'])"
        'body/currency_code' = "@coalesce(body('Get_payment_line')?['alex_currencycode'], 'ILS')"
        'body/credit_terms' = 1
        'body/use_token' = $true
        'body/initial_invoice' = $false
        'body/create_token' = $false
        'body/more_info_1' = "@body('Get_payment_line')?['alex_paypluspaymentlineid']"
        'body/customer/customer_name' = "@coalesce(body('Get_billing_case')?['alex_customername'], 'Customer')"
    }

    $actions = [ordered]@{
        Get_payment_line = DvAction 'GetItem' ([ordered]@{
            entityName = 'alex_paypluspaymentlines'
            recordId = "@triggerOutputs()?['body/alex_paypluspaymentlineid']"
            '$select' = 'alex_paypluspaymentlineid,alex_name,alex_status,alex_chargemode,alex_paymentmethod,alex_amount,alex_currencycode,alex_reference,alex_notes,alex_banknumber,alex_branchnumber,alex_accountnumber,alex_banktransferreference,alex_externaltransactionid,alex_cardlast4,alex_cardbrand,alex_approvalnumber,alex_resultdescription,alex_failurereason,alex_requesteddocflow,_alex_billingcaseid_value,_alex_creditcardid_value,_alex_receiptdocumentid_value'
        })
        Get_billing_case = DvAction 'GetItem' ([ordered]@{
            entityName = 'alex_payplusbillingcases'
            recordId = "@body('Get_payment_line')?['_alex_billingcaseid_value']"
            '$select' = 'alex_payplusbillingcaseid,alex_name,alex_customername,alex_totalamount,alex_paidamount,alex_openbalance,alex_currencycode,alex_defaultflow,alex_sourceentitylogicalname,alex_sourceentityid,alex_sourcedisplayname,_alex_accountid_value,_alex_contactid_value'
        }) ([ordered]@{ Get_payment_line = @('Succeeded') })
        Get_config_row = DvAction 'ListRecords' ([ordered]@{
            entityName = 'alex_payplusconfigurations'
            '$select' = 'alex_payplusconfigurationid,alex_environment,alex_paymentpageuidref,alex_terminaluidref'
            '$top' = 1
        }) ([ordered]@{ Get_billing_case = @('Succeeded') })
        List_payment_page = DvAction 'ListRecords' ([ordered]@{
            entityName = 'alex_payplus_paymentpages'
            '$select' = 'alex_payplus_paymentpageid,alex_paymentpageuid,alex_cashieruid,alex_cashiername'
            '$filter' = "alex_environment eq @{first(outputs('Get_config_row')?['body/value'])?['alex_environment']} and alex_paymentpageuid eq '@{first(outputs('Get_config_row')?['body/value'])?['alex_paymentpageuidref']}'"
            '$top' = 1
        }) ([ordered]@{ Get_config_row = @('Succeeded') })
        Route_payment_line = [ordered]@{
            runAfter = [ordered]@{ List_payment_page = @('Succeeded') }
            type = 'Switch'
            expression = "@body('Get_payment_line')?['alex_status']"
            cases = [ordered]@{
                Payment_pending_execution = [ordered]@{
                    case = 100000001
                    actions = [ordered]@{
                        Condition_is_bank_transfer = [ordered]@{
                            runAfter = [ordered]@{}
                            type = 'If'
                            expression = [ordered]@{ equals = @("@body('Get_payment_line')?['alex_chargemode']", 100000000) }
                            actions = [ordered]@{
                                Condition_recorded_is_check = [ordered]@{
                                    runAfter = [ordered]@{}
                                    type = 'If'
                                    expression = [ordered]@{ equals = @("@body('Get_payment_line')?['alex_paymentmethod']", 100000001) }
                                    actions = FinalizePaymentActions 'check' ([ordered]@{}) "body('Get_payment_line')" "@string(body('Get_payment_line'))" "@coalesce(body('Get_payment_line')?['alex_reference'], '')" '' '' "@coalesce(body('Get_payment_line')?['alex_reference'], '')" 'cheque' "@coalesce(body('Get_payment_line')?['alex_banknumber'], '')" "@coalesce(body('Get_payment_line')?['alex_branchnumber'], '')" "@coalesce(body('Get_payment_line')?['alex_accountnumber'], '')" $false
                                    else = [ordered]@{
                                        actions = FinalizePaymentActions 'bank' ([ordered]@{}) "body('Get_payment_line')" "@string(body('Get_payment_line'))" "@coalesce(body('Get_payment_line')?['alex_banktransferreference'], body('Get_payment_line')?['alex_reference'], '')" '' '' "@coalesce(body('Get_payment_line')?['alex_banktransferreference'], body('Get_payment_line')?['alex_reference'], '')" 'bank-transfer' "@coalesce(body('Get_payment_line')?['alex_banknumber'], '')" "@coalesce(body('Get_payment_line')?['alex_branchnumber'], '')" "@coalesce(body('Get_payment_line')?['alex_accountnumber'], '')" $false
                                    }
                                }
                            }
                            else = [ordered]@{
                                actions = [ordered]@{
                        Get_saved_card = DvAction 'GetItem' ([ordered]@{
                            entityName = 'alex_creditcards'
                            recordId = "@body('Get_payment_line')?['_alex_creditcardid_value']"
                            '$select' = 'alex_creditcardid,alex_name,alex_token,alex_last4,alex_brand,alex_cardholdername,alex_paypluscustomeruid'
                        })
                        Condition_saved_card_config_ready = [ordered]@{
                            runAfter = [ordered]@{ Get_saved_card = @('Succeeded') }
                            type = 'If'
                            expression = [ordered]@{
                                and = @(
                                    [ordered]@{ not = [ordered]@{ equals = @("@empty(body('Get_saved_card')?['alex_token'])", $true) } },
                                    [ordered]@{ not = [ordered]@{ equals = @("@empty(body('Get_saved_card')?['alex_paypluscustomeruid'])", $true) } },
                                    [ordered]@{ not = [ordered]@{ equals = @("@empty(first(outputs('Get_config_row')?['body/value'])?['alex_terminaluidref'])", $true) } },
                                    [ordered]@{ not = [ordered]@{ equals = @("@empty(first(outputs('List_payment_page')?['body/value'])?['alex_cashieruid'])", $true) } }
                                )
                            }
                            actions = [ordered]@{
                                Switch_charge_saved_card = [ordered]@{
                                    runAfter = [ordered]@{}
                                    type = 'Switch'
                                    expression = "@first(outputs('Get_config_row')?['body/value'])?['alex_environment']"
                                    cases = [ordered]@{
                                        Production = [ordered]@{ case = 100000000; actions = [ordered]@{ Charge_saved_card_Production = PayPlusAction 'Production' 'ChargeSavedCard' $savedChargeParams } }
                                        Sandbox = [ordered]@{ case = 100000001; actions = [ordered]@{ Charge_saved_card_Sandbox = PayPlusAction 'Sandbox' 'ChargeSavedCard' $savedChargeParams } }
                                    }
                                    default = [ordered]@{ actions = [ordered]@{} }
                                }
                                Compose_saved_charge_result = [ordered]@{
                                    runAfter = [ordered]@{ Switch_charge_saved_card = @('Succeeded') }
                                    type = 'Compose'
                                    inputs = "@coalesce(body('Charge_saved_card_Production'), body('Charge_saved_card_Sandbox'))"
                                }
                                Compose_saved_charge_status = [ordered]@{
                                    runAfter = [ordered]@{ Compose_saved_charge_result = @('Succeeded') }
                                    type = 'Compose'
                                    inputs = "@toLower(coalesce(outputs('Compose_saved_charge_result')?['results']?['status'], outputs('Compose_saved_charge_result')?['status'], ''))"
                                }
                                Condition_saved_charge_success = [ordered]@{
                                    runAfter = [ordered]@{ Compose_saved_charge_status = @('Succeeded') }
                                    type = 'If'
                                    expression = [ordered]@{ equals = @("@outputs('Compose_saved_charge_status')", 'success') }
                                    actions = FinalizePaymentActions 'saved' ([ordered]@{}) "outputs('Compose_saved_charge_result')" "@string(outputs('Compose_saved_charge_result'))" "@coalesce(outputs('Compose_saved_charge_result')?['data']?['transaction']?['transaction_uid'], outputs('Compose_saved_charge_result')?['data']?['transaction']?['transaction_uuid'], outputs('Compose_saved_charge_result')?['data']?['transaction']?['uid'], outputs('Compose_saved_charge_result')?['data']?['transaction']?['uuid'], outputs('Compose_saved_charge_result')?['data']?['transaction_uid'], outputs('Compose_saved_charge_result')?['data']?['uid'], '')" "@coalesce(outputs('Compose_saved_charge_result')?['data']?['transaction']?['card_information']?['four_digits'], outputs('Compose_saved_charge_result')?['data']?['data']?['card_information']?['four_digits'], body('Get_saved_card')?['alex_last4'], '')" "@coalesce(outputs('Compose_saved_charge_result')?['data']?['transaction']?['card_information']?['brand_name'], outputs('Compose_saved_charge_result')?['data']?['data']?['card_information']?['brand_name'], '')" "@coalesce(outputs('Compose_saved_charge_result')?['data']?['transaction']?['approval_number'], outputs('Compose_saved_charge_result')?['data']?['transaction']?['voucher_number'], '')"
                                    else = [ordered]@{
                                        actions = [ordered]@{
                                            Update_saved_charge_failed = DvAction 'UpdateRecord' ([ordered]@{
                                                entityName = 'alex_paypluspaymentlines'
                                                recordId = "@body('Get_payment_line')?['alex_paypluspaymentlineid']"
                                                'item/alex_status' = 100000004
                                                'item/alex_failurereason' = "@coalesce(outputs('Compose_saved_charge_result')?['results']?['description'], outputs('Compose_saved_charge_result')?['message'], outputs('Compose_saved_charge_result')?['error'], 'Saved-card charge failed')"
                                                'item/alex_rawpaymentjson' = "@string(outputs('Compose_saved_charge_result'))"
                                            })
                                        }
                                    }
                                }
                            }
                            else = [ordered]@{
                                actions = [ordered]@{
                                    Update_saved_charge_missing_config = DvAction 'UpdateRecord' ([ordered]@{
                                        entityName = 'alex_paypluspaymentlines'
                                        recordId = "@body('Get_payment_line')?['alex_paypluspaymentlineid']"
                                        'item/alex_status' = 100000004
                                        'item/alex_failurereason' = 'Missing token, PayPlus customer UID, terminal UID, or cashier UID for saved-card charge.'
                                    })
                                }
                            }
                        }
                                }
                            }
                        }
                    }
                }
                Hosted_fields_pending_verification = [ordered]@{
                    case = 100000008
                    actions = [ordered]@{
                        Switch_view_hosted_transaction = [ordered]@{
                            runAfter = [ordered]@{}
                            type = 'Switch'
                            expression = "@first(outputs('Get_config_row')?['body/value'])?['alex_environment']"
                            cases = [ordered]@{
                                Production = [ordered]@{ case = 100000000; actions = [ordered]@{ View_hosted_transaction_Production = PayPlusAction 'Production' 'ViewTransactions' ([ordered]@{ 'body/more_info' = "@body('Get_payment_line')?['alex_reference']"; 'body/transaction_uid' = "@body('Get_payment_line')?['alex_externaltransactionid']" }) } }
                                Sandbox = [ordered]@{ case = 100000001; actions = [ordered]@{ View_hosted_transaction_Sandbox = PayPlusAction 'Sandbox' 'ViewTransactions' ([ordered]@{ 'body/more_info' = "@body('Get_payment_line')?['alex_reference']"; 'body/transaction_uid' = "@body('Get_payment_line')?['alex_externaltransactionid']" }) } }
                            }
                            default = [ordered]@{ actions = [ordered]@{} }
                        }
                        Compose_hosted_transaction_result = [ordered]@{
                            runAfter = [ordered]@{ Switch_view_hosted_transaction = @('Succeeded') }
                            type = 'Compose'
                            inputs = "@coalesce(body('View_hosted_transaction_Production'), body('View_hosted_transaction_Sandbox'))"
                        }
                        Condition_hosted_transaction_found = [ordered]@{
                            runAfter = [ordered]@{ Compose_hosted_transaction_result = @('Succeeded') }
                            type = 'If'
                            expression = [ordered]@{
                                and = @(
                                    [ordered]@{ equals = @("@toLower(coalesce(outputs('Compose_hosted_transaction_result')?['results']?['status'], ''))", 'success') },
                                    [ordered]@{ not = [ordered]@{ equals = @("@empty(outputs('Compose_hosted_transaction_result')?['data'])", $true) } }
                                )
                            }
                            actions = [ordered]@{
                                Compose_hosted_first_transaction = [ordered]@{ runAfter = [ordered]@{}; type = 'Compose'; inputs = "@first(outputs('Compose_hosted_transaction_result')?['data'])" }
                                Condition_hosted_transaction_has_uid = [ordered]@{
                                    runAfter = [ordered]@{ Compose_hosted_first_transaction = @('Succeeded') }
                                    type = 'If'
                                    expression = [ordered]@{ not = [ordered]@{ equals = @("@empty(coalesce(outputs('Compose_hosted_first_transaction')?['transaction_uid'], outputs('Compose_hosted_first_transaction')?['transaction_uuid'], outputs('Compose_hosted_first_transaction')?['uid'], outputs('Compose_hosted_first_transaction')?['uuid'], outputs('Compose_hosted_first_transaction')?['transaction']?['transaction_uid'], outputs('Compose_hosted_first_transaction')?['transaction']?['transaction_uuid'], outputs('Compose_hosted_first_transaction')?['transaction']?['uid'], outputs('Compose_hosted_first_transaction')?['transaction']?['uuid'], ''))", $true) } }
                                    actions = FinalizePaymentActions 'hosted' ([ordered]@{}) "outputs('Compose_hosted_first_transaction')" "@string(outputs('Compose_hosted_first_transaction'))" "@coalesce(outputs('Compose_hosted_first_transaction')?['transaction_uid'], outputs('Compose_hosted_first_transaction')?['transaction_uuid'], outputs('Compose_hosted_first_transaction')?['uid'], outputs('Compose_hosted_first_transaction')?['uuid'], outputs('Compose_hosted_first_transaction')?['transaction']?['transaction_uid'], outputs('Compose_hosted_first_transaction')?['transaction']?['transaction_uuid'], outputs('Compose_hosted_first_transaction')?['transaction']?['uid'], outputs('Compose_hosted_first_transaction')?['transaction']?['uuid'], '')" "@coalesce(outputs('Compose_hosted_first_transaction')?['card_information']?['four_digits'], outputs('Compose_hosted_first_transaction')?['data']?['card_information']?['four_digits'], '')" "@coalesce(outputs('Compose_hosted_first_transaction')?['card_information']?['brand_name'], outputs('Compose_hosted_first_transaction')?['data']?['card_information']?['brand_name'], outputs('Compose_hosted_first_transaction')?['brand_name'], '')" "@coalesce(outputs('Compose_hosted_first_transaction')?['approval_number'], outputs('Compose_hosted_first_transaction')?['voucher_number'], outputs('Compose_hosted_first_transaction')?['transaction']?['approval_number'], '')"
                                    else = [ordered]@{ actions = [ordered]@{} }
                                }
                            }
                            else = [ordered]@{
                                actions = [ordered]@{
                                    Update_hosted_not_found_yet = DvAction 'UpdateRecord' ([ordered]@{
                                        entityName = 'alex_paypluspaymentlines'
                                        recordId = "@body('Get_payment_line')?['alex_paypluspaymentlineid']"
                                        'item/alex_resultdescription' = 'No matching PayPlus transaction found yet. Payment remains pending verification.'
                                    })
                                }
                            }
                        }
                    }
                }
            }
            default = [ordered]@{ actions = [ordered]@{} }
        }
    }

    [ordered]@{
        schemaVersion = '1.0.0.0'
        properties = [ordered]@{
            connectionReferences = $connectionReferences
            definition = [ordered]@{
                '$schema' = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
                contentVersion = '1.0.0.0'
                parameters = [ordered]@{
                    '$connections' = [ordered]@{ defaultValue = [ordered]@{}; type = 'Object' }
                    '$authentication' = [ordered]@{ defaultValue = [ordered]@{}; type = 'SecureObject' }
                }
                triggers = [ordered]@{
                    When_a_workbench_payment_line_needs_processing = [ordered]@{
                        type = 'OpenApiConnectionWebhook'
                        inputs = [ordered]@{
                            host = DvHost 'SubscribeWebhookTrigger'
                            parameters = [ordered]@{
                                'subscriptionRequest/message' = 4
                                'subscriptionRequest/entityname' = 'alex_paypluspaymentline'
                                'subscriptionRequest/scope' = 4
                                'subscriptionRequest/filteringattributes' = 'alex_status,alex_reference,alex_externaltransactionid,alex_creditcardid'
                                'subscriptionRequest/filterexpression' = '(alex_status eq 100000001 or alex_status eq 100000008)'
                            }
                            authentication = "@parameters('`$authentication')"
                        }
                    }
                }
                actions = $actions
            }
        }
    }
}

$clientData = (New-ClientData | ConvertTo-Json -Depth 100 -Compress)
$null = $clientData | ConvertFrom-Json -Depth 100

if ($ValidateOnly) {
    Write-Host 'Workbench payment flow JSON is valid.'
    return
}

$token = (az account get-access-token --resource $org --query accessToken -o tsv)
if (-not $token) { throw 'Failed to get Dataverse access token.' }

$headers = @{
    Authorization = "Bearer $token"
    'OData-Version' = '4.0'
    'OData-MaxVersion' = '4.0'
    Accept = 'application/json'
    'Content-Type' = 'application/json; charset=utf-8'
}
$base = "$org/api/data/v9.2"

function Get-EntityIdFromHeader($ResponseHeaders, [string]$EntitySet) {
    $entityHeader = $ResponseHeaders['OData-EntityId']
    if ($entityHeader -is [array]) { $entityHeader = $entityHeader[0] }
    if ($entityHeader -match "$EntitySet\(([0-9a-fA-F-]{36})\)") { return $Matches[1] }
    return $null
}

$nameEsc = $flowName.Replace("'", "''")
$existing = Invoke-RestMethod -Method Get -Uri "$base/workflows?`$select=workflowid,statecode,statuscode&`$filter=name eq '$nameEsc' and category eq 5&`$top=1" -Headers $headers
$workflowId = $null
if ($existing.value.Count -gt 0) { $workflowId = $existing.value[0].workflowid }

if ($workflowId) {
    Write-Host "Updating existing flow $workflowId ..."
    $patch = @{ clientdata = $clientData; description = 'Processes Payment Workbench payment lines: saved-card charge and hosted-fields transaction verification.' } | ConvertTo-Json -Depth 5 -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($patch)) | Out-Null
}
else {
    Write-Host 'Creating new DRAFT flow ...'
    $body = @{
        name = $flowName
        description = 'Processes Payment Workbench payment lines: saved-card charge and hosted-fields transaction verification.'
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
if (-not $workflowId) { throw 'Could not determine workflow id.' }

$addBody = @{ ComponentType = 29; ComponentId = $workflowId; SolutionUniqueName = $solution; AddRequiredComponents = $false } | ConvertTo-Json -Compress
try { Invoke-RestMethod -Method Post -Uri "$base/AddSolutionComponent" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($addBody)) | Out-Null }
catch { Write-Warning "AddSolutionComponent: $($_.Exception.Message)" }

try {
    $activate = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Patch -Uri "$base/workflows($workflowId)" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($activate)) | Out-Null
}
catch {
    Write-Warning "Flow was saved but could not be activated via API: $($_.Exception.Message)"
}

$wf = Invoke-RestMethod -Method Get -Uri "$base/workflows($workflowId)?`$select=workflowid,name,statecode,statuscode" -Headers $headers
Write-Host "DONE. Flow '$($wf.name)' = $($wf.workflowid), state=$($wf.statecode)/$($wf.statuscode)."