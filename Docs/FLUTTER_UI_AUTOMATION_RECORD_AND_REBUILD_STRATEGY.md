# Flutter UI Automation Record And Rebuild Strategy

## Status

The current Flutter UI work is paused for product decisions.

- `ppms_flutter` remains in the repository as the old reference app.
- `ppms_tenant_flutter` remains in the repository as the clean tenant-app experiment.
- Neither Flutter folder should be treated as the final product path until we finish the matrix-first rebuild discussion.
- Do not delete either Flutter folder automatically. If deletion is needed later, it should be done deliberately after review.

## Why We Paused

The backend and Phase 9 scenario runner became much stronger than the Flutter UI.

The problem was not only missing APIs. The larger issue was that Flutter screens were being built too broadly and too quickly, which caused:

- screens that looked selectable but were not useful yet
- role/module visibility confusion
- action buttons that existed before the business flow was fully agreed
- repeated manual checking and high frustration
- UI work that did not follow a strict screen-by-screen product contract

## Automation Work Saved For Record

The current automation files are still valuable as a future skill/reference:

- `scripts/tenant_role_matrix.json`
- `scripts/tenant_ui_action_matrix.json`
- `scripts/run_phase9_tenant_ui_api_smoke.py`
- `run_phase9_tenant_ui_api_smoke.ps1`
- `ppms_tenant_flutter/integration_test/tenant_action_smoke_test.dart`
- `.github/workflows/phase9-tenant-automation.yml`

The stable committed automation already proves:

- role matrix navigation exists
- API smoke can be matrix-driven
- Flutter UI can be tested by role and screen
- CI can run backend, API smoke, Flutter tests, and UI action smoke

The interrupted deeper-action draft added the idea of:

- generated form values before safe actions
- per-button expected outcomes
- idempotent handling for already-open shifts
- deeper safe actions for HeadOffice, Manager, and Operator

Do not treat that deeper-action draft as final product behavior. Treat it as a future testing technique.

## New Strategy

Backend is the source of truth first.

Before building any Flutter screen, we must discuss and lock:

- what the real-world workflow is
- which role performs it
- which tables/entities are involved
- which API calls are required
- which fields are required vs optional
- what should be auto-generated
- what should be editable/deletable
- what reports/ledgers/cash/stock effects are expected
- what the UI must show and what it must hide

Only after that do we build the Flutter screen.

## Separate First, Integrate Later

Each product domain must be created and tested separately before it is combined into the final tenant experience.

This means:

- build setup as its own foundation
- build operator/manager operations as their own flow
- build customers/suppliers as their own flow
- build hardware/POS/shops as their own optional flow
- build tankers as their own optional flow
- build reports/documents/notifications after the data-producing flows
- build StationAdmin, HeadOffice, and MasterAdmin after the domain workflows are proven

Only after a domain has:

- a backend contract
- sample data
- expected calculations
- matrix rules
- API smoke coverage
- UI/action automation
- an accepted manual UX decision

should it be integrated into the combined app shell.

## SaaS Module Rule

PPMS is a SaaS product. Different tenants will choose different modules.

Every optional module must be able to turn off cleanly.

When a module is disabled:

- its sidebar item must disappear
- its dashboard/summary card must disappear
- its forms must disappear
- its quick actions must disappear
- its reports/documents/notifications must disappear unless another enabled module needs them
- no disabled-module API calls should be made from the UI
- the tenant experience should look like that module was never installed

This applies especially to:

- tankers
- POS/shop/mart
- hardware
- meter adjustments
- payroll if disabled
- attendance if disabled
- financial documents if disabled
- notifications if disabled
- reports if disabled

The backend may still keep tables and endpoints available, but the tenant UI must respect module settings at organization/station scope.

Integration rule:

- build a module separately
- prove it works
- add its module gate
- prove it fully hides when disabled
- only then connect it to shared reports, ledgers, documents, notifications, and dashboards

## Build Order

### 1. Setup Foundation

Build and test setup as the foundation:

- organization
- station
- fuel types
- tanks
- dispensers
- nozzles
- starting meter readings
- fuel prices
- tank dip baseline
- legal/invoice identity
- module toggles

Important rules:

- tank, dispenser, and nozzle setup must be clear before sales
- nozzle must connect to the correct tank and fuel type
- meter reading and fuel price must exist before operator fuel sales
- edit/delete behavior must be decided before UI is built

### 2. Operator And Manager Core

Build the real station operation loop:

- manager/operator shift open
- operator meter-based fuel sale
- operator cash submission
- manager cash-in-hand review
- manager shift review/close
- manager expenses
- manager purchases
- tank dip checks
- stock movement from sales, purchases, internal fuel, and dips

Important rules:

- sales must be meter-based
- cash-in-hand must follow shift cash rules
- purchases must update supplier payable and tank stock according to the approved business rule
- dips must compare physical stock vs system stock

### 3. Customers And Suppliers

Build credit and ledger flows:

- credit customers
- walk-in/cash customer behavior
- suppliers
- customer credit fuel sale
- customer payment
- supplier payment
- customer ledger
- supplier ledger
- credit limit override
- reversals/approvals

### 4. Hardware, POS, And Shops

Build optional operational modules only after core fuel flow is stable:

- hardware devices
- dispenser/tank-probe simulation
- POS products
- POS sale
- shop/mart items
- shop/rented-outlet behavior if needed
- POS reversal

### 5. Tankers

Build tanker as its own module after the core station and finance flow:

- own tanker
- hired tanker
- tanker driver/helper/staff
- tanker compartments
- tanker trip
- tanker delivery to customer/other pump
- tanker expenses
- delivered quantity
- leftover quantity
- partial leftover transfer into station tank
- remaining tanker leftover
- tanker profit/reporting

### 6. Reports, Documents, And Notifications

Build these after data-producing flows are stable:

- daily closing report
- stock movement report
- customer/supplier statements
- tanker reports
- payroll reports
- document templates
- document preview/dispatch
- notification preferences
- notification retry/diagnostics

### 7. StationAdmin

Build StationAdmin only after single-station HeadOffice and station operations are stable.

Rules:

- StationAdmin exists only for multi-station tenants
- StationAdmin sees only assigned station
- StationAdmin must not see other stations or other organizations
- StationAdmin should manage station users and station operations only

### 8. OrgAdmin / HeadOffice

Build HeadOffice after station-level flows are clear:

- organization-wide view
- station selector for multi-station tenant
- create station admins for multi-station tenant
- organization reports
- organization users/staff
- approvals/corrections
- setup review

Single-station rule:

- HeadOffice acts as StationAdmin for one-station tenants
- no separate StationAdmin should be created for one-station tenants

### 9. MasterAdmin

MasterAdmin belongs outside the tenant app.

Build in support/admin app only after tenant flow is stable:

- create organizations
- create first HeadOffice user
- module/subscription management
- support inspection
- cross-organization debugging
- platform health/support tools

## Matrix-First Rule

For each screen, create/update a matrix before UI work:

- role
- screen
- visible/hidden rules
- setup prerequisites
- form fields
- read APIs
- create APIs
- update APIs
- delete APIs
- approvals/reversals
- expected backend effects
- expected UI states
- automated test coverage

No screen should be built from guesswork.

## Next Working Rule

Do not build everything at once.

For every future UI slice:

1. Discuss the exact business flow.
2. Update the backend/matrix contract.
3. Run backend scenario/API smoke.
4. Build one screen or one tightly connected workflow.
5. Add automation for that screen.
6. Only then review UI polish.
