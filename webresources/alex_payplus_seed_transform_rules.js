var PayPlus = window.PayPlus || (window.PayPlus = {});

PayPlus.seedTransformRules = function (primaryControl) {
  "use strict";
  try {
    Xrm.Navigation.openConfirmDialog({
      title: "\u05D9\u05E6\u05D9\u05E8\u05EA \u05DB\u05DC\u05DC\u05D9 \u05D4\u05DE\u05E8\u05D4",
      text: "\u05D4\u05D0\u05DD \u05DC\u05D9\u05E6\u05D5\u05E8 \u05D0\u05D5 \u05DC\u05E2\u05D3\u05DB\u05DF \u05D0\u05EA \u05DB\u05DC\u05DC\u05D9 \u05D4\u05D4\u05DE\u05E8\u05D4 \u05D4\u05DE\u05D5\u05D1\u05E0\u05D9\u05DD \u05E9\u05DC PayPlus?",
      confirmButtonLabel: "\u05D0\u05D9\u05E9\u05D5\u05E8",
      cancelButtonLabel: "\u05D1\u05D9\u05D8\u05D5\u05DC"
    }).then(function (result) {
      if (!result || !result.confirmed) return;

      var request = {
        getMetadata: function () {
          return {
            boundParameter: null,
            parameterTypes: {},
            operationType: 0,
            operationName: "alex_SeedPayPlusTransformRules"
          };
        }
      };

      Xrm.WebApi.online.execute(request).then(
        function (response) {
          if (!response.ok) throw new Error("HTTP " + response.status);
          return response.json ? response.json() : null;
        }
      ).then(function (data) {
        var msg = data
          ? "\u05DB\u05DC\u05DC\u05D9 \u05D4\u05D4\u05DE\u05E8\u05D4 \u05DE\u05D5\u05DB\u05E0\u05D9\u05DD. \u05E0\u05D5\u05E6\u05E8\u05D5: " + (data.CreatedCount || 0) + ", \u05E2\u05D5\u05D3\u05DB\u05E0\u05D5: " + (data.UpdatedCount || 0) + ", \u05DC\u05DC\u05D0 \u05E9\u05D9\u05E0\u05D5\u05D9: " + (data.SkippedCount || 0) + "."
          : "\u05DB\u05DC\u05DC\u05D9 \u05D4\u05D4\u05DE\u05E8\u05D4 \u05DE\u05D5\u05DB\u05E0\u05D9\u05DD.";
        Xrm.Navigation.openAlertDialog({ text: msg }).then(function () {
          try { if (primaryControl && primaryControl.data) primaryControl.data.refresh(false); } catch (e) { /* ignore */ }
        });
      }).catch(function (err) {
        Xrm.Navigation.openAlertDialog({
          text: "\u05D9\u05E6\u05D9\u05E8\u05EA \u05DB\u05DC\u05DC\u05D9 \u05D4\u05D4\u05DE\u05E8\u05D4 \u05E0\u05DB\u05E9\u05DC\u05D4: " + (err && err.message ? err.message : err)
        });
      });
    });
  } catch (err) {
    Xrm.Navigation.openAlertDialog({ text: "PayPlus: " + (err && err.message ? err.message : err) });
  }
};