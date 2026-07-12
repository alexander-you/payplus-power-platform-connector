using System;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace PayPlus.Plugins
{
    /// <summary>
    /// Enforces a single default credit card per customer.
    ///
    /// When a <c>alex_creditcard</c> row is created or updated with
    /// <c>alex_isdefault = true</c>, every other card that belongs to the same
    /// customer (Contact <c>alex_contact</c> or Account <c>alex_account</c>) has
    /// its <c>alex_isdefault</c> reset to <c>false</c>.
    ///
    /// Registration (synchronous):
    ///   Entity : alex_creditcard
    ///   Messages : Create (post-op) and Update (post-op, filter = alex_isdefault)
    ///   Stage : 40 (Post-Operation)   Mode : 0 (Synchronous)   Isolation : Sandbox
    /// </summary>
    public sealed class EnforceSingleDefaultCard : IPlugin
    {
        private const string EntityName = "alex_creditcard";
        private const string PrimaryId = "alex_creditcardid";
        private const string IsDefault = "alex_isdefault";
        private const string ContactLookup = "alex_contact";
        private const string AccountLookup = "alex_account";

        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracer = (ITracingService)serviceProvider.GetService(typeof(ITracingService));

            if (!context.InputParameters.TryGetValue("Target", out var targetObj) || !(targetObj is Entity target))
                return;
            if (!target.LogicalName.Equals(EntityName, StringComparison.OrdinalIgnoreCase))
                return;

            // Only act when THIS operation explicitly sets the card as default.
            if (!target.Contains(IsDefault) || !(target[IsDefault] is bool isDefault) || !isDefault)
                return;

            var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = factory.CreateOrganizationService(context.UserId);

            // Resolve the id of the card being saved.
            var cardId = target.Id;
            if (cardId == Guid.Empty && context.OutputParameters.Contains("id"))
                Guid.TryParse(context.OutputParameters["id"].ToString(), out cardId);
            if (cardId == Guid.Empty)
                cardId = context.PrimaryEntityId;

            // Resolve the customer. Prefer values on the Target; otherwise read the row.
            var contactRef = target.GetAttributeValue<EntityReference>(ContactLookup);
            var accountRef = target.GetAttributeValue<EntityReference>(AccountLookup);
            if (contactRef == null && accountRef == null && cardId != Guid.Empty)
            {
                var current = service.Retrieve(EntityName, cardId, new ColumnSet(ContactLookup, AccountLookup));
                contactRef = current.GetAttributeValue<EntityReference>(ContactLookup);
                accountRef = current.GetAttributeValue<EntityReference>(AccountLookup);
            }

            if (contactRef == null && accountRef == null)
            {
                tracer.Trace("EnforceSingleDefaultCard: card {0} has no customer; nothing to enforce.", cardId);
                return;
            }

            // Sibling cards of the same customer (Contact OR Account) that are default.
            var customerFilter = new FilterExpression(LogicalOperator.Or);
            if (contactRef != null) customerFilter.AddCondition(ContactLookup, ConditionOperator.Equal, contactRef.Id);
            if (accountRef != null) customerFilter.AddCondition(AccountLookup, ConditionOperator.Equal, accountRef.Id);

            var query = new QueryExpression(EntityName)
            {
                ColumnSet = new ColumnSet(false),
                Criteria = new FilterExpression(LogicalOperator.And)
            };
            query.Criteria.AddCondition(IsDefault, ConditionOperator.Equal, true);
            if (cardId != Guid.Empty)
                query.Criteria.AddCondition(PrimaryId, ConditionOperator.NotEqual, cardId);
            query.Criteria.AddFilter(customerFilter);

            var others = service.RetrieveMultiple(query).Entities;
            foreach (var other in others)
            {
                // Setting isdefault=false re-triggers this plugin but exits immediately
                // (guarded by the isDefault check above), so no recursion occurs.
                service.Update(new Entity(EntityName, other.Id) { [IsDefault] = false });
                tracer.Trace("EnforceSingleDefaultCard: cleared default on sibling card {0}.", other.Id);
            }
        }
    }
}
