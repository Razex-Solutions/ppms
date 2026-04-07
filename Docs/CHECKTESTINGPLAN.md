# PPMS Phase 9 Check Testing Plan

## Purpose

This file is the manual acceptance plan for `Phase 9 - Local Stabilization and Acceptance`.

Use it when the app has many visible issues and we need to find, report, fix, and retest them in a controlled order.

The goal is not to fix everything randomly.

The goal is:

- test one flow at a time
- report the exact problem
- fix the exact problem
- retest the same flow
- move to the next flow only after the current one is acceptable

## Phase 9 Cleanup Direction

During this testing phase, remove or hide UI that does nothing useful.

Examples:

- dashboard cards with fake, empty, or non-actionable numbers
- buttons that open no useful workflow
- placeholder modules that are visible but not ready
- duplicate menu entries that confuse the role flow
- form fields that users do not understand and the system does not use

Do not keep a field or widget only because it exists in the database.

If a field is needed for operations, reporting, invoices, support, or audit, keep it and make it understandable.

If a field is not needed yet, hide it or move it behind an advanced/support-only path.

Current Phase 9 dashboard decision:

- Flutter dashboard metric cards and charts are intentionally removed/simplified for now
- dashboard pages should act only as testing landing pages
- real acceptance should happen inside action workspaces such as Sales, Shifts, Finance, Setup, Reports, Tankers, and Admin
- rebuild richer dashboards only after action flows and access scopes are proven correct

## Critical Access Rule

`MasterAdmin` is the true platform admin.

Tenant roles must not see data outside their organization unless the role is explicitly platform-scoped.

This means:

- `masteradmin` may inspect every organization and station
- `headoffice` is the tenant organization admin and may inspect only the assigned organization
- `stationadmin` is station-scoped and should normally exist only for multi-station organizations
- if the organization has one station, `headoffice` and `stationadmin` responsibilities should be merged into `headoffice`
- `manager`, `operator`, and `accountant` may inspect only their assigned station or permitted organization scope
- the old generic `admin` account/role has been removed from the active seed and should not appear in testing
- no tenant user should see stations, users, sales, purchases, reports, or dashboard totals from another organization
- if a user has no valid scope, the app should show a clear no-access state instead of leaking data

## Working Rule

For each test step:

1. user performs the step in the running app
2. user reports what happened in chat
3. Codex inspects the relevant code and logs
4. Codex fixes the issue
5. Codex runs targeted tests
6. user repeats the same step
7. if it passes, mark the step accepted and continue

## How To Report Issues In Chat

When something fails, send:

```text
Step:
Role:
Screen:
Action:
Expected:
Actual:
Error text:
Screenshot if useful:
```

If there is no visible error text, describe what changed on screen after the click or save.

## Before Starting

Restart the full local testing stack after code changes:

```powershell
cd C:\Fuel Management System
.\restart_local_dev.ps1
```

This restarts the backend, support console, and Flutter Windows app. It also opens support console and Flutter in separate PowerShell windows.

If you only need the backend:

```powershell
cd C:\Fuel Management System
.\restart_local_dev.ps1 -SkipSupportConsole -SkipFlutter
```

Confirm backend health URL works:

```text
http://127.0.0.1:8012/health
```

Manual Flutter command, only if the restart helper is not used:

```powershell
cd C:\Fuel Management System\ppms_flutter
flutter run -d windows --dart-define=PPMS_API_BASE_URL=http://127.0.0.1:8012
```

Manual support console command, only if the restart helper is not used:

```powershell
cd C:\Fuel Management System\support_console
npm.cmd run dev
```

## Test Accounts

Use these accounts unless we intentionally create new users during testing:

```text
masteradmin / master123
headoffice / office123
stationadmin / station123
manager / manager123
operator / operator123
accountant / accountant123
```

## Step 1 - Login And Shell Stability

Role: `masteradmin`

Actions:

- log in
- confirm the app reaches the platform dashboard
- click every visible sidebar item once
- confirm no crash, blank page, or endless loader appears
- log out

Repeat for:

- `headoffice`
- `stationadmin`
- `manager`
- `operator`
- `accountant`

Acceptance:

- every seeded user can log in
- every user can log out
- each role sees a role-appropriate dashboard
- hidden modules do not appear as broken menu items
- no page crashes just by opening it

## Step 2 - Master Admin Platform Flow

Role: `masteradmin`

Actions:

- open platform dashboard
- open organization list or organization search
- open the default organization
- review organization details
- review station details
- review users and roles
- review modules and subscription controls
- try a safe edit such as support note or non-critical text field if available

Acceptance:

- Master Admin can inspect tenant data
- support-only controls are visible to Master Admin
- tenant operation screens are not mixed with platform support workflow in a confusing way
- any edit either saves successfully or shows a clear validation message

## Step 3 - Organization And Station Scope Leakage Check

Purpose:

- catch the issue where a tenant admin can see stations or records from another organization
- verify platform-only access belongs to `masteradmin`

Role sequence:

```text
headoffice
stationadmin
manager
operator
accountant
```

Actions for each role:

- open dashboard
- note every station name shown
- open station selector if one exists
- open users/staff lists if visible
- open sales, purchases, expenses, reports, and dashboards if visible
- check whether records from another organization appear
- check whether totals include data from another organization
- try direct navigation to any visible station detail from another organization if the UI exposes it

Acceptance:

- only `masteradmin` can see all organizations
- tenant users cannot see another organization's stations
- tenant users cannot see another organization's users or staff
- tenant users cannot see another organization's sales, purchases, expenses, tankers, payroll, reports, or dashboard totals
- unauthorized data is blocked both in UI and API behavior
- any selector is scoped to the current user's organization/station permissions

## Step 4 - Dashboard Usefulness Cleanup

Purpose:

- confirm dashboards remain simplified during Phase 9
- prevent fake or dead cards from making the app feel broken

Role sequence:

```text
masteradmin
headoffice
stationadmin
manager
operator
accountant
```

Actions for each role:

- open dashboard
- confirm it is only a testing landing page
- confirm it shows role, scope, organization, and station context where useful
- confirm it does not show fake metrics, dead charts, or misleading totals
- confirm it points testers to real action workspaces
- note role-mismatched instructions such as operator seeing platform support controls

Acceptance:

- dashboard is not used as the source of truth during Phase 9
- no placeholder metric remains visible
- no dashboard card shows cross-organization data to tenant roles
- no disabled module appears as a dashboard card
- testers are directed to real workspaces for action testing

## Step 5 - Setup Form Field Sanity Check

Purpose:

- decide which setup fields should stay, be renamed, be made optional, or be hidden

Role: `headoffice` or `stationadmin`

Actions:

- open organization setup
- open station setup
- open invoice profile setup
- open tank setup
- open dispenser setup
- open nozzle setup
- open fuel type setup

Questions to answer for each field:

- is this field required for real operation?
- does the user understand why this field exists?
- does this field affect reports, invoices, permissions, stock, or support?
- should this be auto-filled from organization or station data?
- should this be optional or advanced-only?
- should this be removed from the main form for now?

Specific checks:

- legal name should allow `same as organization name`, `same as station name`, or `custom`
- invoice legal name should default from organization/station unless explicitly overridden
- tank location should be kept only if it helps identify physical tanks; otherwise make it optional or hide from the main setup flow
- dispenser location should be kept only if it helps identify physical dispensers; otherwise make it optional or hide from the main setup flow
- tank capacity, fuel type, and low-stock threshold are useful and should remain understandable
- dispenser number/code should be auto-generated where possible
- nozzle code should be auto-generated where possible
- nozzle-to-tank and nozzle-to-fuel mapping must remain clear and required

Acceptance:

- no useless setup field blocks progress
- required fields match real business needs
- legal name inheritance is clear
- physical location fields are optional or hidden if not useful
- generated fields do not force manual typing unless there is a custom override

## Step 6 - Tenant Admin Setup Review

Role: `headoffice`

Actions:

- open dashboard
- open setup workspace
- open station setup
- review organization inheritance details
- review invoice profile defaults
- review fuel types
- review tanks
- review dispensers
- review nozzles
- review station modules

Acceptance:

- setup data loads from the fresh DB
- no required setup screen is blank
- station setup does not require duplicate organization entry for the default single-station case
- tank, dispenser, and nozzle mappings are understandable

## Step 7 - Single-Station Scenario

Role: `headoffice`

Actions:

- confirm the default organization behaves like a single-station organization
- review whether `HeadOffice` and `StationAdmin` controls are merged or simplified where expected
- check dashboard cards and menu items
- check whether station-scoped data appears without forcing station selection everywhere

Acceptance:

- single-station flow does not feel like a multi-station setup
- user is not forced into unnecessary station admin duplication
- menus and dashboards are simpler than a multi-station business where possible

## Step 8 - Role Visibility Walkthrough

Role sequence:

```text
headoffice
stationadmin
manager
operator
accountant
```

Actions for each role:

- open dashboard
- list visible menus
- open every visible workspace
- check create/edit buttons
- check read-only areas
- note any module that appears but is unusable

Acceptance:

- role permissions are understandable
- read-only screens do not show dangerous edit actions
- edit-capable roles can reach their expected actions
- off modules leave no visible broken traces

## Step 9 - Shift Flow

Recommended role: `manager`

Actions:

- open shifts workspace
- inspect existing shift state
- open or create a shift if the UI supports it
- confirm opening cash behavior
- confirm shift template or timing display
- close or save only if the flow is safe in the current test data

Acceptance:

- shift screen loads
- opening and closing states are understandable
- cash expectations are visible or clearly handled
- no shift action fails silently

## Step 10 - Meter-Based Fuel Sale

Recommended role: `operator` or `manager`

Actions:

- open sales workspace
- choose a nozzle
- confirm opening meter/current meter display
- enter closing meter higher than opening meter
- confirm quantity is derived from meter movement
- save the sale
- confirm tank stock or sales summary updates

Acceptance:

- user does not manually type fuel quantity as the source of truth
- sale quantity is calculated from meter readings
- invalid closing meter is blocked with a clear message
- successful sale updates summary data

## Step 11 - Cash Submission

Recommended role: `manager`

Actions:

- open shift or cash area
- review expected cash
- submit a cash amount if the UI supports it
- submit a second cash amount if multiple deposits are supported
- review reconciliation or difference

Acceptance:

- cash submission records correctly
- multiple deposits are understandable
- expected, submitted, and difference values make sense
- no approval-heavy flow blocks normal cash recording

## Step 12 - Purchases And Expenses

Recommended role: `manager` or `stationadmin`

Actions:

- open finance or purchases area
- create a small safe purchase if the flow supports test entries
- choose existing supplier or create one in context if available
- choose tank and fuel type
- confirm tank volume update behavior
- create a small safe expense
- confirm expense status and reporting effect

Acceptance:

- purchases can be recorded as operational facts
- expenses can be recorded without unnecessary approval blocks
- supplier reuse works or the gap is clearly recorded
- tank volume and reports remain consistent

## Step 13 - Customers, Suppliers, And Ledgers

Recommended role: `accountant`

Actions:

- open parties workspace
- open customers
- open suppliers
- inspect customer ledger summary
- inspect supplier ledger summary
- record a safe customer payment if supported
- record a safe supplier payment if supported

Acceptance:

- customer and supplier records are reusable
- ledger balances are visible
- payments update balances or show a clear validation message
- accountant can access finance-focused views without unrelated station control clutter

## Step 14 - Payroll And Attendance

Recommended role: `accountant`

Actions:

- open attendance workspace
- inspect staff or attendance state
- open payroll workspace
- inspect payroll runs
- inspect salary adjustments
- generate or preview a payroll run only if the UI clearly supports safe testing

Acceptance:

- payroll page loads
- payroll run data is understandable
- salary adjustment behavior is visible
- accountant has expected payroll access

## Step 15 - Tanker Flow

Recommended role: `manager` or `stationadmin`

Actions:

- open tanker workspace
- inspect tanker summary
- inspect tanker master records
- inspect compartments
- create or review a trip if the UI supports safe testing
- check purchase/load/sale/leftover transfer flow

Acceptance:

- tanker module is visible only when enabled
- tanker trip flow is manager-friendly and summary-based
- compartments and transfers are understandable
- tanker sales stay separate from forecourt meter sales

## Step 16 - Reports, Documents, And Notifications

Recommended roles:

```text
headoffice
accountant
```

Actions:

- open reports workspace
- run daily closing or profit report if available
- check report filters by station/date
- open documents workspace
- generate or inspect a financial document if safe
- open notifications workspace
- inspect preferences, inbox, send logs, retry/process-due actions if present

Acceptance:

- reports load and filter correctly
- documents can be viewed or generated locally
- notifications can be reviewed without real provider credentials
- mock delivery behavior is clear

## Step 17 - Support Console Walkthrough

Use browser support console if running:

```text
http://localhost:3000
```

Role: `masteradmin`

Actions:

- log in
- search/open default organization
- inspect stations
- inspect users/staff
- inspect subscription/package controls
- inspect module toggles
- inspect communication health
- inspect reports/profit support views

Acceptance:

- support console can authenticate through backend
- support console can open tenant details
- support console stays separate from tenant Flutter operations
- support edits are clear and audit-safe where applicable

## Step 18 - Local Freeze Review

Run after all earlier steps are accepted:

```powershell
cd C:\Fuel Management System
venv\Scripts\python.exe -m pytest tests
```

```powershell
cd C:\Fuel Management System\ppms_flutter
flutter analyze
flutter test
```

```powershell
cd C:\Fuel Management System\support_console
npm.cmd run lint
npm.cmd run build
```

Acceptance:

- backend tests pass
- Flutter analyze passes
- Flutter tests pass
- support console lint passes
- support console build passes
- no unresolved manual acceptance blocker remains

## Issue Log

Use this section while working through Phase 9.

```text
Issue ID:
Step:
Role:
Screen:
Problem:
Fix status:
Retest status:
Notes:
```

## Phase 9 Completion Rule

Do not move to cloud deployment until:

- all required test steps are accepted
- all blocker and high-priority issues are fixed
- remaining low-priority issues are documented
- full automated checks pass again
- the fresh local DB path is still clean and understandable
