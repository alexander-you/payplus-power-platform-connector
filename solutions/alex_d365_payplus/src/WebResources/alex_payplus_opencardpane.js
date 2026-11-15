// PayPlus - open the "New Credit Card" side pane from a Contact/Account command button.
// Registered as a ribbon command that passes PrimaryControl.
var PayPlus = window.PayPlus || (window.PayPlus = {});

PayPlus.openCardPane = function (primaryControl) {
  "use strict";
  try {
    var entity = primaryControl.data.entity;
    var id = entity.getId().replace(/[{}]/g, "").toLowerCase();
    var entityName = entity.getEntityName(); // "contact" | "account"

    // best-effort customer display name for the pane header
    var custName = "";
    try {
      var attrName = entityName === "account" ? "name" : "fullname";
      var a = entity.attributes.get(attrName);
      custName = a && a.getValue ? (a.getValue() || "") : "";
    } catch (e) { /* ignore */ }

    var data =
      "entityname=" + encodeURIComponent(entityName) +
      "&id=" + encodeURIComponent(id) +
      "&name=" + encodeURIComponent(custName);

    var paneId = "payplus_card_pane";

    // if the pane is already open, close it so it reloads fresh
    var existing = Xrm.App.sidePanes.getPane(paneId);
    if (existing) { existing.close(); }

    Xrm.App.sidePanes.createPane({
      title: "כרטיס אשראי חדש",
      paneId: paneId,
      canClose: true,
      imageSrc: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAADdSURBVFhHY2AYBaNgFKABnpz9Gvw5exL4s/c2UB2DzM3aaYBuJxzwZ+8p4M/Z+5/WmC9nbz+63VCfYyqmFebL2u2B4gB6+R6Os/c2oDhAzKd2gbhb3n96YZB9KA6Qsgw+oKCg8J9eGGTfqANQHDDgaQBSUGBJrbTC6Llg1AGjDkB2gPfEc//bt90jGoPUY1hACONzAMhQUgBIPYYFhPCgcwBfzt4KmOQARcFuBwxFNMV7ElAcAHZEzt7tmAppgLP3HmeI38+Bbj8Y8GXvyQCnB5rhPQU4LR8Fo2AgAAA0KuDK4/vKDQAAAABJRU5ErkJggg==",
      width: 460
    }).then(function (pane) {
      pane.navigate({
        pageType: "webresource",
        webresourceName: "alex_payplus_cardpane.html",
        data: data
      });
    });
  } catch (err) {
    Xrm.Navigation.openAlertDialog({ text: "PayPlus: " + (err && err.message ? err.message : err) });
  }
};

// ---------------------------------------------------------------------------
// Configuration cache (drives which self-service channels are available)
// ---------------------------------------------------------------------------
PayPlus._cfg = null;
PayPlus._cfgLoading = false;
PayPlus._cfgSelect = "$select=" + [
  "alex_selfservice_email_contact", "alex_selfservice_email_contact_expiry",
  "alex_selfservice_sms_contact", "alex_selfservice_sms_contact_expiry",
  "alex_selfservice_whatsapp_contact", "alex_selfservice_whatsapp_contact_expiry",
  "alex_selfservice_email_account", "alex_selfservice_email_account_expiry",
  "alex_selfservice_sms_account", "alex_selfservice_sms_account_expiry",
  "alex_selfservice_whatsapp_account", "alex_selfservice_whatsapp_account_expiry"
].join(",");

PayPlus._loadCfg = function (primaryControl) {
  if (PayPlus._cfgLoading) return;
  PayPlus._cfgLoading = true;
  Xrm.WebApi.retrieveMultipleRecords("alex_payplusconfiguration", "?" + PayPlus._cfgSelect + "&$top=1").then(
    function (r) {
      PayPlus._cfg = (r.entities && r.entities[0]) || {};
      PayPlus._cfgLoading = false;
      // re-evaluate ribbon rules now that config is known
      try { primaryControl.ui.refreshRibbon(); }
      catch (e) { try { Xrm.Page.ui.refreshRibbon(); } catch (e2) { /* ignore */ } }
    },
    function () { PayPlus._cfg = {}; PayPlus._cfgLoading = false; }
  );
};

// Promise-returning config loader — guarantees _cfg is populated before use
// (the ribbon path warms _cfg via DisplayRules, but the PCF grid path does not).
PayPlus._ensureCfg = function () {
  if (PayPlus._cfg) return Promise.resolve(PayPlus._cfg);
  return Xrm.WebApi.retrieveMultipleRecords("alex_payplusconfiguration", "?" + PayPlus._cfgSelect + "&$top=1").then(
    function (r) { PayPlus._cfg = (r.entities && r.entities[0]) || {}; return PayPlus._cfg; },
    function () { PayPlus._cfg = {}; return PayPlus._cfg; }
  );
};

PayPlus._et = function (primaryControl) {
  try { return primaryControl.data.entity.getEntityName(); } catch (e) { return ""; }
};

// DisplayRule custom rule: show a channel button only when config allows it for this record type.
PayPlus._canChannel = function (primaryControl, channel) {
  var et = PayPlus._et(primaryControl);
  if (et !== "contact" && et !== "account") return false;
  if (!PayPlus._cfg) { PayPlus._loadCfg(primaryControl); return false; }
  return !!PayPlus._cfg["alex_selfservice_" + channel + "_" + et];
};
PayPlus.canEmail = function (pc) { return PayPlus._canChannel(pc, "email"); };
PayPlus.canSms = function (pc) { return PayPlus._canChannel(pc, "sms"); };
PayPlus.canWhatsapp = function (pc) { return PayPlus._canChannel(pc, "whatsapp"); };

// ---------------------------------------------------------------------------
// Self-service: create a card-collection session tagged with a channel + expiry.
// A Dataverse "row created" flow picks it up and delivers the link.
// ---------------------------------------------------------------------------
PayPlus._chVal = { email: 100000001, sms: 100000002, whatsapp: 100000003 };
PayPlus._chLabel = {
  email: "\u05D3\u05D5\u05D0\u05E8 \u05D0\u05DC\u05E7\u05D8\u05E8\u05D5\u05E0\u05D9",
  sms: "\u05DE\u05E1\u05E8\u05D5\u05DF",
  whatsapp: "WhatsApp"
};

PayPlus._guid = function () {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
    var r = (Math.random() * 16) | 0, v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
};

PayPlus.sendSelfService = function (primaryControl, channel) {
  "use strict";
  try {
    var et = PayPlus._et(primaryControl);
    if (et !== "contact" && et !== "account") return;
    var entity = primaryControl.data.entity;
    var id = entity.getId().replace(/[{}]/g, "").toLowerCase();
    var chLabel = PayPlus._chLabel[channel] || channel;

    Xrm.Navigation.openConfirmDialog({
      title: "\u05E9\u05DC\u05D9\u05D7\u05EA \u05E7\u05D9\u05E9\u05D5\u05E8 \u05DC\u05E2\u05D3\u05DB\u05D5\u05DF \u05DB\u05E8\u05D8\u05D9\u05E1 \u05D0\u05E9\u05E8\u05D0\u05D9",
      text: "\u05D4\u05D0\u05DD \u05D0\u05EA\u05D4 \u05D1\u05D8\u05D5\u05D7 \u05E9\u05D1\u05E8\u05E6\u05D5\u05E0\u05DA \u05DC\u05E9\u05DC\u05D5\u05D7 \u05DC\u05DC\u05E7\u05D5\u05D7 \u05E7\u05D9\u05E9\u05D5\u05E8 \u05DC\u05E2\u05D3\u05DB\u05D5\u05DF \u05DB\u05E8\u05D8\u05D9\u05E1 \u05D0\u05E9\u05E8\u05D0\u05D9 \u05D1\u05E2\u05E8\u05D5\u05E5 " + chLabel + "?"
    }).then(function (res) {
      if (!res || !res.confirmed) return;

      PayPlus._ensureCfg().then(function (cfg) {
      var days = parseInt(cfg["alex_selfservice_" + channel + "_" + et + "_expiry"], 10);
      if (!days || days < 1) days = 3;
      var exp = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
      var requestId = PayPlus._guid();

      var rec = {
        alex_name: requestId,
        alex_requestid: requestId,
        alex_status: "Pending",
        alex_channel: PayPlus._chVal[channel],
        alex_expireson: exp.toISOString()
      };
      if (et === "contact") rec["alex_Contact@odata.bind"] = "/contacts(" + id + ")";
      if (et === "account") rec["alex_Account@odata.bind"] = "/accounts(" + id + ")";

      Xrm.WebApi.createRecord("alex_pp_hfsession", rec).then(
        function () {
          Xrm.Navigation.openAlertDialog({
            text: "\u05D4\u05D1\u05E7\u05E9\u05D4 \u05E0\u05D5\u05E6\u05E8\u05D4. \u05E7\u05D9\u05E9\u05D5\u05E8 \u05D9\u05D9\u05E9\u05DC\u05D7 \u05D1\u05E2\u05E8\u05D5\u05E5 " + chLabel + " (\u05D1\u05EA\u05D5\u05E7\u05E3 \u05DC-" + days + " \u05D9\u05DE\u05D9\u05DD)."
          });
        },
        function (err) {
          Xrm.Navigation.openAlertDialog({ text: "\u05D9\u05E6\u05D9\u05E8\u05EA \u05D4\u05D1\u05E7\u05E9\u05D4 \u05E0\u05DB\u05E9\u05DC\u05D4: " + (err && err.message ? err.message : err) });
        }
      );
      });
    });
  } catch (err) {
    Xrm.Navigation.openAlertDialog({ text: "PayPlus: " + (err && err.message ? err.message : err) });
  }
};
