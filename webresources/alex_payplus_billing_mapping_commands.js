(function (root) {
    "use strict";

    var namespace = root.PayPlus = root.PayPlus || {};
    var salesAvailability;

    function xrm(primaryControl) {
        return (primaryControl && primaryControl.context) || root.Xrm || (root.parent && root.parent.Xrm);
    }

    function recordId(primaryControl) {
        try {
            return String(primaryControl.data.entity.getId() || "").replace(/[{}]/g, "");
        } catch (error) {
            return "";
        }
    }

    function canShowSalesAutoMap(primaryControl) {
        if (salesAvailability) return salesAvailability;
        var api = xrm(primaryControl);
        if (!api || !api.Utility) return Promise.resolve(false);
        var url = api.Utility.getGlobalContext().getClientUrl().replace(/\/$/, "") +
            "/api/data/v9.2/EntityDefinitions(LogicalName='invoice')?$select=MetadataId";
        salesAvailability = fetch(url, {
            credentials: "same-origin",
            headers: { Accept: "application/json", "OData-MaxVersion": "4.0", "OData-Version": "4.0" }
        }).then(function (response) {
            return response.ok;
        }).catch(function () {
            return false;
        });
        return salesAvailability;
    }

    function hasSavedRecord(primaryControl) {
        return !!recordId(primaryControl);
    }

    function openAutoMapping(primaryControl) {
        var api = xrm(primaryControl);
        var id = recordId(primaryControl);
        if (!api || !api.Navigation || !id) return;
        var data = "configId=" + encodeURIComponent(id) + "&mode=auto";
        return api.Navigation.navigateTo(
            { pageType: "webresource", webresourceName: "alex_payplus_billing_mapping.html", data: data },
            { target: 2, width: { value: 85, unit: "%" }, height: { value: 85, unit: "%" }, position: 1 }
        );
    }

    namespace.BillingMapping = {
        canShowSalesAutoMap: canShowSalesAutoMap,
        hasSavedRecord: hasSavedRecord,
        openAutoMapping: openAutoMapping
    };
})(window);