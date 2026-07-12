using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace PayPlus.Plugins
{
    public sealed class QueueSyncOutboxOnSourceChange : IPlugin
    {
        private const int OperationCreate = 100000000;
        private const int OperationUpdate = 100000001;
        private const int StatusPending = 100000000;
        private const int StatusFailed = 100000003;
        private const int StatusRetryScheduled = 100000004;
        private const int SourceTypeField = 100000000;
        private const int SourceTypeConstant = 100000001;
        private const int SourceTypeRelated = 100000004;
        private const int NullOmit = 100000000;
        private const int NullSend = 100000001;
        private const int NullUseDefault = 100000002;
        private const int NullFail = 100000003;
        private const int DataTypeNumber = 100000001;
        private const int DataTypeDecimal = 100000002;
        private const int DataTypeMoney = 100000003;
        private const int DataTypeBoolean = 100000004;
        private const int DataTypeDateTime = 100000005;
        private const int DataTypeChoice = 100000007;
        private const int DataTypeArray = 100000009;

        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracer = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
            var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = factory.CreateOrganizationService(null);

            if (!String.Equals(context.MessageName, "Create", StringComparison.OrdinalIgnoreCase)
                && !String.Equals(context.MessageName, "Update", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            if (!context.InputParameters.Contains("Target") || !(context.InputParameters["Target"] is Entity target))
            {
                return;
            }

            var sourceTable = context.PrimaryEntityName;
            var sourceId = target.Id != Guid.Empty ? target.Id : context.PrimaryEntityId;
            if (sourceId == Guid.Empty)
            {
                return;
            }

            var operation = String.Equals(context.MessageName, "Create", StringComparison.OrdinalIgnoreCase) ? OperationCreate : OperationUpdate;
            var sourceSnapshot = RetrieveSourceSnapshot(service, sourceTable, sourceId, tracer);
            var mappings = RetrieveActiveMappings(service, sourceTable, operation);

            foreach (var mapping in mappings.Entities)
            {
                QueueOutbox(service, mapping, sourceTable, sourceId, operation, sourceSnapshot, tracer);
            }
        }

        private static EntityCollection RetrieveActiveMappings(IOrganizationService service, string sourceTable, int operation)
        {
            var query = new QueryExpression("alex_payplus_entitymapping")
            {
                ColumnSet = new ColumnSet("alex_payplus_entitymappingid", "alex_name", "alex_targetobject", "alex_allowcreate", "alex_allowupdate", "alex_coalesceupdates", "alex_syncprofileid"),
                Criteria = new FilterExpression(LogicalOperator.And)
            };
            query.Criteria.AddCondition("statecode", ConditionOperator.Equal, 0);
            query.Criteria.AddCondition("alex_isactive", ConditionOperator.Equal, true);
            query.Criteria.AddCondition("alex_sourcetablelogicalname", ConditionOperator.Equal, sourceTable);
            query.Criteria.AddCondition(operation == OperationCreate ? "alex_allowcreate" : "alex_allowupdate", ConditionOperator.Equal, true);

            var profile = query.AddLink("alex_payplus_syncprofile", "alex_syncprofileid", "alex_payplus_syncprofileid", JoinOperator.Inner);
            profile.LinkCriteria.AddCondition("statecode", ConditionOperator.Equal, 0);
            profile.LinkCriteria.AddCondition("alex_isactive", ConditionOperator.Equal, true);

            return service.RetrieveMultiple(query);
        }

        private static void QueueOutbox(IOrganizationService service, Entity mapping, string sourceTable, Guid sourceId, int operation, Entity sourceSnapshot, ITracingService tracer)
        {
            var mappingId = mapping.Id;
            var profileRef = mapping.GetAttributeValue<EntityReference>("alex_syncprofileid");
            var targetObject = mapping.GetAttributeValue<OptionSetValue>("alex_targetobject");
            if (profileRef == null || targetObject == null)
            {
                tracer.Trace("QueueSyncOutboxOnSourceChange: mapping {0} missing profile or target.", mappingId);
                return;
            }

            var correlationKey = $"{mappingId:N}:{sourceTable}:{sourceId:N}";
            var coalesce = mapping.GetAttributeValue<bool>("alex_coalesceupdates");
            var existing = coalesce ? FindOpenOutbox(service, correlationKey) : null;
            var payload = BuildPayload(service, mappingId, sourceTable, sourceId, tracer);
            var status = String.IsNullOrWhiteSpace(payload.Error) ? StatusPending : StatusFailed;

            if (existing != null)
            {
                var update = new Entity("alex_payplus_syncoutbox", existing.Id)
                {
                    ["alex_lastdetectedon"] = DateTime.UtcNow,
                    ["alex_operation"] = new OptionSetValue(operation),
                    ["alex_status"] = new OptionSetValue(status),
                    ["alex_payloadsnapshot"] = payload.Json,
                    ["alex_lasterror"] = payload.Error,
                    ["alex_sourceversionnumber"] = SourceValue(sourceSnapshot, "versionnumber"),
                    ["alex_sourcemodifiedon"] = sourceSnapshot?.GetAttributeValue<DateTime?>("modifiedon")
                };
                service.Update(update);
                tracer.Trace("QueueSyncOutboxOnSourceChange: coalesced outbox {0}.", existing.Id);
                return;
            }

            var name = $"{sourceTable} {operationLabel(operation)} {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss}";
            var row = new Entity("alex_payplus_syncoutbox")
            {
                ["alex_name"] = name,
                ["alex_sourcetablelogicalname"] = sourceTable,
                ["alex_sourcerowid"] = sourceId.ToString("D"),
                ["alex_targetobject"] = new OptionSetValue(targetObject.Value),
                ["alex_operation"] = new OptionSetValue(operation),
                ["alex_status"] = new OptionSetValue(status),
                ["alex_correlationkey"] = correlationKey,
                ["alex_sourceversionnumber"] = SourceValue(sourceSnapshot, "versionnumber"),
                ["alex_sourcemodifiedon"] = sourceSnapshot?.GetAttributeValue<DateTime?>("modifiedon"),
                ["alex_lastdetectedon"] = DateTime.UtcNow,
                ["alex_attemptcount"] = 0,
                ["alex_maxattempts"] = 3,
                ["alex_payloadsnapshot"] = payload.Json,
                ["alex_lasterror"] = payload.Error,
                ["alex_syncprofileid"] = profileRef,
                ["alex_entitymappingid"] = new EntityReference("alex_payplus_entitymapping", mappingId)
            };
            service.Create(row);
            tracer.Trace("QueueSyncOutboxOnSourceChange: created outbox for {0} {1}.", sourceTable, sourceId);
        }

        private static Entity FindOpenOutbox(IOrganizationService service, string correlationKey)
        {
            var query = new QueryExpression("alex_payplus_syncoutbox")
            {
                ColumnSet = new ColumnSet("alex_payplus_syncoutboxid"),
                Criteria = new FilterExpression(LogicalOperator.And),
                TopCount = 1
            };
            query.Criteria.AddCondition("alex_correlationkey", ConditionOperator.Equal, correlationKey);
            query.Criteria.AddCondition("alex_status", ConditionOperator.In, StatusPending, StatusRetryScheduled);
            query.AddOrder("createdon", OrderType.Descending);
            var rows = service.RetrieveMultiple(query).Entities;
            return rows.Count == 0 ? null : rows[0];
        }

        private static PayloadBuildResult BuildPayload(IOrganizationService service, Guid mappingId, string sourceTable, Guid sourceId, ITracingService tracer)
        {
            try
            {
                var fields = RetrieveFieldMappings(service, mappingId);
                var sourceColumns = SourceColumns(fields);
                var source = RetrieveSourceForPayload(service, sourceTable, sourceId, sourceColumns);
                var payload = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);

                foreach (var field in fields.Entities)
                {
                    var target = field.GetAttributeValue<string>("alex_targetfieldlogicalname");
                    if (String.IsNullOrWhiteSpace(target)) continue;

                    var sourceType = OptionValue(field, "alex_sourcetype", SourceTypeField);
                    var defaultValue = field.GetAttributeValue<string>("alex_defaultvalue");
                    var value = ResolveFieldValue(service, source, field, sourceType, defaultValue);
                    value = ApplyTransform(service, field, value);
                    value = ApplyNullHandling(field, target, value, defaultValue);
                    if (value == Omit.Value) continue;

                    var payPlusType = OptionValue(field, "alex_payplusdatatype", -1);
                    SetPayloadValue(payload, target, CoerceValue(value, payPlusType));
                }

                return new PayloadBuildResult(SerializeJson(payload), null);
            }
            catch (Exception ex)
            {
                tracer.Trace("QueueSyncOutboxOnSourceChange: payload build failed. {0}", ex);
                return new PayloadBuildResult("{}", ex.Message);
            }
        }

        private static void SetPayloadValue(IDictionary<string, object> payload, string targetPath, object value)
        {
            var parts = targetPath.Split(new[] { '.' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 0) return;
            if (parts.Length == 1)
            {
                payload[parts[0]] = value;
                return;
            }

            var root = parts[0];
            var current = IsArrayRoot(root) ? GetOrCreateArrayObject(payload, root) : GetOrCreateObject(payload, root);
            for (var i = 1; i < parts.Length - 1; i++)
            {
                current = GetOrCreateObject(current, parts[i]);
            }
            current[parts[parts.Length - 1]] = value;
        }

        private static bool IsArrayRoot(string root)
        {
            return String.Equals(root, "contacts", StringComparison.OrdinalIgnoreCase)
                || String.Equals(root, "items", StringComparison.OrdinalIgnoreCase)
                || String.Equals(root, "products", StringComparison.OrdinalIgnoreCase)
                || String.Equals(root, "payments", StringComparison.OrdinalIgnoreCase);
        }

        private static Dictionary<string, object> GetOrCreateObject(IDictionary<string, object> parent, string key)
        {
            if (parent.TryGetValue(key, out var existing) && existing is Dictionary<string, object> existingObject) return existingObject;
            var created = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            parent[key] = created;
            return created;
        }

        private static Dictionary<string, object> GetOrCreateArrayObject(IDictionary<string, object> parent, string key)
        {
            if (parent.TryGetValue(key, out var existing) && existing is object[] array && array.Length > 0 && array[0] is Dictionary<string, object> existingObject) return existingObject;
            var created = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            parent[key] = new object[] { created };
            return created;
        }

        private static EntityCollection RetrieveFieldMappings(IOrganizationService service, Guid mappingId)
        {
            var query = new QueryExpression("alex_payplus_fieldmapping")
            {
                ColumnSet = new ColumnSet("alex_targetfieldlogicalname", "alex_sourcefieldlogicalname", "alex_sourcetype", "alex_defaultvalue", "alex_nullhandling", "alex_requiredforpayload", "alex_payplusdatatype", "alex_transformruleid", "alex_isactive", "alex_sortorder"),
                Criteria = new FilterExpression(LogicalOperator.And)
            };
            query.Criteria.AddCondition("statecode", ConditionOperator.Equal, 0);
            query.Criteria.AddCondition("alex_isactive", ConditionOperator.Equal, true);
            query.Criteria.AddCondition("alex_entitymappingid", ConditionOperator.Equal, mappingId);
            query.AddOrder("alex_sortorder", OrderType.Ascending);
            query.AddOrder("createdon", OrderType.Ascending);
            return service.RetrieveMultiple(query);
        }

        private static ColumnSet SourceColumns(EntityCollection fields)
        {
            var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "versionnumber", "modifiedon" };
            foreach (var field in fields.Entities)
            {
                var sourceType = OptionValue(field, "alex_sourcetype", SourceTypeField);
                if (sourceType == SourceTypeConstant) continue;
                var source = field.GetAttributeValue<string>("alex_sourcefieldlogicalname");
                if (String.IsNullOrWhiteSpace(source)) continue;
                names.Add(source.Contains(".") ? RelatedLookupColumnName(source) : source);
            }
            var columns = new ColumnSet();
            foreach (var name in names) columns.AddColumn(name);
            return columns;
        }

        private static Entity RetrieveSourceForPayload(IOrganizationService service, string sourceTable, Guid sourceId, ColumnSet columns)
        {
            return service.Retrieve(sourceTable, sourceId, columns);
        }

        private static object ResolveFieldValue(IOrganizationService service, Entity source, Entity field, int sourceType, string defaultValue)
        {
            if (sourceType == SourceTypeConstant) return defaultValue;
            var sourceField = field.GetAttributeValue<string>("alex_sourcefieldlogicalname");
            if (String.IsNullOrWhiteSpace(sourceField)) return null;
            if (sourceField.Contains(".")) return ResolveRelatedFieldValue(service, source, sourceField);
            return source.Contains(sourceField) ? NormalizeAttributeValue(source[sourceField]) : null;
        }

        private static object ResolveRelatedFieldValue(IOrganizationService service, Entity source, string sourcePath)
        {
            var parts = sourcePath.Split(new[] { '.' }, 2, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length != 2) return null;
            var lookupColumn = RelatedLookupColumnName(sourcePath);
            if (!source.Contains(lookupColumn) || !(source[lookupColumn] is EntityReference reference)) return null;
            var related = service.Retrieve(reference.LogicalName, reference.Id, new ColumnSet(parts[1]));
            return related.Contains(parts[1]) ? NormalizeAttributeValue(related[parts[1]]) : null;
        }

        private static string RelatedLookupColumnName(string sourcePath)
        {
            var root = sourcePath.Split(new[] { '.' }, 2, StringSplitOptions.RemoveEmptyEntries)[0];
            return root.EndsWith("id", StringComparison.OrdinalIgnoreCase) ? root : root + "id";
        }

        private static object ApplyTransform(IOrganizationService service, Entity field, object value)
        {
            var ruleRef = field.GetAttributeValue<EntityReference>("alex_transformruleid");
            if (ruleRef == null) return value;
            var rule = service.Retrieve("alex_payplus_transformrule", ruleRef.Id, new ColumnSet("alex_rulecode", "alex_expression"));
            var code = rule.GetAttributeValue<string>("alex_rulecode") ?? String.Empty;
            var text = value == null ? null : Convert.ToString(value, CultureInfo.InvariantCulture);

            switch (code)
            {
                case "text.trim": return text?.Trim();
                case "text.lowercase": return text?.ToLowerInvariant();
                case "text.uppercase": return text?.ToUpperInvariant();
                case "phone.normalize-il": return NormalizePhone(text);
                case "guid.to-string": return text;
                case "date.iso-date": return value is DateTime date ? date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : text;
                case "money.to-decimal": return ToDecimal(value);
                case "statecode.to-valid": return StateCodeToValid(value);
                case "number.zero-one-to-boolean": return ZeroOneToBoolean(value);
                case "array.single-to-array": return value == null ? null : new object[] { value };
                case "default.currency-ils": return String.IsNullOrWhiteSpace(text) ? "ILS" : value;
                case "default.country-il": return String.IsNullOrWhiteSpace(text) ? "IL" : value;
                default: return value;
            }
        }

        private static object ApplyNullHandling(Entity field, string target, object value, string defaultValue)
        {
            var isEmpty = value == null || (value is string text && String.IsNullOrWhiteSpace(text));
            if (!isEmpty) return value;

            var nullHandling = OptionValue(field, "alex_nullhandling", NullOmit);
            if (nullHandling == NullUseDefault && !String.IsNullOrWhiteSpace(defaultValue)) return defaultValue;
            if (nullHandling == NullSend) return null;
            if (nullHandling == NullFail || field.GetAttributeValue<bool>("alex_requiredforpayload"))
            {
                throw new InvalidPluginExecutionException($"Required PayPlus field {target} has no value.");
            }
            return Omit.Value;
        }

        private static object NormalizeAttributeValue(object value)
        {
            if (value == null) return null;
            if (value is AliasedValue aliased) return NormalizeAttributeValue(aliased.Value);
            if (value is EntityReference reference) return reference.Id.ToString("D");
            if (value is OptionSetValue option) return option.Value;
            if (value is Money money) return money.Value;
            if (value is Guid id) return id.ToString("D");
            return value;
        }

        private static object CoerceValue(object value, int dataType)
        {
            if (value == null) return null;
            if (dataType == DataTypeArray) return value is object[] ? value : new object[] { value };
            if (dataType == DataTypeBoolean && value is string boolText && Boolean.TryParse(boolText, out var boolValue)) return boolValue;
            if ((dataType == DataTypeNumber || dataType == DataTypeChoice) && Int32.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, out var intValue)) return intValue;
            if ((dataType == DataTypeDecimal || dataType == DataTypeMoney) && Decimal.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, out var decimalValue)) return decimalValue;
            if (dataType == DataTypeDateTime && value is DateTime date) return date.ToString("o", CultureInfo.InvariantCulture);
            return value;
        }

        private static decimal? ToDecimal(object value)
        {
            if (value == null) return null;
            if (value is Money money) return money.Value;
            if (value is decimal decimalValue) return decimalValue;
            if (Decimal.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed)) return parsed;
            return null;
        }

        private static object StateCodeToValid(object value)
        {
            var number = ToInt(value);
            if (number == 0) return true;
            if (number == 1) return false;
            return value;
        }

        private static object ZeroOneToBoolean(object value)
        {
            var number = ToInt(value);
            if (number == 0) return false;
            if (number == 1) return true;
            return value;
        }

        private static int? ToInt(object value)
        {
            if (value == null) return null;
            if (value is OptionSetValue option) return option.Value;
            if (value is bool boolValue) return boolValue ? 1 : 0;
            if (value is int intValue) return intValue;
            if (Int32.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed)) return parsed;
            return null;
        }

        private static string NormalizePhone(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return value;
            var builder = new StringBuilder();
            foreach (var c in value)
            {
                if (Char.IsDigit(c)) builder.Append(c);
            }
            return builder.ToString();
        }

        private static int OptionValue(Entity row, string attributeName, int fallback)
        {
            return row.GetAttributeValue<OptionSetValue>(attributeName)?.Value ?? fallback;
        }

        private static string SerializeJson(IDictionary<string, object> values)
        {
            var builder = new StringBuilder();
            builder.Append('{');
            var first = true;
            foreach (var pair in values)
            {
                if (!first) builder.Append(',');
                first = false;
                AppendJsonString(builder, pair.Key);
                builder.Append(':');
                AppendJsonValue(builder, pair.Value);
            }
            builder.Append('}');
            return builder.ToString();
        }

        private static void AppendJsonValue(StringBuilder builder, object value)
        {
            if (value == null)
            {
                builder.Append("null");
                return;
            }
            if (value is bool boolValue)
            {
                builder.Append(boolValue ? "true" : "false");
                return;
            }
            if (value is byte || value is short || value is int || value is long || value is float || value is double || value is decimal)
            {
                builder.Append(Convert.ToString(value, CultureInfo.InvariantCulture));
                return;
            }
            if (value is object[] array)
            {
                builder.Append('[');
                for (var i = 0; i < array.Length; i++)
                {
                    if (i > 0) builder.Append(',');
                    AppendJsonValue(builder, array[i]);
                }
                builder.Append(']');
                return;
            }
            if (value is IDictionary<string, object> objectValue)
            {
                builder.Append(SerializeJson(objectValue));
                return;
            }
            AppendJsonString(builder, Convert.ToString(value, CultureInfo.InvariantCulture));
        }

        private static void AppendJsonString(StringBuilder builder, string value)
        {
            builder.Append('"');
            foreach (var c in value ?? String.Empty)
            {
                switch (c)
                {
                    case '"': builder.Append("\\\""); break;
                    case '\\': builder.Append("\\\\"); break;
                    case '\b': builder.Append("\\b"); break;
                    case '\f': builder.Append("\\f"); break;
                    case '\n': builder.Append("\\n"); break;
                    case '\r': builder.Append("\\r"); break;
                    case '\t': builder.Append("\\t"); break;
                    default:
                        if (c < 32) builder.Append("\\u" + ((int)c).ToString("x4", CultureInfo.InvariantCulture));
                        else builder.Append(c);
                        break;
                }
            }
            builder.Append('"');
        }

        private static Entity RetrieveSourceSnapshot(IOrganizationService service, string sourceTable, Guid sourceId, ITracingService tracer)
        {
            try
            {
                return service.Retrieve(sourceTable, sourceId, new ColumnSet("versionnumber", "modifiedon"));
            }
            catch (Exception ex)
            {
                tracer.Trace("QueueSyncOutboxOnSourceChange: source snapshot skipped. {0}", ex.Message);
                return null;
            }
        }

        private static string SourceValue(Entity sourceSnapshot, string attributeName)
        {
            if (sourceSnapshot == null || !sourceSnapshot.Contains(attributeName) || sourceSnapshot[attributeName] == null) return null;
            return Convert.ToString(sourceSnapshot[attributeName]);
        }

        private static string operationLabel(int operation)
        {
            return operation == OperationCreate ? "Create" : "Update";
        }

        private sealed class PayloadBuildResult
        {
            public PayloadBuildResult(string json, string error)
            {
                Json = json;
                Error = error;
            }

            public string Json { get; }
            public string Error { get; }
        }

        private sealed class Omit
        {
            public static readonly Omit Value = new Omit();
            private Omit() { }
        }
    }
}