// Patches "PayPlus HF Session" clientdata: GeneratePaymentLink currency comes from alex_pp_hfsession.alex_currencycode
// (written by PaymentWizard from the billing case), defaulting to ILS when empty.
// Usage: node hfsession-currency.js <in.json> <out.json>
'use strict';
const fs = require('fs');

const [, , inFile, outFile] = process.argv;
if (!inFile || !outFile) { console.error('usage: node hfsession-currency.js <in.json> <out.json>'); process.exit(2); }

const clientData = JSON.parse(fs.readFileSync(inFile, 'utf8').replace(/^\uFEFF/, ''));
const actions = clientData.properties.definition.actions;
const CURRENCY = "@toUpper(coalesce(if(empty(first(outputs('Get_session_row')?['body/value'])?['alex_currencycode']), null, trim(first(outputs('Get_session_row')?['body/value'])?['alex_currencycode'])), 'ILS'))";

const found = {};
(function walk(a) {
    for (const [k, v] of Object.entries(a || {})) {
        found[k] = v;
        walk(v.actions);
        if (v.else) walk(v.else.actions);
        if (v.cases) for (const c of Object.values(v.cases)) walk(c.actions);
        if (v.default) walk(v.default.actions);
    }
})(actions);

if (!found.Get_session_row) throw new Error('Get_session_row not found');
const targets = Object.entries(found).filter(([, v]) => v.inputs && v.inputs.host && v.inputs.host.operationId === 'GeneratePaymentLink');
if (targets.length === 0) throw new Error('No GeneratePaymentLink actions found');

let changed = 0;
for (const [name, action] of targets) {
    const p = action.inputs.parameters;
    if (p['body/currency_code'] !== CURRENCY) { p['body/currency_code'] = CURRENCY; changed++; console.log(`${name}: currency from session`); }
}
fs.writeFileSync(outFile, JSON.stringify(clientData));
console.log(changed ? `Patched ${changed} action(s).` : 'Already patched; no changes.');
