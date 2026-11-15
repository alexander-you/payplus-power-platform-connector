// Patches a "PayPlus - Process Workbench Payment" (base or Sales) clientdata JSON with the receipt fixes:
//  1. vatType from alex_document_vat_mode (VAT exempt -> vat-type-exempt, otherwise vat-type-included).
//  2. Receipt items from the billing case source lines (alex_billingmappingjson, default invoice/invoicedetail)
//     when the payment covers exactly those lines; otherwise the existing allocation-based items.
//  3. Foreign-currency receipts: autocalculate_rate + store alex_conversionrate (read back via GetDocument).
//  4. close_doc falls back to the latest inv_proforma (transaction account) of the billing case.
//  5. (1.2.1) Source lines keep negative amounts (discount lines); only zero lines are dropped.
// Usage: node workbench-receipt-fixes.js <in.json> <out.json>
'use strict';
const fs = require('fs');

const [, , inFile, outFile] = process.argv;
if (!inFile || !outFile) { console.error('usage: node workbench-receipt-fixes.js <in.json> <out.json>'); process.exit(2); }

const clientData = JSON.parse(fs.readFileSync(inFile, 'utf8').replace(/^\uFEFF/, ''));
const def = clientData.properties.definition;
const top = def.actions;
const MARKER = 'Compose_receipt_vat_type';
const PREFIXES = ['check', 'bank', 'saved', 'hosted'];
const sourceLineFilter = (amountExpr) => `@not(equals(${amountExpr}, 0))`;

// Flows already carrying the 1.2.0 patch only get the incremental changes.
if (top[MARKER]) {
    const filter = top.Scope_receipt_source_lines.actions.Condition_receipt_source_lines_mapped.actions.Filter_receipt_source_lines;
    const where = filter.inputs.where;
    const match = /^@greater\((.*), 0\)$/.exec(where);
    if (match) { filter.inputs.where = sourceLineFilter(match[1]); console.log('Upgraded source-line filter to keep negative lines.'); }
    else console.log('Already patched; no incremental changes needed.');
    fs.writeFileSync(outFile, JSON.stringify(clientData));
    process.exit(0);
}

// ---------- helpers ----------
function index(actions, map = {}) {
    for (const [name, action] of Object.entries(actions || {})) {
        map[name] = { action, parent: actions };
        index(action.actions, map);
        if (action.else) index(action.else.actions, map);
        if (action.cases) for (const c of Object.values(action.cases)) index(c.actions, map);
        if (action.default) index(action.default.actions, map);
    }
    return map;
}
function insertAfter(container, afterKey, entries) {
    const out = {};
    for (const [k, v] of Object.entries(container)) {
        out[k] = v;
        if (k === afterKey) Object.assign(out, entries);
    }
    for (const k of Object.keys(container)) delete container[k];
    Object.assign(container, out);
}
function must(map, name) { if (!map[name]) throw new Error(`Action not found: ${name}`); return map[name]; }
const dvHost = (operationId) => ({ apiId: '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps', operationId, connectionName: 'alex_payplus_dataverse' });
const auth = "@parameters('$authentication')";
const dv = (operationId, parameters, runAfter = {}) => ({ runAfter, type: 'OpenApiConnection', inputs: { host: dvHost(operationId), parameters, authentication: auth } });
const ALL = ['Succeeded', 'Failed', 'Skipped', 'TimedOut'];

const map = index(top);
for (const p of PREFIXES) must(map, `Create_receipt_Sandbox_${p}`);

// PayPlus hosts are taken from the existing CreateDocument actions so the patch works for any connector/connection naming.
const payplusHost = {
    Production: must(map, 'Create_receipt_Production_bank').action.inputs.host,
    Sandbox: must(map, 'Create_receipt_Sandbox_bank').action.inputs.host
};

// ---------- 1. Config row: no $select (alex_billingmappingjson may not exist in every environment) ----------
delete must(map, 'Get_config_row').action.inputs.parameters.$select;

// ---------- top-level: VAT type, billing mapping, source lines ----------
const cfg = "first(outputs('Get_config_row')?['body/value'])";
const amount = "float(coalesce(body('Get_payment_line')?['alex_amount'], 0))";
const mapping = "outputs('Compose_billing_mapping')";
const lf = (k) => `${mapping}?['lines']?['${k}']`;
const defaultMapping = '{"version":1,"header":{"logicalName":"invoice"},"lines":{"entitySetName":"invoicedetails","parentLookupField":"invoiceid","nameField":"productname","descriptionField":"productdescription","quantityField":"quantity","unitPriceField":"priceperunit","amountField":"extendedamount","productField":"productid"}}';

const Q = `float(coalesce(item()?[${lf('quantityField')}], 1))`;
const A = `float(coalesce(item()?[${lf('amountField')}], 0))`;
const U = `float(formatNumber(div(${A}, if(greater(${Q}, 0), ${Q}, 1)), '0.00', 'en-US'))`;
const exactQty = `and(greater(${Q}, 0), lessOrEquals(max(sub(mul(${Q}, ${U}), ${A}), sub(${A}, mul(${Q}, ${U}))), 0.005))`;
const fmt = (field) => `item()?[concat('_', coalesce(${lf(field)}, ''), '_value@OData.Community.Display.V1.FormattedValue')]`;
const lineName = `@coalesce(if(empty(item()?[${lf('nameField')}]), null, item()?[${lf('nameField')}]), ${fmt('nameField')}, ${fmt('productField')}, if(empty(item()?[${lf('descriptionField')}]), null, item()?[${lf('descriptionField')}]), 'Item')`;

const topEntries = {
    Init_receipt_source_items: {
        runAfter: { List_payment_page: ['Succeeded'] }, type: 'InitializeVariable',
        inputs: { variables: [{ name: 'ReceiptSourceItems', type: 'array', value: [] }] }
    },
    Init_receipt_source_total: {
        runAfter: { Init_receipt_source_items: ['Succeeded'] }, type: 'InitializeVariable',
        inputs: { variables: [{ name: 'ReceiptSourceTotal', type: 'float', value: 0 }] }
    },
    // Receipts carry the gross amount actually collected, so only "VAT exempt" changes the receipt VAT type.
    Compose_receipt_vat_type: {
        runAfter: { Init_receipt_source_total: ['Succeeded'] }, type: 'Compose',
        inputs: `@if(equals(${cfg}?['alex_document_vat_mode'], 100000003), 'vat-type-exempt', 'vat-type-included')`
    },
    Compose_billing_mapping: {
        runAfter: { Compose_receipt_vat_type: ['Succeeded'] }, type: 'Compose',
        inputs: `@if(empty(${cfg}?['alex_billingmappingjson']), json('${defaultMapping}'), json(${cfg}?['alex_billingmappingjson']))`
    },
    Scope_receipt_source_lines: {
        runAfter: { Compose_billing_mapping: ['Succeeded', 'Failed', 'TimedOut'] }, type: 'Scope',
        actions: {
            Condition_receipt_source_lines_mapped: {
                runAfter: {}, type: 'If',
                expression: {
                    and: [
                        { equals: [`@toLower(coalesce(body('Get_billing_case')?['alex_sourceentitylogicalname'], ''))`, `@toLower(coalesce(${mapping}?['header']?['logicalName'], '-'))`] },
                        { not: { equals: ["@empty(body('Get_billing_case')?['alex_sourceentityid'])", true] } },
                        { not: { equals: [`@empty(${lf('entitySetName')})`, true] } },
                        { not: { equals: [`@empty(${lf('parentLookupField')})`, true] } },
                        { not: { equals: [`@empty(${lf('amountField')})`, true] } }
                    ]
                },
                actions: {
                    List_receipt_source_lines: dv('ListRecords', {
                        entityName: `@{${lf('entitySetName')}}`,
                        $filter: `_@{${lf('parentLookupField')}}_value eq @{body('Get_billing_case')?['alex_sourceentityid']}`,
                        $orderby: 'createdon asc',
                        $top: 250
                    }),
                    Filter_receipt_source_lines: {
                        runAfter: { List_receipt_source_lines: ['Succeeded'] }, type: 'Query',
                        inputs: { from: "@outputs('List_receipt_source_lines')?['body/value']", where: sourceLineFilter(A) }
                    },
                    Select_receipt_source_lines: {
                        runAfter: { Filter_receipt_source_lines: ['Succeeded'] }, type: 'Select',
                        inputs: {
                            from: "@body('Filter_receipt_source_lines')",
                            select: {
                                name: lineName,
                                quantity: `@if(${exactQty}, ${Q}, 1)`,
                                price: `@if(${exactQty}, ${U}, ${A})`
                            }
                        }
                    },
                    Set_receipt_source_items: {
                        runAfter: { Select_receipt_source_lines: ['Succeeded'] }, type: 'SetVariable',
                        inputs: { name: 'ReceiptSourceItems', value: "@body('Select_receipt_source_lines')" }
                    },
                    For_each_receipt_source_line: {
                        runAfter: { Set_receipt_source_items: ['Succeeded'] }, type: 'Foreach',
                        foreach: "@body('Filter_receipt_source_lines')",
                        runtimeConfiguration: { concurrency: { repetitions: 1 } },
                        actions: {
                            Increment_receipt_source_total: {
                                runAfter: {}, type: 'IncrementVariable',
                                inputs: { name: 'ReceiptSourceTotal', value: `@float(coalesce(items('For_each_receipt_source_line')?[${lf('amountField')}], 0))` }
                            }
                        }
                    }
                },
                else: { actions: {} }
            }
        }
    },
    // Source lines are used only when they add up to this payment (full payment); partial payments keep allocations.
    Compose_receipt_source_items: {
        runAfter: { Scope_receipt_source_lines: ALL }, type: 'Compose',
        inputs: `@if(and(greater(length(variables('ReceiptSourceItems')), 0), lessOrEquals(max(sub(variables('ReceiptSourceTotal'), ${amount}), sub(${amount}, variables('ReceiptSourceTotal'))), 0.01)), variables('ReceiptSourceItems'), null)`
    }
};
insertAfter(top, 'List_payment_page', topEntries);
must(map, 'Route_payment_line').action.runAfter = { Compose_receipt_source_items: ['Succeeded'] };

// ---------- per payment branch ----------
for (const p of PREFIXES) {
    const listTax = `List_invoice_document_for_receipt_${p}`;
    const listProforma = `List_proforma_document_for_receipt_${p}`;
    const tax = (f) => `first(outputs('${listTax}')?['body/value'])?['${f}']`;
    const pro = (f) => `first(outputs('${listProforma}')?['body/value'])?['${f}']`;
    const closeUuid = `coalesce(${tax('alex_payplusdocumentuuid')}, ${pro('alex_payplusdocumentuuid')})`;
    const currency = `coalesce(body('Get_payment_line')?['alex_currencycode'], body('Get_billing_case')?['alex_currencycode'], 'ILS')`;

    // 4. latest transaction account (inv_proforma) of the billing case
    const taxEntry = must(map, listTax);
    insertAfter(taxEntry.parent, listTax, {
        [listProforma]: dv('ListRecords', {
            entityName: 'alex_payplusdocuments',
            $select: 'alex_payplusdocumentid,alex_payplusdocumentuuid,alex_customername,alex_customeremail,alex_customerphone,alex_customervatnumber',
            $filter: `alex_documenttypecode eq 'inv_proforma' and alex_payplusdocumentuuid ne null and _alex_billingcaseid_value eq @{body('Get_billing_case')?['alex_payplusbillingcaseid']}`,
            $orderby: 'createdon desc',
            $top: 1
        }, { [listTax]: ['Succeeded'] })
    });
    must(map, `Compose_effective_doctype_${p}`).action.runAfter = { [listProforma]: ['Succeeded'] };

    const customer = {
        'body/customer/name': `@coalesce(${tax('alex_customername')}, ${pro('alex_customername')}, body('Get_billing_case')?['alex_customername'], 'Customer')`,
        'body/customer/email': `@coalesce(${tax('alex_customeremail')}, ${pro('alex_customeremail')})`,
        'body/customer/phone': `@coalesce(${tax('alex_customerphone')}, ${pro('alex_customerphone')})`,
        'body/customer/vat_number': `@coalesce(${tax('alex_customervatnumber')}, ${pro('alex_customervatnumber')})`
    };
    for (const name of [`Create_receipt_Production_${p}`, `Create_receipt_Sandbox_${p}`, `Create_receipt_retry_Production_${p}`, `Create_receipt_retry_Sandbox_${p}`]) {
        const params = must(map, name).action.inputs.parameters;
        params['body/vatType'] = "@outputs('Compose_receipt_vat_type')";
        params['body/autocalculate_rate'] = `@not(equals(toUpper(${currency}), 'ILS'))`;
        params['body/items'] = `@coalesce(outputs('Compose_receipt_source_items'), if(empty(body('Select_receipt_items_${p}')), null, body('Select_receipt_items_${p}')))`;
        Object.assign(params, customer);
        if (!name.includes('_retry_')) params['body/close_doc'] = `@if(empty(coalesce(${closeUuid}, '')), null, ${closeUuid})`;
    }
    must(map, `Condition_retry_without_close_${p}`).action.expression.and[1] = { not: { equals: [`@empty(coalesce(${closeUuid}, ''))`, true] } };

    // Receipt record in Dataverse: parent = tax invoice, else the closed transaction account; customer fallback.
    const doc = must(map, `Create_receipt_payplus_document_${p}`).action.inputs.parameters;
    const parentId = `coalesce(${tax('alex_payplusdocumentid')}, ${pro('alex_payplusdocumentid')})`;
    doc['item/alex_parentdocumentid@odata.bind'] = `@if(empty(coalesce(${parentId}, '')), null, concat('/alex_payplusdocuments(', ${parentId}, ')'))`;
    doc['item/alex_customername'] = `@coalesce(${tax('alex_customername')}, ${pro('alex_customername')}, body('Get_billing_case')?['alex_customername'])`;
    doc['item/alex_customeremail'] = customer['body/customer/email'];
    doc['item/alex_customerphone'] = customer['body/customer/phone'];
    doc['item/alex_customervatnumber'] = customer['body/customer/vat_number'];

    // 3. Conversion rate for foreign-currency receipts (best effort; never fails the run).
    const createDoc = `Create_receipt_payplus_document_${p}`;
    const receiptUuid = `body('${createDoc}')?['alex_payplusdocumentuuid']`;
    const getProd = `Get_receipt_document_Production_${p}`;
    const getSandbox = `Get_receipt_document_Sandbox_${p}`;
    const details = `Compose_receipt_document_details_${p}`;
    const rate = `Compose_receipt_conversion_rate_${p}`;
    const d = `outputs('${details}')`;
    const getDoc = (env) => ({
        runAfter: {}, type: 'OpenApiConnection',
        inputs: { host: { ...payplusHost[env], operationId: 'GetDocument' }, parameters: { uuid: `@${receiptUuid}` }, authentication: auth }
    });
    // Kept flat (no Scope/If around the Switch) because the saved-card branch is already 7 levels deep (max 8).
    const isForeign = `and(not(equals(toUpper(${currency}), 'ILS')), not(empty(${receiptUuid})))`;
    const docBody = `coalesce(body('${getProd}'), body('${getSandbox}'))`;
    const success = must(map, `Condition_receipt_success_${p}`).action;
    Object.assign(success.actions, {
        [`Switch_get_receipt_document_${p}`]: {
            runAfter: { [`Update_billing_case_receipt_issued_${p}`]: ['Succeeded'] }, type: 'Switch',
            expression: `@if(${isForeign}, ${cfg}?['alex_environment'], 0)`,
            cases: {
                Production: { case: 100000000, actions: { [getProd]: getDoc('Production') } },
                Sandbox: { case: 100000001, actions: { [getSandbox]: getDoc('Sandbox') } }
            },
            default: { actions: {} }
        },
        [details]: {
            runAfter: { [`Switch_get_receipt_document_${p}`]: ALL }, type: 'Compose',
            inputs: `@coalesce(${docBody}?['details'], ${docBody}?['data'], ${docBody}, json('{}'))`
        },
        // Prefer an explicit rate; otherwise derive it from the base-currency (ILS) total PayPlus returns.
        [rate]: {
            runAfter: { [details]: ['Succeeded'] }, type: 'Compose',
            inputs: `@coalesce(${d}?['conversion_rate'], ${d}?['currency_rate'], ${d}?['exchange_rate'], if(and(greater(float(coalesce(${d}?['total_items_base_currency'], 0)), 0), greater(float(coalesce(${d}?['total_items'], ${d}?['total_amount'], ${d}?['totalAmount'], ${amount})), 0)), float(formatNumber(div(float(coalesce(${d}?['total_items_base_currency'], 0)), float(coalesce(${d}?['total_items'], ${d}?['total_amount'], ${d}?['totalAmount'], ${amount}, 1))), '0.000000', 'en-US')), null))`
        },
        [`Condition_has_conversion_rate_${p}`]: {
            runAfter: { [rate]: ['Succeeded'] }, type: 'If',
            expression: { and: [{ not: { equals: [`@empty(${docBody})`, true] } }] },
            actions: {
                [`Update_receipt_conversion_rate_${p}`]: dv('UpdateRecord', {
                    entityName: 'alex_payplusdocuments',
                    recordId: `@body('${createDoc}')?['alex_payplusdocumentid']`,
                    'item/alex_conversionrate': `@outputs('${rate}')`,
                    'item/alex_rawdocumentjson': `@string(${d})`
                })
            },
            else: { actions: {} }
        },
        [`Compose_conversion_rate_done_${p}`]: {
            runAfter: { [`Condition_has_conversion_rate_${p}`]: ALL }, type: 'Compose', inputs: 'done'
        }
    });
}

fs.writeFileSync(outFile, JSON.stringify(clientData));
console.log(`Patched ${PREFIXES.length} branches -> ${outFile}`);
