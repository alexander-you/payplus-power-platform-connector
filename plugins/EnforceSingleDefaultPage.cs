using System;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace PayPlus.Plugins
{
    /// <summary>
    /// Enforces a single default payment page per terminal and process type.
    ///
    /// When an <c>alex_payplus_paymentpage</c> row is created or updated with
    /// <c>alex_isdefault = true</c>, every other page that belongs to the same
    /// parent terminal (<c>alex_terminalid</c>) and has the same
    /// <c>alex_processtype</c> has its <c>alex_isdefault</c> reset to <c>false</c>.
    ///
    /// Registration (synchronous):
    ///   Entity : alex_payplus_paymentpage
    ///   Messages : Create (post-op) and Update (post-op, filter = alex_isdefault)
    ///   Stage : 40 (Post-Operation)   Mode : 0 (Synchronous)   Isolation : Sandbox
    /// </summary>
    public sealed class EnforceSingleDefaultPage : IPlugin
    {
        private const string EntityName = "alex_payplus_paymentpage";
        private const string PrimaryId = "alex_payplus_paymentpageid";
        private const string IsDefault = "alex_isdefault";
        private const string TerminalLookup = "alex_terminalid";
        private const string ProcessType = "alex_processtype";

        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracer = (ITracingService)serviceProvider.GetService(typeof(ITracingService));

            if (!context.InputParameters.TryGetValue("Target", out var targetObj) || !(targetObj is Entity target))
                return;
            if (!target.LogicalName.Equals(EntityName, StringComparison.OrdinalIgnoreCase))
                return;

            // Only act when THIS operation explicitly sets the page as default.
            if (!target.Contains(IsDefault) || !(target[IsDefault] is bool isDefault) || !isDefault)
                return;

            var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = factory.CreateOrganizationService(context.UserId);

            // Resolve the id of the page being saved.
            var pageId = target.Id;
            if (pageId == Guid.Empty && context.OutputParameters.Contains("id"))
                Guid.TryParse(context.OutputParameters["id"].ToString(), out pageId);
            if (pageId == Guid.Empty)
                pageId = context.PrimaryEntityId;

            // Resolve the parent terminal + process type. Prefer values on the Target; otherwise read the row.
            var terminalRef = target.GetAttributeValue<EntityReference>(TerminalLookup);
            var processType = target.GetAttributeValue<OptionSetValue>(ProcessType);
            if ((terminalRef == null || processType == null) && pageId != Guid.Empty)
            {
                var current = service.Retrieve(EntityName, pageId, new ColumnSet(TerminalLookup, ProcessType));
                if (terminalRef == null) terminalRef = current.GetAttributeValue<EntityReference>(TerminalLookup);
                if (processType == null) processType = current.GetAttributeValue<OptionSetValue>(ProcessType);
            }

            if (terminalRef == null)
            {
                tracer.Trace("EnforceSingleDefaultPage: page {0} has no parent terminal; nothing to enforce.", pageId);
                return;
            }

            var query = new QueryExpression(EntityName)
            {
                ColumnSet = new ColumnSet(false),
                Criteria = new FilterExpression(LogicalOperator.And)
            };
            query.Criteria.AddCondition(IsDefault, ConditionOperator.Equal, true);
            query.Criteria.AddCondition(TerminalLookup, ConditionOperator.Equal, terminalRef.Id);
            if (processType != null)
                query.Criteria.AddCondition(ProcessType, ConditionOperator.Equal, processType.Value);
            else
                query.Criteria.AddCondition(ProcessType, ConditionOperator.Null);
            if (pageId != Guid.Empty)
                query.Criteria.AddCondition(PrimaryId, ConditionOperator.NotEqual, pageId);

            var others = service.RetrieveMultiple(query).Entities;
            foreach (var other in others)
            {
                // Setting isdefault=false re-triggers this plugin but exits immediately
                // (guarded by the isDefault check above), so no recursion occurs.
                service.Update(new Entity(EntityName, other.Id) { [IsDefault] = false });
                tracer.Trace("EnforceSingleDefaultPage: cleared default on sibling page {0}.", other.Id);
            }
        }
    }
}
