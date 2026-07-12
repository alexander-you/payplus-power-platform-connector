using System;
using System.Collections.Generic;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace PayPlus.Plugins
{
    public sealed class ReconcileSyncSteps : IPlugin
    {
        private const string QueuePluginTypeName = "PayPlus.Plugins.QueueSyncOutboxOnSourceChange";
        private const int PluginStepNotRequired = 100000000;
        private const int PluginStepNotRegistered = 100000001;
        private const int PluginStepRegistered = 100000002;
        private const int PluginStepFailed = 100000003;

        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracer = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
            var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = factory.CreateOrganizationService(null);

            var entityMappingId = ParseGuid(InputString(context, "EntityMappingId"));
            var syncProfileId = ParseGuid(InputString(context, "SyncProfileId"));
            var allowInactiveRegistration = entityMappingId.HasValue;
            var queuePluginTypeId = RetrievePluginTypeId(service, QueuePluginTypeName);
            var messageIds = new Dictionary<string, Guid>(StringComparer.OrdinalIgnoreCase);
            var created = 0;
            var updated = 0;
            var skipped = 0;
            var failed = 0;

            var mappings = RetrieveMappings(service, entityMappingId, syncProfileId);
            foreach (var mapping in mappings.Entities)
            {
                try
                {
                    var outcome = ReconcileMapping(service, mapping, queuePluginTypeId, messageIds, tracer, allowInactiveRegistration);
                    created += outcome.Created;
                    updated += outcome.Updated;
                    skipped += outcome.Skipped;
                }
                catch (Exception ex)
                {
                    failed++;
                    UpdateMappingStatus(service, mapping.Id, PluginStepFailed);
                    tracer.Trace("ReconcileSyncSteps: failed for mapping {0}. {1}", mapping.Id, ex);
                }
            }

            context.OutputParameters["CreatedCount"] = created;
            context.OutputParameters["UpdatedCount"] = updated;
            context.OutputParameters["SkippedCount"] = skipped;
            context.OutputParameters["FailedCount"] = failed;
            context.OutputParameters["Message"] = $"PayPlus sync steps reconciled. Created: {created}, updated: {updated}, skipped: {skipped}, failed: {failed}.";
        }

        private static StepOutcome ReconcileMapping(IOrganizationService service, Entity mapping, Guid queuePluginTypeId, IDictionary<string, Guid> messageIds, ITracingService tracer, bool allowInactiveRegistration)
        {
            var sourceTable = mapping.GetAttributeValue<string>("alex_sourcetablelogicalname");
            var isActive = mapping.GetAttributeValue<bool>("alex_isactive");
            var allowCreate = mapping.GetAttributeValue<bool>("alex_allowcreate");
            var allowUpdate = mapping.GetAttributeValue<bool>("alex_allowupdate");

            if (String.IsNullOrWhiteSpace(sourceTable) || (!isActive && !allowInactiveRegistration) || (!allowCreate && !allowUpdate))
            {
                UpdateMappingStatus(service, mapping.Id, PluginStepNotRequired);
                return StepOutcome.SkippedOnly();
            }

            var outcome = new StepOutcome();
            if (allowCreate)
            {
                outcome.Add(EnsureSourceStep(service, queuePluginTypeId, "Create", sourceTable, messageIds));
            }
            if (allowUpdate)
            {
                outcome.Add(EnsureSourceStep(service, queuePluginTypeId, "Update", sourceTable, messageIds));
            }

            UpdateMappingStatus(service, mapping.Id, PluginStepRegistered);
            tracer.Trace("ReconcileSyncSteps: mapping {0} registered for {1}.", mapping.Id, sourceTable);
            return outcome;
        }

        private static StepChange EnsureSourceStep(IOrganizationService service, Guid queuePluginTypeId, string messageName, string entityLogicalName, IDictionary<string, Guid> messageIds)
        {
            var messageId = RetrieveMessageId(service, messageName, messageIds);
            var filterId = RetrieveMessageFilterId(service, messageId, entityLogicalName);
            var stepName = $"PayPlus.Plugins.QueueSyncOutboxOnSourceChange : {messageName} of {entityLogicalName}";
            var existing = RetrieveStep(service, stepName);
            var step = new Entity("sdkmessageprocessingstep")
            {
                ["name"] = stepName,
                ["description"] = "Creates a PayPlus sync outbox job for active mappings when this source row changes.",
                ["stage"] = new OptionSetValue(40),
                ["mode"] = new OptionSetValue(0),
                ["rank"] = 1,
                ["supporteddeployment"] = new OptionSetValue(0),
                ["asyncautodelete"] = false,
                ["eventhandler"] = new EntityReference("plugintype", queuePluginTypeId),
                ["sdkmessageid"] = new EntityReference("sdkmessage", messageId),
                ["sdkmessagefilterid"] = new EntityReference("sdkmessagefilter", filterId)
            };

            if (existing == null)
            {
                service.Create(step);
                return StepChange.Created;
            }

            step.Id = existing.Id;
            service.Update(step);
            return StepChange.Updated;
        }

        private static EntityCollection RetrieveMappings(IOrganizationService service, Guid? entityMappingId, Guid? syncProfileId)
        {
            var query = new QueryExpression("alex_payplus_entitymapping")
            {
                ColumnSet = new ColumnSet("alex_payplus_entitymappingid", "alex_sourcetablelogicalname", "alex_allowcreate", "alex_allowupdate", "alex_isactive", "alex_syncprofileid"),
                Criteria = new FilterExpression(LogicalOperator.And)
            };
            query.Criteria.AddCondition("statecode", ConditionOperator.Equal, 0);
            if (entityMappingId.HasValue)
            {
                query.Criteria.AddCondition("alex_payplus_entitymappingid", ConditionOperator.Equal, entityMappingId.Value);
            }
            if (syncProfileId.HasValue)
            {
                query.Criteria.AddCondition("alex_syncprofileid", ConditionOperator.Equal, syncProfileId.Value);
            }

            var profile = query.AddLink("alex_payplus_syncprofile", "alex_syncprofileid", "alex_payplus_syncprofileid", JoinOperator.Inner);
            profile.LinkCriteria.AddCondition("statecode", ConditionOperator.Equal, 0);
            profile.LinkCriteria.AddCondition("alex_isactive", ConditionOperator.Equal, true);
            return service.RetrieveMultiple(query);
        }

        private static Guid RetrievePluginTypeId(IOrganizationService service, string typeName)
        {
            var query = new QueryExpression("plugintype")
            {
                ColumnSet = new ColumnSet("plugintypeid"),
                TopCount = 1
            };
            query.Criteria.AddCondition("typename", ConditionOperator.Equal, typeName);
            var rows = service.RetrieveMultiple(query).Entities;
            if (rows.Count == 0) throw new InvalidPluginExecutionException($"Plugin type {typeName} was not found.");
            return rows[0].Id;
        }

        private static Guid RetrieveMessageId(IOrganizationService service, string messageName, IDictionary<string, Guid> cache)
        {
            if (cache.TryGetValue(messageName, out var cached)) return cached;
            var query = new QueryExpression("sdkmessage")
            {
                ColumnSet = new ColumnSet("sdkmessageid"),
                TopCount = 1
            };
            query.Criteria.AddCondition("name", ConditionOperator.Equal, messageName);
            var rows = service.RetrieveMultiple(query).Entities;
            if (rows.Count == 0) throw new InvalidPluginExecutionException($"SDK message {messageName} was not found.");
            cache[messageName] = rows[0].Id;
            return rows[0].Id;
        }

        private static Guid RetrieveMessageFilterId(IOrganizationService service, Guid messageId, string entityLogicalName)
        {
            var query = new QueryExpression("sdkmessagefilter")
            {
                ColumnSet = new ColumnSet("sdkmessagefilterid"),
                TopCount = 1
            };
            query.Criteria.AddCondition("sdkmessageid", ConditionOperator.Equal, messageId);
            query.Criteria.AddCondition("primaryobjecttypecode", ConditionOperator.Equal, entityLogicalName);
            var rows = service.RetrieveMultiple(query).Entities;
            if (rows.Count == 0) throw new InvalidPluginExecutionException($"SDK message filter for {entityLogicalName} / {messageId} was not found.");
            return rows[0].Id;
        }

        private static Entity RetrieveStep(IOrganizationService service, string stepName)
        {
            var query = new QueryExpression("sdkmessageprocessingstep")
            {
                ColumnSet = new ColumnSet("sdkmessageprocessingstepid"),
                TopCount = 1
            };
            query.Criteria.AddCondition("name", ConditionOperator.Equal, stepName);
            var rows = service.RetrieveMultiple(query).Entities;
            return rows.Count == 0 ? null : rows[0];
        }

        private static void UpdateMappingStatus(IOrganizationService service, Guid mappingId, int status)
        {
            service.Update(new Entity("alex_payplus_entitymapping", mappingId)
            {
                ["alex_pluginstepstatus"] = new OptionSetValue(status)
            });
        }

        private static string InputString(IPluginExecutionContext context, string key)
        {
            return context.InputParameters.Contains(key) && context.InputParameters[key] != null ? Convert.ToString(context.InputParameters[key]) : null;
        }

        private static Guid? ParseGuid(string value)
        {
            return Guid.TryParse(value, out var id) ? id : (Guid?)null;
        }

        private enum StepChange
        {
            Created,
            Updated,
            Skipped
        }

        private sealed class StepOutcome
        {
            public int Created { get; private set; }
            public int Updated { get; private set; }
            public int Skipped { get; private set; }

            public static StepOutcome SkippedOnly()
            {
                return new StepOutcome { Skipped = 1 };
            }

            public void Add(StepChange change)
            {
                if (change == StepChange.Created) Created++;
                else if (change == StepChange.Updated) Updated++;
                else Skipped++;
            }
        }
    }
}