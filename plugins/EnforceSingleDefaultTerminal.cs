using System;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace PayPlus.Plugins
{
    /// <summary>
    /// Enforces a single default terminal per environment.
    ///
    /// When an <c>alex_payplus_terminal</c> row is created or updated with
    /// <c>alex_isdefault = true</c>, every other terminal in the same
    /// <c>alex_environment</c> has its <c>alex_isdefault</c> reset to <c>false</c>.
    ///
    /// Registration (synchronous):
    ///   Entity : alex_payplus_terminal
    ///   Messages : Create (post-op) and Update (post-op, filter = alex_isdefault)
    ///   Stage : 40 (Post-Operation)   Mode : 0 (Synchronous)   Isolation : Sandbox
    /// </summary>
    public sealed class EnforceSingleDefaultTerminal : IPlugin
    {
        private const string EntityName = "alex_payplus_terminal";
        private const string PrimaryId = "alex_payplus_terminalid";
        private const string IsDefault = "alex_isdefault";
        private const string Environment = "alex_environment";

        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracer = (ITracingService)serviceProvider.GetService(typeof(ITracingService));

            if (!context.InputParameters.TryGetValue("Target", out var targetObj) || !(targetObj is Entity target))
                return;
            if (!target.LogicalName.Equals(EntityName, StringComparison.OrdinalIgnoreCase))
                return;

            // Only act when THIS operation explicitly sets the terminal as default.
            if (!target.Contains(IsDefault) || !(target[IsDefault] is bool isDefault) || !isDefault)
                return;

            var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = factory.CreateOrganizationService(context.UserId);

            // Resolve the id of the terminal being saved.
            var terminalId = target.Id;
            if (terminalId == Guid.Empty && context.OutputParameters.Contains("id"))
                Guid.TryParse(context.OutputParameters["id"].ToString(), out terminalId);
            if (terminalId == Guid.Empty)
                terminalId = context.PrimaryEntityId;

            // Resolve the environment. Prefer the value on the Target; otherwise read the row.
            var env = target.GetAttributeValue<OptionSetValue>(Environment);
            if (env == null && terminalId != Guid.Empty)
            {
                var current = service.Retrieve(EntityName, terminalId, new ColumnSet(Environment));
                env = current.GetAttributeValue<OptionSetValue>(Environment);
            }

            if (env == null)
            {
                tracer.Trace("EnforceSingleDefaultTerminal: terminal {0} has no environment; nothing to enforce.", terminalId);
                return;
            }

            var query = new QueryExpression(EntityName)
            {
                ColumnSet = new ColumnSet(false),
                Criteria = new FilterExpression(LogicalOperator.And)
            };
            query.Criteria.AddCondition(IsDefault, ConditionOperator.Equal, true);
            query.Criteria.AddCondition(Environment, ConditionOperator.Equal, env.Value);
            if (terminalId != Guid.Empty)
                query.Criteria.AddCondition(PrimaryId, ConditionOperator.NotEqual, terminalId);

            var others = service.RetrieveMultiple(query).Entities;
            foreach (var other in others)
            {
                // Setting isdefault=false re-triggers this plugin but exits immediately
                // (guarded by the isDefault check above), so no recursion occurs.
                service.Update(new Entity(EntityName, other.Id) { [IsDefault] = false });
                tracer.Trace("EnforceSingleDefaultTerminal: cleared default on sibling terminal {0}.", other.Id);
            }
        }
    }
}
