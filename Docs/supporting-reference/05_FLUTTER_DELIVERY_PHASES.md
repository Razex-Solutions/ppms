# Flutter Delivery Phases

This is the new implementation order.

Build one clean feature packet at a time.

## Phase A - Foundation

Goal:

- create the new Flutter project
- wire backend auth
- load current user and capabilities
- build responsive shell

Included:

- app bootstrap
- environment config
- auth login/logout/refresh
- `/auth/me`
- role and capability store
- module-aware navigation
- compact, medium, expanded layout rules

Done when:

- user can log in
- shell hides inaccessible destinations
- shell works at desktop and mobile breakpoints

## Phase B - Setup Read Foundation

Goal:

- let the app read real tenant setup and station context before editing anything

Included:

- organizations read context
- stations read context
- invoice profile read
- fuel types read
- tanks read
- dispensers read
- nozzles read
- station modules read
- station shift templates read

Done when:

- HeadOffice and StationAdmin can inspect setup safely
- no edit flows are required yet
- setup screens are clear on all breakpoints

## Phase C - Setup Edit Packet

Goal:

- build clean setup management from real schemas

Included:

- station editing
- invoice profile editing
- fuel type CRUD
- tank CRUD
- dispenser CRUD
- nozzle CRUD
- station module editing
- station shift template CRUD

Done when:

- setup works end to end
- permissions and module toggles are enforced
- forms map directly to backend schema fields

## Phase D - Shift And Fuel Sale Packet

Goal:

- build the operational core first

Included:

- shift open/read/close
- shift cash summary
- cash submission
- fuel sale creation
- sale history
- nozzle meter history read

Done when:

- Manager and Operator can run a shift
- meter-based sale flow is clear
- cash flow is understandable

## Phase E - Finance And Parties Packet

Goal:

- build the accounting-facing workflows next

Included:

- customers
- suppliers
- purchases
- expenses
- customer payments
- supplier payments
- ledger summaries
- ledger detail views

Done when:

- Accountant has a coherent finance packet
- reversal states are visible
- no cross-station leakage occurs

## Phase F - HR And Payroll Packet

Goal:

- support people, attendance, and payroll after finance basics

Included:

- employee profiles
- attendance
- salary adjustments
- payroll runs
- payroll lines
- payroll finalize flow

Done when:

- Accountant and eligible admin roles can review and process payroll

## Phase G - Optional Module Packet

Goal:

- add optional domains only after the core is stable

Included:

- tanker module
- POS module
- hardware module
- meter adjustment feature packet

Done when:

- module visibility is exact
- hidden modules leave no visual trace

## Phase H - Reporting And Communication Packet

Goal:

- add read-heavy and export-heavy workflows after source transactions are stable

Included:

- reports
- report exports
- saved report definitions
- document templates
- financial documents
- notifications

Done when:

- read and export flows are reliable
- mobile and desktop layouts both stay usable

## Phase I - Polish And Portability Review

Goal:

- make sure the app is future-proof for Android and iOS

Checklist:

- responsive breakpoints audited
- dialogs and forms work on compact screens
- no desktop-only assumptions remain in feature widgets
- touch targets and spacing are mobile-safe
- navigation works in drawer and rail modes

## Working Rule For Every Phase

For each packet:

1. confirm schemas
2. confirm tables involved
3. confirm permissions
4. confirm modules and feature flags
5. build repositories
6. build state/controllers
7. build responsive UI
8. test desktop first
9. review compact layout before calling the packet complete

## Recommended First Build Sequence

Start here:

1. Phase A
2. Phase B
3. Phase C
4. Phase D
5. Phase E

Reason:

- this creates a usable tenant product path quickly
- it builds the frontend around the real operational backbone
- it reduces later rewrite risk for mobile
