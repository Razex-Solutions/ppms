# PPMS Tenant Flutter Rebuild Plan

## Decision

Stop patching the current Flutter tenant UI screen by screen.

The current app has too much accumulated UI confusion and rendering instability for Phase 9 acceptance. We will plan a clean tenant-app rebuild while preserving the backend, database, permissions, and useful API work.

Do not delete `ppms_flutter` until the replacement path is ready and committed. The current app remains a reference for API calls, models, and test coverage.

## Target App Split

Long-term product split:

- MasterAdmin app: platform admin/support app for Razex
- Tenant app: organization/station worker app for customers

`ppms_flutter` should become the tenant app only.

MasterAdmin organization creation and support workflows can remain available during Phase 9 only as temporary setup tooling, but they should move out of the tenant app later.

## Role Model

The rebuild must follow this role model:

- `MasterAdmin`: platform admin, separate from tenant operations
- `HeadOffice`: tenant organization admin
- `StationAdmin`: station admin only for multi-station organizations
- single-station tenant: `HeadOffice` acts as both organization admin and station admin
- `Manager`: daily station supervisor
- `Accountant`: finance, ledgers, payroll, reports
- `Operator`: shift/sales/cash entry

For the current `check` tenant, skip `StationAdmin` because it has one station.

## What To Keep

Keep:

- backend FastAPI app
- fresh DB bootstrap and seed work
- role hierarchy and permission model
- existing backend tests
- current API client knowledge from the old Flutter app
- local restart scripts
- Phase 9 check testing plan
- support console for MasterAdmin/support work

## What To Replace

Replace:

- current Flutter shell layout
- current sidebar/navigation implementation
- dashboard-heavy tenant pages
- confusing combined admin/staff/user screens
- screens that show placeholder UI or dead actions
- screens that require station selection when tenant scope already determines it
- any MasterAdmin daily-operations screens inside the tenant app

## Rebuild Rule

Build one vertical slice at a time.

Each slice must have:

- backend endpoint contract checked
- simple UI
- clear role access
- no cross-tenant leakage
- no placeholder dashboard cards
- create/edit/delete only when the role should have it
- test notes added to Phase 9 plan
- commit and push after completion

## Permission Rules For The Rebuild

Use permission checks by module/action, not just role names.

Role names decide the default hierarchy. Permissions decide exact screen actions.

Default hierarchy:

- `MasterAdmin` creates organizations and the first `HeadOffice`
- `HeadOffice` creates `StationAdmin` only for multi-station organizations
- `HeadOffice` creates `Manager`, `Accountant`, `Operator`, and profile-only staff for single-station organizations
- `StationAdmin` creates `Manager`, `Accountant`, `Operator`, and station staff for assigned stations in multi-station organizations
- `Manager` may create selected profile-only staff later if policy allows
- `Accountant` and `Operator` do not create login users
- lower roles do not create higher roles
- the old generic `Admin` role must not appear in active tenant rebuild flows

Scope rules:

- platform scope belongs only to `MasterAdmin`
- organization scope belongs to `HeadOffice`
- station scope belongs to `StationAdmin`, `Manager`, `Accountant`, and `Operator`
- single-station tenants use `HeadOffice` as the merged organization admin and station admin
- station-scoped roles must never see another organization's station
- organization-scoped roles must never see another organization

Action permission categories:

- `view`
- `create`
- `update`
- `delete`
- `approve`
- `reverse`
- `export`

Suggested permission examples to preserve as the long-term target:

- `users.create.station_admin`
- `users.create.manager`
- `users.create.accountant`
- `users.create.operator`
- `users.view.station`
- `staff_profiles.create`
- `staff_profiles.update`
- `stations.view`
- `stations.update`
- `tanks.create`
- `tanks.update`
- `tanks.delete`
- `dispensers.create`
- `dispensers.update`
- `dispensers.delete`
- `nozzles.create`
- `nozzles.update`
- `nozzles.delete`
- `nozzles.adjust_meter`
- `fuel_sales.create`
- `fuel_sales.view`
- `fuel_sales.reverse.request`
- `fuel_sales.reverse.approve`
- `shifts.open`
- `shifts.close`
- `shift_cash.manage`
- `cash_submissions.create`
- `purchases.create`
- `purchases.approve`
- `expenses.create`
- `expenses.approve`
- `customer_payments.create`
- `supplier_payments.create`
- `ledger.view`
- `reports.view.organization`
- `reports.view.station`
- `reports.export`
- `attendance.self`
- `attendance.manage.station`
- `payroll.view`
- `payroll.run`
- `payroll.finalize`
- `tankers.view`
- `tankers.create`
- `tanker_trips.manage`
- `hardware.view`
- `hardware.configure`
- `pos_products.manage`
- `pos_sales.create`

## Role Permission Matrix

Use this as the rebuild target. If the backend currently differs, either hide the unsupported UI or update the backend intentionally with tests.

| Area | MasterAdmin | HeadOffice | StationAdmin | Manager | Accountant | Operator |
|---|---|---|---|---|---|---|
| Organizations | all create/update/support | own org view/update selected settings | no | no | no | no |
| Subscriptions/modules | platform manage | own org view/request/update where allowed | station modules if delegated | no | no | no |
| Stations | all inspect/support | all own org stations | assigned station | assigned station view | assigned station view | assigned station limited view |
| Users | create first HeadOffice | create StationAdmin only if multi-station; create Manager/Accountant/Operator | create station Manager/Accountant/Operator | no login users by default | no | no |
| Staff profiles | support inspect | org/station staff | assigned station staff | selected station staff if allowed | view payroll staff if allowed | self/none |
| Setup inventory | support inspect/repair | own org/station setup | assigned station setup | partial operational setup if allowed | view only/none | no |
| Shifts | support inspect | view | manage assigned station | open/close/manage | view finance impact | work assigned shift |
| Fuel sales | support inspect | view | view/manage | create/manage | view mostly | create assigned sales |
| Cash control | support inspect | org view | station manage | manage/submit/review | finance view | submit own shift cash if allowed |
| Purchases | support inspect | org view | station manage | create/operational | finance view/process | no |
| Expenses | support inspect | org view | station manage/approve if delegated | create/manage selected | finance view/process | limited submission only if allowed |
| Parties/ledger | support inspect | org view | station view/manage | operational view | manage/view finance | no |
| Payroll/attendance | support inspect | org view | station manage | attendance manage selected | payroll view/run if allowed | self attendance |
| Tankers | support inspect | org view | station manage | operational manage | finance/report view | no unless DriverLogin later |
| Reports/documents | platform support | org reports | station reports | operational station reports | finance reports/docs | limited/no |
| Hardware/POS | support inspect | org/station view | station configure if delegated | operational use | finance view for POS | operational POS/fuel sale use |

## Data Model And Table Map

The clean tenant app should reuse or extend the existing backend tables. Do not create parallel duplicate models when an existing model can be normalized.

Core setup tables:

- `brands`: brand catalog such as PSO, Shell, Total, GO, Attock, Custom
- `organizations`: customer company/tenant identity, legal name, brand, contact, active state
- `stations`: station identity, organization link, legal name, brand override, address/contact
- `invoice_profiles`: station invoice/legal/tax profile and document identity
- `fuel_types`: reusable fuel type master data
- `tanks`: station tanks, fuel type, capacity, current volume, low stock threshold
- `dispensers`: station dispensers, generated numbering
- `nozzles`: dispenser nozzles, tank/fuel mapping, meter reading, segment start
- `station_shift_templates`: setup templates for daily/hourly/custom shifts

Runtime operation tables:

- `shifts`: actual open/closed daily shift records
- `fuel_sales`: fuel sale records
- `meter_readings`: preferred future runtime table for opening/closing meter-based sales if needed
- `meter_segments`: preferred future runtime table for meter reset/replacement segments if needed
- `meter_adjustments`: preferred model for elevated meter correction if existing nozzle adjustment events are not enough
- `shift_cash`: preferred future table for shift-level cash expectation and closing
- `cash_submissions`: preferred future table for multiple cash deposits inside one shift
- `tank_dips`: physical tank dip measurements
- `purchases`: fuel purchase records
- `expenses`: station expense records

People and access tables:

- `users`: login accounts, role, organization/station scope, active state
- `roles`: role catalog and role permission defaults
- `employee_profiles`: staff records that may or may not have login access
- `attendance`: check-in/check-out and manual attendance records
- `payroll_runs`: monthly payroll batch header
- `payroll_lines`: payroll line details
- `salary_adjustments`: bonuses, loans, deductions

Finance and master data tables:

- `customers`: customer/credit-party records
- `suppliers`: supplier records
- `customer_ledger`: preferred ledger identity if existing ledger implementation needs expansion
- `supplier_ledger`: preferred ledger identity if existing ledger implementation needs expansion
- `customer_payments`: customer payment records
- `supplier_payments`: supplier payment records
- `fuel_prices`: preferred future table for purchase/sale price history if current pricing is not enough

Module and SaaS tables:

- `organization_modules`: enabled/disabled modules at organization level
- `station_modules`: enabled/disabled modules at station level
- `saas_plans` or existing subscription plan table: platform subscription plans
- organization subscription table/record: active plan, status, billing/free-trial details

Tanker/POS/hardware tables:

- `tankers`: tanker vehicle records
- `tanker_compartments`: preferred future compartments if current tanker model needs expansion
- `tanker_trips`: tanker trip records
- tanker deliveries and tanker expenses tables/routes: existing trip child records
- `pos_products`: non-fuel product master data
- `pos_sales`: POS sale records
- `hardware_devices`: configured hardware devices
- hardware event table/routes: dispenser/tank probe/simulator events

Documents, notifications, and reporting tables:

- `financial_documents`: generated/previewed financial documents
- `document_templates`: station document templates
- `report_definitions`: saved/report configuration definitions if needed
- `report_exports`: export jobs and downloadable outputs
- `notifications`: in-app notification records
- notification preferences/deliveries/logs: reuse existing notification delivery tracking
- `online_api_hooks`: online integration hooks
- `attachments`: preferred future generic file attachment table if needed
- `audit_logs`: audit trail

## Backend API Contract Map

The rebuild should use the current API inventory as the starting contract.

Required first-slice APIs:

- `POST /auth/login`
- `GET /auth/me`
- `GET /organizations/`
- `GET /stations/`
- `GET /roles/`
- `GET /roles/permission-catalog`
- `GET /users/`
- `POST /users/`
- `PUT /users/{user_id}`
- `DELETE /users/{user_id}`

Required setup APIs:

- `GET/POST/PUT/DELETE /stations/`
- `GET/POST/PUT/DELETE /fuel-types/`
- `GET/POST/PUT/DELETE /tanks/`
- `GET/POST/PUT/DELETE /dispensers/`
- `GET/POST/PUT/DELETE /nozzles/`
- `POST /nozzles/{nozzle_id}/adjust-meter`
- `GET/PUT /invoice-profiles/{station_id}`
- `GET/PUT /organization-modules/{organization_id}`
- `GET/PUT /station-modules/{station_id}`

Required operations APIs:

- `POST /shifts/`
- `POST /shifts/{shift_id}/close`
- `GET /shifts/`
- `POST /fuel-sales/`
- `GET /fuel-sales/`
- `POST /fuel-sales/{sale_id}/reverse`
- `GET/POST /attendance/`
- `POST /attendance/check-in`
- `POST /attendance/{attendance_id}/check-out`

Required finance APIs:

- `GET/POST/PUT/DELETE /customers/`
- `GET/POST/PUT/DELETE /suppliers/`
- `GET/POST /purchases/`
- `GET/POST/PUT/DELETE /expenses/`
- `POST /customer-payments/`
- `POST /supplier-payments/`
- `GET /ledger/customer/{customer_id}`
- `GET /ledger/supplier/{supplier_id}`
- `GET /reports/*`
- `POST /report-exports/`

Required staff/payroll APIs:

- `GET/POST /employee-profiles/`
- `PUT/DELETE /employee-profiles/{employee_profile_id}`
- `GET/POST /payroll/runs`
- `GET /payroll/runs/{payroll_run_id}/lines`
- `POST /payroll/runs/{payroll_run_id}/finalize`

Optional module APIs:

- `GET/POST/PUT/DELETE /tankers/`
- `POST/GET /tankers/trips`
- `POST /tankers/trips/{trip_id}/deliveries`
- `POST /tankers/trips/{trip_id}/expenses`
- `POST /tankers/trips/{trip_id}/complete`
- `GET/POST/PUT/DELETE /pos-products/`
- `GET/POST /pos-sales/`
- `GET/POST/PUT/DELETE /hardware/devices`
- `GET /hardware/vendors`
- `POST /hardware/simulate/dispenser-reading`
- `GET/PUT /notifications/preferences/{event_type}`
- `GET /financial-documents/*`
- `GET/PUT /document-templates/*`

## Proposed Folder Strategy

Preferred safe strategy:

1. keep existing `ppms_flutter` as reference for now
2. create a new clean app folder, for example `ppms_tenant_flutter`
3. rebuild the tenant app there
4. move over only the useful API/client pieces
5. when the new tenant app passes Phase 9 slices, replace or retire old `ppms_flutter`

Avoid deleting `ppms_flutter` first because it contains working endpoint examples and test wiring.

## Easy Local Test Tenant Setup

Use this helper whenever the local test tenant needs to be prepared again:

```powershell
cd C:\Fuel Management System
.\prepare_phase9_tenant.ps1
```

It prepares the one-station `check` tenant for the clean tenant app:

- organization: `check`
- station: `check`
- HeadOffice login: `check / office123`
- Manager login: `check_manager / manager123`
- Accountant login: `check_accountant / accountant123`
- Operator login: `check_operator / operator123`
- basic tanks, dispensers, and nozzles

It intentionally does not create `StationAdmin` because this is a one-station tenant.

## Tenant App Screen Order

Rebuild in this order:

1. Login and session shell
2. Tenant landing page
3. HeadOffice admin: users and station setup
4. Manager shift console
5. Operator fuel sale flow
6. Manager cash review/submission
7. Expenses and purchases
8. Parties and ledgers
9. Accountant finance and reports
10. Attendance and payroll
11. Tankers, if enabled
12. Documents and notifications
13. Settings and diagnostics

## Screen Rules

Login:

- asks for username and password
- shows clear backend/API connection errors
- stores session safely
- never assumes platform access for tenant users

Shell:

- shows role, organization, and station context
- has simple scrollable navigation
- hides screens the current role cannot use
- hides disabled modules
- has logout and refresh

HeadOffice admin:

- single-station tenant does not create `StationAdmin`
- multi-station tenant can create station admins
- creates Manager, Accountant, and Operator users
- asks only useful worker fields first
- links staff profile details in a clear second section or wizard step

Station setup:

- single-station setup uses org/station defaults
- tank, dispenser, and nozzle rows support edit and delete
- codes are generated unless a support/manual override is needed
- station/location fields are kept only if used operationally

Sales:

- uses assigned station and nozzle data
- meter sale is based on opening/closing meter
- blocks invalid meter input with clear messages
- does not show other org/station data

Shifts:

- manager opens and closes shifts
- operator works inside assigned shift
- cash expectation is clear
- no station leakage

Finance:

- accountant sees scoped purchases, expenses, parties, payments, ledgers, payroll, and reports
- manager sees only operational finance actions
- operator does not see accounting controls

## Backend Gap Policy

If a clean screen needs backend changes, update the backend intentionally instead of forcing the UI to work around bad contracts.

Examples:

- add a single endpoint for tenant setup summary if many screens duplicate calls
- add scoped worker creation endpoint if user + staff profile should be one action
- add clearer station default endpoint for single-station tenants
- add role-scoped permissions if current permission strings are too broad

Every backend change must have at least targeted tests before commit.

## Phase 9 Acceptance For Rebuild

The rebuild is acceptable when:

- `check` can log in as HeadOffice
- `check` can create Manager, Accountant, and Operator users
- single-station tenant does not require StationAdmin
- Manager can run shift flow
- Operator can enter a fuel sale
- Accountant can inspect finance/report flows
- no tenant role sees another organization
- no screen renders corrupted content
- all visible buttons either work or show useful validation
