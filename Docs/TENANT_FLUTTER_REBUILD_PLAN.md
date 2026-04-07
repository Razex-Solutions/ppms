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

## Proposed Folder Strategy

Preferred safe strategy:

1. keep existing `ppms_flutter` as reference for now
2. create a new clean app folder, for example `ppms_tenant_flutter`
3. rebuild the tenant app there
4. move over only the useful API/client pieces
5. when the new tenant app passes Phase 9 slices, replace or retire old `ppms_flutter`

Avoid deleting `ppms_flutter` first because it contains working endpoint examples and test wiring.

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

