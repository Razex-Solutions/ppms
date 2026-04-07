# Automation And Matrix Bundle

## Purpose

This file explains the current automation scripts, JSON matrices, Flutter automation record, and how they should be used after the pivot to backend-first, matrix-first development.

The goal is to avoid losing the work already done while also avoiding more broad Flutter work before the product flow is agreed.

## Current App Folders

### `ppms_flutter`

Old Flutter app.

Status:

- kept in the repository
- reference only
- not the future source of truth
- do not delete automatically

Use it only to inspect previous ideas, old screens, or possible UI behavior.

### `ppms_tenant_flutter`

Clean tenant Flutter experiment.

Status:

- kept in the repository
- contains the login/session/shell experiment
- contains Flutter navigation tests
- contains integration-test automation record
- not final until the backend/matrix-first strategy is applied domain by domain
- do not delete automatically

Use it as a record of how Flutter automation can be wired, not as a final app guarantee.

### `support_console`

MasterAdmin/support console.

Status:

- separate platform/support app direction
- MasterAdmin belongs here, not in tenant Flutter

## PowerShell Entry Points

### `prepare_phase9_tenant.ps1`

Purpose:

- prepares the Phase 9 test tenants and users
- calls `scripts/ensure_phase9_tenant.py`

Creates/verifies:

- one-station `check` tenant
- `check / office123`
- `check_manager / manager123`
- `check_accountant / accountant123`
- `check_operator / operator123`
- multi-station `p9_multi`
- `p9_multi_station_a_admin / station123`
- `p9_multi_station_b_admin / station123`
- minimal-module `p9_minimal`

Use when:

- local DB needs known test tenants
- API smoke needs stable users
- Phase 9 scenario runner needs prerequisites

### `restart_local_dev.ps1`

Purpose:

- restarts the backend
- opens backend log watcher
- prepares Phase 9 tenant data unless skipped
- starts support console
- starts the tenant Flutter experiment by default

Important:

- this still points at `ppms_tenant_flutter` for local convenience
- after the pivot, do not assume this means `ppms_tenant_flutter` is final

Useful options:

- `-UseOldFlutter` starts `ppms_flutter`
- `-SkipTenantPrep` skips test tenant preparation

### `run_phase9_scenario.ps1`

Purpose:

- runs the large backend scenario through real API calls
- calls `scripts/run_phase9_scenario.py`

This is the strongest current backend acceptance check.

It verifies:

- users
- profile-only staff
- shifts
- meter sales
- cash submissions
- cash-in-hand
- purchases
- supplier payable behavior
- expenses
- tank dips
- customers
- suppliers
- customer payments
- supplier payments
- ledgers
- payroll
- attendance
- tankers
- tanker leftover transfer
- POS
- hardware simulation
- reports
- documents
- notifications
- reversals
- credit override
- meter adjustments
- multi-station scope
- minimal-module toggles

### `run_phase9_tenant_ui_api_smoke.ps1`

Purpose:

- runs API smoke for the tenant UI contract
- calls `scripts/run_phase9_tenant_ui_api_smoke.py`

It verifies:

- each test login can authenticate
- visible screens call allowed APIs
- disabled modules do not require UI calls
- station-scoped users do not cross station boundaries
- mutating endpoints are delegated to the scenario runner

### `watch_backend_logs.ps1`

Purpose:

- tails backend stdout/stderr logs
- helps see `200`, `400`, `403`, and `500` responses during manual checks

Use when debugging live local UI/API behavior.

## Python Scripts

### `scripts/ensure_phase9_tenant.py`

Purpose:

- creates/updates stable Phase 9 tenants and users
- enforces one-station and multi-station test setup
- creates minimal-module tenant for disabled-module checks

Treat as:

- local fixture setup
- not production seed

### `scripts/run_phase9_scenario.py`

Purpose:

- creates a large running-pump scenario via API
- checks expected totals and expected backend effects

Treat as:

- backend source-of-truth acceptance runner
- strongest automated proof that business logic works locally

### `scripts/run_phase9_tenant_ui_api_smoke.py`

Purpose:

- reads the tenant role matrix
- logs in as test users
- checks read endpoints and permission boundaries
- avoids unsafe UI-style mutation

Treat as:

- API contract check for future UI screens
- bridge between matrix and backend

## JSON Matrices

### `scripts/phase9_dataset_manifest.json`

Purpose:

- describes the large Phase 9 scenario dataset
- defines running-pump style test data and expected calculations

Includes:

- users
- staff profiles
- shifts
- meter sales
- cash submissions
- purchases
- expenses
- dips
- credit customers
- suppliers
- payments
- ledgers
- payroll
- attendance
- tankers
- POS
- hardware
- reports
- documents
- notifications
- reversals/corrections
- multi-station/minimal-module datasets

Use when:

- expanding backend scenario data
- verifying expected formulas
- deciding if a future UI screen has enough sample data

### `scripts/tenant_role_matrix.json`

Purpose:

- machine-readable role/screen/API contract for the tenant app idea

Includes:

- roles
- screens
- visibility rules
- read APIs
- create APIs
- update APIs
- delete APIs
- module-gated screens
- role notes

Use when:

- deciding which role should see a screen
- generating API smoke
- generating navigation tests
- reviewing SaaS module visibility

Important:

- this matrix may still need cleanup before future UI rebuild
- do not blindly build UI from it without discussion

### `scripts/tenant_ui_action_matrix.json`

Purpose:

- machine-readable safe Flutter UI action smoke matrix

Includes:

- test accounts
- expected visible labels
- expected hidden labels
- screens to open
- labels that should appear
- safe buttons to tap

Use when:

- preserving how the current Flutter action automation was structured
- designing future UI automation

Important:

- this matrix belongs to the paused Flutter experiment
- destructive actions are intentionally not included
- future rebuild should create a new domain-specific action matrix after discussion

## Flutter Test Files

### `ppms_tenant_flutter/test/widget_test.dart`

Purpose:

- checks tenant navigation definitions
- checks role matrix screen labels
- checks minimal-module hiding behavior at a light widget-test level

Treat as:

- useful reference
- not enough to prove real UI flows

### `ppms_tenant_flutter/integration_test/tenant_action_smoke_test.dart`

Purpose:

- reads `scripts/tenant_ui_action_matrix.json`
- logs into the Flutter experiment
- opens role screens
- checks expected text
- taps limited safe actions
- catches Flutter rendering/runtime errors

Treat as:

- useful future automation pattern
- not the final app acceptance test

## GitHub Actions

### `.github/workflows/phase9-tenant-automation.yml`

Purpose:

- CI pipeline for the Phase 9 automation stack

Currently intended to run:

- backend dependency install
- database migration
- backend tests
- backend startup
- Phase 9 scenario
- tenant UI API smoke
- Flutter dependency install
- Flutter analyze
- Flutter widget/navigation tests
- Flutter integration action smoke
- Flutter Windows debug build

Important:

- this workflow records the intended automation architecture
- future CI should be updated after the new domain-by-domain UI strategy is finalized

## Recommended Future Workflow

For every future domain:

1. Discuss the real workflow first.
2. Update or create a domain-specific matrix.
3. Add/update backend scenario data.
4. Add/update API smoke contract.
5. Build the domain in isolation.
6. Add UI automation only for that domain.
7. Prove the domain hides cleanly when its module is disabled.
8. Integrate into the combined app shell only after it is proven.

## Domain Order

Use this order unless we explicitly decide otherwise:

1. Setup foundation: organization, station, tanks, dispensers, nozzles, dips, meter readings, prices
2. Operator and Manager core: shifts, meter sales, cash, purchases, expenses, dips
3. Customers and suppliers: credit, payments, ledgers, reversals
4. Hardware, POS, and shops
5. Tankers: trips, deliveries, leftover transfer, tanker reports
6. Reports, documents, and notifications
7. StationAdmin for multi-station tenants
8. HeadOffice / OrgAdmin
9. MasterAdmin in support/admin app

## SaaS Module Rule

Every optional module must be fully hideable.

When disabled:

- no sidebar item
- no forms
- no quick actions
- no reports/documents/notifications tied only to that module
- no UI API calls for that module
- the tenant experience should look like the module was never installed

