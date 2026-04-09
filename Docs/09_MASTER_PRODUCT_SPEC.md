# Master Product Spec

This document consolidates the finalized product direction into one clean build reference.

Use this as the main product specification.

Use [08_FINALIZED_PRODUCT_DIRECTION_SO_FAR.md](/C:/Fuel%20Management%20System/Docs/08_FINALIZED_PRODUCT_DIRECTION_SO_FAR.md) as the detailed decision log behind it.

## 1. Product Goal

Build one modular fuel and station management app that:

- starts with real forecourt and finance operations
- works on desktop first
- is structured for later Android and iOS reuse
- is driven by backend contracts
- supports role-based access and module toggles
- supports English and Urdu from the foundation

This is not a dashboard-first rebuild.

The first release should feel like a real operations system for stations and organizations.

## 2. Product Principles

- operations first
- modular by design
- responsive from day one
- PostgreSQL-safe backend assumptions
- auditable edits and corrections
- setup by wizard where possible
- role-aware navigation
- no dead menu items for disabled modules
- localization-ready from the start

## 3. Scope Model

The system works across these scope levels:

- platform
- organization
- station
- shift

Core identity rule:

- if an organization has one station only, `HeadOffice = StationAdmin`

## 4. Roles

Priority order for build and UX:

1. `Operator`
2. `Manager`
3. `Accountant`
4. `StationAdmin`
5. `HeadOffice`
6. `MasterAdmin`

Access roles:

- `MasterAdmin`
- `HeadOffice`
- `StationAdmin`
- `Manager`
- `Accountant`
- `Operator`

Staff titles stay separate from access roles.

Examples:

- guard
- cleaner
- helper
- driver
- pump attendant
- custom title

## 5. Module Map

Core first-release modules:

- auth and session
- onboarding and setup
- organizations and stations
- fuel setup
- shifts
- meter-based fuel sales
- tank dips
- supplier receiving
- customers and credit
- suppliers and payments
- expenses
- lubricant inventory and sales
- internal fuel usage
- attendance
- payroll
- tanker operations
- notifications
- reports and exports
- invoice and document generation

Optional or later-detail business modules:

- shop / mart
- restaurant
- service station / workshop
- rented shops / lease units
- ATM / third-party unit
- tyre shop

Module-toggle rule:

- if disabled, the app hides the module's menus, screens, and actions
- historical data and reports remain preserved

## 6. Language Rule

Supported app languages:

- English
- Urdu

Display rule:

- wording can switch to Urdu
- numbers remain English digits in both languages
- reports and invoices also keep numeric values in English digits

Technical rule:

- translations must be planned from the start
- database values and internal codes should remain language-neutral

## 7. Setup And Onboarding

There are three setup layers:

1. `MasterAdmin` organization onboarding
2. station forecourt setup
3. per-module setup wizards

### 7.1 Organization Onboarding

Current-phase `MasterAdmin` handles:

- create/edit organization
- station count
- branding defaults
- module enablement
- first admin assignment
- onboarding progress

Required organization details:

- organization name
- brand
- organization address
- registration number (`KForm`)
- legal name or same-as-org-name choice
- tax number
- GST number
- contact phone
- contact email
- active status
- inherit branding to stations

Code/id behavior:

- organization code is auto-generated
- station code is auto-generated

Brand behavior:

- brand dropdown
- linked brand logo assets managed by backend

### 7.2 Station Forecourt Setup

Station setup is separate from organization onboarding.

The station wizard should:

- ask fuel type count
- ask tank count
- ask dispenser count
- ask nozzle count patterns
- auto-generate rows
- allow editing of names, codes, mappings, and capacities

Important rules:

- petrol and diesel should appear as default fuel types
- live meter values are not part of onboarding
- starting live values are set later by admins
- unnecessary location fields should not be forced

### 7.3 Setup UX Rules

- save wizard steps as draft
- block only affected modules when setup is incomplete
- show who must complete the missing step
- after setup, show checklist plus next-action dashboard

## 8. Role Product Behavior

### 8.1 Operator

`Operator` is self-service only.

Included:

- login
- own profile
- own staff details
- own attendance if enabled
- own payroll summary

Payroll display rule:

- show bonus only if present
- show loans/deductions only if present

### 8.2 Manager

`Manager` is the active shift operator.

Landing:

- lands directly in shift workspace during active shift

Workspace includes:

- shift status
- cash in hand
- pending tasks
- quick actions
- dispenser-grouped nozzle checklist

Default pending tasks:

- missing dips
- pending receiving entries
- credit follow-ups
- expense entries
- cash submissions
- shift-close readiness issues
- admin-created notifications

Manager capabilities:

- each shift belongs to one manager only
- next manager takes over through shift handover, not parallel shift ownership
- operators work under the current manager shift
- close prepared shifts
- enter closing nozzle readings
- review calculated sales before final close
- record tank dips
- receive fuel from supplier
- receive fuel from own tanker
- recover credit payments
- trigger over-limit visibility/notification when customer exposure crosses the admin-set credit limit
- record expenses
- record lubricant sales
- record internal fuel usage
- submit cash during shift in multiple intervals

Important manager rules:

- shifts are pre-generated from templates
- only one manager shift can be open at a station at a time
- the next manager cannot start until the previous manager closes and hands over
- opening cash carries forward from previous shift
- opening nozzle readings carry forward from previous shift
- dip/close context carries forward from the previous completed shift where relevant
- fuel sales are meter-based and per nozzle
- final shift close is blocked by:
  - missing nozzle readings
  - missing required dips
  - unresolved abnormal meter entries
  - required cash summary mismatch

Cash rules:

- cash can be submitted multiple times during a shift
- remaining closing cash becomes next shift opening cash
- shift cash accountability is:
  - opening cash
  - plus fuel cash sales
  - plus lubricant and other cash sales
  - plus customer recoveries
  - minus cash expenses
  - checked against submissions plus closing cash left in hand

Credit limit rule:

- manager does not formally increase customer credit limit
- credit limit remains an admin-controlled setting
- when customer exposure crosses that limit, admins should be notified

Meter rules:

- readings are handled one nozzle at a time
- lower closing reading is blocked unless a recorded admin adjustment explains it
- rate changes during active shift require mandatory boundary readings for affected fuel-type nozzles only

Dip rules:

- dip is entered in `mm`
- volume is calculated from the selected tank's calibration chart
- if multiple dip values are entered, the final confirmed value is used

### 8.3 Accountant

`Accountant` lands in a finance workspace.

Included:

- customer ledger and payments
- supplier ledger and payments
- expense review
- payroll list and payroll runs
- payroll finalization
- finance alerts
- reports and exports

Important finance rules:

- customer and supplier payments can be edited/removed by authorized finance/admin roles
- all edits/removals must be auditable
- payroll is manual by default
- attendance affects payroll only if explicit attendance-payroll linkage is enabled later

### 8.4 StationAdmin

`StationAdmin` lands on a reports/dashboard-first station control view.

Included:

- everything `Manager` can do
- everything `Accountant` can do
- staff creation and management
- access role assignment
- custom staff title assignment
- payroll basics
- module toggles
- forecourt editing after onboarding
- branding and invoice settings
- meter reversal and adjustment
- tanker module operation

Important admin rules:

- forecourt changes use safe mapping validation
- deactivation is preferred over destructive removal
- branding and invoice controls live inside settings
- meter adjustments must record old value, new value, nozzle, reason, and audit event

### 8.5 HeadOffice

`HeadOffice` lands on an organization dashboard.

Included:

- station summaries
- alerts
- module status
- cross-station staff oversight
- combined reports
- single-station drill-down reports
- create/edit stations
- assign `StationAdmin`
- manage station module toggles

Important organization rule:

- `HeadOffice` can enter a station context and do anything a `StationAdmin` can do there

### 8.6 MasterAdmin

Current-phase `MasterAdmin` is onboarding-first.

Included now:

- create/edit organization
- control onboarding progress
- choose enabled modules
- assign first admin
- quick access into tenants

Planned later:

- SaaS packages
- subscriptions
- billing dashboards
- active subscription graphs

Support direction:

- deep support and corrective access remains part of the long-term plan
- support actions must be logged and auditable
- separate support console may exist later

## 9. Core Operational Flows

### 9.1 Shift Flow

- shifts are template-driven
- manager does not create shifts manually
- shift sales auto-post on successful close
- sales rate comes from the active station fuel price at the relevant time

### 9.2 Fuel Sales

- meter-difference based
- calculated per nozzle
- fuel rates support mid-shift rate splits
- abnormal meter conditions move to admin correction path

### 9.3 Customer Credit

- manager can recover credit payments
- manager can give customer credit operationally, but not by free amount-only entry
- system notifies admins
- accountability comes through alerts and variance reporting, not default approvals
- manager credit-given entry must be linked to the actual forecourt sale context:
  - selected nozzle
  - resulting fuel type / tank mapping
  - quantity in liters
  - active station rate
- this credit entry is the payment type for a real sale, not a separate stock adjustment
- stock deduction and nozzle movement must stay on the normal nozzle-sale path

### 9.4 Receiving

Supplier receiving requires:

- supplier
- fuel type
- target tank
- quantity
- dip before
- dip after
- reference / GRN
- optional notes

Own-tanker receiving follows the same base pattern but stays distinct in source and totals.

### 9.5 Lubricants

- simple inventory items
- fixed selling price
- stock deduction per sale
- totals kept separate from fuel totals

### 9.6 Internal Fuel Usage

Internal usage records:

- vehicle or person
- fuel type
- quantity
- nozzle
- reason

Stock decreases accordingly, but reporting stays separate from normal sales.

## 10. Tanker Product Model

Tanker operations are important in the first detailed plan.

Data-scope rule:

- tanker operations are organization-owned
- station linkage exists where relevant

Master data:

- tanker vehicle
- registration
- compartment structure
- capacity
- status
- driver pool links

Driver rule:

- drivers are a shared pool
- assignment is for record and accountability, not permanent binding

Trip model:

- one tanker trip can hold multiple compartment lines
- each compartment line has its own fuel type, purchase source, load, remaining balance, and purchase rate
- one tanker trip can have many delivery stops

Delivery model:

- each delivery records customer/pump, fuel type, quantity, sale rate, amount, paid amount, and outstanding
- tanker customer can be the same customer master as normal customers
- tanker ledger/category remains separate from normal station credit when needed

Own-station leftover rule:

- leftover fuel can be dumped to own station
- recorded as explicit tanker-to-station transfer
- valued at original purchase price

Trip expenses:

- expense type
- amount
- optional note
- optional attachment

Profitability:

- trip revenue
- purchase cost
- trip expenses
- net profit

Trip status flow:

- `draft`
- `active / in_transit`
- `partially_settled`
- `settled / closed`

Trip closure rule:

- trip stays open until all fuel is sold, dumped to own station, or otherwise settled

## 11. Notifications

First release:

- in-app notifications

Provider-ready later:

- WhatsApp Evolution API
- Firebase

Routing rule:

- notifications are role-and-event based

Future external messaging:

- customer ledger updates
- invoice sending
- tanker challan/invoice sending

## 12. Reports And Exports

First report families:

- operational reports
- finance summaries
- staff/payroll summaries
- exception/variance reports

Standard filters:

- date range
- station
- fuel type
- staff/user
- status where relevant

First exception types:

- cash variance
- dip variance
- abnormal meter events
- credit limit breaches
- unusual edits/removals

Export formats:

- PDF
- Excel / CSV

## 13. Document And Invoice Direction

First-release document needs:

- invoice profile
- station-level invoice settings
- printable sale invoice
- printable tanker invoice/challan

Future channel direction:

- document sending through WhatsApp

## 14. Audit And Correction Rules

The system must preserve traceability for:

- payment edits
- payment removals
- expense edits/removals
- meter adjustments
- support/admin corrections
- module enable/disable changes

This product favors accountability, auditability, and exception visibility.

Optional approval flows may exist later, but approvals are not the base operational model.

## 15. Deferred Or Later-Detailed Areas

These remain intentionally lighter for now:

- shop / mart detailed design
- restaurant detailed design
- workshop detailed design
- rented unit / lease detailed design
- ATM / third-party unit detailed design
- tyre shop detailed design
- full SaaS subscription center
- separate support console implementation

## 16. Build Interpretation

When implementing this product:

- start from backend contracts
- enforce role and module visibility centrally
- keep Flutter layouts responsive
- design for desktop first without hardcoding desktop-only UX
- prefer additive modules over one giant app surface
- do not build large generic dashboards before operational flows are working
