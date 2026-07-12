# Continuous Sync Documentation

This folder documents the Dynamics 365 / Dataverse to PayPlus continuous sync solution.

The sync engine is intentionally narrow. It is designed for controlled outbound synchronization from Dynamics 365 to PayPlus for business objects that have a clear PayPlus counterpart and a clear operational reason to exist in PayPlus.

## Documents

| Document | Purpose |
| --- | --- |
| [Solution concept](solution-concept.md) | Business concept, goals, process boundaries, and how the sync should be understood by business and implementation teams. |
| [Architecture and components](architecture-and-components.md) | Technical architecture, runtime flow, Dataverse tables, plugin responsibilities, Power Automate responsibilities, and diagrams. |
| [Sync scope and governance](sync-scope-and-governance.md) | Recommended sync targets, tables that should not be synced generically, decision criteria, and implementation guardrails. |

## One-line Summary

Dynamics 365 remains the source of truth. A Dataverse plugin checks active mapping and filter rules, writes eligible changes to a sync outbox, and a generic Power Automate flow sends those outbox items to PayPlus through sandbox or production custom connectors.
