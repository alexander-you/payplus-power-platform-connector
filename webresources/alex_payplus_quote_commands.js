// PayPlus - Quote command bar placeholder actions.
// Registered as Quote form and grid ribbon commands.
var PayPlus = window.PayPlus || (window.PayPlus = {});

(function () {
  "use strict";

  var ALERT_TEXT = "\u05D4\u05DE\u05E9\u05EA\u05DE\u05E9 \u05DC\u05D7\u05E5 \u05E2\u05DC \u05DB\u05E4\u05EA\u05D5\u05E8";
  var PREVIEW_CUSTOM_PAGE_NAME = "alex_payplusdocumentpreview_b4f29";
  var PREVIEW_CUSTOM_PAGE_ID = "f9363e7c-e9f6-4706-891f-55ea27f7d88f";
  var PENDING_PREVIEW_REUSE_MS = 2 * 60 * 1000;
  var DOCUMENT_POLL_INTERVAL_MS = 4000;
  var DOCUMENT_POLL_TIMEOUT_MS = 180000;

  PayPlus._quoteCfg = PayPlus._quoteCfg || null;
  PayPlus._quoteCfgLoading = PayPlus._quoteCfgLoading || false;
  PayPlus._quoteCfgSelect = "$select=" + [
    "alex_doc_quote_enabled",
    "alex_doc_quote_draftpreview",
    "alex_doc_quote_bulkcreate",
    "alex_doc_quote_resend_email_allowed",
    "alex_doc_quote_resend_sms_allowed",
    "alex_doc_quote_resend_whatsapp_allowed",
    "alex_doc_quote_resend_default_linktype",
    "alex_doc_quote_resend_original_allowed",
    "alex_doc_quote_resend_copy_allowed",
    "alex_billing_default_flow",
    "alex_billing_allow_user_override",
    "alex_billing_cancellation_policy",
    "alex_billing_create_payment_page_with_document",
    "alex_billing_create_d365_reversal_invoice",
    "alex_billing_doc_taxinvoice_enabled",
    "alex_billing_doc_taxinvoice_issue_allowed",
    "alex_billing_doc_taxinvoice_preview_allowed",
    "alex_billing_doc_taxinvoice_bulkcreate",
    "alex_billing_doc_taxinvoice_send_email_allowed",
    "alex_billing_doc_taxinvoice_send_sms_allowed",
    "alex_billing_doc_taxinvoice_send_whatsapp_allowed",
    "alex_billing_doc_taxinvoicereceipt_enabled",
    "alex_billing_doc_taxinvoicereceipt_issue_allowed",
    "alex_billing_doc_taxinvoicereceipt_send_email_allowed",
    "alex_billing_doc_taxinvoicereceipt_send_sms_allowed",
    "alex_billing_doc_taxinvoicereceipt_send_whatsapp_allowed",
    "alex_billing_doc_paymentdemand_enabled",
    "alex_billing_doc_paymentdemand_issue_allowed",
    "alex_billing_doc_paymentdemand_preview_allowed",
    "alex_billing_doc_paymentdemand_bulkcreate",
    "alex_billing_doc_paymentdemand_send_email_allowed",
    "alex_billing_doc_paymentdemand_send_sms_allowed",
    "alex_billing_doc_paymentdemand_send_whatsapp_allowed",
    "alex_billing_doc_paymentrequest_enabled",
    "alex_billing_doc_paymentrequest_issue_allowed",
    "alex_billing_doc_paymentrequest_preview_allowed",
    "alex_billing_doc_paymentrequest_bulkcreate",
    "alex_billing_doc_paymentrequest_send_email_allowed",
    "alex_billing_doc_paymentrequest_send_sms_allowed",
    "alex_billing_doc_paymentrequest_send_whatsapp_allowed",
    "alex_doc_salesorder_enabled",
    "alex_doc_salesorder_draftpreview",
    "alex_doc_salesorder_bulkcreate",
    "alex_doc_salesorder_resend_email_allowed",
    "alex_doc_salesorder_resend_sms_allowed",
    "alex_doc_salesorder_resend_whatsapp_allowed",
    "alex_doc_salesorder_resend_default_linktype",
    "alex_doc_salesorder_resend_original_allowed",
    "alex_doc_salesorder_resend_copy_allowed"
  ].join(",");

  PayPlus._quoteRefreshRibbon = function (control) {
    try {
      if (control && control.ui && control.ui.refreshRibbon) {
        control.ui.refreshRibbon();
        return;
      }
    } catch (e) { /* ignore */ }

    try {
      if (control && control.refreshRibbon) {
        control.refreshRibbon();
        return;
      }
    } catch (e2) { /* ignore */ }

    try { Xrm.Page.ui.refreshRibbon(); } catch (e3) { /* ignore */ }
  };

  PayPlus._loadQuoteCfg = function (control) {
    if (PayPlus._quoteCfgLoading) return;
    PayPlus._quoteCfgLoading = true;

    Xrm.WebApi.retrieveMultipleRecords("alex_payplusconfiguration", "?" + PayPlus._quoteCfgSelect + "&$top=1").then(
      function (result) {
        PayPlus._quoteCfg = (result.entities && result.entities[0]) || {};
        PayPlus._quoteCfgLoading = false;
        PayPlus._quoteRefreshRibbon(control);
      },
      function () {
        PayPlus._quoteCfg = {};
        PayPlus._quoteCfgLoading = false;
      }
    );
  };

  PayPlus._quoteCfgReady = function (control) {
    if (!PayPlus._quoteCfg) {
      PayPlus._loadQuoteCfg(control);
      return null;
    }
    return PayPlus._quoteCfg;
  };

  PayPlus._quoteEnabled = function (control) {
    var cfg = PayPlus._quoteCfgReady(control);
    return !!(cfg && cfg.alex_doc_quote_enabled === true);
  };

  PayPlus._quoteIsSavedForm = function (primaryControl) {
    try {
      var formType = primaryControl && primaryControl.ui && primaryControl.ui.getFormType && primaryControl.ui.getFormType();
      if (formType === 1) return false;
      if (formType) return true;
    } catch (e) { /* ignore */ }

    return !!PayPlus._quoteId(primaryControl);
  };

  PayPlus._quoteStateCode = function (primaryControl) {
    try {
      var attr = primaryControl && primaryControl.getAttribute && primaryControl.getAttribute("statecode");
      if (!attr && primaryControl && primaryControl.data && primaryControl.data.entity && primaryControl.data.entity.attributes) {
        attr = primaryControl.data.entity.attributes.get("statecode");
      }
      if (attr && attr.getValue) return attr.getValue();
    } catch (e) { /* ignore */ }

    return null;
  };

  PayPlus._quoteIsActiveOrClosed = function (primaryControl) {
    var statecode = PayPlus._quoteStateCode(primaryControl);
    if (statecode === 1) return true;

    try {
      var formType = primaryControl && primaryControl.ui && primaryControl.ui.getFormType && primaryControl.ui.getFormType();
      return formType === 3 || formType === 4;
    } catch (e) { return false; }
  };

  PayPlus._quoteFlag = function (control, fieldName) {
    var cfg = PayPlus._quoteCfgReady(control);
    return !!(cfg && PayPlus._quoteEnabled(control) && cfg[fieldName] === true);
  };

  PayPlus._quoteResendAllowed = function (control, fieldName) {
    return PayPlus._quoteFlag(control, fieldName);
  };

  PayPlus._quoteAnySend = function (control) {
    var cfg = PayPlus._quoteCfgReady(control);
    return !!(cfg && PayPlus._quoteEnabled(control) && (
      PayPlus._quoteResendAllowed(control, "alex_doc_quote_resend_email_allowed") ||
      PayPlus._quoteResendAllowed(control, "alex_doc_quote_resend_sms_allowed") ||
      PayPlus._quoteResendAllowed(control, "alex_doc_quote_resend_whatsapp_allowed")
    ));
  };

  PayPlus.quoteCanShow = function (primaryControl) {
    return !!(PayPlus._quoteEnabled(primaryControl) && PayPlus._quoteIsSavedForm(primaryControl) && (
      PayPlus.quoteCanPreview(primaryControl) ||
      PayPlus.quoteCanGenerate(primaryControl) ||
      PayPlus.quoteCanAnySend(primaryControl)
    ));
  };

  PayPlus.quoteFormCommandEnabled = function (primaryControl) {
    return PayPlus._quoteIsSavedForm(primaryControl);
  };

  PayPlus.quoteCanPreview = function (primaryControl) {
    return !!(PayPlus._quoteIsSavedForm(primaryControl) && PayPlus._quoteFlag(primaryControl, "alex_doc_quote_draftpreview"));
  };

  PayPlus.quoteCanGenerate = function (primaryControl) {
    return !!(PayPlus._quoteEnabled(primaryControl) && PayPlus._quoteIsSavedForm(primaryControl) && !PayPlus._quoteIsActiveOrClosed(primaryControl));
  };

  PayPlus.quoteCanAnySend = function (primaryControl) {
    return !!(PayPlus._quoteIsSavedForm(primaryControl) && PayPlus._quoteAnySend(primaryControl));
  };

  PayPlus.quoteCanSendEmail = function (primaryControl) {
    return !!(PayPlus._quoteIsSavedForm(primaryControl) && PayPlus._quoteResendAllowed(primaryControl, "alex_doc_quote_resend_email_allowed"));
  };

  PayPlus.quoteCanSendSms = function (primaryControl) {
    return !!(PayPlus._quoteIsSavedForm(primaryControl) && PayPlus._quoteResendAllowed(primaryControl, "alex_doc_quote_resend_sms_allowed"));
  };

  PayPlus.quoteCanSendWhatsapp = function (primaryControl) {
    return !!(PayPlus._quoteIsSavedForm(primaryControl) && PayPlus._quoteResendAllowed(primaryControl, "alex_doc_quote_resend_whatsapp_allowed"));
  };

  PayPlus.quoteGridCanShow = function (selectedControl) {
    var cfg = PayPlus._quoteCfgReady(selectedControl);
    return !!(cfg && PayPlus._quoteEnabled(selectedControl) && (
      cfg.alex_doc_quote_bulkcreate === true || PayPlus._quoteAnySend(selectedControl)
    ));
  };

  PayPlus.quoteGridCanGenerate = function (selectedControl) {
    return PayPlus._quoteFlag(selectedControl, "alex_doc_quote_bulkcreate");
  };

  PayPlus.quoteGridCanAnySend = function (selectedControl) {
    return PayPlus._quoteAnySend(selectedControl);
  };

  PayPlus.quoteGridCanSendEmail = function (selectedControl) {
    return PayPlus._quoteResendAllowed(selectedControl, "alex_doc_quote_resend_email_allowed");
  };

  PayPlus.quoteGridCanSendSms = function (selectedControl) {
    return PayPlus._quoteResendAllowed(selectedControl, "alex_doc_quote_resend_sms_allowed");
  };

  PayPlus.quoteGridCanSendWhatsapp = function (selectedControl) {
    return PayPlus._quoteResendAllowed(selectedControl, "alex_doc_quote_resend_whatsapp_allowed");
  };

  PayPlus._quoteId = function (primaryControl) {
    try { return primaryControl.data.entity.getId().replace(/[{}]/g, "").toLowerCase(); }
    catch (e) { return ""; }
  };

  PayPlus._quoteDisplayName = function (primaryControl) {
    try {
      var entity = primaryControl.data.entity;
      var numberAttr = entity.attributes.get("quotenumber");
      var nameAttr = entity.attributes.get("name");
      return (numberAttr && numberAttr.getValue && numberAttr.getValue()) ||
        (nameAttr && nameAttr.getValue && nameAttr.getValue()) ||
        entity.getPrimaryAttributeValue() ||
        "Quote";
    } catch (e) { return "Quote"; }
  };

  PayPlus._quotePreviewTitle = function () {
    return PayPlus._t("previewTitle");
  };

  PayPlus._isHebrew = function () {
    try {
      var globalContext = Xrm.Utility && Xrm.Utility.getGlobalContext && Xrm.Utility.getGlobalContext();
      return !!(globalContext && globalContext.userSettings && globalContext.userSettings.languageId === 1037);
    } catch (e) { return false; }
  };

  PayPlus._t = function (key) {
    var he = {
      previewTitle: "\u05EA\u05E6\u05D5\u05D2\u05D4 \u05DE\u05E7\u05D3\u05D9\u05DE\u05D4 PayPlus",
      issueTitle: "\u05D4\u05E4\u05E7\u05EA \u05DE\u05E1\u05DE\u05DA \u05D1-PayPlus",
      issueText: "\u05D4\u05DE\u05E1\u05DE\u05DA \u05D9\u05D5\u05E4\u05E7 \u05D1-PayPlus \u05E2\u05DC \u05D1\u05E1\u05D9\u05E1 \u05E0\u05EA\u05D5\u05E0\u05D9 \u05D4\u05E6\u05E2\u05EA \u05D4\u05DE\u05D7\u05D9\u05E8 \u05D4\u05E9\u05DE\u05D5\u05E8\u05D9\u05DD \u05D1-Dynamics 365. \u05D4\u05D0\u05DD \u05DC\u05D0\u05E9\u05E8 \u05D4\u05E4\u05E7\u05D4?",
      issueConfirm: "\u05D0\u05E9\u05E8 \u05D4\u05E4\u05E7\u05D4",
      cancel: "\u05D1\u05D9\u05D8\u05D5\u05DC",
      generating: "PayPlus - \u05DE\u05E4\u05D9\u05E7 \u05DE\u05E1\u05DE\u05DA \u05D1-PayPlus...",
      generatedTitle: "\u05D4\u05DE\u05E1\u05DE\u05DA \u05D4\u05D5\u05E4\u05E7 \u05D1\u05D4\u05E6\u05DC\u05D7\u05D4",
      generatedText: "\u05D4\u05DE\u05E1\u05DE\u05DA \u05D4\u05D5\u05E4\u05E7 \u05D1\u05D4\u05E6\u05DC\u05D7\u05D4 \u05D1-PayPlus. \u05D4\u05D0\u05DD \u05DC\u05D4\u05E6\u05D9\u05D2 \u05D0\u05D5\u05EA\u05D5?",
      showDocument: "\u05D4\u05E6\u05D2 \u05DE\u05E1\u05DE\u05DA",
      sendTitle: "\u05E9\u05DC\u05D9\u05D7\u05EA \u05DE\u05E1\u05DE\u05DA PayPlus",
      sendLinkChoice: "\u05D0\u05D9\u05D6\u05D4 \u05E7\u05D9\u05E9\u05D5\u05E8 \u05DC\u05E9\u05DC\u05D5\u05D7? \u05DC\u05E9\u05DC\u05D9\u05D7\u05D4 \u05D7\u05D5\u05D6\u05E8\u05EA \u05DE\u05D5\u05DE\u05DC\u05E5 \u05DC\u05D1\u05D7\u05D5\u05E8 \u05E2\u05D5\u05EA\u05E7.",
      sendCopy: "\u05E2\u05D5\u05EA\u05E7",
      sendOriginal: "\u05DE\u05E7\u05D5\u05E8",
      sendQueued: "\u05D1\u05E7\u05E9\u05EA \u05D4\u05E9\u05DC\u05D9\u05D7\u05D4 \u05E0\u05E8\u05E9\u05DE\u05D4.",
      sendNoDocument: "\u05DC\u05D0 \u05E0\u05DE\u05E6\u05D0 \u05DE\u05E1\u05DE\u05DA PayPlus \u05E9\u05D4\u05D5\u05E4\u05E7 \u05D1\u05D4\u05E6\u05DC\u05D7\u05D4 \u05DC\u05D4\u05E6\u05E2\u05D4 \u05D6\u05D5.",
      sendBulkQueued: "\u05D1\u05E7\u05E9\u05D5\u05EA \u05E9\u05DC\u05D9\u05D7\u05D4 \u05E0\u05E8\u05E9\u05DE\u05D5.",
      notNow: "\u05DC\u05D0 \u05E2\u05DB\u05E9\u05D9\u05D5",
      activateTitle: "\u05D4\u05E4\u05E2\u05DC\u05EA \u05D4\u05E6\u05E2\u05EA \u05DE\u05D7\u05D9\u05E8",
      activateText: "\u05D4\u05D0\u05DD \u05DC\u05D4\u05E4\u05E2\u05D9\u05DC \u05D0\u05EA \u05D4\u05E6\u05E2\u05EA \u05D4\u05DE\u05D7\u05D9\u05E8 \u05D1-Dynamics 365?",
      activateConfirm: "\u05D4\u05E4\u05E2\u05DC \u05D4\u05E6\u05E2\u05EA \u05DE\u05D7\u05D9\u05E8",
      activating: "Dynamics 365 - \u05DE\u05E4\u05E2\u05D9\u05DC \u05D4\u05E6\u05E2\u05EA \u05DE\u05D7\u05D9\u05E8...",
      activated: "\u05D4\u05E6\u05E2\u05EA \u05D4\u05DE\u05D7\u05D9\u05E8 \u05D4\u05D5\u05E4\u05E2\u05DC\u05D4 \u05D1\u05D4\u05E6\u05DC\u05D7\u05D4.",
      issueFailed: "\u05D4\u05E4\u05E7\u05EA \u05D4\u05DE\u05E1\u05DE\u05DA \u05E0\u05DB\u05E9\u05DC\u05D4 \u05D1-PayPlus: ",
      issueTimeout: "\u05D4\u05E4\u05E7\u05EA \u05D4\u05DE\u05E1\u05DE\u05DA \u05E2\u05D3\u05D9\u05D9\u05DF \u05D1\u05E2\u05D9\u05D1\u05D5\u05D3. \u05E0\u05D9\u05EA\u05DF \u05DC\u05D1\u05D3\u05D5\u05E7 \u05D0\u05EA \u05E8\u05E9\u05D5\u05DE\u05EA \u05DE\u05E1\u05DE\u05DA PayPlus \u05D1\u05D4\u05DE\u05E9\u05DA.",
      bulkNoSelection: "\u05DC\u05D0 \u05E0\u05D1\u05D7\u05E8\u05D5 \u05D4\u05E6\u05E2\u05D5\u05EA \u05DE\u05D7\u05D9\u05E8."
    };
    var en = {
      previewTitle: "PayPlus Preview",
      issueTitle: "Issue document in PayPlus",
      issueText: "The document will be issued in PayPlus using the saved Dynamics 365 quote data. Do you want to continue?",
      issueConfirm: "Issue document",
      cancel: "Cancel",
      generating: "PayPlus - issuing document in PayPlus...",
      generatedTitle: "Document issued successfully",
      generatedText: "The document was issued successfully in PayPlus. Do you want to view it?",
      showDocument: "View document",
      sendTitle: "Send PayPlus document",
      sendLinkChoice: "Which link should be sent? For resend, copy is recommended.",
      sendCopy: "Copy",
      sendOriginal: "Original",
      sendQueued: "The send request was recorded.",
      sendNoDocument: "No successfully issued PayPlus document was found for this quote.",
      sendBulkQueued: "Send requests were recorded.",
      notNow: "Not now",
      activateTitle: "Activate quote",
      activateText: "Do you want to activate the quote in Dynamics 365?",
      activateConfirm: "Activate quote",
      activating: "Dynamics 365 - activating quote...",
      activated: "The quote was activated successfully.",
      issueFailed: "Document issue failed in PayPlus: ",
      issueTimeout: "The document issue is still processing. You can check the PayPlus Document row later.",
      bulkNoSelection: "No quotes were selected."
    };
    return (PayPlus._isHebrew() ? he : en)[key] || key;
  };

  PayPlus._saveQuoteIfNeeded = function (primaryControl) {
    try {
      if (primaryControl && primaryControl.data && primaryControl.data.getIsDirty && primaryControl.data.getIsDirty()) {
        return primaryControl.data.save();
      }
    } catch (e) { /* ignore */ }
    return Promise.resolve();
  };

  PayPlus._getQuoteSourceSnapshot = function (quoteId) {
    var quoteQuery = "?$select=modifiedon,versionnumber,statecode";
    var detailQuery = "?$select=quotedetailid,modifiedon,versionnumber&$filter=_quoteid_value eq " + quoteId + "&$orderby=modifiedon desc&$top=1&$count=true";

    return Promise.all([
      Xrm.WebApi.retrieveRecord("quote", quoteId, quoteQuery),
      Xrm.WebApi.retrieveMultipleRecords("quotedetail", detailQuery)
    ]).then(function (results) {
      var quote = results[0] || {};
      var details = results[1] || {};
      var detail = details.entities && details.entities[0] || {};
      var detailCount = details["@odata.count"] || 0;
      var quoteVersion = quote.versionnumber == null ? "" : String(quote.versionnumber);
      var detailVersion = detail.versionnumber == null ? "" : String(detail.versionnumber);
      var quoteModified = quote.modifiedon || "";
      var detailModified = detail.modifiedon || "";

      return {
        quoteModifiedOn: quoteModified,
        quoteVersionNumber: quoteVersion,
        detailModifiedOn: detailModified,
        detailVersionNumber: detailVersion,
        detailCount: detailCount,
        statecode: quote.statecode,
        fingerprint: [quoteModified, quoteVersion, detailModified, detailVersion, detailCount].join("|")
      };
    });
  };

  PayPlus._addSourceSnapshot = function (body, snapshot) {
    if (!body || !snapshot) return body;
    body.alex_sourcemodifiedon = snapshot.quoteModifiedOn || null;
    body.alex_sourceversionnumber = snapshot.quoteVersionNumber || "";
    body.alex_sourcedetailmodifiedon = snapshot.detailModifiedOn || null;
    body.alex_sourcedetailversionnumber = snapshot.detailVersionNumber || "";
    body.alex_sourcedetailcount = snapshot.detailCount || 0;
    body.alex_sourcefingerprint = snapshot.fingerprint || "";
    return body;
  };

  PayPlus._findLatestGeneratedQuoteDocument = function (quoteId) {
    var query = "?$select=alex_payplusdocumentid,alex_sourcefingerprint,alex_sourcemodifiedon,alex_sourceversionnumber,alex_sourcedetailmodifiedon,alex_sourcedetailversionnumber,alex_sourcedetailcount,alex_documenturl,alex_pdfurl,alex_copypdfurl,modifiedon&$filter=_alex_quoteid_value eq " + quoteId + " and alex_documenttypecode eq 'dc_quote' and alex_lastoperation eq 'Generate' and alex_lastsyncstatus eq 100000001&$orderby=modifiedon desc&$top=1";
    return Xrm.WebApi.retrieveMultipleRecords("alex_payplusdocument", query).then(function (result) {
      return result.entities && result.entities[0] || null;
    }, function () { return null; });
  };

  PayPlus._generatedDocumentMatchesSnapshot = function (documentRow, snapshot) {
    if (!documentRow || !snapshot || !documentRow.alex_sourcefingerprint) return false;
    return String(documentRow.alex_sourcefingerprint) === String(snapshot.fingerprint || "");
  };

  PayPlus._findPendingQuotePreviewDocument = function (quoteId) {
    var query = "?$select=alex_payplusdocumentid,alex_lastsyncstatus,modifiedon,alex_sourcefingerprint&$filter=_alex_quoteid_value eq " + quoteId + " and alex_documenttypecode eq 'dc_quote' and alex_lastoperation eq 'Preview' and alex_lastsyncstatus eq 100000000&$orderby=modifiedon desc&$top=1";
    return Xrm.WebApi.retrieveMultipleRecords("alex_payplusdocument", query).then(function (result) {
      var row = result.entities && result.entities[0];
      if (!row || !row.alex_payplusdocumentid) return "";
      var modified = row.modifiedon ? new Date(row.modifiedon).getTime() : 0;
      if (!modified || Date.now() - modified > PENDING_PREVIEW_REUSE_MS) return "";
      return row.alex_payplusdocumentid;
    });
  };

  PayPlus._getPreviewConfiguration = function () {
    return Xrm.WebApi.retrieveMultipleRecords("alex_payplusconfiguration", "?$select=alex_payplusconfigurationid,alex_environment,alex_billing_default_flow,alex_billing_require_receipt_to_close_invoice,alex_billing_cancellation_policy,alex_billing_create_payment_page_with_document,alex_billing_create_d365_reversal_invoice&$top=1").then(function (result) {
      var cfg = result.entities && result.entities[0];
      if (!cfg) throw new Error("PayPlus configuration was not found.");
      return cfg;
    });
  };

  PayPlus._getDcQuoteDocumentType = function (environmentValue) {
    var query = "?$select=alex_payplus_documenttypeid&$filter=alex_code eq 'dc_quote' and alex_environment eq " + environmentValue + "&$top=1";
    return Xrm.WebApi.retrieveMultipleRecords("alex_payplus_documenttype", query).then(function (result) {
      return result.entities && result.entities[0] && result.entities[0].alex_payplus_documenttypeid || "";
    }, function () { return ""; });
  };

  PayPlus._createPendingQuoteDocument = function (primaryControl, quoteId, operation, sourceSnapshot) {
    operation = operation || "Preview";
    var displayName = PayPlus._quoteDisplayName(primaryControl);
    return PayPlus._getPreviewConfiguration().then(function (cfg) {
      var env = cfg.alex_environment;
      return PayPlus._getDcQuoteDocumentType(env).then(function (docTypeId) {
        var isGenerate = operation === "Generate";
        var prefix = isGenerate ? "quote-generate-" : "quote-preview-";
        var body = {
          alex_name: (isGenerate ? "PayPlus Quote - " : "PayPlus Preview - ") + displayName,
          alex_environment: env,
          alex_documenttypecode: "dc_quote",
          alex_uniqueidentifier: prefix + quoteId + "-" + Date.now(),
          alex_sourceentitylogicalname: "quote",
          alex_sourceentityid: quoteId,
          alex_sourcedisplayname: displayName,
          alex_lastsyncstatus: 100000000,
          alex_businessstatus: isGenerate ? 100000002 : 100000000,
          alex_lastoperation: operation,
          alex_origin: 100000000,
          "alex_configurationid@odata.bind": "/alex_payplusconfigurations(" + cfg.alex_payplusconfigurationid + ")",
          "alex_quoteid@odata.bind": "/quotes(" + quoteId + ")"
        };
        PayPlus._addSourceSnapshot(body, sourceSnapshot);
        if (docTypeId) body["alex_documenttypeid@odata.bind"] = "/alex_payplus_documenttypes(" + docTypeId + ")";
        return Xrm.WebApi.createRecord("alex_payplusdocument", body).then(function (created) {
          return created.id.replace(/[{}]/g, "").toLowerCase();
        });
      });
    });
  };

  PayPlus._pollPayPlusDocument = function (documentId, startedAt) {
    var query = "?$select=alex_payplusdocumentid,alex_lastsyncstatus,alex_payplusresultstatus,alex_payplusresultdescription,alex_documenturl,alex_pdfurl,alex_lastoperation";
    return Xrm.WebApi.retrieveRecord("alex_payplusdocument", documentId, query).then(function (row) {
      if (row.alex_lastsyncstatus === 100000001) return row;
      if (row.alex_lastsyncstatus === 100000002) {
        throw new Error(row.alex_payplusresultdescription || row.alex_payplusresultstatus || "PayPlus document operation failed.");
      }
      if (Date.now() - startedAt > DOCUMENT_POLL_TIMEOUT_MS) throw new Error(PayPlus._t("issueTimeout"));
      return new Promise(function (resolve) {
        window.setTimeout(resolve, DOCUMENT_POLL_INTERVAL_MS);
      }).then(function () { return PayPlus._pollPayPlusDocument(documentId, startedAt); });
    });
  };

  PayPlus._askOpenIssuedDocument = function (primaryControl, documentId) {
    return Xrm.Navigation.openConfirmDialog({
      title: PayPlus._t("generatedTitle"),
      text: PayPlus._t("generatedText"),
      confirmButtonLabel: PayPlus._t("showDocument"),
      cancelButtonLabel: PayPlus._t("notNow")
    }).then(function (result) {
      if (!result.confirmed) return;
      return PayPlus._openQuoteDocumentPreview(primaryControl, documentId);
    });
  };

  PayPlus._askActivateQuote = function (primaryControl, quoteId) {
    return Xrm.WebApi.retrieveRecord("quote", quoteId, "?$select=statecode,statuscode").then(function (quote) {
      if (quote.statecode === 1) return;
      return Xrm.Navigation.openConfirmDialog({
        title: PayPlus._t("activateTitle"),
        text: PayPlus._t("activateText"),
        confirmButtonLabel: PayPlus._t("activateConfirm"),
        cancelButtonLabel: PayPlus._t("notNow")
      }).then(function (result) {
        if (!result.confirmed) return;
        Xrm.Utility.showProgressIndicator(PayPlus._t("activating"));
        return Xrm.WebApi.updateRecord("quote", quoteId, { statecode: 1, statuscode: 2 }).then(function () {
          Xrm.Utility.closeProgressIndicator();
          try { primaryControl.data.refresh(false); } catch (e) { /* ignore */ }
          return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("activated") });
        }, function (err) {
          Xrm.Utility.closeProgressIndicator();
          throw err;
        });
      });
    });
  };

  PayPlus._sendChannelValue = function (action) {
    if (action === "send-email") return 100000000;
    if (action === "send-sms") return 100000001;
    if (action === "send-whatsapp") return 100000002;
    return null;
  };

  PayPlus._sendChannelName = function (action) {
    if (action === "send-email") return "email";
    if (action === "send-sms") return "sms";
    if (action === "send-whatsapp") return "whatsapp";
    return "";
  };

  PayPlus._quoteLinkPolicy = function (control) {
    var cfg = PayPlus._quoteCfgReady(control) || {};
    return {
      defaultLinkType: cfg.alex_doc_quote_resend_default_linktype || 100000001,
      originalAllowed: cfg.alex_doc_quote_resend_original_allowed !== false,
      copyAllowed: cfg.alex_doc_quote_resend_copy_allowed !== false
    };
  };

  PayPlus._allowedDocumentLinkTypes = function (documentRow, policy) {
    var types = [];
    if (policy.copyAllowed && documentRow && documentRow.alex_copypdfurl) types.push(100000001);
    if (policy.originalAllowed && documentRow && documentRow.alex_pdfurl) types.push(100000000);
    return types;
  };

  PayPlus._chooseSendLinkTypeFromPolicy = function (policy, documentRow) {
    var allowed = PayPlus._allowedDocumentLinkTypes(documentRow, policy);
    if (!allowed.length) return Promise.reject(new Error(PayPlus._t("sendNoDocument")));
    if (allowed.length === 1) return Promise.resolve(allowed[0]);

    var defaultIsCopy = policy.defaultLinkType !== 100000000;
    var confirmValue = defaultIsCopy ? 100000001 : 100000000;
    var cancelValue = defaultIsCopy ? 100000000 : 100000001;
    return Xrm.Navigation.openConfirmDialog({
      title: PayPlus._t("sendTitle"),
      text: PayPlus._t("sendLinkChoice"),
      confirmButtonLabel: defaultIsCopy ? PayPlus._t("sendCopy") : PayPlus._t("sendOriginal"),
      cancelButtonLabel: defaultIsCopy ? PayPlus._t("sendOriginal") : PayPlus._t("sendCopy")
    }).then(function (result) {
      return result.confirmed ? confirmValue : cancelValue;
    });
  };

  PayPlus._chooseSendLinkType = function (control, documentRow) {
    return PayPlus._chooseSendLinkTypeFromPolicy(PayPlus._quoteLinkPolicy(control), documentRow);
  };

  PayPlus._requestedBy = function () {
    try {
      var userSettings = Xrm.Utility.getGlobalContext().userSettings;
      return userSettings.userName || userSettings.userId || "";
    } catch (e) { return ""; }
  };

  PayPlus._queueDocumentSendRequest = function (documentRow, action, linkType) {
    var channel = PayPlus._sendChannelValue(action);
    if (channel == null || !documentRow || !documentRow.alex_payplusdocumentid) return Promise.resolve(false);
    if (linkType === 100000001 && !documentRow.alex_copypdfurl) return Promise.resolve(false);
    if (linkType === 100000000 && !documentRow.alex_pdfurl) return Promise.resolve(false);

    var message = {
      source: "ribbon",
      action: "send",
      channel: PayPlus._sendChannelName(action),
      linkType: linkType === 100000001 ? "copy" : "original",
      documentId: documentRow.alex_payplusdocumentid
    };
    var body = {
      alex_requestedaction: 100000000,
      alex_requestedchannel: channel,
      alex_requestedlinktype: linkType,
      alex_requestedactionstatus: 100000000,
      alex_businessstatus: 100000004,
      alex_requestedactionon: new Date().toISOString(),
      alex_requestedactionby: PayPlus._requestedBy(),
      alex_requestedactionmessage: JSON.stringify(message)
    };
    return Xrm.WebApi.updateRecord("alex_payplusdocument", documentRow.alex_payplusdocumentid, body).then(function () { return true; });
  };

  PayPlus.sendQuoteDocument = function (primaryControl, action) {
    var quoteId = PayPlus._quoteId(primaryControl);
    if (!quoteId) return Xrm.Navigation.openAlertDialog({ text: "PayPlus: Quote record was not found." });

    return PayPlus._findLatestGeneratedQuoteDocument(quoteId).then(function (documentRow) {
      if (!documentRow || !documentRow.alex_payplusdocumentid) return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("sendNoDocument") });
      return PayPlus._chooseSendLinkType(primaryControl, documentRow).then(function (linkType) {
        return PayPlus._queueDocumentSendRequest(documentRow, action, linkType).then(function () {
          return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("sendQueued") });
        });
      });
    });
  };

  PayPlus._openQuoteDocumentPreviewForm = function (documentId) {
    return Xrm.Navigation.navigateTo({
      pageType: "entityrecord",
      entityName: "alex_payplusdocument",
      entityId: documentId
    }, {
      target: 2,
      position: 1,
      width: { value: 82, unit: "%" },
      height: { value: 86, unit: "%" },
      title: PayPlus._quotePreviewTitle()
    });
  };

  PayPlus._currentAppHasPreviewCustomPage = function () {
    if (PayPlus._quotePreviewCustomPageCheck) return PayPlus._quotePreviewCustomPageCheck;

    PayPlus._quotePreviewCustomPageCheck = Promise.resolve().then(function () {
      var globalContext = Xrm.Utility && Xrm.Utility.getGlobalContext && Xrm.Utility.getGlobalContext();
      if (!globalContext || !globalContext.getCurrentAppProperties || !globalContext.getClientUrl || !window.fetch) return false;

      return globalContext.getCurrentAppProperties().then(function (app) {
        var appId = app && app.appId && app.appId.replace(/[{}]/g, "");
        if (!appId) return false;

        return window.fetch(globalContext.getClientUrl() + "/api/data/v9.2/appmodules(" + appId + ")?$select=descriptor", {
          credentials: "same-origin",
          headers: { Accept: "application/json" }
        }).then(function (response) {
          if (!response.ok) return false;
          return response.json();
        }).then(function (data) {
          if (data && data.descriptor && (
            data.descriptor.toLowerCase().indexOf(PREVIEW_CUSTOM_PAGE_ID) >= 0 ||
            data.descriptor.indexOf(PREVIEW_CUSTOM_PAGE_NAME) >= 0
          )) return true;

          return window.fetch(globalContext.getClientUrl() + "/api/data/v9.2/RetrieveAppComponents(AppModuleId=" + appId + ")", {
            credentials: "same-origin",
            headers: { Accept: "application/json" }
          }).then(function (componentResponse) {
            if (!componentResponse.ok) return false;
            return componentResponse.json();
          });
        }).then(function (data) {
          if (data === true || data === false) return data;
          var rows = data && data.value || [];
          for (var i = 0; i < rows.length; i += 1) {
            if (Number(rows[i].componenttype) === 300 && String(rows[i].objectid || "").toLowerCase() === PREVIEW_CUSTOM_PAGE_ID) return true;
          }
          return false;
        }, function () { return false; });
      }, function () { return false; });
    });

    return PayPlus._quotePreviewCustomPageCheck;
  };

  PayPlus._openQuoteDocumentPreview = function (primaryControl, documentId) {
    return PayPlus._currentAppHasPreviewCustomPage().then(function (hasCustomPage) {
      if (!hasCustomPage) return PayPlus._openQuoteDocumentPreviewForm(documentId);

      return Xrm.Navigation.navigateTo({
        pageType: "custom",
        name: PREVIEW_CUSTOM_PAGE_NAME,
        entityName: "alex_payplusdocument",
        recordId: documentId
      }, {
        target: 2,
        position: 1,
        width: { value: 82, unit: "%" },
        height: { value: 86, unit: "%" },
        title: PayPlus._quotePreviewTitle()
      }).catch(function (err) {
        try { console.warn("PayPlus custom page preview failed; falling back to the form dialog.", err); } catch (e) { /* ignore */ }
        return PayPlus._openQuoteDocumentPreviewForm(documentId);
      });
    });
  };

  PayPlus.previewQuoteDocument = function (primaryControl) {
    var quoteId = PayPlus._quoteId(primaryControl);
    if (!quoteId) return Xrm.Navigation.openAlertDialog({ text: "PayPlus: Quote record was not found." });
    var sourceSnapshot = null;
    var latestGenerated = null;

    Xrm.Utility.showProgressIndicator("PayPlus - \u05DE\u05DB\u05D9\u05DF \u05EA\u05E6\u05D5\u05D2\u05D4 \u05DE\u05E7\u05D3\u05D9\u05DE\u05D4...");
    return PayPlus._saveQuoteIfNeeded(primaryControl).then(function () {
      return PayPlus._getQuoteSourceSnapshot(quoteId);
    }).then(function (snapshot) {
      sourceSnapshot = snapshot;
      return PayPlus._findLatestGeneratedQuoteDocument(quoteId);
    }).then(function (documentRow) {
      latestGenerated = documentRow;
      if (!latestGenerated || !latestGenerated.alex_payplusdocumentid) return "";
      if (PayPlus._quoteIsActiveOrClosed(primaryControl)) return latestGenerated.alex_payplusdocumentid;
      if (PayPlus._generatedDocumentMatchesSnapshot(latestGenerated, sourceSnapshot)) return latestGenerated.alex_payplusdocumentid;
      return "";
    }).then(function (documentId) {
      if (documentId) return documentId;
      return PayPlus._findPendingQuotePreviewDocument(quoteId);
    }).then(function (documentId) {
      if (documentId) return documentId;
      return PayPlus._createPendingQuoteDocument(primaryControl, quoteId, "Preview", sourceSnapshot);
    }).then(function (documentId) {
      Xrm.Utility.closeProgressIndicator();
      return PayPlus._openQuoteDocumentPreview(primaryControl, documentId);
    }, function (err) {
      Xrm.Utility.closeProgressIndicator();
      return Xrm.Navigation.openAlertDialog({ text: "PayPlus: " + (err && err.message ? err.message : err) });
    });
  };

  PayPlus.generateQuoteDocument = function (primaryControl) {
    var quoteId = PayPlus._quoteId(primaryControl);
    if (!quoteId) return Xrm.Navigation.openAlertDialog({ text: "PayPlus: Quote record was not found." });

    return Xrm.Navigation.openConfirmDialog({
      title: PayPlus._t("issueTitle"),
      text: PayPlus._t("issueText"),
      confirmButtonLabel: PayPlus._t("issueConfirm"),
      cancelButtonLabel: PayPlus._t("cancel")
    }).then(function (confirm) {
      if (!confirm.confirmed) return;
      Xrm.Utility.showProgressIndicator(PayPlus._t("generating"));
      return PayPlus._saveQuoteIfNeeded(primaryControl).then(function () {
        return PayPlus._getQuoteSourceSnapshot(quoteId);
      }).then(function (sourceSnapshot) {
        return PayPlus._createPendingQuoteDocument(primaryControl, quoteId, "Generate", sourceSnapshot);
      }).then(function (documentId) {
        return PayPlus._pollPayPlusDocument(documentId, Date.now()).then(function () {
          Xrm.Utility.closeProgressIndicator();
          return PayPlus._askOpenIssuedDocument(primaryControl, documentId).then(function () {
            return PayPlus._askActivateQuote(primaryControl, quoteId);
          });
        });
      }).catch(function (err) {
        Xrm.Utility.closeProgressIndicator();
        return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("issueFailed") + (err && err.message ? err.message : err) });
      });
    });
  };

  PayPlus.quoteCommand = function (primaryControl, action) {
    if (action === "preview") return PayPlus.previewQuoteDocument(primaryControl);
    if (action === "generate") return PayPlus.generateQuoteDocument(primaryControl);
    if (action === "send-email" || action === "send-sms" || action === "send-whatsapp") return PayPlus.sendQuoteDocument(primaryControl, action);
    return Xrm.Navigation.openAlertDialog({ text: ALERT_TEXT });
  };

  PayPlus._BULK_MAX = 100;

  PayPlus._normalizeId = function (id) {
    return String(id || "").replace(/[{}]/g, "").toLowerCase();
  };

  PayPlus._chunk = function (arr, size) {
    var out = [];
    for (var i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
    return out;
  };

  PayPlus._gridSelectedIds = function (selectedControl) {
    var ids = [];
    try {
      if (!selectedControl || !selectedControl.getGrid) return ids;
      var selectedRows = selectedControl.getGrid().getSelectedRows();
      if (!selectedRows || !selectedRows.forEach) return ids;

      selectedRows.forEach(function (selectedRow) {
        try {
          var entity = selectedRow.getData().getEntity();
          var id = entity && entity.getId && entity.getId();
          if (id) ids.push(id);
        } catch (e) { /* ignore row */ }
      });
    } catch (e2) { /* ignore grid */ }
    return ids;
  };

  // Gathers quote metadata + already-issued state for the selected ids, in chunks
  // to keep each Web API request URL within a safe length.
  PayPlus._bulkGatherEligibility = function (ids) {
    var chunks = PayPlus._chunk(ids, 25);
    var quotes = {};
    var issued = {};

    var quotePromises = chunks.map(function (chunk) {
      var filter = chunk.map(function (id) { return "quoteid eq " + id; }).join(" or ");
      return Xrm.WebApi.retrieveMultipleRecords("quote", "?$select=quotenumber,name,statecode,_customerid_value&$filter=(" + filter + ")").then(function (res) {
        (res.entities || []).forEach(function (q) {
          var qid = PayPlus._normalizeId(q.quoteid);
          quotes[qid] = {
            name: q.quotenumber || q.name || "Quote",
            statecode: q.statecode,
            hasCustomer: !!q._customerid_value
          };
        });
      });
    });

    var docPromises = chunks.map(function (chunk) {
      var filter = chunk.map(function (id) { return "_alex_quoteid_value eq " + id; }).join(" or ");
      return Xrm.WebApi.retrieveMultipleRecords("alex_payplusdocument", "?$select=_alex_quoteid_value&$filter=(" + filter + ") and alex_documenttypecode eq 'dc_quote' and alex_lastoperation eq 'Generate' and alex_lastsyncstatus eq 100000001").then(function (res) {
        (res.entities || []).forEach(function (d) {
          issued[PayPlus._normalizeId(d._alex_quoteid_value)] = true;
        });
      }, function () { /* ignore document query errors - treat as not issued */ });
    });

    return Promise.all(quotePromises.concat(docPromises)).then(function () {
      return { quotes: quotes, issued: issued };
    });
  };

  // Creates one Pending Generate document row per eligible quote. Config and
  // document type are resolved once and reused. Runs sequentially so the enqueue
  // progress can advance and PayPlus/Power Automate is not flooded at once.
  PayPlus._bulkCreateGenerate = function (eligible, onProgress) {
    return PayPlus._getPreviewConfiguration().then(function (cfg) {
      return PayPlus._getDcQuoteDocumentType(cfg.alex_environment).then(function (docTypeId) {
        var created = 0;
        var failed = 0;
        var i = 0;

        function next() {
          if (i >= eligible.length) return Promise.resolve();
          var q = eligible[i];
          i += 1;
          if (onProgress) onProgress(i, eligible.length);

          var body = {
            alex_name: "PayPlus Quote - " + q.name,
            alex_environment: cfg.alex_environment,
            alex_documenttypecode: "dc_quote",
            alex_uniqueidentifier: "quote-generate-" + q.id + "-" + Date.now(),
            alex_sourceentitylogicalname: "quote",
            alex_sourceentityid: q.id,
            alex_sourcedisplayname: q.name,
            alex_lastsyncstatus: 100000000,
            alex_lastoperation: "Generate",
            alex_origin: 100000000,
            "alex_configurationid@odata.bind": "/alex_payplusconfigurations(" + cfg.alex_payplusconfigurationid + ")",
            "alex_quoteid@odata.bind": "/quotes(" + q.id + ")"
          };
          if (docTypeId) body["alex_documenttypeid@odata.bind"] = "/alex_payplus_documenttypes(" + docTypeId + ")";

          return Xrm.WebApi.createRecord("alex_payplusdocument", body).then(
            function () { created += 1; },
            function () { failed += 1; }
          ).then(next);
        }

        return next().then(function () { return { created: created, failed: failed }; });
      });
    });
  };

  // Optionally activates the eligible quotes in Dynamics 365 after enqueueing.
  PayPlus._bulkActivate = function (eligible, onProgress) {
    var activated = 0;
    var failed = 0;
    var i = 0;

    function next() {
      if (i >= eligible.length) return Promise.resolve();
      var q = eligible[i];
      i += 1;
      if (onProgress) onProgress(i, eligible.length);
      if (q.statecode === 1) return next();

      return Xrm.WebApi.updateRecord("quote", q.id, { statecode: 1, statuscode: 2 }).then(
        function () { activated += 1; },
        function () { failed += 1; }
      ).then(next);
    }

    return next().then(function () { return { activated: activated, failed: failed }; });
  };

  PayPlus.bulkGenerateQuoteDocuments = function (selectedControl, selectedIds) {
    var he = PayPlus._isHebrew();

    var ids = (selectedIds && selectedIds.length ? selectedIds : PayPlus._gridSelectedIds(selectedControl)).map(PayPlus._normalizeId).filter(function (x) { return x; });
    ids = ids.filter(function (v, idx) { return ids.indexOf(v) === idx; });

    if (!ids.length) return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("bulkNoSelection") });

    if (ids.length > PayPlus._BULK_MAX) {
      return Xrm.Navigation.openAlertDialog({
        text: he
          ? ("\u05E0\u05D1\u05D7\u05E8\u05D5 " + ids.length + " \u05D4\u05E6\u05E2\u05D5\u05EA \u05DE\u05D7\u05D9\u05E8. \u05E0\u05D9\u05EA\u05DF \u05DC\u05D4\u05E4\u05D9\u05E7 \u05E2\u05D3 " + PayPlus._BULK_MAX + " \u05D1\u05DB\u05DC \u05E4\u05E2\u05DD. \u05E6\u05DE\u05E6\u05DE\u05D5 \u05D0\u05EA \u05D4\u05D1\u05D7\u05D9\u05E8\u05D4 \u05D5\u05E0\u05E1\u05D5 \u05E9\u05D5\u05D1.")
          : (ids.length + " quotes selected. Up to " + PayPlus._BULK_MAX + " can be issued at once. Reduce the selection and try again.")
      });
    }

    Xrm.Utility.showProgressIndicator(he ? "PayPlus - \u05D1\u05D5\u05D3\u05E7 \u05DB\u05E9\u05D9\u05E8\u05D5\u05EA..." : "PayPlus - checking eligibility...");

    return PayPlus._bulkGatherEligibility(ids).then(function (info) {
      Xrm.Utility.closeProgressIndicator();

      var eligible = [];
      var alreadyIssued = 0;
      var alreadyActive = 0;
      var noCustomer = 0;
      var missing = 0;

      ids.forEach(function (id) {
        var q = info.quotes[id];
        if (!q) { missing += 1; return; }
        if (info.issued[id]) { alreadyIssued += 1; return; }
        if (q.statecode === 1) { alreadyActive += 1; return; }
        if (!q.hasCustomer) { noCustomer += 1; return; }
        eligible.push({ id: id, name: q.name, statecode: q.statecode });
      });

      if (!eligible.length) {
        return Xrm.Navigation.openAlertDialog({
          text: he
            ? ("\u05D0\u05D9\u05DF \u05D4\u05E6\u05E2\u05D5\u05EA \u05DE\u05D7\u05D9\u05E8 \u05DB\u05E9\u05D9\u05E8\u05D5\u05EA \u05DC\u05D4\u05E4\u05E7\u05D4 \u05DE\u05D1\u05D9\u05DF " + ids.length + " \u05E9\u05E0\u05D1\u05D7\u05E8\u05D5 (\u05DB\u05D1\u05E8 \u05D4\u05D5\u05E4\u05E7\u05D5, \u05E4\u05E2\u05D9\u05DC\u05D5\u05EA, \u05D0\u05D5 \u05DC\u05DC\u05D0 \u05DC\u05E7\u05D5\u05D7).")
            : ("None of the " + ids.length + " selected quotes are eligible (already issued, active, or missing customer).")
        });
      }

      var skippedParts = [];
      if (alreadyIssued) skippedParts.push(alreadyIssued + (he ? " \u05DB\u05D1\u05E8 \u05D4\u05D5\u05E4\u05E7\u05D5" : " already issued"));
      if (alreadyActive) skippedParts.push(alreadyActive + (he ? " \u05E4\u05E2\u05D9\u05DC\u05D5\u05EA" : " active"));
      if (noCustomer) skippedParts.push(noCustomer + (he ? " \u05DC\u05DC\u05D0 \u05DC\u05E7\u05D5\u05D7" : " missing customer"));
      if (missing) skippedParts.push(missing + (he ? " \u05DC\u05D0 \u05E0\u05DE\u05E6\u05D0\u05D5" : " not found"));
      var skippedText = "";
      if (skippedParts.length) {
        skippedText = he
          ? (" (" + skippedParts.join(", ") + " \u05D9\u05E1\u05D5\u05E0\u05E0\u05D5.)")
          : (" (" + skippedParts.join(", ") + " will be skipped.)");
      }

      var confirmText = he
        ? ("\u05E0\u05D1\u05D7\u05E8\u05D5 " + ids.length + " \u05D4\u05E6\u05E2\u05D5\u05EA \u05DE\u05D7\u05D9\u05E8. " + eligible.length + " \u05DB\u05E9\u05D9\u05E8\u05D5\u05EA \u05DC\u05D4\u05E4\u05E7\u05D4 \u05D1-PayPlus." + skippedText + " \u05DC\u05D4\u05E4\u05D9\u05E7 \u05D0\u05EA " + eligible.length + " \u05D4\u05DE\u05E1\u05DE\u05DB\u05D9\u05DD?")
        : (ids.length + " quotes selected. " + eligible.length + " are eligible for issuing in PayPlus." + skippedText + " Issue " + eligible.length + " documents?");

      return Xrm.Navigation.openConfirmDialog({
        title: he ? "\u05D4\u05E4\u05E7\u05D4 \u05DE\u05E8\u05D5\u05D1\u05D4 \u05D1-PayPlus" : "Bulk issue in PayPlus",
        text: confirmText,
        confirmButtonLabel: he ? ("\u05D4\u05E4\u05E7 " + eligible.length + " \u05DE\u05E1\u05DE\u05DB\u05D9\u05DD") : ("Issue " + eligible.length + " documents"),
        cancelButtonLabel: PayPlus._t("cancel")
      }).then(function (confirm) {
        if (!confirm.confirmed) return;

        return Xrm.Navigation.openConfirmDialog({
          title: he ? "\u05D4\u05E4\u05E2\u05DC\u05EA \u05D4\u05E6\u05E2\u05D5\u05EA \u05DE\u05D7\u05D9\u05E8" : "Activate quotes",
          text: he
            ? "\u05D4\u05D0\u05DD \u05DC\u05D4\u05E4\u05E2\u05D9\u05DC \u05D2\u05DD \u05D0\u05EA \u05D4\u05E6\u05E2\u05D5\u05EA \u05D4\u05DE\u05D7\u05D9\u05E8 \u05E9\u05E0\u05D1\u05D7\u05E8\u05D5 \u05D1-Dynamics 365 \u05DC\u05D0\u05D7\u05E8 \u05D4\u05D4\u05E4\u05E7\u05D4?"
            : "Do you also want to activate the selected quotes in Dynamics 365 after issuing?",
          confirmButtonLabel: he ? "\u05DB\u05DF, \u05D2\u05DD \u05DC\u05D4\u05E4\u05E2\u05D9\u05DC" : "Yes, activate too",
          cancelButtonLabel: he ? "\u05DC\u05D0, \u05E8\u05E7 \u05D4\u05E4\u05E7\u05D4" : "No, issue only"
        }).then(function (activateConfirm) {
          var doActivate = !!activateConfirm.confirmed;

          return PayPlus._bulkCreateGenerate(eligible, function (done, total) {
            Xrm.Utility.showProgressIndicator((he ? "PayPlus - \u05D9\u05D5\u05E6\u05E8 \u05D1\u05E7\u05E9\u05D5\u05EA \u05D4\u05E4\u05E7\u05D4... " : "PayPlus - creating issue requests... ") + done + "/" + total);
          }).then(function (enqueueResult) {
            if (!doActivate) return { enqueue: enqueueResult, activate: null };
            return PayPlus._bulkActivate(eligible, function (done, total) {
              Xrm.Utility.showProgressIndicator((he ? "Dynamics 365 - \u05DE\u05E4\u05E2\u05D9\u05DC \u05D4\u05E6\u05E2\u05D5\u05EA \u05DE\u05D7\u05D9\u05E8... " : "Dynamics 365 - activating quotes... ") + done + "/" + total);
            }).then(function (activateResult) {
              return { enqueue: enqueueResult, activate: activateResult };
            });
          });
        }).then(function (result) {
          Xrm.Utility.closeProgressIndicator();
          try { if (selectedControl && selectedControl.refresh) selectedControl.refresh(); } catch (e) { /* ignore */ }

          var msg;
          if (he) {
            msg = "\u2713 " + result.enqueue.created + " \u05DE\u05E1\u05DE\u05DB\u05D9\u05DD \u05E0\u05E9\u05DC\u05D7\u05D5 \u05DC\u05D4\u05E4\u05E7\u05D4 \u05D1-PayPlus. \u05D4\u05D4\u05E4\u05E7\u05D4 \u05DE\u05EA\u05D1\u05E6\u05E2\u05EA \u05D1\u05E8\u05E7\u05E2 \u2014 \u05E0\u05D9\u05EA\u05DF \u05DC\u05E2\u05D6\u05D5\u05D1 \u05D0\u05EA \u05D4\u05E2\u05DE\u05D5\u05D3. \u05D4\u05DE\u05E6\u05D1 \u05D9\u05EA\u05E2\u05D3\u05DB\u05DF \u05D1\u05E8\u05E9\u05D5\u05DE\u05D5\u05EA \u05DE\u05E1\u05DE\u05DA PayPlus.";
            if (result.enqueue.failed) msg += " (" + result.enqueue.failed + " \u05E0\u05DB\u05E9\u05DC\u05D5 \u05D1\u05D9\u05E6\u05D9\u05E8\u05D4.)";
            if (result.activate) msg += "\n" + result.activate.activated + " \u05D4\u05E6\u05E2\u05D5\u05EA \u05DE\u05D7\u05D9\u05E8 \u05D4\u05D5\u05E4\u05E2\u05DC\u05D5." + (result.activate.failed ? " (" + result.activate.failed + " \u05E0\u05DB\u05E9\u05DC\u05D5 \u05D1\u05D4\u05E4\u05E2\u05DC\u05D4.)" : "");
          } else {
            msg = "\u2713 " + result.enqueue.created + " documents were queued for issuing in PayPlus. Issuing runs in the background - you can leave the page. Status will update on the PayPlus Document rows.";
            if (result.enqueue.failed) msg += " (" + result.enqueue.failed + " failed to create.)";
            if (result.activate) msg += "\n" + result.activate.activated + " quotes were activated." + (result.activate.failed ? " (" + result.activate.failed + " failed to activate.)" : "");
          }
          return Xrm.Navigation.openAlertDialog({ text: msg });
        });
      });
    }, function (err) {
      Xrm.Utility.closeProgressIndicator();
      return Xrm.Navigation.openAlertDialog({ text: "PayPlus: " + (err && err.message ? err.message : err) });
    });
  };

  PayPlus.bulkSendQuoteDocuments = function (selectedControl, selectedIds, action) {
    var he = PayPlus._isHebrew();
    var ids = (selectedIds && selectedIds.length ? selectedIds : PayPlus._gridSelectedIds(selectedControl)).map(PayPlus._normalizeId).filter(function (x) { return x; });
    ids = ids.filter(function (v, idx) { return ids.indexOf(v) === idx; });

    if (!ids.length) return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("bulkNoSelection") });

    var policy = PayPlus._quoteLinkPolicy(selectedControl);
    return PayPlus._chooseSendLinkType(selectedControl, { alex_pdfurl: policy.originalAllowed ? "1" : "", alex_copypdfurl: policy.copyAllowed ? "1" : "" }).then(function (linkType) {
      var queued = 0;
      var missing = 0;
      var failed = 0;
      var i = 0;

      Xrm.Utility.showProgressIndicator(he ? "PayPlus - \u05DE\u05D1\u05E7\u05E9 \u05E9\u05DC\u05D9\u05D7\u05D4..." : "PayPlus - requesting send...");

      function next() {
        if (i >= ids.length) return Promise.resolve();
        var quoteId = ids[i];
        i += 1;
        Xrm.Utility.showProgressIndicator((he ? "PayPlus - \u05DE\u05D1\u05E7\u05E9 \u05E9\u05DC\u05D9\u05D7\u05D4... " : "PayPlus - requesting send... ") + i + "/" + ids.length);

        return PayPlus._findLatestGeneratedQuoteDocument(quoteId).then(function (documentRow) {
          if (!documentRow || !documentRow.alex_payplusdocumentid) { missing += 1; return; }
          return PayPlus._queueDocumentSendRequest(documentRow, action, linkType).then(function (ok) { if (ok) queued += 1; else missing += 1; });
        }, function () { failed += 1; }).then(next, function () { failed += 1; return next(); });
      }

      return next().then(function () {
        Xrm.Utility.closeProgressIndicator();
        try { if (selectedControl && selectedControl.refresh) selectedControl.refresh(); } catch (e) { /* ignore */ }
        var msg = he
          ? (queued + " \u05D1\u05E7\u05E9\u05D5\u05EA \u05E9\u05DC\u05D9\u05D7\u05D4 \u05E0\u05E8\u05E9\u05DE\u05D5.")
          : (queued + " send requests were recorded.");
        if (missing) msg += he ? (" " + missing + " \u05DC\u05DC\u05D0 \u05DE\u05E1\u05DE\u05DA \u05E9\u05D4\u05D5\u05E4\u05E7.") : (" " + missing + " had no issued document.");
        if (failed) msg += he ? (" " + failed + " \u05E0\u05DB\u05E9\u05DC\u05D5.") : (" " + failed + " failed.");
        return Xrm.Navigation.openAlertDialog({ text: msg || PayPlus._t("sendBulkQueued") });
      }, function (err) {
        Xrm.Utility.closeProgressIndicator();
        return Xrm.Navigation.openAlertDialog({ text: "PayPlus: " + (err && err.message ? err.message : err) });
      });
    });
  };

  PayPlus._salesOrderDocumentTypeCode = "purchase";

  PayPlus._salesOrderFlag = function (control, fieldName) {
    var cfg = PayPlus._quoteCfgReady(control);
    return !!(cfg && cfg.alex_doc_salesorder_enabled === true && cfg[fieldName] === true);
  };

  PayPlus._salesOrderAnySend = function (control) {
    var cfg = PayPlus._quoteCfgReady(control);
    return !!(cfg && cfg.alex_doc_salesorder_enabled === true && (
      cfg.alex_doc_salesorder_resend_email_allowed === true ||
      cfg.alex_doc_salesorder_resend_sms_allowed === true ||
      cfg.alex_doc_salesorder_resend_whatsapp_allowed === true
    ));
  };

  PayPlus._salesOrderLinkPolicy = function (control) {
    var cfg = PayPlus._quoteCfgReady(control) || {};
    return {
      defaultLinkType: cfg.alex_doc_salesorder_resend_default_linktype || 100000001,
      originalAllowed: cfg.alex_doc_salesorder_resend_original_allowed !== false,
      copyAllowed: cfg.alex_doc_salesorder_resend_copy_allowed !== false
    };
  };

  PayPlus._salesOrderId = function (primaryControl) {
    try { return primaryControl.data.entity.getId().replace(/[{}]/g, "").toLowerCase(); }
    catch (e) { return ""; }
  };

  PayPlus._salesOrderDisplayName = function (primaryControl) {
    try {
      var entity = primaryControl.data.entity;
      var numberAttr = entity.attributes.get("ordernumber");
      var nameAttr = entity.attributes.get("name");
      return (numberAttr && numberAttr.getValue && numberAttr.getValue()) ||
        (nameAttr && nameAttr.getValue && nameAttr.getValue()) ||
        entity.getPrimaryAttributeValue() ||
        "Sales Order";
    } catch (e) { return "Sales Order"; }
  };

  PayPlus._salesOrderStateCode = function (primaryControl) {
    try {
      var attr = primaryControl && primaryControl.getAttribute && primaryControl.getAttribute("statecode");
      if (!attr && primaryControl && primaryControl.data && primaryControl.data.entity && primaryControl.data.entity.attributes) {
        attr = primaryControl.data.entity.attributes.get("statecode");
      }
      if (attr && attr.getValue) return attr.getValue();
    } catch (e) { /* ignore */ }
    return null;
  };

  PayPlus._salesOrderIsTerminal = function (primaryControl) {
    var statecode = PayPlus._salesOrderStateCode(primaryControl);
    return statecode === 2 || statecode === 3 || statecode === 4;
  };

  PayPlus._salesOrderFormCommandEnabled = function (primaryControl) {
    return PayPlus._quoteIsSavedForm(primaryControl);
  };

  PayPlus.salesOrderCanShow = function (primaryControl) {
    var cfg = PayPlus._quoteCfgReady(primaryControl);
    return !!(cfg && cfg.alex_doc_salesorder_enabled === true && PayPlus._salesOrderFormCommandEnabled(primaryControl) && (
      PayPlus.salesOrderCanPreview(primaryControl) || PayPlus.salesOrderCanGenerate(primaryControl) || PayPlus.salesOrderCanAnySend(primaryControl)
    ));
  };

  PayPlus.salesOrderCanPreview = function (primaryControl) {
    return !!(PayPlus._salesOrderFormCommandEnabled(primaryControl) && PayPlus._salesOrderFlag(primaryControl, "alex_doc_salesorder_draftpreview"));
  };

  PayPlus.salesOrderCanGenerate = function (primaryControl) {
    var cfg = PayPlus._quoteCfgReady(primaryControl);
    return !!(cfg && cfg.alex_doc_salesorder_enabled === true && PayPlus._salesOrderFormCommandEnabled(primaryControl) && !PayPlus._salesOrderIsTerminal(primaryControl));
  };

  PayPlus.salesOrderCanAnySend = function (primaryControl) {
    return !!(PayPlus._salesOrderFormCommandEnabled(primaryControl) && PayPlus._salesOrderAnySend(primaryControl));
  };

  PayPlus.salesOrderCanSendEmail = function (primaryControl) {
    return !!(PayPlus._salesOrderFormCommandEnabled(primaryControl) && PayPlus._salesOrderFlag(primaryControl, "alex_doc_salesorder_resend_email_allowed"));
  };

  PayPlus.salesOrderCanSendSms = function (primaryControl) {
    return !!(PayPlus._salesOrderFormCommandEnabled(primaryControl) && PayPlus._salesOrderFlag(primaryControl, "alex_doc_salesorder_resend_sms_allowed"));
  };

  PayPlus.salesOrderCanSendWhatsapp = function (primaryControl) {
    return !!(PayPlus._salesOrderFormCommandEnabled(primaryControl) && PayPlus._salesOrderFlag(primaryControl, "alex_doc_salesorder_resend_whatsapp_allowed"));
  };

  PayPlus.salesOrderGridCanShow = function (selectedControl) {
    var cfg = PayPlus._quoteCfgReady(selectedControl);
    return !!(cfg && cfg.alex_doc_salesorder_enabled === true && (
      cfg.alex_doc_salesorder_bulkcreate === true || PayPlus._salesOrderAnySend(selectedControl)
    ));
  };

  PayPlus.salesOrderGridCanGenerate = function (selectedControl) {
    return PayPlus._salesOrderFlag(selectedControl, "alex_doc_salesorder_bulkcreate");
  };

  PayPlus.salesOrderGridCanAnySend = function (selectedControl) {
    return PayPlus._salesOrderAnySend(selectedControl);
  };

  PayPlus.salesOrderGridCanSendEmail = function (selectedControl) {
    return PayPlus._salesOrderFlag(selectedControl, "alex_doc_salesorder_resend_email_allowed");
  };

  PayPlus.salesOrderGridCanSendSms = function (selectedControl) {
    return PayPlus._salesOrderFlag(selectedControl, "alex_doc_salesorder_resend_sms_allowed");
  };

  PayPlus.salesOrderGridCanSendWhatsapp = function (selectedControl) {
    return PayPlus._salesOrderFlag(selectedControl, "alex_doc_salesorder_resend_whatsapp_allowed");
  };

  PayPlus._getDocumentTypeId = function (environmentValue, documentTypeCode) {
    var query = "?$select=alex_payplus_documenttypeid&$filter=alex_code eq '" + documentTypeCode + "' and alex_environment eq " + environmentValue + "&$top=1";
    return Xrm.WebApi.retrieveMultipleRecords("alex_payplus_documenttype", query).then(function (result) {
      return result.entities && result.entities[0] && result.entities[0].alex_payplus_documenttypeid || "";
    }, function () { return ""; });
  };

  PayPlus._getSalesOrderSourceSnapshot = function (orderId) {
    var orderQuery = "?$select=modifiedon,versionnumber,statecode,statuscode,ispricelocked,totalamount";
    var detailQuery = "?$select=salesorderdetailid,modifiedon,versionnumber&$filter=_salesorderid_value eq " + orderId + "&$orderby=modifiedon desc&$top=1&$count=true";
    return Promise.all([
      Xrm.WebApi.retrieveRecord("salesorder", orderId, orderQuery),
      Xrm.WebApi.retrieveMultipleRecords("salesorderdetail", detailQuery)
    ]).then(function (results) {
      var order = results[0] || {};
      var details = results[1] || {};
      var detail = details.entities && details.entities[0] || {};
      var detailCount = details["@odata.count"] || 0;
      var orderVersion = order.versionnumber == null ? "" : String(order.versionnumber);
      var detailVersion = detail.versionnumber == null ? "" : String(detail.versionnumber);
      var orderModified = order.modifiedon || "";
      var detailModified = detail.modifiedon || "";
      var total = order.totalamount == null ? "" : String(order.totalamount);
      return {
        orderModifiedOn: orderModified,
        orderVersionNumber: orderVersion,
        detailModifiedOn: detailModified,
        detailVersionNumber: detailVersion,
        detailCount: detailCount,
        statecode: order.statecode,
        statuscode: order.statuscode,
        isPriceLocked: order.ispricelocked === true,
        fingerprint: [orderModified, orderVersion, detailModified, detailVersion, detailCount, order.statecode, order.statuscode, order.ispricelocked === true, total].join("|")
      };
    });
  };

  PayPlus._findLatestGeneratedSalesOrderDocument = function (orderId) {
    var query = "?$select=alex_payplusdocumentid,alex_sourcefingerprint,alex_documenturl,alex_pdfurl,alex_copypdfurl,modifiedon&$filter=_alex_salesorderid_value eq " + orderId + " and alex_documenttypecode eq '" + PayPlus._salesOrderDocumentTypeCode + "' and alex_lastoperation eq 'Generate' and alex_lastsyncstatus eq 100000001&$orderby=modifiedon desc&$top=1";
    return Xrm.WebApi.retrieveMultipleRecords("alex_payplusdocument", query).then(function (result) {
      return result.entities && result.entities[0] || null;
    }, function () { return null; });
  };

  PayPlus._findPendingSalesOrderPreviewDocument = function (orderId) {
    var query = "?$select=alex_payplusdocumentid,modifiedon&$filter=_alex_salesorderid_value eq " + orderId + " and alex_documenttypecode eq '" + PayPlus._salesOrderDocumentTypeCode + "' and alex_lastoperation eq 'Preview' and alex_lastsyncstatus eq 100000000&$orderby=modifiedon desc&$top=1";
    return Xrm.WebApi.retrieveMultipleRecords("alex_payplusdocument", query).then(function (result) {
      var row = result.entities && result.entities[0];
      if (!row || !row.alex_payplusdocumentid) return "";
      var modified = row.modifiedon ? new Date(row.modifiedon).getTime() : 0;
      if (!modified || Date.now() - modified > PENDING_PREVIEW_REUSE_MS) return "";
      return row.alex_payplusdocumentid;
    });
  };

  PayPlus._addSalesOrderSourceSnapshot = function (body, snapshot) {
    if (!body || !snapshot) return body;
    body.alex_sourcemodifiedon = snapshot.orderModifiedOn || null;
    body.alex_sourceversionnumber = snapshot.orderVersionNumber || "";
    body.alex_sourcedetailmodifiedon = snapshot.detailModifiedOn || null;
    body.alex_sourcedetailversionnumber = snapshot.detailVersionNumber || "";
    body.alex_sourcedetailcount = snapshot.detailCount || 0;
    body.alex_sourcefingerprint = snapshot.fingerprint || "";
    return body;
  };

  PayPlus._createPendingSalesOrderDocument = function (primaryControl, orderId, operation, sourceSnapshot) {
    operation = operation || "Preview";
    var displayName = PayPlus._salesOrderDisplayName(primaryControl);
    return PayPlus._getPreviewConfiguration().then(function (cfg) {
      return PayPlus._getDocumentTypeId(cfg.alex_environment, PayPlus._salesOrderDocumentTypeCode).then(function (docTypeId) {
        var isGenerate = operation === "Generate";
        var prefix = isGenerate ? "salesorder-generate-" : "salesorder-preview-";
        var body = {
          alex_name: (isGenerate ? "PayPlus Sales Order - " : "PayPlus Sales Order Preview - ") + displayName,
          alex_environment: cfg.alex_environment,
          alex_documenttypecode: PayPlus._salesOrderDocumentTypeCode,
          alex_uniqueidentifier: prefix + orderId + "-" + Date.now(),
          alex_sourceentitylogicalname: "salesorder",
          alex_sourceentityid: orderId,
          alex_sourcedisplayname: displayName,
          alex_lastsyncstatus: 100000000,
          alex_businessstatus: isGenerate ? 100000002 : 100000000,
          alex_lastoperation: operation,
          alex_origin: 100000000,
          "alex_configurationid@odata.bind": "/alex_payplusconfigurations(" + cfg.alex_payplusconfigurationid + ")",
          "alex_salesorderid@odata.bind": "/salesorders(" + orderId + ")"
        };
        PayPlus._addSalesOrderSourceSnapshot(body, sourceSnapshot);
        if (docTypeId) body["alex_documenttypeid@odata.bind"] = "/alex_payplus_documenttypes(" + docTypeId + ")";
        return Xrm.WebApi.createRecord("alex_payplusdocument", body).then(function (created) {
          return created.id.replace(/[{}]/g, "").toLowerCase();
        });
      });
    });
  };

  PayPlus.previewSalesOrderDocument = function (primaryControl) {
    var orderId = PayPlus._salesOrderId(primaryControl);
    if (!orderId) return Xrm.Navigation.openAlertDialog({ text: "PayPlus: Sales Order record was not found." });
    var sourceSnapshot = null;
    Xrm.Utility.showProgressIndicator(PayPlus._isHebrew() ? "PayPlus - \u05DE\u05DB\u05D9\u05DF \u05EA\u05E6\u05D5\u05D2\u05D4 \u05DE\u05E7\u05D3\u05D9\u05DE\u05D4..." : "PayPlus - preparing preview...");
    return PayPlus._saveQuoteIfNeeded(primaryControl).then(function () {
      return PayPlus._getSalesOrderSourceSnapshot(orderId);
    }).then(function (snapshot) {
      sourceSnapshot = snapshot;
      return PayPlus._findLatestGeneratedSalesOrderDocument(orderId);
    }).then(function (documentRow) {
      if (!documentRow || !documentRow.alex_payplusdocumentid) return "";
      if (PayPlus._salesOrderIsTerminal(primaryControl)) return documentRow.alex_payplusdocumentid;
      if (PayPlus._generatedDocumentMatchesSnapshot(documentRow, sourceSnapshot)) return documentRow.alex_payplusdocumentid;
      return "";
    }).then(function (documentId) {
      if (documentId) return documentId;
      return PayPlus._findPendingSalesOrderPreviewDocument(orderId);
    }).then(function (documentId) {
      if (documentId) return documentId;
      return PayPlus._createPendingSalesOrderDocument(primaryControl, orderId, "Preview", sourceSnapshot);
    }).then(function (documentId) {
      Xrm.Utility.closeProgressIndicator();
      return PayPlus._openQuoteDocumentPreview(primaryControl, documentId);
    }, function (err) {
      Xrm.Utility.closeProgressIndicator();
      return Xrm.Navigation.openAlertDialog({ text: "PayPlus: " + (err && err.message ? err.message : err) });
    });
  };

  PayPlus.generateSalesOrderDocument = function (primaryControl) {
    var orderId = PayPlus._salesOrderId(primaryControl);
    if (!orderId) return Xrm.Navigation.openAlertDialog({ text: "PayPlus: Sales Order record was not found." });
    return PayPlus._getSalesOrderSourceSnapshot(orderId).then(function (snapshot) {
      if (snapshot.statecode !== 0 && snapshot.statecode !== 1) {
        return Xrm.Navigation.openAlertDialog({ text: PayPlus._isHebrew() ? "לא ניתן להפיק מסמך PayPlus להזמנה במצב זה." : "A PayPlus document cannot be issued for this order state." });
      }
      if (!snapshot.isPriceLocked) {
        return Xrm.Navigation.openAlertDialog({ text: PayPlus._isHebrew() ? "יש לנעול מחירים לפני הפקת מסמך PayPlus להזמנה." : "Lock prices before issuing a PayPlus document for this order." });
      }
      return Xrm.Navigation.openConfirmDialog({
        title: PayPlus._t("issueTitle"),
        text: PayPlus._isHebrew() ? "המסמך יופק ב-PayPlus על בסיס נתוני ההזמנה השמורים. האם לאשר הפקה?" : "The document will be issued in PayPlus using the saved Sales Order data. Continue?",
        confirmButtonLabel: PayPlus._t("issueConfirm"),
        cancelButtonLabel: PayPlus._t("cancel")
      }).then(function (confirm) {
        if (!confirm.confirmed) return;
        Xrm.Utility.showProgressIndicator(PayPlus._t("generating"));
        return PayPlus._saveQuoteIfNeeded(primaryControl).then(function () {
          return PayPlus._getSalesOrderSourceSnapshot(orderId);
        }).then(function (freshSnapshot) {
          return PayPlus._createPendingSalesOrderDocument(primaryControl, orderId, "Generate", freshSnapshot);
        }).then(function (documentId) {
          return PayPlus._pollPayPlusDocument(documentId, Date.now()).then(function () {
            Xrm.Utility.closeProgressIndicator();
            return PayPlus._askOpenIssuedDocument(primaryControl, documentId);
          });
        }).catch(function (err) {
          Xrm.Utility.closeProgressIndicator();
          return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("issueFailed") + (err && err.message ? err.message : err) });
        });
      });
    });
  };

  PayPlus.sendSalesOrderDocument = function (primaryControl, action) {
    var orderId = PayPlus._salesOrderId(primaryControl);
    if (!orderId) return Xrm.Navigation.openAlertDialog({ text: "PayPlus: Sales Order record was not found." });
    return PayPlus._findLatestGeneratedSalesOrderDocument(orderId).then(function (documentRow) {
      if (!documentRow || !documentRow.alex_payplusdocumentid) return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("sendNoDocument") });
      var policy = PayPlus._salesOrderLinkPolicy(primaryControl);
      return PayPlus._chooseSendLinkTypeFromPolicy ? PayPlus._chooseSendLinkTypeFromPolicy(policy, documentRow) : PayPlus._chooseSendLinkType(primaryControl, documentRow);
    }).then(function (linkType) {
      return PayPlus._findLatestGeneratedSalesOrderDocument(orderId).then(function (documentRow) {
        return PayPlus._queueDocumentSendRequest(documentRow, action, linkType).then(function () {
          return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("sendQueued") });
        });
      });
    });
  };

  PayPlus.salesOrderCommand = function (primaryControl, action) {
    if (action === "preview") return PayPlus.previewSalesOrderDocument(primaryControl);
    if (action === "generate") return PayPlus.generateSalesOrderDocument(primaryControl);
    if (action === "send-email" || action === "send-sms" || action === "send-whatsapp") return PayPlus.sendSalesOrderDocument(primaryControl, action);
    return Xrm.Navigation.openAlertDialog({ text: ALERT_TEXT });
  };

  PayPlus.salesOrderGridCommand = function (selectedControl, selectedIds, action) {
    if (action === "generate") return PayPlus.bulkGenerateSalesOrderDocuments(selectedControl, selectedIds);
    if (action === "send-email" || action === "send-sms" || action === "send-whatsapp") return PayPlus.bulkSendSalesOrderDocuments(selectedControl, selectedIds, action);
    return Xrm.Navigation.openAlertDialog({ text: ALERT_TEXT });
  };

  PayPlus._bulkGatherSalesOrderEligibility = function (ids) {
    var chunks = PayPlus._chunk(ids, 25);
    var orders = {};
    var issued = {};

    var orderPromises = chunks.map(function (chunk) {
      var filter = chunk.map(function (id) { return "salesorderid eq " + id; }).join(" or ");
      return Xrm.WebApi.retrieveMultipleRecords("salesorder", "?$select=ordernumber,name,statecode,statuscode,ispricelocked,_customerid_value&$filter=(" + filter + ")").then(function (res) {
        (res.entities || []).forEach(function (o) {
          var oid = PayPlus._normalizeId(o.salesorderid);
          orders[oid] = {
            name: o.ordernumber || o.name || "Sales Order",
            statecode: o.statecode,
            statuscode: o.statuscode,
            isPriceLocked: o.ispricelocked === true,
            hasCustomer: !!o._customerid_value
          };
        });
      });
    });

    var detailPromises = chunks.map(function (chunk) {
      var filter = chunk.map(function (id) { return "_salesorderid_value eq " + id; }).join(" or ");
      return Xrm.WebApi.retrieveMultipleRecords("salesorderdetail", "?$select=_salesorderid_value&$filter=(" + filter + ")").then(function (res) {
        (res.entities || []).forEach(function (d) {
          var oid = PayPlus._normalizeId(d._salesorderid_value);
          if (orders[oid]) orders[oid].hasLines = true;
        });
      }, function () { /* ignore */ });
    });

    var docPromises = chunks.map(function (chunk) {
      var filter = chunk.map(function (id) { return "_alex_salesorderid_value eq " + id; }).join(" or ");
      return Xrm.WebApi.retrieveMultipleRecords("alex_payplusdocument", "?$select=_alex_salesorderid_value&$filter=(" + filter + ") and alex_documenttypecode eq '" + PayPlus._salesOrderDocumentTypeCode + "' and alex_lastoperation eq 'Generate' and alex_lastsyncstatus eq 100000001").then(function (res) {
        (res.entities || []).forEach(function (d) {
          issued[PayPlus._normalizeId(d._alex_salesorderid_value)] = true;
        });
      }, function () { /* ignore */ });
    });

    return Promise.all(orderPromises.concat(detailPromises).concat(docPromises)).then(function () {
      return { orders: orders, issued: issued };
    });
  };

  PayPlus._bulkCreateSalesOrderGenerate = function (eligible, onProgress) {
    return PayPlus._getPreviewConfiguration().then(function (cfg) {
      return PayPlus._getDocumentTypeId(cfg.alex_environment, PayPlus._salesOrderDocumentTypeCode).then(function (docTypeId) {
        var created = 0;
        var failed = 0;
        var i = 0;

        function next() {
          if (i >= eligible.length) return Promise.resolve();
          var o = eligible[i];
          i += 1;
          if (onProgress) onProgress(i, eligible.length);

          return PayPlus._getSalesOrderSourceSnapshot(o.id).then(function (snapshot) {
            var body = {
              alex_name: "PayPlus Sales Order - " + o.name,
              alex_environment: cfg.alex_environment,
              alex_documenttypecode: PayPlus._salesOrderDocumentTypeCode,
              alex_uniqueidentifier: "salesorder-generate-" + o.id + "-" + Date.now(),
              alex_sourceentitylogicalname: "salesorder",
              alex_sourceentityid: o.id,
              alex_sourcedisplayname: o.name,
              alex_lastsyncstatus: 100000000,
              alex_businessstatus: 100000002,
              alex_lastoperation: "Generate",
              alex_origin: 100000000,
              "alex_configurationid@odata.bind": "/alex_payplusconfigurations(" + cfg.alex_payplusconfigurationid + ")",
              "alex_salesorderid@odata.bind": "/salesorders(" + o.id + ")"
            };
            PayPlus._addSalesOrderSourceSnapshot(body, snapshot);
            if (docTypeId) body["alex_documenttypeid@odata.bind"] = "/alex_payplus_documenttypes(" + docTypeId + ")";
            return Xrm.WebApi.createRecord("alex_payplusdocument", body).then(
              function () { created += 1; },
              function () { failed += 1; }
            );
          }).then(next, function () { failed += 1; return next(); });
        }

        return next().then(function () { return { created: created, failed: failed }; });
      });
    });
  };

  PayPlus.bulkGenerateSalesOrderDocuments = function (selectedControl, selectedIds) {
    var he = PayPlus._isHebrew();
    var ids = (selectedIds && selectedIds.length ? selectedIds : PayPlus._gridSelectedIds(selectedControl)).map(PayPlus._normalizeId).filter(function (x) { return x; });
    ids = ids.filter(function (v, idx) { return ids.indexOf(v) === idx; });
    if (!ids.length) return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("bulkNoSelection") });

    Xrm.Utility.showProgressIndicator(he ? "PayPlus - \u05D1\u05D5\u05D3\u05E7 \u05DB\u05E9\u05D9\u05E8\u05D5\u05EA..." : "PayPlus - checking eligibility...");
    return PayPlus._bulkGatherSalesOrderEligibility(ids).then(function (info) {
      Xrm.Utility.closeProgressIndicator();
      var eligible = [];
      var skipped = 0;
      ids.forEach(function (id) {
        var o = info.orders[id];
        if (!o || info.issued[id] || !o.hasCustomer || !o.hasLines || !o.isPriceLocked || (o.statecode !== 0 && o.statecode !== 1)) { skipped += 1; return; }
        eligible.push({ id: id, name: o.name });
      });
      if (!eligible.length) return Xrm.Navigation.openAlertDialog({ text: he ? "אין הזמנות כשירות להפקה. נדרש לקוח, שורות, מחירים נעולים ומצב פעיל/נשלח." : "No selected sales orders are eligible. Customer, lines, locked prices, and Active/Submitted state are required." });

      return Xrm.Navigation.openConfirmDialog({
        title: he ? "הפקת הזמנות ב-PayPlus" : "Issue sales orders in PayPlus",
        text: he ? (eligible.length + " הזמנות כשירות. " + skipped + " ידולגו. להפיק?") : (eligible.length + " orders are eligible. " + skipped + " will be skipped. Issue documents?"),
        confirmButtonLabel: he ? "הפק" : "Issue",
        cancelButtonLabel: PayPlus._t("cancel")
      }).then(function (confirm) {
        if (!confirm.confirmed) return;
        return PayPlus._bulkCreateSalesOrderGenerate(eligible, function (done, total) {
          Xrm.Utility.showProgressIndicator((he ? "PayPlus - יוצר בקשות הפקה... " : "PayPlus - creating issue requests... ") + done + "/" + total);
        }).then(function (result) {
          Xrm.Utility.closeProgressIndicator();
          try { if (selectedControl && selectedControl.refresh) selectedControl.refresh(); } catch (e) { /* ignore */ }
          return Xrm.Navigation.openAlertDialog({ text: he ? (result.created + " בקשות הפקה נרשמו." + (result.failed ? " " + result.failed + " נכשלו." : "")) : (result.created + " issue requests were queued." + (result.failed ? " " + result.failed + " failed." : "")) });
        });
      });
    }, function (err) {
      Xrm.Utility.closeProgressIndicator();
      return Xrm.Navigation.openAlertDialog({ text: "PayPlus: " + (err && err.message ? err.message : err) });
    });
  };

  PayPlus.bulkSendSalesOrderDocuments = function (selectedControl, selectedIds, action) {
    var he = PayPlus._isHebrew();
    var ids = (selectedIds && selectedIds.length ? selectedIds : PayPlus._gridSelectedIds(selectedControl)).map(PayPlus._normalizeId).filter(function (x) { return x; });
    ids = ids.filter(function (v, idx) { return ids.indexOf(v) === idx; });
    if (!ids.length) return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("bulkNoSelection") });

    var policy = PayPlus._salesOrderLinkPolicy(selectedControl);
    return PayPlus._chooseSendLinkTypeFromPolicy(policy, { alex_pdfurl: policy.originalAllowed ? "1" : "", alex_copypdfurl: policy.copyAllowed ? "1" : "" }).then(function (linkType) {
      var queued = 0;
      var missing = 0;
      var failed = 0;
      var i = 0;
      Xrm.Utility.showProgressIndicator(he ? "PayPlus - מבקש שליחה..." : "PayPlus - requesting send...");

      function next() {
        if (i >= ids.length) return Promise.resolve();
        var orderId = ids[i];
        i += 1;
        Xrm.Utility.showProgressIndicator((he ? "PayPlus - מבקש שליחה... " : "PayPlus - requesting send... ") + i + "/" + ids.length);
        return PayPlus._findLatestGeneratedSalesOrderDocument(orderId).then(function (documentRow) {
          if (!documentRow || !documentRow.alex_payplusdocumentid) { missing += 1; return; }
          return PayPlus._queueDocumentSendRequest(documentRow, action, linkType).then(function (ok) { if (ok) queued += 1; else missing += 1; });
        }, function () { failed += 1; }).then(next, function () { failed += 1; return next(); });
      }

      return next().then(function () {
        Xrm.Utility.closeProgressIndicator();
        try { if (selectedControl && selectedControl.refresh) selectedControl.refresh(); } catch (e) { /* ignore */ }
        var msg = he ? (queued + " בקשות שליחה נרשמו.") : (queued + " send requests were recorded.");
        if (missing) msg += he ? (" " + missing + " ללא מסמך שהופק.") : (" " + missing + " had no issued document.");
        if (failed) msg += he ? (" " + failed + " נכשלו.") : (" " + failed + " failed.");
        return Xrm.Navigation.openAlertDialog({ text: msg });
      });
    });
  };

  PayPlus.quoteGridCommand = function (selectedControl, selectedIds, action) {
    if (action === "generate") return PayPlus.bulkGenerateQuoteDocuments(selectedControl, selectedIds);
    if (action === "send-email" || action === "send-sms" || action === "send-whatsapp") return PayPlus.bulkSendQuoteDocuments(selectedControl, selectedIds, action);
    return Xrm.Navigation.openAlertDialog({ text: ALERT_TEXT });
  };

  PayPlus._invoiceId = function (primaryControl) {
    try { return primaryControl.data.entity.getId().replace(/[{}]/g, "").toLowerCase(); }
    catch (e) { return ""; }
  };

  PayPlus._invoiceDisplayName = function (primaryControl) {
    try {
      var entity = primaryControl.data.entity;
      var numberAttr = entity.attributes.get("invoicenumber");
      var nameAttr = entity.attributes.get("name");
      return (numberAttr && numberAttr.getValue && numberAttr.getValue()) ||
        (nameAttr && nameAttr.getValue && nameAttr.getValue()) ||
        entity.getPrimaryAttributeValue() ||
        "Invoice";
    } catch (e) { return "Invoice"; }
  };

  PayPlus.invoiceCanShow = function (primaryControl) {
    var cfg = PayPlus._quoteCfgReady(primaryControl);
    var canShow = !!(cfg && PayPlus._quoteIsSavedForm(primaryControl) && PayPlus._invoiceIsReady(primaryControl) && PayPlus._invoiceAnyBillingActionAllowed(primaryControl));
    // Warm the demand-document cache at ribbon-init time (and again after the config loads and the
    // ribbon refreshes). The nested "Payment Workbench" (קליטת תשלום) display rule only evaluates
    // when the flyout is populated (PopulateOnlyOnce), so kicking the async load here ensures the
    // answer is cached before the flyout opens - otherwise the button never appears in time.
    if (canShow) PayPlus._invoiceHasDemandDoc(primaryControl, PayPlus._invoiceId(primaryControl));
    return canShow;
  };

  PayPlus.invoiceFormCommandEnabled = function (primaryControl) {
    return PayPlus._quoteIsSavedForm(primaryControl);
  };

  PayPlus._invoiceStateCode = function (primaryControl) {
    try {
      var attr = primaryControl && primaryControl.getAttribute && primaryControl.getAttribute("statecode");
      if (!attr && primaryControl && primaryControl.data && primaryControl.data.entity && primaryControl.data.entity.attributes) attr = primaryControl.data.entity.attributes.get("statecode");
      if (attr && attr.getValue) {
        var value = attr.getValue();
        return (value === null || value === undefined) ? -1 : value;
      }
    } catch (e) { /* ignore */ }
    return -1;
  };

  // Hide "Payment Workbench" (קליטת תשלום) once the invoice is Paid (2) or Closed/Cancelled (1).
  PayPlus.invoicePaymentWorkbenchCanShow = function (primaryControl) {
    var state = PayPlus._invoiceStateCode(primaryControl);
    if (state === 1 || state === 2) return false;
    if (!PayPlus.invoiceCanShow(primaryControl)) return false;
    // There must be something open to collect against: a demand document (tax invoice / proforma /
    // payment request) must already have been issued for this invoice.
    return PayPlus._invoiceHasDemandDoc(primaryControl, PayPlus._invoiceId(primaryControl)) === true;
  };

  // Cache of "does this invoice already have an issued demand document?" keyed by invoice id.
  PayPlus._invoiceDemandDocCache = PayPlus._invoiceDemandDocCache || {};

  PayPlus._loadInvoiceDemandDoc = function (control, invoiceId) {
    if (PayPlus._invoiceDemandDocLoading === invoiceId) return;
    PayPlus._invoiceDemandDocLoading = invoiceId;
    var codes = "(alex_documenttypecode eq 'inv_tax' or alex_documenttypecode eq 'inv_proforma' or alex_documenttypecode eq 'inv_pay_request')";
    var query = "?$select=alex_payplusdocumentid&$filter=alex_sourceentitylogicalname eq 'invoice' and alex_sourceentityid eq '" + invoiceId.replace(/'/g, "''") + "' and alex_lastoperation eq 'Generate' and alex_lastsyncstatus eq 100000001 and " + codes + "&$top=1";
    Xrm.WebApi.retrieveMultipleRecords("alex_payplusdocument", query).then(
      function (result) {
        PayPlus._invoiceDemandDocCache[invoiceId] = !!(result.entities && result.entities.length);
        PayPlus._invoiceDemandDocLoading = null;
        PayPlus._quoteRefreshRibbon(control);
      },
      function () {
        PayPlus._invoiceDemandDocCache[invoiceId] = false;
        PayPlus._invoiceDemandDocLoading = null;
      }
    );
  };

  PayPlus._invoiceHasDemandDoc = function (control, invoiceId) {
    if (!invoiceId) return false;
    if (Object.prototype.hasOwnProperty.call(PayPlus._invoiceDemandDocCache, invoiceId)) return PayPlus._invoiceDemandDocCache[invoiceId];
    PayPlus._loadInvoiceDemandDoc(control, invoiceId);
    return null;
  };

  PayPlus._invoiceIsReady = function (primaryControl) {
    try {
      var attr = primaryControl && primaryControl.getAttribute && primaryControl.getAttribute("ispricelocked");
      if (!attr && primaryControl && primaryControl.data && primaryControl.data.entity && primaryControl.data.entity.attributes) attr = primaryControl.data.entity.attributes.get("ispricelocked");
      if (attr && attr.getValue && attr.getValue() !== true) return false;
    } catch (e) { /* ignore */ }
    return true;
  };

  PayPlus._invoiceBillingDocs = {
    taxinvoice: { code: "inv_tax", role: 100000001, labelHe: "חשבונית מס", labelEn: "Tax invoice" },
    taxinvoicereceipt: { code: "inv_tax_receipt", role: 100000003, labelHe: "חשבונית מס קבלה", labelEn: "Tax invoice receipt" },
    paymentdemand: { code: "inv_proforma", role: 100000000, labelHe: "חשבונית עסקה", labelEn: "Proforma invoice" },
    paymentrequest: { code: "inv_pay_request", role: 100000000, labelHe: "בקשת תשלום", labelEn: "Payment request" },
    creditinvoice: { code: "inv_refund", role: 100000004, labelHe: "חשבונית זיכוי", labelEn: "Credit invoice" }
  };

  PayPlus._invoiceBillingDoc = function (key) {
    return PayPlus._invoiceBillingDocs[key] || null;
  };

  PayPlus._invoiceBillingDocLabel = function (doc) {
    if (!doc) return "";
    return PayPlus._isHebrew() ? (doc.labelHe || doc.labelEn || doc.code) : (doc.labelEn || doc.labelHe || doc.code);
  };

  PayPlus._invoiceIssueText = function (doc) {
    var code = doc && doc.code;
    if (PayPlus._isHebrew()) {
      if (code === "inv_tax") return "חשבונית המס תופק ב-PayPlus על בסיס נתוני החשבונית השמורים ב-Dynamics 365. האם לאשר הפקה?";
      if (code === "inv_refund") return "חשבונית זיכוי תופק ב-PayPlus לביטול המסמך הקודם. האם לאשר?";
      if (code === "inv_proforma") return "חשבונית העסקה תופק ב-PayPlus על בסיס נתוני החשבונית השמורים ב-Dynamics 365. האם לאשר הפקה?";
      if (code === "inv_pay_request") return "בקשת התשלום תופק ב-PayPlus על בסיס נתוני החשבונית השמורים ב-Dynamics 365. האם לאשר הפקה?";
      return "המסמך יופק ב-PayPlus על בסיס נתוני החשבונית השמורים ב-Dynamics 365. האם לאשר הפקה?";
    }
    if (code === "inv_tax") return "The tax invoice will be issued in PayPlus using the saved Dynamics 365 invoice data. Continue?";
    if (code === "inv_refund") return "A credit invoice will be issued in PayPlus to cancel the previous document. Continue?";
    if (code === "inv_proforma") return "The proforma invoice will be issued in PayPlus using the saved Dynamics 365 invoice data. Continue?";
    if (code === "inv_pay_request") return "The payment request will be issued in PayPlus using the saved Dynamics 365 invoice data. Continue?";
    return "The document will be issued in PayPlus using the saved Dynamics 365 invoice data. Continue?";
  };

  PayPlus._invoiceDocPrefix = function (key) {
    return "alex_billing_doc_" + key + "_";
  };

  PayPlus._invoiceDocAllowedByDefaultFlow = function (control, key) {
    var cfg = PayPlus._quoteCfgReady(control);
    if (!cfg) return false;
    if (cfg.alex_billing_allow_user_override === true) return true;

    var flow = cfg.alex_billing_default_flow;
    if (flow == null || flow === 100000004) return true;
    var docKeyByFlow = {
      100000000: "paymentdemand",
      100000001: "paymentrequest",
      100000002: "taxinvoice",
      100000003: "taxinvoicereceipt"
    };
    return docKeyByFlow[flow] ? key === docKeyByFlow[flow] : true;
  };

  PayPlus._invoiceDefaultDocKey = function (primaryControl) {
    var cfg = PayPlus._quoteCfgReady(primaryControl);
    if (!cfg) return "";
    var docKeyByFlow = {
      100000000: "paymentdemand",
      100000001: "paymentrequest",
      100000002: "taxinvoice",
      100000003: "taxinvoicereceipt"
    };
    return docKeyByFlow[cfg.alex_billing_default_flow] || "";
  };

  PayPlus._invoiceDocEnabled = function (primaryControl, key) {
    var cfg = PayPlus._quoteCfgReady(primaryControl);
    return !!(cfg && PayPlus._invoiceDocAllowedByDefaultFlow(primaryControl, key) && cfg[PayPlus._invoiceDocPrefix(key) + "enabled"] === true);
  };

  PayPlus._invoiceDocActionAllowed = function (primaryControl, key, action) {
    var cfg = PayPlus._quoteCfgReady(primaryControl);
    if (!(PayPlus._invoiceDocEnabled(primaryControl, key) && cfg && cfg[PayPlus._invoiceDocPrefix(key) + action] === true)) return false;
    // Lifecycle gating: once an invoice is Cancelled (2) no PayPlus action is relevant; once it is
    // Paid/Closed (1) the collection lifecycle is complete, so no new document should be issued or
    // previewed - only re-sending an already-issued document remains available.
    var state = PayPlus._invoiceStateCode(primaryControl);
    if (state === 2) return false;
    if (state === 1 && (action === "issue_allowed" || action === "preview_allowed")) return false;
    return true;
  };

  PayPlus._invoiceAnyBillingActionAllowed = function (primaryControl) {
    var keys = ["taxinvoice", "taxinvoicereceipt", "paymentdemand", "paymentrequest"];
    for (var i = 0; i < keys.length; i += 1) {
      if (PayPlus.invoiceDocRecommendedCanShow(primaryControl, keys[i])) return true;
      if (PayPlus.invoiceDocCanShow(primaryControl, keys[i])) return true;
    }
    return false;
  };

  PayPlus.invoiceDocCanShow = function (primaryControl, key) {
    if (PayPlus._invoiceDocShownAsRecommended(primaryControl, key)) return false;
    // Tax-invoice-receipt is issued exclusively through the payment wizard - it has no standalone
    // preview or send actions, so its flyout appears only when issuing is allowed.
    if (key === "taxinvoicereceipt") return PayPlus._invoiceDocActionAllowed(primaryControl, key, "issue_allowed");
    return !!(PayPlus._invoiceDocActionAllowed(primaryControl, key, "issue_allowed") ||
      PayPlus._invoiceDocActionAllowed(primaryControl, key, "preview_allowed") ||
      PayPlus._invoiceDocActionAllowed(primaryControl, key, "send_email_allowed") ||
      PayPlus._invoiceDocActionAllowed(primaryControl, key, "send_sms_allowed") ||
      PayPlus._invoiceDocActionAllowed(primaryControl, key, "send_whatsapp_allowed"));
  };

  PayPlus._invoiceDocShownAsRecommended = function (primaryControl, key) {
    var cfg = PayPlus._quoteCfgReady(primaryControl);
    return !!(cfg && cfg.alex_billing_allow_user_override === true && PayPlus._invoiceDefaultDocKey(primaryControl) === key && PayPlus._invoiceDocActionAllowed(primaryControl, key, "issue_allowed"));
  };

  PayPlus.invoiceDocRecommendedCanShow = function (primaryControl, key) {
    return !!(PayPlus._quoteIsSavedForm(primaryControl) && PayPlus._invoiceIsReady(primaryControl) && PayPlus._invoiceDocShownAsRecommended(primaryControl, key));
  };

  PayPlus.invoiceDocTaxCanShow = function (primaryControl) { return PayPlus.invoiceDocCanShow(primaryControl, "taxinvoice"); };
  PayPlus.invoiceDocTaxReceiptCanShow = function (primaryControl) { return PayPlus.invoiceDocCanShow(primaryControl, "taxinvoicereceipt"); };
  PayPlus.invoiceDocPaymentDemandCanShow = function (primaryControl) { return PayPlus.invoiceDocCanShow(primaryControl, "paymentdemand"); };
  PayPlus.invoiceDocPaymentRequestCanShow = function (primaryControl) { return PayPlus.invoiceDocCanShow(primaryControl, "paymentrequest"); };

  PayPlus.invoiceDocTaxRecommendedCanShow = function (primaryControl) { return PayPlus.invoiceDocRecommendedCanShow(primaryControl, "taxinvoice"); };
  PayPlus.invoiceDocTaxReceiptRecommendedCanShow = function (primaryControl) { return PayPlus.invoiceDocRecommendedCanShow(primaryControl, "taxinvoicereceipt"); };
  PayPlus.invoiceDocPaymentDemandRecommendedCanShow = function (primaryControl) { return PayPlus.invoiceDocRecommendedCanShow(primaryControl, "paymentdemand"); };
  PayPlus.invoiceDocPaymentRequestRecommendedCanShow = function (primaryControl) { return PayPlus.invoiceDocRecommendedCanShow(primaryControl, "paymentrequest"); };

  PayPlus.invoiceDocTaxIssueCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "taxinvoice", "issue_allowed"); };
  PayPlus.invoiceDocTaxPreviewCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "taxinvoice", "preview_allowed"); };
  PayPlus.invoiceDocTaxSendEmailCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "taxinvoice", "send_email_allowed"); };
  PayPlus.invoiceDocTaxSendSmsCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "taxinvoice", "send_sms_allowed"); };
  PayPlus.invoiceDocTaxSendWhatsappCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "taxinvoice", "send_whatsapp_allowed"); };

  PayPlus.invoiceDocTaxReceiptIssueCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "taxinvoicereceipt", "issue_allowed"); };
  PayPlus.invoiceDocTaxReceiptSendEmailCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "taxinvoicereceipt", "send_email_allowed"); };
  PayPlus.invoiceDocTaxReceiptSendSmsCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "taxinvoicereceipt", "send_sms_allowed"); };
  PayPlus.invoiceDocTaxReceiptSendWhatsappCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "taxinvoicereceipt", "send_whatsapp_allowed"); };

  PayPlus.invoiceDocPaymentDemandIssueCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "paymentdemand", "issue_allowed"); };
  PayPlus.invoiceDocPaymentDemandPreviewCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "paymentdemand", "preview_allowed"); };
  PayPlus.invoiceDocPaymentDemandSendEmailCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "paymentdemand", "send_email_allowed"); };
  PayPlus.invoiceDocPaymentDemandSendSmsCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "paymentdemand", "send_sms_allowed"); };
  PayPlus.invoiceDocPaymentDemandSendWhatsappCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "paymentdemand", "send_whatsapp_allowed"); };

  PayPlus.invoiceDocPaymentRequestIssueCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "paymentrequest", "issue_allowed"); };
  PayPlus.invoiceDocPaymentRequestPreviewCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "paymentrequest", "preview_allowed"); };
  PayPlus.invoiceDocPaymentRequestSendEmailCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "paymentrequest", "send_email_allowed"); };
  PayPlus.invoiceDocPaymentRequestSendSmsCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "paymentrequest", "send_sms_allowed"); };
  PayPlus.invoiceDocPaymentRequestSendWhatsappCanShow = function (primaryControl) { return PayPlus._invoiceDocActionAllowed(primaryControl, "paymentrequest", "send_whatsapp_allowed"); };

  PayPlus._getInvoiceSourceSnapshot = function (invoiceId, primaryControl) {
    var query = "?$select=name,invoicenumber,totalamount,totaltax,statecode,statuscode,_customerid_value";
    return Xrm.WebApi.retrieveRecord("invoice", invoiceId, query).then(function (invoice) {
      var displayName = invoice.invoicenumber || invoice.name || PayPlus._invoiceDisplayName(primaryControl);
      var total = invoice.totalamount == null ? 0 : Number(invoice.totalamount);
      var vat = invoice.totaltax == null ? 0 : Number(invoice.totaltax);
      return {
        displayName: displayName,
        customerName: invoice["_customerid_value@OData.Community.Display.V1.FormattedValue"] || "",
        totalAmount: isNaN(total) ? 0 : total,
        vatAmount: isNaN(vat) ? 0 : vat,
        statecode: invoice.statecode,
        statuscode: invoice.statuscode
      };
    });
  };

  PayPlus._findDraftBillingCase = function (sourceEntity, sourceId) {
    var query = "?$select=alex_payplusbillingcaseid&$filter=alex_sourceentitylogicalname eq '" + sourceEntity.replace(/'/g, "''") + "' and alex_sourceentityid eq '" + sourceId.replace(/'/g, "''") + "' and alex_status ne 100000005 and alex_status ne 100000007&$orderby=modifiedon desc&$top=1";
    return Xrm.WebApi.retrieveMultipleRecords("alex_payplusbillingcase", query).then(function (result) {
      return result.entities && result.entities[0] && result.entities[0].alex_payplusbillingcaseid || "";
    }, function () { return ""; });
  };

  PayPlus._createInvoiceBillingCase = function (primaryControl, invoiceId, snapshot, preselectFlow) {
    return PayPlus._getPreviewConfiguration().then(function (cfg) {
      var body = {
        alex_name: (PayPlus._isHebrew() ? "יצירה ב-PayPlus - " : "Create in PayPlus - ") + (snapshot.displayName || PayPlus._invoiceDisplayName(primaryControl)),
        alex_status: 100000000,
        alex_defaultflow: preselectFlow != null ? preselectFlow : (cfg.alex_billing_default_flow == null ? 100000004 : cfg.alex_billing_default_flow),
        alex_sourceentitylogicalname: "invoice",
        alex_sourceentityid: invoiceId,
        alex_sourcedisplayname: snapshot.displayName || PayPlus._invoiceDisplayName(primaryControl),
        alex_customername: snapshot.customerName || "",
        alex_currencycode: "ILS",
        alex_totalamount: snapshot.totalAmount || 0,
        alex_vatamount: snapshot.vatAmount || 0,
        alex_paidamount: 0,
        alex_openbalance: snapshot.totalAmount || 0,
        alex_requirereceipttocloseinvoice: cfg.alex_billing_require_receipt_to_close_invoice !== false,
        alex_openedon: new Date().toISOString(),
        alex_notes: JSON.stringify({ createdBy: "invoice-ribbon", sourceEntity: "invoice", statecode: snapshot.statecode, statuscode: snapshot.statuscode }),
        "alex_configurationid@odata.bind": "/alex_payplusconfigurations(" + cfg.alex_payplusconfigurationid + ")"
      };
      return Xrm.WebApi.createRecord("alex_payplusbillingcase", body).then(function (created) {
        return created.id.replace(/[{}]/g, "").toLowerCase();
      });
    });
  };

  PayPlus._createPendingInvoiceDocument = function (primaryControl, invoiceId, billingCaseId, snapshot, issueDocument, operation) {
    operation = operation || "Generate";
    return PayPlus._getPreviewConfiguration().then(function (cfg) {
      return PayPlus._getDocumentTypeId(cfg.alex_environment, issueDocument.code).then(function (docTypeId) {
        var displayName = snapshot.displayName || PayPlus._invoiceDisplayName(primaryControl);
        var documentLabel = PayPlus._invoiceBillingDocLabel(issueDocument);
        var isGenerate = operation === "Generate";
        var policyPayload = {
          source: "invoice-ribbon",
          documentTypeCode: issueDocument.code,
          operation: operation,
          createPaymentPageWithDocument: cfg.alex_billing_create_payment_page_with_document === true
        };
        var body = {
          alex_name: "PayPlus - " + documentLabel + " - " + displayName,
          alex_environment: cfg.alex_environment,
          alex_documenttypecode: issueDocument.code,
          alex_uniqueidentifier: "invoice-" + operation.toLowerCase() + "-" + issueDocument.code + "-" + invoiceId + "-" + Date.now(),
          alex_sourceentitylogicalname: "invoice",
          alex_sourceentityid: invoiceId,
          alex_sourcedisplayname: displayName,
          alex_lastsyncstatus: 100000000,
          alex_businessstatus: isGenerate ? 100000002 : 100000000,
          alex_lastoperation: operation,
          alex_origin: 100000000,
          alex_documentrole: issueDocument.role,
          alex_totalamount: snapshot.totalAmount || 0,
          alex_vatamount: snapshot.vatAmount || 0,
          alex_balanceamount: snapshot.totalAmount || 0,
          alex_currencycode: "ILS",
          alex_moreinfo: JSON.stringify(policyPayload),
          "alex_configurationid@odata.bind": "/alex_payplusconfigurations(" + cfg.alex_payplusconfigurationid + ")",
          "alex_billingcaseid@odata.bind": "/alex_payplusbillingcases(" + billingCaseId + ")",
          "alex_invoiceid@odata.bind": "/invoices(" + invoiceId + ")"
        };
        if (docTypeId) body["alex_documenttypeid@odata.bind"] = "/alex_payplus_documenttypes(" + docTypeId + ")";
        return Xrm.WebApi.createRecord("alex_payplusdocument", body).then(function (created) {
          return created.id.replace(/[{}]/g, "").toLowerCase();
        });
      });
    });
  };

  PayPlus._findLatestGeneratedInvoiceDocument = function (invoiceId, docKey) {
    var doc = PayPlus._invoiceBillingDoc(docKey);
    if (!doc) return Promise.resolve(null);
    var query = "?$select=alex_payplusdocumentid,alex_payplusdocumentuuid,alex_documentnumber,alex_name,alex_documenturl,alex_pdfurl,alex_copypdfurl,alex_businessstatus,modifiedon&$filter=alex_sourceentitylogicalname eq 'invoice' and alex_sourceentityid eq '" + invoiceId.replace(/'/g, "''") + "' and alex_documenttypecode eq '" + doc.code + "' and alex_lastoperation eq 'Generate' and alex_lastsyncstatus eq 100000001 and alex_businessstatus ne 100000007&$orderby=modifiedon desc&$top=1";
    return Xrm.WebApi.retrieveMultipleRecords("alex_payplusdocument", query).then(function (result) {
      return result.entities && result.entities[0] || null;
    }, function () { return null; });
  };

  PayPlus._createPendingInvoiceCancellationDocument = function (primaryControl, invoiceId, billingCaseId, snapshot, originalDocument, issueDocument) {
    return PayPlus._getPreviewConfiguration().then(function (cfg) {
      var creditDocument = PayPlus._invoiceBillingDoc("creditinvoice");
      return PayPlus._getDocumentTypeId(cfg.alex_environment, creditDocument.code).then(function (docTypeId) {
        var displayName = snapshot.displayName || PayPlus._invoiceDisplayName(primaryControl);
        var originalNumber = originalDocument.alex_documentnumber || originalDocument.alex_name || originalDocument.alex_payplusdocumentuuid || "";
        var policyPayload = {
          source: "invoice-ribbon",
          operation: "CancelPrevious",
          documentTypeCode: creditDocument.code,
          cancelDoc: originalDocument.alex_payplusdocumentuuid || "",
          originalDocumentId: originalDocument.alex_payplusdocumentid || "",
          originalDocumentNumber: originalNumber,
          reissueDocumentTypeCode: issueDocument.code
        };
        var body = {
          alex_name: "PayPlus - " + PayPlus._invoiceBillingDocLabel(creditDocument) + " - " + displayName,
          alex_environment: cfg.alex_environment,
          alex_documenttypecode: creditDocument.code,
          alex_uniqueidentifier: "invoice-cancel-" + issueDocument.code + "-" + invoiceId + "-" + Date.now(),
          alex_sourceentitylogicalname: "invoice",
          alex_sourceentityid: invoiceId,
          alex_sourcedisplayname: displayName,
          alex_lastsyncstatus: 100000000,
          alex_businessstatus: 100000002,
          alex_lastoperation: "Generate",
          alex_origin: 100000000,
          alex_documentrole: creditDocument.role,
          alex_totalamount: snapshot.totalAmount || 0,
          alex_vatamount: snapshot.vatAmount || 0,
          alex_balanceamount: 0,
          alex_currencycode: "ILS",
          alex_moreinfo: JSON.stringify(policyPayload),
          "alex_configurationid@odata.bind": "/alex_payplusconfigurations(" + cfg.alex_payplusconfigurationid + ")",
          "alex_billingcaseid@odata.bind": "/alex_payplusbillingcases(" + billingCaseId + ")",
          "alex_invoiceid@odata.bind": "/invoices(" + invoiceId + ")",
          "alex_reversesdocumentid@odata.bind": "/alex_payplusdocuments(" + originalDocument.alex_payplusdocumentid + ")",
          "alex_parentdocumentid@odata.bind": "/alex_payplusdocuments(" + originalDocument.alex_payplusdocumentid + ")",
          "alex_relatedinvoicedocumentid@odata.bind": "/alex_payplusdocuments(" + originalDocument.alex_payplusdocumentid + ")"
        };
        if (docTypeId) body["alex_documenttypeid@odata.bind"] = "/alex_payplus_documenttypes(" + docTypeId + ")";
        return Xrm.WebApi.createRecord("alex_payplusdocument", body).then(function (created) {
          return created.id.replace(/[{}]/g, "").toLowerCase();
        });
      });
    });
  };

  PayPlus._sendInvoiceDocument = function (primaryControl, docKey, action) {
    var invoiceId = PayPlus._invoiceId(primaryControl);
    if (!invoiceId) return Xrm.Navigation.openAlertDialog({ text: PayPlus._isHebrew() ? "PayPlus: לא נמצאה רשומת חשבונית." : "PayPlus: Invoice record was not found." });
    var actionField = action === "send-email" ? "send_email_allowed" : (action === "send-sms" ? "send_sms_allowed" : "send_whatsapp_allowed");
    if (!PayPlus._invoiceDocActionAllowed(primaryControl, docKey, actionField)) return Xrm.Navigation.openAlertDialog({ text: PayPlus._isHebrew() ? "פעולה זו אינה מורשית לפי הגדרות PayPlus." : "This action is not allowed by PayPlus settings." });
    return PayPlus._findLatestGeneratedInvoiceDocument(invoiceId, docKey).then(function (documentRow) {
      if (!documentRow || !documentRow.alex_payplusdocumentid) return Xrm.Navigation.openAlertDialog({ text: PayPlus._isHebrew() ? "לא נמצא מסמך PayPlus שהופק בהצלחה לסוג זה." : "No successfully issued PayPlus document was found for this type." });
      var policy = { originalAllowed: true, copyAllowed: true, defaultLinkType: 100000001 };
      return PayPlus._chooseSendLinkTypeFromPolicy(policy, documentRow).then(function (linkType) {
        return PayPlus._queueDocumentSendRequest(documentRow, action, linkType).then(function () {
          return Xrm.Navigation.openAlertDialog({ text: PayPlus._t("sendQueued") });
        });
      });
    });
  };

  PayPlus._findPaymentWorkbenchCustomPageName = function () {
    if (PayPlus._paymentWorkbenchCustomPageName !== undefined) return Promise.resolve(PayPlus._paymentWorkbenchCustomPageName);
    var query = "?$select=name,displayname&$filter=name eq 'alex_paypluspaymentworkbench' or contains(name,'paypluspaymentworkbench') or contains(name,'paymentworkbench')&$top=1";
    return Xrm.WebApi.retrieveMultipleRecords("canvasapp", query).then(function (result) {
      var name = result.entities && result.entities[0] && result.entities[0].name || "";
      PayPlus._paymentWorkbenchCustomPageName = name;
      return name;
    }, function () {
      PayPlus._paymentWorkbenchCustomPageName = "";
      return "";
    });
  };

  PayPlus._openPaymentWorkbench = function (billingCaseId) {
    return PayPlus._findPaymentWorkbenchCustomPageName().then(function (customPageName) {
      if (!customPageName) {
        return Xrm.Navigation.openAlertDialog({ text: PayPlus._isHebrew() ? "PayPlus: עמוד קליטת התשלום לא נמצא." : "PayPlus: Payment Workbench page was not found." });
      }
      return Xrm.Navigation.navigateTo({
        pageType: "custom",
        name: customPageName,
        entityName: "alex_payplusbillingcase",
        recordId: billingCaseId
      }, {
        target: 2,
        width: { value: 92, unit: "%" },
        height: { value: 88, unit: "%" },
        position: 1,
        title: PayPlus._isHebrew() ? "קליטת תשלום" : "Payment Workbench"
      });
    });
  };

  PayPlus.captureInvoicePayment = function (primaryControl, preselectDocKey) {
    var invoiceId = PayPlus._invoiceId(primaryControl);
    if (!invoiceId) return Xrm.Navigation.openAlertDialog({ text: PayPlus._isHebrew() ? "PayPlus: לא נמצאה רשומת חשבונית." : "PayPlus: Invoice record was not found." });
    var preselectFlow = preselectDocKey === "taxinvoicereceipt" ? 100000003 : null;
    var snapshot = null;
    Xrm.Utility.showProgressIndicator(PayPlus._isHebrew() ? "PayPlus - פותח קליטת תשלום..." : "PayPlus - opening payment capture...");
    return PayPlus._saveQuoteIfNeeded(primaryControl).then(function () {
      return PayPlus._getInvoiceSourceSnapshot(invoiceId, primaryControl);
    }).then(function (sourceSnapshot) {
      snapshot = sourceSnapshot;
      return PayPlus._findDraftBillingCase("invoice", invoiceId);
    }).then(function (billingCaseId) {
      if (billingCaseId) {
        if (preselectFlow == null) return billingCaseId;
        return Xrm.WebApi.updateRecord("alex_payplusbillingcase", billingCaseId, { alex_defaultflow: preselectFlow }).then(function () { return billingCaseId; }, function () { return billingCaseId; });
      }
      return PayPlus._createInvoiceBillingCase(primaryControl, invoiceId, snapshot, preselectFlow);
    }).then(function (billingCaseId) {
      Xrm.Utility.closeProgressIndicator();
      return PayPlus._openPaymentWorkbench(billingCaseId);
    }).catch(function (err) {
      Xrm.Utility.closeProgressIndicator();
      return Xrm.Navigation.openAlertDialog({ text: "PayPlus: " + (err && err.message ? err.message : err) });
    });
  };

  PayPlus.issueInvoiceInPayPlus = function (primaryControl, docKey, operation) {
    var invoiceId = PayPlus._invoiceId(primaryControl);
    var issueDocument = PayPlus._invoiceBillingDoc(docKey);
    if (!invoiceId) return Xrm.Navigation.openAlertDialog({ text: PayPlus._isHebrew() ? "PayPlus: לא נמצאה רשומת חשבונית." : "PayPlus: Invoice record was not found." });
    if (!issueDocument) return Xrm.Navigation.openAlertDialog({ text: "PayPlus: Unknown invoice document type." });
    if (issueDocument.code === "inv_tax_receipt") return Xrm.Navigation.openAlertDialog({ text: PayPlus._isHebrew() ? "חשבונית מס קבלה תקבל תהליך נפרד הכולל פרטי תשלום וקבלה. הפעולה הזו עדיין לא מחוברת ל-Flow הכללי." : "Tax invoice receipt will use a separate payment and receipt process. This action is not connected to the generic invoice Flow yet." });

    var snapshot = null;
    var duplicateDocument = null;
    var targetInvoiceId = invoiceId;
    operation = operation === "preview" ? "Preview" : "Generate";
    var actionField = operation === "Preview" ? "preview_allowed" : "issue_allowed";
    if (!PayPlus._invoiceDocActionAllowed(primaryControl, docKey, actionField)) return Xrm.Navigation.openAlertDialog({ text: PayPlus._isHebrew() ? "פעולה זו אינה מורשית לפי הגדרות PayPlus." : "This action is not allowed by PayPlus settings." });

    var runOperation = function () {
      Xrm.Utility.showProgressIndicator(operation === "Preview" ? (PayPlus._isHebrew() ? "PayPlus - מכין תצוגה מקדימה..." : "PayPlus - preparing preview...") : PayPlus._t("generating"));
      return PayPlus._saveQuoteIfNeeded(primaryControl).then(function () {
        return PayPlus._getInvoiceSourceSnapshot(invoiceId, primaryControl);
      }).then(function (sourceSnapshot) {
        snapshot = sourceSnapshot;
        return PayPlus._findDraftBillingCase("invoice", invoiceId);
      }).then(function (billingCaseId) {
        if (billingCaseId) return billingCaseId;
        return PayPlus._createInvoiceBillingCase(primaryControl, invoiceId, snapshot);
      }).then(function (billingCaseId) {
        if (!duplicateDocument) return billingCaseId;
        // Cancel-and-reissue: create the credit document and let the reissued document stay on the
        // original invoice. The original (cancelled), the credit note and the reissued document all keep
        // alex_invoiceid pointing at the original invoice, so they appear together in its documents grid.
        return PayPlus._createPendingInvoiceCancellationDocument(primaryControl, invoiceId, billingCaseId, snapshot, duplicateDocument, issueDocument).then(function (cancelDocumentId) {
          return PayPlus._pollPayPlusDocument(cancelDocumentId, Date.now()).then(function () {
            return billingCaseId;
          });
        });
      }).then(function (billingCaseId) {
        return PayPlus._createPendingInvoiceDocument(primaryControl, targetInvoiceId, billingCaseId, snapshot, issueDocument, operation);
      }).then(function (documentId) {
        if (operation === "Preview") {
          Xrm.Utility.closeProgressIndicator();
          return PayPlus._openQuoteDocumentPreview(primaryControl, documentId);
        }
        return PayPlus._pollPayPlusDocument(documentId, Date.now()).then(function () {
          Xrm.Utility.closeProgressIndicator();
          // A demand document was just issued - refresh the "קליטת תשלום" button visibility.
          PayPlus._invoiceDemandDocCache = {};
          PayPlus._quoteRefreshRibbon(primaryControl);
          return PayPlus._askOpenIssuedDocument(primaryControl, documentId);
        });
      }).catch(function (err) {
        Xrm.Utility.closeProgressIndicator();
        return Xrm.Navigation.openAlertDialog({ text: "PayPlus: " + (err && err.message ? err.message : err) });
      });
    };

    if (operation === "Generate") {
      return PayPlus._findLatestGeneratedInvoiceDocument(invoiceId, docKey).then(function (existingDocument) {
        if (existingDocument && existingDocument.alex_payplusdocumentid && existingDocument.alex_payplusdocumentuuid) {
          duplicateDocument = existingDocument;
          var existingLabel = existingDocument.alex_documentnumber || existingDocument.alex_name || existingDocument.alex_payplusdocumentuuid;
          return Xrm.Navigation.openConfirmDialog({
            title: PayPlus._isHebrew() ? "מסמך חשבונאי כבר הופק" : "Accounting document already issued",
            text: PayPlus._isHebrew()
              ? "כבר קיימת " + PayPlus._invoiceBillingDocLabel(issueDocument) + " שהופקה ב-PayPlus (" + existingLabel + "). כדי להפיק חדשה יש לבטל את המסמך הקודם באמצעות חשבונית זיכוי. האם להמשיך?"
              : "A " + PayPlus._invoiceBillingDocLabel(issueDocument) + " was already issued in PayPlus (" + existingLabel + "). To issue a new one, the previous document must be cancelled with a credit invoice. Continue?",
            confirmButtonLabel: PayPlus._isHebrew() ? "בטל והפק חדש" : "Cancel and issue new",
            cancelButtonLabel: PayPlus._t("cancel")
          });
        }
        return Xrm.Navigation.openConfirmDialog({
          title: PayPlus._t("issueTitle"),
          text: PayPlus._invoiceIssueText(issueDocument),
          confirmButtonLabel: PayPlus._t("issueConfirm"),
          cancelButtonLabel: PayPlus._t("cancel")
        });
      }).then(function (confirm) {
        if (!confirm.confirmed) return;
        return runOperation();
      });
    }

    return runOperation();
  };

  PayPlus.invoiceCommand = function (primaryControl, action) {
    var parts = String(action || "").split(":");
    if (parts[0] === "payment-capture") return PayPlus.captureInvoicePayment(primaryControl);
    // Tax invoice receipt is issued through the payment-capture wizard (it acknowledges received money),
    // with the "חשבונית מס קבלה" document pre-selected.
    if ((parts[0] === "issue" || parts[0] === "preview") && parts[1] === "taxinvoicereceipt") return PayPlus.captureInvoicePayment(primaryControl, "taxinvoicereceipt");
    if (parts[0] === "issue") return PayPlus.issueInvoiceInPayPlus(primaryControl, parts[1], "issue");
    if (parts[0] === "preview") return PayPlus.issueInvoiceInPayPlus(primaryControl, parts[1], "preview");
    if (parts[0] === "send-email" || parts[0] === "send-sms" || parts[0] === "send-whatsapp") return PayPlus._sendInvoiceDocument(primaryControl, parts[1], parts[0]);
    return Xrm.Navigation.openAlertDialog({ text: ALERT_TEXT });
  };
}());