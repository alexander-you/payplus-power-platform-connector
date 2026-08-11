# Connecting Your Custom Solution to PayPlus — without Dynamics 365 Sales 🇬🇧

A customer-facing, step-by-step guide for connecting **your own tables and processes** (custom tables)
to **PayPlus** in an environment that has **no** Dynamics 365 Sales. Everything you need ships in the
**Base solution** (`alex_d365_payplus`) — a fully self-contained package with **zero** Sales dependency.

> **Version:** v1.0.0 · **Publisher:** AlexanderYurpolsky (prefix `alex`)
> **Download:** <https://github.com/alexander-you/payplus-power-platform-connector/releases/tag/v1.0.0>
> Companion guide: [PAYPLUS_SETUP_GUIDE_HE.md](PAYPLUS_SETUP_GUIDE_HE.md) (initial install & API keys).

---

## Who this is for

A customer with **their own Dataverse data model** (`contact`, `account`, or custom tables such as
`new_customerproduct`) who wants to sync it to PayPlus — **without** installing the Sales extension and
**without** touching any flows. The entire connection is configured through the **sync engine** and the
**Mapping Studio** control, in configuration only (No-Code).

---

## How it works — at a glance

```
Your source table  ──►  Entity Mapping + Field Mapping  ──►  Sync Outbox  ──►  Flow "Process Sync Outbox"  ──►  PayPlus
   (Dataverse)          (configured in Mapping Studio)      (job queue)         (built into the Base)          (Connector)
```

- **Entity Mapping** — defines *which* Dataverse table syncs to *which* PayPlus object.
- **Field Mapping** — defines *which fields* are sent and how.
- **Sync Outbox / State / Log** — the job queue, the correlation state (PayPlus UID) and run history.
- Everything is driven from a single **Sync Profile** record (`alex_payplus_syncprofile`) via Mapping Studio.

---

## Prerequisites

| # | Requirement |
|---|-------------|
| 1 | A **Dataverse** environment with **System Administrator / Customizer** privileges. |
| 2 | The **Base solution** `alex_d365_payplus` installed (managed recommended). Dynamics 365 Sales is **not required**. |
| 3 | **PayPlus API keys** (`api_key` + `secret_key`) and an active **Connection** to the custom connector — see the setup guide. |
| 4 | The source table you want to sync already exists in the environment (standard or custom). |

---

## Step 1 — Install the Base only

1. Import **`alex_d365_payplus_1_0_0_0_managed.zip`** only (do **not** import the Sales extension).
2. Create a **Connection** to PayPlus (Prod / SandBox) and bind the connection references, as described in the setup guide.
3. Complete the setup wizard (API keys, terminal).

> ✅ After this step you have the full PayPlus platform with no Sales dependency whatsoever.

---

## Step 2 — Create a Sync Profile

1. Open the PayPlus model-driven app.
2. Go to **Sync Profiles** (`alex_payplus_syncprofile`) → **New**.
3. Set:
   - **Environment** — `Sandbox` for testing or `Production` for go-live.
   - **Is Active** — mark it active.
4. Save. The profile record is the "workbench" — the **Mapping Studio** control lives on it.

> ⚠️ Note: on the Sync Profile table the environment values are **reversed** compared to the config table (Sandbox=`100000000`, Production=`100000001`). The UI handles this — just pick by name.

---

## Step 3 — Map your table (Mapping Studio)

Inside the Sync Profile record, in the **Mapping Studio** control:

1. **Pick a source table** — choose the table to sync (e.g. `contact`, `account`, or a custom `new_customerproduct`).
   This creates an **Entity Mapping** (`alex_payplus_entitymapping`) with a `Source Table Logical Name`.
2. **Pick the target PayPlus object** — e.g. `Customer`.
3. **Map fields (Field Mapping)** — for each PayPlus target field, select the matching source field.
   - Standard tables get **automatic mapping suggestions**; custom tables are mapped manually.
   - PayPlus required fields are flagged — make sure they are all mapped.
4. *(Optional)* **Transform Rule** — value conversions (formatting, concatenation, etc.).
5. *(Optional)* **Value Mapping** — map choice values between D365 and PayPlus (e.g. country / currency codes).
6. *(Optional)* **Filter Rule** — restrict which source records are eligible to sync.
7. Activate the Entity Mapping (**Is Active**).

> 💡 **Recommended start:** begin with a single complete mapping — `contact → Customer` — to prove all components work before expanding to more tables.

---

## Step 4 — Enable event detection (Plugin or Polling)

There are two ways to create sync jobs when a source record is created/updated:

| Method | When to use | How |
|--------|-------------|-----|
| **Async Plugin Step** | Frequently-changing tables; near-real-time sync | On the Entity Mapping set **Plugin Step Status** to register a Step on Create/Update of the source table. |
| **Polling** (alternative) | Custom tables without a plugin step, or periodic sync | The flow periodically scans eligible records and creates Outbox jobs. |

In both methods, a change to a **mapped** field creates/updates a **Sync Outbox** record in `Pending` state.

---

## Step 5 — Turn on the processing flow

1. Ensure the flow **`PayPlus - Process Sync Outbox`** (built into the Base) is **turned on**.
2. The flow reads each Outbox job, builds the payload from the Field Mapping, branches by the profile's
   environment (Sandbox / Production), calls the matching connector, and stores the result:
   - The **PayPlus UID** is saved in **Sync State** (`alex_payplus_syncstate`) — so an existing record is updated, not recreated.
   - Successes/failures are written to **Sync Log** (`alex_payplus_synclog`).

### Missing UID Policy
When a record is updated but has no PayPlus UID yet, choose the behavior per Entity Mapping:

| Policy | Behavior | Recommended for |
|--------|----------|-----------------|
| **Create** | Creates a new record in PayPlus | Customers, products |
| **Block** | Stops and waits for manual review | Financial documents |
| **Failed** | Marks as failed for handling | Sensitive scenarios |

---

## Step 6 — End-to-end test

1. Create/update a record in the source table (e.g. a new `contact` that passes the filter rule).
2. Confirm a **Sync Outbox** record is created in `Pending` state.
3. Wait for the flow to run (or run it manually) → status moves to `Processed`.
4. Confirm a **Sync State** is created with the **PayPlus UID**, and a matching record exists in PayPlus.
5. Update the record again → the same PayPlus record is updated (not a new one).

---

## Step 7 — Expand to more tables

Repeat **Step 3** for each additional table (`account`, products, custom tables, etc.).
Each new source is just another **Entity Mapping + Field Mapping** — **no flow changes and no code**.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| No Outbox created on record update | The updated field isn't mapped, or the plugin step is off | Check Field Mapping and Plugin Step Status; or enable Polling. |
| Outbox stuck in `Pending` | Flow is off or the connection is broken | Turn on `Process Sync Outbox`; check the connection reference. |
| Duplicates created in PayPlus | Missing Sync State / correlation | Ensure the UID is saved; use `alex_correlationkey`. |
| A PayPlus required field is empty | Not fully mapped | Complete the Field Mapping for all required fields. |
| A Choice value is rejected by PayPlus | Missing Value Mapping | Define a Value Mapping for the choice values. |

---

## Appendix — Engine tables

| Table | Logical name | Role |
|-------|--------------|------|
| Sync Profile | `alex_payplus_syncprofile` | Environment settings and default behavior |
| Entity Mapping | `alex_payplus_entitymapping` | Source table ↔ PayPlus object |
| Field Mapping | `alex_payplus_fieldmapping` | Field mapping |
| Filter Rule | `alex_payplus_filterrule` | Source record eligibility |
| Transform Rule | `alex_payplus_transformrule` | Value conversions |
| Value Mapping | `alex_payplus_valuemapping` | Choice value mapping |
| Sync Outbox | `alex_payplus_syncoutbox` | Sync job queue |
| Sync State | `alex_payplus_syncstate` | Correlation + PayPlus UID |
| Sync Log | `alex_payplus_synclog` | Run history and errors |

> All tables and the **Mapping Studio** control ship in the Base solution — no Sales, no code required.
