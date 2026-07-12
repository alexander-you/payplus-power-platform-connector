using System;
using System.Collections.Generic;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace PayPlus.Plugins
{
    public sealed class SeedTransformRules : IPlugin
    {
        private const string EntityName = "alex_payplus_transformrule";
        private const string RuleCode = "alex_rulecode";
        private const string Name = "alex_name";
        private const string RuleKind = "alex_rulekind";
        private const string Expression = "alex_expression";
        private const string ParametersJson = "alex_parametersjson";
        private const string OutputType = "alex_outputtype";
        private const string IsActive = "alex_isactive";
        private const string Description = "alex_description";

        private const int KindNone = 100000000;
        private const int KindTrim = 100000001;
        private const int KindLowercase = 100000002;
        private const int KindUppercase = 100000003;
        private const int KindNormalizePhone = 100000004;
        private const int KindGuidToString = 100000005;
        private const int KindLookupValue = 100000006;
        private const int KindValueMapping = 100000007;
        private const int KindDefaultValue = 100000008;
        private const int KindConcatenate = 100000009;
        private const int KindCurrencyCode = 100000010;

        private const int TypeText = 100000000;
        private const int TypeNumber = 100000001;
        private const int TypeDecimal = 100000002;
        private const int TypeBoolean = 100000004;
        private const int TypeDateTime = 100000005;
        private const int TypeJson = 100000008;
        private const int TypeArray = 100000009;

        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracer = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
            var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = factory.CreateOrganizationService(context.UserId);

            var created = 0;
            var updated = 0;
            var skipped = 0;

            foreach (var rule in BuiltInRules())
            {
                var existing = FindByCode(service, rule.Code);
                if (existing == null)
                {
                    service.Create(ToEntity(rule));
                    created++;
                    tracer.Trace("SeedTransformRules: created {0}.", rule.Code);
                    continue;
                }

                if (NeedsUpdate(existing, rule))
                {
                    var update = ToEntity(rule);
                    update.Id = existing.Id;
                    service.Update(update);
                    updated++;
                    tracer.Trace("SeedTransformRules: updated {0}.", rule.Code);
                }
                else
                {
                    skipped++;
                }
            }

            context.OutputParameters["CreatedCount"] = created;
            context.OutputParameters["UpdatedCount"] = updated;
            context.OutputParameters["SkippedCount"] = skipped;
            context.OutputParameters["Message"] = $"Transform rules are ready. Created: {created}, updated: {updated}, skipped: {skipped}.";
        }

        private static Entity FindByCode(IOrganizationService service, string code)
        {
            var query = new QueryExpression(EntityName)
            {
                ColumnSet = new ColumnSet(Name, RuleCode, RuleKind, Expression, ParametersJson, OutputType, IsActive, Description),
                Criteria = new FilterExpression(LogicalOperator.And),
                TopCount = 1
            };
            query.Criteria.AddCondition(RuleCode, ConditionOperator.Equal, code);
            var rows = service.RetrieveMultiple(query).Entities;
            return rows.Count == 0 ? null : rows[0];
        }

        private static Entity ToEntity(RuleDefinition rule)
        {
            return new Entity(EntityName)
            {
                [Name] = rule.Name,
                [RuleCode] = rule.Code,
                [RuleKind] = new OptionSetValue(rule.RuleKind),
                [Expression] = rule.Expression,
                [ParametersJson] = rule.ParametersJson,
                [OutputType] = new OptionSetValue(rule.OutputType),
                [IsActive] = true,
                [Description] = rule.Description
            };
        }

        private static bool NeedsUpdate(Entity existing, RuleDefinition rule)
        {
            return StringValue(existing, Name) != rule.Name
                || OptionValue(existing, RuleKind) != rule.RuleKind
                || StringValue(existing, Expression) != rule.Expression
                || StringValue(existing, ParametersJson) != rule.ParametersJson
                || OptionValue(existing, OutputType) != rule.OutputType
                || !existing.GetAttributeValue<bool>(IsActive)
                || StringValue(existing, Description) != rule.Description;
        }

        private static string StringValue(Entity row, string attributeName)
        {
            return row.GetAttributeValue<string>(attributeName) ?? String.Empty;
        }

        private static int OptionValue(Entity row, string attributeName)
        {
            return row.GetAttributeValue<OptionSetValue>(attributeName)?.Value ?? -1;
        }

        private static IEnumerable<RuleDefinition> BuiltInRules()
        {
            yield return new RuleDefinition("text.trim", "Text - Trim", KindTrim, "trim(input)", "{\"operation\":\"trim\"}", TypeText, "Removes leading and trailing whitespace before sending text to PayPlus.");
            yield return new RuleDefinition("text.lowercase", "Text - Lowercase", KindLowercase, "lower(input)", "{\"operation\":\"lowercase\"}", TypeText, "Converts text to lowercase for fields that require normalized values.");
            yield return new RuleDefinition("text.uppercase", "Text - Uppercase", KindUppercase, "upper(input)", "{\"operation\":\"uppercase\"}", TypeText, "Converts text to uppercase for fields such as ISO codes.");
            yield return new RuleDefinition("phone.normalize-il", "Phone - Normalize Israel", KindNormalizePhone, "normalizePhone(input, 'IL')", "{\"country\":\"IL\",\"removeSeparators\":true}", TypeText, "Normalizes Israeli phone numbers before sending customer contact data to PayPlus.");
            yield return new RuleDefinition("guid.to-string", "GUID - To String", KindGuidToString, "toString(input)", "{\"format\":\"D\",\"stripBraces\":true}", TypeText, "Converts a Dataverse GUID to a plain string. Do not use this for PayPlus subject_code; PayPlus expects a short numeric code there.");
            yield return new RuleDefinition("statecode.to-valid", "StateCode - To PayPlus Valid", KindValueMapping, "input == 0", "{\"map\":{\"0\":true,\"1\":false},\"default\":true}", TypeBoolean, "Converts Dataverse statecode to PayPlus valid flag. Active becomes true, inactive becomes false.");
            yield return new RuleDefinition("number.zero-one-to-boolean", "Number - 0/1 To Boolean", KindValueMapping, "input == 1", "{\"map\":{\"0\":false,\"1\":true},\"default\":null}", TypeBoolean, "Converts numeric flags to Boolean values. 0 becomes false, 1 becomes true.");
            yield return new RuleDefinition("currency.lookup-to-iso", "Currency Lookup - To ISO Code", KindCurrencyCode, "lookup(input).isocurrencycode", "{\"lookupTable\":\"transactioncurrency\",\"field\":\"isocurrencycode\",\"fallback\":\"ILS\"}", TypeText, "Reads a Dataverse currency lookup and returns an ISO currency code such as ILS, USD or EUR.");
            yield return new RuleDefinition("lookup.name", "Lookup - Primary Name", KindLookupValue, "lookup(input).name", "{\"field\":\"name\",\"fallback\":null}", TypeText, "Reads the primary name from a lookup record.");
            yield return new RuleDefinition("date.iso-date", "Date - ISO Date", KindNone, "formatDate(input, 'yyyy-MM-dd')", "{\"format\":\"yyyy-MM-dd\"}", TypeDateTime, "Formats a Dataverse date as an ISO date string for PayPlus.");
            yield return new RuleDefinition("money.to-decimal", "Money - To Decimal", KindNone, "decimal(input)", "{\"round\":2}", TypeDecimal, "Converts Dataverse Money values to a decimal number rounded to two digits.");
            yield return new RuleDefinition("default.currency-ils", "Default - Currency ILS", KindDefaultValue, "default('ILS')", "{\"value\":\"ILS\"}", TypeText, "Returns ILS when a PayPlus currency code is required and no source value is mapped.");
            yield return new RuleDefinition("default.country-il", "Default - Country IL", KindDefaultValue, "default('IL')", "{\"value\":\"IL\"}", TypeText, "Returns IL as the default country ISO code.");
            yield return new RuleDefinition("array.single-to-array", "Array - Single Value To Array", KindNone, "array(input)", "{\"omitWhenNull\":true}", TypeArray, "Wraps a single value as an array, useful for PayPlus fields such as category_uids.");
            yield return new RuleDefinition("json.parse", "JSON - Parse", KindNone, "parseJson(input)", "{\"onInvalid\":\"fail\"}", TypeJson, "Parses a text field that contains JSON before building advanced PayPlus payloads.");
            yield return new RuleDefinition("concat.space", "Text - Concatenate With Space", KindConcatenate, "concat(values, ' ')", "{\"separator\":\" \",\"skipEmpty\":true}", TypeText, "Concatenates multiple source values with a single space while skipping empty values.");
        }

        private sealed class RuleDefinition
        {
            public RuleDefinition(string code, string name, int ruleKind, string expression, string parametersJson, int outputType, string description)
            {
                Code = code;
                Name = name;
                RuleKind = ruleKind;
                Expression = expression;
                ParametersJson = parametersJson;
                OutputType = outputType;
                Description = description;
            }

            public string Code { get; }
            public string Name { get; }
            public int RuleKind { get; }
            public string Expression { get; }
            public string ParametersJson { get; }
            public int OutputType { get; }
            public string Description { get; }
        }
    }
}