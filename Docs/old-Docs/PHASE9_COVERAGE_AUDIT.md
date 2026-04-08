# PPMS Phase 9 Coverage Audit

## Purpose

This file answers:

```text
Are we still following the docs, and what is still missing?
```

Read it after:

- [FINAL_PHASED_MASTER_ROADMAP.md](FINAL_PHASED_MASTER_ROADMAP.md)
- [SIMPLIFIED_SETUP_AND_ROLE_PLAN.md](SIMPLIFIED_SETUP_AND_ROLE_PLAN.md)
- [TENANT_FLUTTER_REBUILD_PLAN.md](TENANT_FLUTTER_REBUILD_PLAN.md)
- [CHECKTESTINGPLAN.md](CHECKTESTINGPLAN.md)
- [PHASE9_SAMPLE_DATASET.md](PHASE9_SAMPLE_DATASET.md)

## Current Answer

We are on the right path.

The automated Phase 9 scenario now covers the main product flow at backend/API level. The clean tenant Flutter app is being rebuilt around the same role and module model.

This does not mean the full product UI is finished yet.

## Automated Scenario Coverage

The runner at [run_phase9_scenario.py](/C:/Fuel%20Management%20System/scripts/run_phase9_scenario.py) now covers:

- fresh Phase 9 tenant preparation
- one-station `check` tenant
- single-station admin rule: `HeadOffice` acts as tenant admin and station admin
- no `StationAdmin` for one-station tenant
- worker login users: `Manager`, `Accountant`, `Operator`
- extra realistic running-pump users
- profile-only staff for pump attendants, security, tanker drivers, and cleaners/helpers
- tanks, dispensers, nozzles, and fuel types
- shift open, shift close, balanced shift, variance shift, and open shift
- meter-based fuel sales
- cash submissions
- expenses
- purchases
- direct Manager purchase posting
- supplier payments and supplier ledger checks
- credit customers
- credit fuel sales
- customer payments and customer ledger checks
- attendance
- salary adjustments
- payroll run generation and finalization
- POS products and POS sale
- POS sale reversal and stock restoration
- tankers, tanker compartments, tanker trips, tanker deliveries, tanker expenses, and leftover transfer
- scoped reports
- saved report definition
- report export
- financial document rendering for sales, payments, and ledgers
- notification summary and inbox readability
- customer payment reversal request and approval
- fuel sale reversal request and approval
- supplier payment reversal request and approval
- purchase reversal request and approval
- reversal rejection paths for fuel sales, purchases, customer payments, and supplier payments
- credit override request and approval
- credit override rejection
- internal fuel usage
- HeadOffice meter adjustment for the one-station admin rule
- meter adjustment history and meter segment readback
- multi-station tenant setup
- per-station `StationAdmin` users for multi-station tenant
- StationAdmin station leakage checks
- minimal-module tenant setup
- module toggles for POS, mart, tanker, hardware, and meter adjustments
- tank dips across all tanks
- expected vs actual totals for the main money, stock, payroll, tanker, and scope checks

Expected command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_phase9_scenario.ps1
```

Expected result:

```text
Phase 9 scenario passed.
```

## Tenant Flutter Coverage

The clean tenant Flutter app at [ppms_tenant_flutter](/C:/Fuel%20Management%20System/ppms_tenant_flutter) now covers:

- login and session context
- quick-login buttons for Phase 9 users
- station resolution for organization-scoped `HeadOffice`
- role-aware navigation
- module-aware navigation
- `StationAdmin` navigation for multi-station tenants
- hidden optional modules for minimal-module tenant
- `HeadOffice` worker user CRUD for the single-station tenant
- setup foundation read views
- Manager operations starter views
- Operator shift and meter sale starter views

This app is not finished yet.

## Resolved Gap Decisions

These were open in the first audit and are now covered by the runner:

- open shift cash-in-hand now includes live cash sales and cash submissions
- normal `Manager`, `StationAdmin`, and `HeadOffice` purchases now post directly as approved operational records
- tanker completion supports partial leftover transfer and remaining leftover tracking
- reversal rejection paths are covered for fuel sales, purchases, customer payments, and supplier payments
- credit override rejection is covered
- profile-only staff payroll is now supported through employee-profile payroll lines
- hardware simulation now covers dispenser and tank-probe devices plus events
- notification preference, delivery diagnostics, and document template edit/preview checks are covered
- multi-station operations now cover station-specific shifts, expenses, scoped reads, and cross-station denial checks

## Important Known Gaps

### 1. Clean Tenant Flutter UI Completion

Current coverage:

- login
- context
- navigation
- users
- setup read views
- Manager and Operator starter operations

Still needed:

- Accountant finance packet
- parties and ledger UI packet
- payroll and attendance UI packet
- tankers UI packet
- POS UI packet
- reports/documents/notifications UI packet
- correction/reversal UI packet
- multi-station HeadOffice user creation with a real station selector
- question-based setup wizard UI
- support-console Phase 9 walkthrough

## Not Phase 9 Blocking Yet

These should not block the current tenant rebuild unless we explicitly pull them into Phase 9:

- production deployment
- external WhatsApp/SMS/email provider credentials
- full offline-first sync engine
- production hardware vendor rollout
- advanced SaaS billing collection
- mobile app packaging

## Recommended Next Batch

Next best batch:

```text
Accountant finance packet:
1. parties list/view
2. customer payment
3. supplier payment
4. customer ledger view
5. supplier ledger view
6. payroll run view
7. scoped reports read view
```

Why:

- backend automation already proves these flows
- the clean tenant app still needs Accountant UI
- this unlocks a full role packet after HeadOffice, Manager, and Operator starter flows

After that:

```text
1. Tanker + POS UI packet
2. Reports/Documents/Notifications UI packet
3. Correction/Reversal UI packet
4. Multi-station HeadOffice + StationAdmin UI packet
5. Support-console Phase 9 walkthrough
```
