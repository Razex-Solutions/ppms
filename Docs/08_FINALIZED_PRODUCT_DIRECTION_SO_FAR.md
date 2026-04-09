# Finalized Product Direction So Far

This file records what has been discussed and finalized so far.

It is intentionally focused on current agreed direction.

Anything not yet finalized should not be treated as locked.

## 1. Core Product Direction

The new app should be:

- operations-first
- modular
- backend-driven
- built from real backend contracts
- responsive from day one
- reusable later for Windows, Android, and iOS without major rework

The app should not be rebuilt admin-first.

The first priority is the real pump workflow, not dashboards or platform-heavy screens.

## 2. Role Priority Order

The app should be designed in this user priority order:

1. `Operator`
2. `Manager`
3. `Accountant`
4. `StationAdmin`
5. `HeadOffice`
6. `MasterAdmin`

This means the product should feel like a real station operations app first.

## 3. Finalized Role Definitions

### Operator

`Operator` is self-service only.

Current finalized scope:

- login
- own profile
- own staff details
- own payroll details
- own attendance if attendance is enabled

`Operator` should not receive broader station controls in the first plan.

### Manager

`Manager` is the main shift and station operations role.

Current finalized scope:

- see shift summary on login
- each shift belongs to one manager only
- there is no single manager handling all station shifts together
- each next shift is handed over to the next manager
- operators work under the current manager shift
- receive opening cash automatically carried from previous shift
- receive opening nozzle readings automatically carried from previous shift
- receive dip context carried from the previous completed shift where relevant
- close shift, not create shift
- enter closing nozzle readings for all nozzles
- fuel sales should be calculated from meter differences
- see fuel rates used for sales
- record tank dips
- see recent dip history
- receive fuel from supplier
- record dip before and dip after receiving fuel
- receive fuel from own tanker
- transfer tanker fuel into station tanks
- sell lubricant like a fixed-price inventory item
- view customer credit list
- recover customer money
- increase customer credit directly
- system sends notification to higher admin when manager increases credit
- record station expenses
- record shift-worker expenses such as food
- record own/internal fuel usage such as boss or organization vehicle fuel
- mark own attendance if attendance is enabled

Manager should also see operational totals:

- fuel sales totals
- lubricant sales totals
- receiving totals
- expense totals
- combined totals
- separated totals by category

### Accountant

`Accountant` is the full station finance role.

Current finalized scope:

- customer payments
- supplier payments
- customer ledger
- supplier ledger
- expense review
- payroll runs
- salary adjustments
- reports
- document generation
- finance-related notifications and follow-up

### StationAdmin

`StationAdmin` is the full station control role.

Current finalized scope:

- everything `Manager` can do
- everything `Accountant` can do
- reverse or adjust nozzle meter safely
- manage station setup
- manage fuel types
- manage tanks
- manage dispensers
- manage nozzles
- manage users and staff
- create or assign login access roles
- create custom staff titles such as guard, cleaner, helper, driver, or other
- use custom staff titles in dropdowns while creating staff profiles
- manage module toggles
- update branding and invoice profile
- manage station-level tanker operations
- manage wholesale tanker selling to other pumps
- keep wholesale and tanker ledgers separate where needed
- manage tanker leftover behavior and transfer behavior
- configure which station modules/features are active so menus update accordingly

Important finalized rule:

- approval/review should be optional
- approval should be enabled or disabled by `MasterAdmin` during onboarding
- approval is an add-on control, not a forced default workflow

### HeadOffice

`HeadOffice` is the full organization owner across stations.

Current finalized scope:

- everything `StationAdmin` can do
- control all stations inside the organization
- see combined organization reports
- see single-station reports
- act as full organization owner over all stations

Important finalized rule:

- if organization has only one station, then:
  - `HeadOffice = StationAdmin`
  - no separate `StationAdmin` is needed

### MasterAdmin

`MasterAdmin` is the platform controller and support super-admin.

Current finalized scope:

- create organization
- create first `HeadOffice`
- choose modules during onboarding
- enable or disable approval system during onboarding
- manage package and subscription details
- manage all SaaS/platform details
- access any organization
- access any station
- access any user, role, staff, settings, and data path inside that tenant
- edit, create, update, enable, disable, and fix records when support is needed
- act as platform support when lower roles do not understand what went wrong

Important expected rule:

- `MasterAdmin` edits should remain auditable

## 4. Access Roles Vs Staff Titles

This is finalized as a design direction.

We should treat these as two different things:

### Access roles

- `MasterAdmin`
- `HeadOffice`
- `StationAdmin`
- `Manager`
- `Accountant`
- `Operator`

### Staff titles / employee roles

Examples:

- guard
- cleaner
- helper
- driver
- pump attendant
- custom title

This separation is important so permissions do not get mixed with HR labels.

## 5. Module Direction

The product should be modular.

Modules must be attachable and detachable.

When a module is disabled:

- no menu item
- no screen
- no dashboard block
- no quick action
- no broken placeholder
- no confusing empty workflow

### Core operational module family

These are the core business areas discussed so far:

- fuel setup
- shifts
- fuel sales
- tank dips
- supplier receiving
- own tanker receiving and transfer
- lubricant sales
- customers and credit
- suppliers and purchases
- expenses
- internal fuel usage
- payroll and attendance
- reports and documents

### Optional business module family

These should exist in modular form and be easy to enable or disable:

- shop / mart
- restaurant
- service station / workshop
- rented shops / lease units
- ATM / third-party unit
- tyre shop

These are wanted in the long-term architecture, but they will be built one by one later.

## 6. Attendance Rule

Attendance is optional.

Current finalized rule:

- attendance can be enabled or disabled
- if enabled, users like `Operator` and `Manager` can use it
- if disabled, their account should still work normally
- attendance should not break the account if the module is off

## 7. Setup Direction

Current finalized setup direction:

- setup should be question-based
- setup should follow a wizard-style flow
- forms should only appear where necessary
- onboarding and station setup are two different wizards
- each enabled optional module should have its own separate setup wizard

This is preferred over large raw CRUD forms.

### 7A. MasterAdmin Organization Onboarding Wizard

This is the first wizard.

Main entry:

- `MasterAdmin` logs in
- chooses:
  - create organization
  - edit organization

If creating organization, the wizard should ask:

Required:

- organization name
- brand
- number of stations
- organization address
- registration number (`KForm`)
- legal name choice
- tax number
- GST number
- contact phone
- contact email

Optional:

- custom legal name if it is different from organization name

Default behavior:

- active = yes
- inherit branding to stations = yes

ID/code behavior:

- organization code should be auto-generated
- it should use organization initials plus brand context
- users should not need to type the organization code manually

Brand behavior:

- brand should be chosen from a dropdown
- common brand names should be available in the dropdown
- when a brand is selected, the linked logo should be attached automatically
- brand logo assets should be stored locally in the backend or backend-managed asset path

Current preferred onboarding order:

1. organization details
2. station count
3. station details
4. fuel types
5. tank count and tank setup
6. dispenser count and dispenser setup
7. nozzle count and nozzle mapping
8. fuel sale rates
9. optional modules
10. staff and admin creation

This setup flow belongs mainly to `MasterAdmin` onboarding first.

Important clarification:

- `fuel tanks` are part of the forecourt/station setup wizard
- `tanker vehicles` are a separate optional module
- if tanker module is enabled, tanker setup should be handled in its own module wizard, not mixed into the basic forecourt wizard

Single-station rule during onboarding:

- if station count = 1
  - `HeadOffice = StationAdmin`
  - organization details should auto-transfer to the station by default
  - station code should be auto-generated using organization context plus a counter or station suffix

Multi-station rule during onboarding:

- if station count > 1
  - stations should be handled as separate station records
  - each station can later have its own station admin path

Responsibility after onboarding:

- for single-station organizations:
  - `HeadOffice` completes the station forecourt setup wizard

- for multi-station organizations:
  - `StationAdmin` completes the station forecourt setup wizard for the assigned station

### 7B. Station Forecourt Setup Wizard

This is a separate wizard from organization onboarding.

Purpose:

- define the forecourt and pump structure
- auto-generate normal rows
- allow editing where needed

#### Fuel types

Question pattern:

- ask how many fuel types are used

Default behavior:

- petrol and diesel should appear as default/common fuel types
- additional fuel types such as hi-octane, adblue, or custom can be added
- default entries should still be editable

#### Tanks

Question pattern:

- ask how many fuel tanks are there

Behavior:

- tank rows should be auto-generated first
- each tank should then be assigned:
  - fuel type
  - capacity

Not needed in onboarding/station setup wizard:

- current tank fuel volume
- unnecessary location text fields by default

Important rule:

- current load in the tank should not be required during onboarding
- starting fuel values should be handled later by admin when the station goes live

#### Dispensers

Question pattern:

- ask how many dispensers are there

Behavior:

- dispenser rows should be auto-generated first

#### Nozzle counts

Question pattern:

- ask if all dispensers have the same number of nozzles

If yes:

- ask one nozzle count
- apply it to all dispensers

If no:

- ask nozzle count for each dispenser separately

#### Fuel mapping for nozzles

Question pattern:

- ask if all nozzles on a dispenser use the same fuel type

If yes:

- choose one fuel type
- apply it to all nozzles on that dispenser

If no:

- ask fuel type for each nozzle separately

#### Tank mapping for nozzles

Question pattern:

- after fuel mapping, ask if the same tank should be applied where possible

Behavior:

- only tanks matching the selected fuel type should be shown
- if same tank is selected, it should apply automatically to all matching nozzles
- otherwise allow nozzle-by-nozzle tank selection

#### Codes and naming

Behavior:

- tank, dispenser, and nozzle codes should be auto-generated
- generated codes should use station or organization context in a useful way
- users should not need to type normal operational codes manually

Editing rule:

- auto-generated rows should be editable after generation

Editable inside the station setup wizard:

- names
- codes
- mapping
- capacities where relevant

#### Meter readings

Important rule:

- live meter readings should not be part of onboarding
- onboarding should not try to fix live nozzle readings
- admin can set starting values later when going live for the first time

#### Locations

Important rule:

- location fields for tanks, dispensers, and nozzles are unnecessary by default
- do not force them in the wizard unless later explicitly needed

### 7C. Separate Module Setup Wizards

This is finalized.

Every enabled optional module should have its own separate wizard or setup flow.

Examples:

- tanker module setup wizard
- shop / mart setup wizard
- restaurant setup wizard
- service workshop setup wizard
- rented units setup wizard
- ATM / third-party unit setup wizard
- tyre shop setup wizard

### 7D. Post-Setup Landing Direction

After station forecourt setup is completed, the next experience should support:

- a station admin checklist
- a dashboard with next actions

This should guide the station side into the next unfinished work instead of dropping them into a generic empty home screen.

### 7E. Setup Save Behavior

Current finalized rule:

- station setup should save step by step as draft
- users should not lose the entire wizard if they stop part way through

### 7F. Incomplete Setup Behavior

Current finalized rule:

- block only the affected modules
- do not block the whole app if unrelated parts are valid

Expected UX:

- when a module is blocked because setup is incomplete, the app should show a clear message
- the message should explain which setup step is incomplete
- the message should indicate whether the missing step is expected from the current user or from `MasterAdmin` or another higher role where relevant

After onboarding:

- `HeadOffice`
- and where relevant `StationAdmin`

can continue editing inside their own scope.

## 8. Meter Adjustment Direction

This is finalized as an included controlled feature.

Current agreed direction:

- `StationAdmin` should be able to reverse or adjust nozzle meter safely
- meter adjustment should not break later calculations
- this should stay controlled and auditable
- this should be module/feature-flag aware

## 9. Notifications, Integrations, And Deployment Direction

This is now also part of the agreed direction.

### Notifications

Notifications are part of the product and should be planned from the start.

They should support:

- in-app notifications
- future WhatsApp notifications
- future Firebase-based notification flows

Current direction:

- keep local-safe and test-safe notification behavior first
- use mock or local-safe delivery behavior while building locally
- add real provider connectivity later after the app is complete and tested

Planned provider direction:

- WhatsApp Evolution API
- Firebase

Important rule:

- provider logic should be abstracted behind backend configuration and service adapters
- frontend should work whether delivery is mock or real

### Database compatibility

The product must remain PostgreSQL-compatible.

Current direction:

- build locally first
- but do not rely on SQLite-only behavior
- schema and migrations should remain PostgreSQL-safe
- future deployment should be able to move cleanly to PostgreSQL-compatible infrastructure

### Deployment direction

Deployment is not the current phase, but the product should stay compatible with the planned deployment target.

Planned hosting direction:

- backend on Amazon EC2 Ubuntu
- database in a PostgreSQL-compatible deployment path

Important rule:

- everything should be completed and stabilized locally first
- deployment happens only after local work is done and tested properly
- do not optimize current work around cloud deployment before local completion

## 10. Summary Of What Is Locked

These are currently locked enough to plan against:

- role priority order
- role definitions
- single-station `HeadOffice = StationAdmin` rule
- optional attendance behavior
- modular app direction
- optional business units direction
- wizard-based setup direction
- separate onboarding wizard direction
- separate station setup wizard direction
- separate per-module wizard direction
- manager-led station operations direction
- controlled meter adjustment direction
- notification and provider direction
- PostgreSQL compatibility rule
- local-first then EC2 deployment direction

## 11. Things To Define Next

These still need deeper question-by-question definition later:

- detailed `HeadOffice` first screen and workflow
- exact `MasterAdmin` onboarding UX
- exact fuel setup wizard questions
- exact shift lifecycle rules
- exact fuel receiving workflow
- exact customer credit and recovery workflow
- exact supplier receiving and purchase flow
- exact lubricant and POS behavior
- exact tanker wholesale workflow
- exact reporting views by role
- exact shop / restaurant / workshop / leased unit behavior

## 12. Build Path We Will Follow

For now, the intended product path remains:

1. `Operator`
2. `Manager`
3. `Accountant`
4. `StationAdmin`
5. `HeadOffice`
6. `MasterAdmin`

But the actual coding foundation should still begin with:

- auth
- capability loading
- module visibility
- responsive shell

Then feature packets should be built in the agreed role-aware order.

## 13. Newly Locked Wizard Decisions (Latest)

These are now finalized based on the latest answers:

### 13A. Shift Start Model

Chosen option: `Option A`

Finalized behavior:

- shifts are pre-generated from station shift templates
- manager does not manually create shifts
- manager lands on the current prepared shift and operates it
- open/close flow should follow prepared shift boundaries
- only one manager shift can be open at a station at a time
- next manager can only start after previous manager closes and hands over the shift
- handover carries forward:
  - closing cash left in hand
  - final nozzle/meter readings
  - dip/close context needed for the next manager

### 13B. Sales Posting From Closing Meters

Chosen option: `Option B`

Finalized behavior:

- manager enters closing meter readings
- system calculates sales from opening vs closing meter difference
- system shows a review/preview first
- manager confirms posting after review

### 13C. Per-Nozzle And Per-Meter Handling Rule

Important finalized requirement:

- meter capture and calculation must be handled one by one per nozzle
- no blanket assumptions across different nozzles
- each nozzle can have a different meter progression and must be accounted for independently

### 13D. Abnormal Lower Closing Meter Rule

Chosen option: `Option A`

Finalized behavior:

- if a nozzle closing meter is lower than its opening meter, that nozzle must be blocked from normal posting
- the manager must provide a reason
- the affected nozzle should move into a `StationAdmin` correction flow
- other valid nozzles can continue in draft without being lost

Important exception:

- if meter reading reversal/adjustment was officially performed by `StationAdmin`
- and that reversal is recorded in the system
- then lower readings may be accepted as part of the audited reversal case
- that nozzle/day should be clearly marked as meter-reversed or meter-adjusted
- totals for that day must still be calculated safely without corrupting fuel sales or tank-liter logic
- dip and reconciliation views should clearly show that a meter reversal/adjustment affected that period

### 13E. Missing Nozzle Reading At Shift Close

Chosen option: `Option B`

Finalized behavior:

- shift close is strictly blocked until all nozzle readings are entered
- no final close is allowed with missing nozzle readings

Reasoning already agreed by business rule:

- meters are always working in the normal pump flow
- if a nozzle is stopped, fuel sale from that station side is also effectively stopped
- therefore missing meter readings should not be treated as normal closable behavior

### 13F. Tank Dip Recording And Stock Update Rule

Finalized behavior:

- when manager records a dip, the raw input is the dip reading in `mm`
- that `mm` reading must be converted using the uploaded calibration/chart for that exact tank
- dip comparison must use that tank's own chart because tanks can differ in shape, capacity, and volume mapping
- after conversion, the tank stock should update to the resulting calculated volume for that tank

Multiple dip behavior:

- users may take more than one dip reading for the same dip event
- there should be support for entering more than one dip reading when enabled
- if multiple dip values are entered, users can edit the values before saving
- the final/last confirmed dip value should be used for the operational process and stock update

Important rule:

- dip logic is tank-specific and must never assume one shared volume formula across all tanks

### 13G. Fuel Receiving Workflow Rule

Chosen direction: based on `Option A` with added business detail

Finalized required fields:

- supplier
- fuel type
- target tank
- quantity received
- dip before
- dip after
- reference / GRN
- optional notes

Additional receiving source requirement:

- the workflow should clearly support whether receiving is from external supplier or own tanker vehicle
- own-tanker receiving should remain properly recorded as its own operational source where relevant

Live-system rule:

- receiving edits and corrections happen in a live system
- if a receiving record is edited through an allowed flow, the impact must reflect everywhere relevant
- records, stock views, and linked calculations must stay synchronized and auditable

### 13H. Purchase Responsibility And Approval Direction

Finalized direction:

- managers are not responsible for supplier payment or purchase approval decisions
- managers are responsible for operational recording such as readings, dips, and receiving-related entries as instructed
- purchases and purchase control belong to higher admin roles
- payment responsibility does not sit with shift cash in hand

Approval direction:

- formal approvals/rejections are not the default operational model
- instead, the product should favor accountability, auditability, and variance visibility
- optional approval controls may still exist as an add-on, but the base product should not depend on them

### 13I. Cash Submission During Shift

Important finalized business rule:

- during a shift, managers may submit cash in intervals during the day
- this can happen multiple times in one shift
- the manager may keep some cash in hand and submit the rest

Example business pattern:

- opening cash carried forward: `90000`
- later total cash sales collected: `500000`
- manager may submit `400000`
- manager may keep `100000` as current cash in hand

Expected system behavior:

- each cash submission/drop should be recorded separately
- current cash in hand should update after each submission
- end-of-shift cash should reflect prior submissions plus remaining cash in hand
- this flow should support multiple cash submissions in the same shift

Cash carry-forward clarification:

- the cash in hand at shift start is the carried-forward operational cash for that shift
- during the shift, as cash sales happen, physical cash in hand increases
- the manager may submit part of that cash during the shift and keep the remaining balance in hand
- by shift end, the manager may leave a smaller change amount in hand for the next shift
- that remaining amount is not fixed and can vary by operational need
- the remaining closing cash in hand becomes the next shift opening cash in hand

Example pattern:

- opening cash in hand: `100000`
- additional cash collected during shift: `500000`
- mid-shift submission: `300000`
- remaining cash in hand after submission: `200000`
- later, by close, only `50000` may be kept as change
- next shift opens with that `50000`

### 13J. Credit Limit And Notification Direction

Finalized direction:

- credit limits are mainly a safety and visibility control
- if credit exposure is increased or exceeds expectation, higher admins should be informed
- the core action should not depend on approvals or rejections

Expected behavior:

- manager can update credit as allowed by role rules
- system should notify the relevant admin role
- system should keep an audit trail
- variance and exception-style reporting should help admins review what happened later

### 13K. Lubricant Sales Direction

Chosen option: `Option A`

Finalized behavior:

- lubricants should behave like simple inventory items
- each lubricant item should have quantity-based stock
- each lubricant item should have a fixed selling price that can be updated by higher admin roles
- each lubricant sale should deduct stock accordingly
- lubricant totals should remain visible separately from fuel totals

### 13L. Internal Fuel Usage Direction

Chosen option: `Option A`

Finalized behavior:

- internal fuel usage should be recorded separately from normal customer sales
- user should select:
  - vehicle or person
  - fuel type
  - quantity
  - nozzle
  - reason
- stock impact should follow the nozzle/fuel movement logic
- the quantity should reduce fuel availability like a sales-equivalent movement
- reporting should classify it separately as internal usage, not as a normal sale

### 13M. Manager Operational Totals Screen

Chosen option: `Option A`

Finalized behavior:

- manager should see separate live sections/cards for:
  - fuel sales
  - lubricant sales
  - receiving
  - expenses
  - credit recovery
  - cash in hand
- manager should also see one grand total summary

Drill-down behavior:

- when the user clicks a section/card, they should enter that functional area
- inside that area they should be able to:
  - view records
  - add a new record where allowed
- if they add a record, the summary should update accordingly
- users should also be able to open a section just to review/view data without adding anything

### 13N. Credit Recovery Entry Direction

Chosen option: `Option A` with business clarification

Finalized behavior:

- manager should select the customer
- manager should enter the recovered amount
- optional note/reference can be added
- customer outstanding balance should reduce immediately after posting
- relevant admin should be notified that a recovery was recorded

Important direction:

- the flow should stay operationally simple
- no approval step is required for normal credit recovery recording

### 13O. Manager Expense Entry Direction

Chosen option: `Option A` with field clarification

Finalized behavior:

- expense category is mandatory
- category should be selected from a dropdown
- amount is mandatory
- note/reason is optional
- attachment is optional and can be supported later

Important direction:

- the form should stay simple for live shift use
- only the key required fields should block save

### 13P. Own Tanker Receiving Direction

Chosen option: `Option A`

Finalized base behavior:

- own-tanker receiving should use the same core receiving screen structure as supplier receiving
- the source should be own tanker trip / own tanker vehicle instead of supplier
- records and totals should stay separate from supplier receiving where relevant

Important future-detail note:

- tanker records are also managed and updated by admin roles
- the tanker module still needs a deeper dedicated design pass later
- this base rule is only to keep manager receiving flow aligned for now without losing tanker-specific detail later

### 13Q. Manager Login Landing Direction

Chosen option: `Option A`

Finalized behavior:

- when manager logs in during an active shift, they should land directly on the shift workspace
- this shift workspace should show:
  - current shift status
  - cash in hand
  - nozzle checklist
  - pending tasks
  - quick actions

Important UX rule:

- the manager landing experience should start from live work first, not from a passive summary screen

### 13R. Manager Nozzle Checklist Layout

Chosen option: `Option B`

Finalized behavior:

- nozzle checklist in the manager shift workspace should be grouped by dispenser first
- user should expand a dispenser to see its nozzles
- this layout should still preserve nozzle-by-nozzle handling underneath

Important rule:

- grouping is only for usability
- meter entry, review, warnings, and calculations still happen per nozzle

### 13S. Manager Pending Tasks List

Chosen direction: based on `Option A` plus admin notifications

Finalized default task types:

- missing dips
- pending receiving entries
- credit follow-ups
- expense entries
- cash submissions
- shift-close readiness issues
- notifications created by admins

Admin control direction:

- admins should be able to edit or influence this list when needed
- the task area should remain configurable enough for admin-led operational follow-up later

### 13T. Nozzle Row Detail In Manager Workspace

Chosen option: `Option A`

Finalized default row fields:

- nozzle name/code
- fuel type
- opening meter
- closing meter field/status
- mapped tank
- warning badge where needed

Important direction:

- the row should expose the key operational context without forcing extra taps
- warning states should remain visible at nozzle level

### 13U. Shift-Close Readiness Rules

Chosen option: `Option A`

Finalized default blockers:

- missing nozzle readings
- missing required dips
- unresolved abnormal meter entries
- required cash summary mismatch

Important rule:

- these are blocking conditions for final shift close
- the manager workspace should make these blockers visible before the user reaches the final close action

### 13V. Cash Summary Mismatch Handling

Chosen option: `Option B`

Finalized behavior:

- system should auto-calculate cash variance
- manager can still proceed without a mandatory variance note as the base rule

Important direction:

- cash mismatch should still remain visible in the shift close summary
- higher roles should be able to review the variance later through reports, audit trails, and exception visibility

### 13W. When Dips Are Mandatory For Shift Close

Chosen option: `Option A` with business exception

Finalized base rule:

- dips are required only for tanks/nozzles that were active during the shift
- dips are also required where receiving activity happened

Additional exception rule:

- if total meter usage tied to that tank is less than `100`
- the shift may still be submitted without a dip for that tank
- in that case, the system should create a warning notification that meter movement occurred below the dip-required threshold

Important UX rule:

- managers should not need to understand or manage this exception logic manually
- the system should handle the rule in the background
- relevant admins should be able to see the warning/notification later

### 13X. Fuel Sales Posting At Shift Close

Chosen option: `Option A`

Finalized behavior:

- fuel sales should auto-post on successful shift close
- no extra final posting button is required in the base workflow

Important rule:

- auto-post should happen only after the shift-close blockers are satisfied
- posted sales must remain traceable to the underlying nozzle readings and shift context

### 13Y. Fuel Rate Source During Sales Calculation

Chosen option: `Option A` with important rate-change handling

Finalized base rule:

- fuel sale rate should come from the active station fuel price for that fuel type at that time

Important Pakistan operations rule:

- fuel rates often change after midnight
- if a rate change happens during an active shift, the manager should be notified
- the system should require a mandatory meter reading at the moment of rate change

Expected behavior when rate changes mid-shift:

- the nozzle effectively gets a split point for calculation
- one meter reading is captured for the rate-change boundary
- another meter reading is captured later at normal shift close
- sales before the rate change should use the old rate
- sales after the rate change should use the new rate

Important direction:

- this should be handled as a system-supported mid-shift rate split
- the manager should be guided through it clearly when it happens

### 13Z. Mid-Shift Rate Change Scope

Chosen option: `Option A`

Finalized behavior:

- if only one fuel type rate changes during a shift
- only the affected nozzles for that fuel type require a boundary meter reading
- unaffected nozzles should continue normally without extra interruption

Important rule:

- rate-change handling must stay selective and fuel-specific
- the system should not disturb unrelated nozzles just for workflow simplicity

### 13AA. Rate Change Notification UX

Chosen option: `Option A`

Finalized behavior:

- when a rate change requires boundary readings, the manager should see a blocking task banner in the shift workspace
- the banner remains until the required boundary meter readings are entered

Important rule:

- this is an operational blocker for the affected fuel/nozzle flow
- the manager should be guided directly to the required action from the banner

### 13AB. Attendance UX For Operator And Manager

Chosen option: `Option A`

Finalized behavior:

- when attendance is enabled, `Operator` and `Manager` should be able to self check-in and check-out
- attendance actions should be available from profile or home screen

Important direction:

- attendance entry should stay simple and fast
- it should not depend on shift creation logic

### 13AC. Payroll Visibility For Operator And Manager

Chosen option: `Option A` with display clarification

Finalized behavior:

- `Operator` and `Manager` should only see their own salary/payroll summary

Display rules:

- bonuses should appear only if any bonus exists
- loans or deductions should appear only if such values exist
- zero-value bonus or loan sections should not be shown just to fill space

Important direction:

- payroll view should remain private, simple, and clean

### 13AD. Accountant Landing Direction

Chosen option: `Option A`

Finalized behavior:

- `Accountant` should land on a finance workspace
- this workspace should focus on:
  - customer recoveries
  - supplier payments
  - expenses
  - payroll
  - alerts

Important direction:

- accountant flow should begin from live finance work, not a passive report-first screen

### 13AE. Customer Ledger Handling By Accountant

Chosen option: `Option A` with edit clarification

Finalized behavior:

- accountant can view customer ledger
- accountant can record customer payments
- accountant can adjust notes/reference details
- accountant can see customer credit exposure
- accountant can edit or remove allowed customer payment/ledger records through controlled flows

Important rule:

- edits and removals must remain auditable
- finance corrections in a live system should reflect everywhere relevant

### 13AF. Supplier Payment Workflow By Accountant

Chosen option: `Option A`

Finalized behavior:

- accountant selects supplier
- accountant enters payment amount
- accountant enters reference
- optional note can be added
- payment posts immediately
- supplier payable balance reduces immediately

Important rule:

- supplier payment changes must remain auditable
- live finance updates should reflect everywhere relevant

### 13AG. Expense Workspace Scope For Accountant

Chosen option: `Option A` with reporting clarification

Finalized behavior:

- accountant can view all expense records
- accountant can edit or remove allowed expense records
- accountant can filter expense records by:
  - date
  - category
  - station

Summary/reporting requirement:

- expense workspace should also provide:
  - daily summary
  - weekly summary
  - monthly summary
  - yearly summary
- those summaries should support filters as well

### 13AH. Payroll Scope For Accountant

Chosen direction: `Option A` expanded with day-one payroll processing

Finalized behavior:

- accountant can view staff payroll list
- accountant can view salary details
- bonuses and deductions should appear when present
- accountant can generate payroll summaries
- accountant can create payroll runs from day one
- accountant can finalize payroll runs from day one

Important inheritance rule:

- when the relevant module is enabled
- `StationAdmin` should also have everything the accountant has in this area

### 13AI. Accountant Alerts Workspace

Chosen option: `Option A`

Finalized default alert types:

- overdue customer balances
- supplier dues
- unusual expense activity
- payroll issues
- admin notifications

### 13AJ. Payroll Calculation Direction

Chosen direction: combined `Option A` and `Option C`

Finalized base rule:

- payroll should be manual by default
- payroll should not automatically change just because attendance exists

Supported calculation structure:

- payroll should be able to use:
  - base salary
  - bonuses
  - deductions
- attendance impact should only apply if attendance/payroll linkage is explicitly enabled as a separate business rule

Important direction:

- attendance presence alone must not auto-change payroll
- linkage between attendance and payroll should remain optional and controlled

### 13AK. Payment Edit And Removal Rule

Chosen option: `Option A`

Finalized behavior:

- authorized finance/admin roles can edit customer and supplier payment records
- authorized finance/admin roles can remove customer and supplier payment records
- full audit trail must be kept
- variance and exception visibility should remain available for later review

### 13AL. StationAdmin Landing Direction

Chosen option: `Option B`

Finalized behavior:

- `StationAdmin` should land on a reports/dashboard-first screen

Expected first-screen focus:

- station performance overview
- operational summaries
- finance summaries
- alerts and exceptions
- quick navigation into admin actions

Important direction:

- unlike `Manager`, `StationAdmin` starts from oversight first
- the screen should still provide fast access into live control areas from the dashboard

### 13AM. StationAdmin Staff Control Scope

Chosen option: `Option A`

Finalized behavior:

- `StationAdmin` can create staff
- `StationAdmin` can assign access role
- `StationAdmin` can assign staff title
- `StationAdmin` can activate or deactivate staff
- `StationAdmin` can edit profile basics
- `StationAdmin` can edit payroll basics

Important rule:

- access role and staff title remain separate concepts
- staff records should support both login-enabled and non-login staff where relevant

### 13AN. StationAdmin Meter Reversal / Adjustment Rule

Chosen option: `Option A`

Finalized required fields and behavior:

- nozzle
- old reading
- new reading
- reason
- automatic audit/event flag

Important rule:

- meter adjustment must remain controlled, traceable, and safe for downstream calculations

### 13AO. StationAdmin Module Toggle Behavior

Chosen option: `Option A`

Finalized behavior:

- when a module is turned off, menus and actions for that module should be hidden
- historical data should be preserved
- historical reports should remain preserved

Important rule:

- turning off a module should not destroy prior records
- module visibility and module data retention are separate concerns

## 14. Language And Localization Direction

This is now finalized as a core product rule.

### 14A. App Languages

The app should support:

- English
- Urdu

Important direction:

- bilingual support should be planned from the start
- it should not be treated as a later retrofit

### 14B. Number Display Rule

Finalized display rule:

- numbers should remain in English digits in both languages
- this applies to app screens
- this also applies to reports

### 14C. Reporting And Template Direction

Finalized direction:

- wording/labels can appear in Urdu when Urdu is selected
- numeric values should still remain in English digits
- reports, summaries, invoices, and other document labels should be designed to support translation from the foundation

### 14D. Technical Planning Rule

Important architecture rule:

- screen text, validation messages, notifications, and report headings should be built through a localization layer from day one
- database codes, stored values, and identifiers should remain language-neutral where possible
- translations can be filled module by module later, but the structure must exist from the beginning

## 15. Additional StationAdmin Decisions

### 15A. StationAdmin Branding And Invoice Control

Chosen option: `Option A`

Finalized behavior:

- `StationAdmin` can manage:
  - display name
  - logo override
  - invoice profile
  - tax labels and tax numbers
  - footer text
  - whether to inherit organization branding

Important UX rule:

- these controls should live inside settings or invoice settings
- they should not appear as a large always-visible form on the main admin screen

### 15B. StationAdmin Forecourt Structure Changes After Onboarding

Chosen option: `Option A`

Finalized behavior:

- `StationAdmin` can add tanks, dispensers, and nozzles after onboarding
- `StationAdmin` can edit tanks, dispensers, and nozzles after onboarding
- `StationAdmin` can deactivate tanks, dispensers, and nozzles after onboarding
- all such changes must use safe mapping validation

Important rule:

- forecourt changes must protect tank/nozzle/fuel mapping integrity
- deactivation should be preferred over destructive removal where live history exists

## 16. HeadOffice Decisions

### 16A. HeadOffice Landing Direction

Chosen option: `Option A`

Finalized behavior:

- `HeadOffice` should land on an organization-wide dashboard
- this dashboard should prioritize:
  - station summaries
  - alerts
  - module status
  - quick drill-down into any station

Important direction:

- `HeadOffice` starts from organization oversight first
- station-level actions should remain easily reachable from the dashboard

### 16B. HeadOffice Station Control Scope

Chosen option: `Option A` with expanded authority

Finalized behavior:

- `HeadOffice` can create stations
- `HeadOffice` can edit stations
- `HeadOffice` can assign `StationAdmin`
- `HeadOffice` can view station health and setup status
- `HeadOffice` can control station-level module toggles

Expanded inheritance rule:

- `HeadOffice` can open a station and do anything a `StationAdmin` can do inside that station

### 16C. HeadOffice Reporting Scope

Chosen option: `Option A`

Finalized behavior:

- `HeadOffice` should have combined organization reports
- `HeadOffice` should also have single-station drill-down reports

Important direction:

- reporting should support both oversight and station-level investigation from the same role

### 16D. HeadOffice Staffing Control Scope

Chosen option: `Option A`

Finalized behavior:

- `HeadOffice` can view staff across all stations
- `HeadOffice` can manage staff across all stations
- `HeadOffice` can manage role assignment across stations
- `HeadOffice` can view payroll visibility by station

Important UX direction:

- `HeadOffice` should be able to switch into a station-focused mode when needed
- this station mode should make station-level people and operations easier to manage without losing organization context

## 17. MasterAdmin Direction For Current Phase

This is now narrowed for the current build phase.

### 17A. Current MasterAdmin Priority

Finalized direction:

- for now, `MasterAdmin` should focus mainly on organization creation and onboarding-related control
- the immediate product focus is not the full SaaS subscription/package center yet

Current `MasterAdmin` scope for this phase:

- create organization
- edit organization
- drive onboarding steps
- manage onboarding progress/status
- control what is enabled during onboarding

### 17B. SaaS Scope Timing

Finalized direction:

- SaaS package management
- subscriptions
- billing/package dashboards
- active subscription graphs

should be planned for later after the operational and admin foundations are complete

Important rule:

- these SaaS features are still part of the long-term product
- but they are not the current connected priority for the first build phases

### 17C. MasterAdmin Support Access

Finalized direction:

- `MasterAdmin` should be able to enter tenant context for support and control
- support access should allow deep control and editing where needed
- logs and audit history should be recorded for such actions

Important implementation note:

- going into station/tenant mode for deeper support can be handled through a separate browser-based support path
- this can be a separate support console on the frontend later
- current direction mentioned is a separate `Node.js` support console, potentially deployed separately such as on `Vercel`

### 17D. Data-Level Support Capability

Finalized direction:

- `MasterAdmin` should ultimately be able to control and correct data deeply when support requires it
- this may include record-level fixes and deeper backend/database-oriented support tools
- these support capabilities should remain separate from normal station-user experience

### 17E. Current-Phase MasterAdmin Landing Direction

Chosen option: `Option A`

Finalized behavior:

- `MasterAdmin` should land on an organization onboarding workspace
- this workspace should prioritize:
  - create organization
  - edit organization
  - onboarding progress
  - pending setup issues
  - quick access into tenants

Important direction:

- current-phase `MasterAdmin` should start from onboarding and tenant readiness first
- broader SaaS dashboard concerns can come later

### 17F. Current-Phase MasterAdmin Onboarding Controls

Chosen option: `Option A`

Finalized behavior:

- `MasterAdmin` can configure organization details
- `MasterAdmin` can configure station count
- `MasterAdmin` can configure module enablement
- `MasterAdmin` can configure branding defaults
- `MasterAdmin` can assign the first admin
- `MasterAdmin` can manage setup progress

## 18. Notification Direction

### 18A. First-Release Notification Scope

Chosen option: `Option A`

Finalized behavior:

- first release should support in-app notifications
- notification architecture should be provider-ready for later WhatsApp and Firebase integration

Important direction:

- build notification events, templates, and delivery routing in a way that can later plug into:
  - WhatsApp
  - Firebase
- first release should not depend on external delivery providers to function correctly

### 18B. Notification Audience Rules

Chosen option: `Option A` with customer communication note

Finalized behavior:

- notifications should be sent based on role and event type
- recipients can include roles such as:
  - `Manager`
  - `StationAdmin`
  - `HeadOffice`
  - `Accountant`

Customer-facing future messaging direction:

- ledger-related updates should later be able to reach customers with custom-built messages
- those messages can include current ledger/outstanding information
- sale-related invoice delivery should also be supported as part of the communication plan

Important rule:

- internal operational notifications and external customer communication should share a clean event/template foundation
- delivery channel can vary later without changing the underlying business event model

## 19. Reporting Direction

### 19A. First Build Report Families

Chosen option: `Option A`

Finalized report families for the first real build:

- operational reports
- finance summaries
- staff/payroll summaries
- exception/variance reports

Important direction:

- reporting should reflect both day-to-day operations and accountability review

### 19B. Shared Report Filtering Standard

Chosen option: `Option A`

Finalized standard filters across most reports:

- date range
- station
- fuel type
- staff/user
- status where relevant

Important direction:

- reports should share a common filtering language where possible
- this should reduce inconsistency across modules and roles

### 19C. First Exception / Variance Report Scope

Chosen option: `Option A`

Finalized first exception/variance report types:

- cash variance
- dip variance
- abnormal meter events
- credit limit breaches
- unusual edits/removals

### 19D. First Export Formats

Chosen option: `Option A`

Finalized export direction:

- major reports should support PDF export
- major reports should support Excel / CSV export

## 20. Deferred Modules And Tanker Priority

### 20A. Optional Business Unit Modules In Current Planning

Chosen option: `Option A`

Finalized direction:

- shop / mart
- restaurant
- service station / workshop
- rented shops / lease units
- ATM / third-party unit
- tyre shop

should remain in the current product plan as modular placeholders

Current planning rule:

- keep only high-level scope for these modules right now
- design them in full detail later one by one

### 20B. Tanker Module Planning Priority

Chosen option: `Option B`

Finalized direction:

- tanker operations should now receive a full detailed design pass before moving further

Important reason:

- tanker workflows are important enough to require full planning now
- the earlier base receiving rules stay valid, but tanker-specific behavior must now be detailed properly before implementation planning continues

### 20C. Real Tanker Business Model Captured

This is the real tanker business pattern described so far and should guide tanker planning.

Core business pattern:

- there are multiple suppliers
- the business buys petrol and diesel from those suppliers
- tankers can have multiple compartments
- compartments may have different capacities or the same capacity

Example purchase and selling flow:

- buy `10000` diesel at purchase price `X`
- buy `10000` petrol at purchase price `Y`
- then sell part of that load, for example `2000` diesel and `2000` petrol, to pump/customer `X` at selling price `Z`
- trip profitability is generally:
  - sales revenue
  - minus purchase cost
  - minus trip expenses

Own pump dump behavior:

- if some petrol or diesel remains unsold
- the remaining fuel may be dumped into the company's own station tanks
- when dumped into own station tanks, it should be valued at the original buy price

Fleet structure:

- the company currently has `2` own tankers
- there are `4` drivers currently
- operationally this may look like `2` drivers per vehicle, but assignments can vary
- drivers are not permanently tied to one specific tanker

Operational variations:

- sometimes the company sends its own tanker directly for its own petrol/diesel and dumps it into its own tanks
- in those cases trip expenses should still be recorded and reflected against the oil movement/business result

External/company tanker variation:

- sometimes a supplier/company sends its own tanker
- in those cases driver details may be unknown or not tracked
- there may be no tanker-trip expenses on the buyer side
- instead there is usually a payable bill
- that bill may be paid in advance or on credit depending on the case

### 20D. Tanker Trip Creation Model

Chosen option: `Option A` with scale clarification

Finalized behavior:

- one tanker trip should support multiple compartment lines
- each compartment line should track:
  - fuel type
  - capacity/load
  - purchase source
  - remaining balance

Important operational note:

- a single loaded tanker can serve many stations/customers on the same run
- for example, a tanker loaded with `20000` liters may sell in smaller quantities across many stops
- the trip model must support extended multi-stop usage without forcing artificial trip splitting

### 20E. Multi-Stop Tanker Delivery Model

Chosen option: `Option A` with ledger clarification

Finalized behavior:

- one tanker trip should support multiple delivery entries
- each delivery entry should track:
  - customer / pump
  - fuel type
  - quantity
  - sale rate
  - amount

Ledger rule:

- each delivery should update the related party ledger correctly
- example pattern:
  - previous outstanding = `3000000`
  - new tanker sale = `5000000`
  - payment received = `4000000`
  - resulting outstanding should update accordingly

Own-station leftover rule:

- if the same trip also ends with leftover fuel dumped into the company's own station
- that leftover movement should also be recorded and reflected properly
- own-station leftover should update the station side accordingly using the agreed valuation rule

### 20F. Tanker Delivery Payment Recording

Chosen option: `Option A` with ledger clarification

Finalized behavior:

- each tanker delivery can record paid amount immediately
- each tanker delivery should update the remaining outstanding immediately against that customer/pump ledger

Important business clarification:

- sometimes a customer pays nothing at delivery time and pays later
- therefore the system must support unpaid and later-paid tanker deliveries cleanly

Separate ledger rule:

- tanker selling should have separate ledgers from other normal station/customer credit ledgers where needed
- this separation is important so tanker receivables do not get mixed with normal forecourt/customer credit

### 20G. Leftover Fuel Dump To Own Station

Chosen option: `Option A`

Finalized behavior:

- leftover fuel from a tanker trip should be recorded as a tanker-to-station internal transfer
- user should select the destination station tank
- the movement should be valued at the original purchase price
- tanker remaining balance should reduce accordingly

Important rule:

- this is not just a manual stock adjustment
- it must remain an explicit operational record between tanker side and station side

### 20H. Tanker Trip Expense Recording

Chosen option: `Option A` with field clarification

Finalized behavior:

- tanker trip expenses should record:
  - expense type from a dropdown
  - amount
  - optional note
  - optional attachment
- trip profit should update based on total trip expenses

### 20I. Driver Assignment In Tanker Module

Chosen option: `Option A`

Finalized behavior:

- drivers should be treated as a shared pool
- drivers can be assigned to any tanker/trip as needed
- drivers are not permanently locked to a single tanker

Important business direction:

- driver assignment is mainly for records and accountability
- the system should help answer who was on that trip/day if questions arise later

### 20J. Tanker Master Data Scope

Chosen option: `Option A`

Finalized master data scope:

- tanker vehicle
- registration
- compartment structure
- capacity
- status
- driver pool links

### 20K. Supplier / Company-Owned Tanker Receiving

Chosen option: `Option A` with commercial clarification

Finalized behavior:

- supplier/company-owned tanker deliveries to the station should be recorded as receiving records
- those records should link to the supplier bill / payable side
- liters and price should be captured as part of that record

Important direction:

- this path should not depend on full driver/tanker-trip management when that information is unknown or irrelevant

### 20L. Tanker Compartment Tracking Rule

Chosen option: `Option A`

Finalized behavior:

- tanker sales and remaining stock should be tracked by compartment line
- remaining fuel should stay known per compartment and per fuel type

Important rule:

- tanker stock should not be flattened into one generic tanker total where compartment detail matters

### 20M. Tanker Profitability Calculation

Chosen option: `Option A`

Finalized first-version calculations:

- trip revenue
- purchase cost
- total trip expenses
- net profit

### 20N. Tanker Module Role Scope

Chosen option: `Option A`

Finalized first-version role access:

- tanker module day-to-day operation should be handled by `StationAdmin` and above only

### 20O. Open Tanker Trip Settlement Rule

Chosen option: `Option A`

Finalized behavior:

- a tanker trip should remain open until all fuel is:
  - sold
  - dumped to own station
  - or otherwise settled through an approved operational outcome

Warning rule:

- the system should clearly warn when a tanker trip is still open with remaining fuel

### 20P. Tanker Customer Master And Ledger Rule

Chosen option: `Option A`

Finalized behavior:

- tanker sales should use the same customer master as normal customers
- tanker ledger/category should remain separate where needed

Important rule:

- customer identity can stay unified
- financial tracking should still distinguish tanker business from normal station credit

### 20Q. Tanker Sales Documents

Chosen option: `Option A` with future messaging note

Finalized first-version behavior:

- tanker sale should produce a delivery record
- tanker sale should also support a printable invoice/challan

Future communication direction:

- there should be a future option to send tanker sale messages and invoice/challan through WhatsApp
- this should align with the broader notification and document-dispatch architecture

### 20R. Tanker Purchase Cost Basis

Chosen option: `Option A`

Finalized behavior:

- each tanker compartment line should keep its own purchase rate
- each tanker compartment line should keep its own cost basis

Important rule:

- mixed-fuel or mixed-rate tanker loads must not be flattened into one average cost unless explicitly required later for a separate reporting view

### 20S. Mixed Trip Settlement Rule

Chosen option: `Option A`

Finalized behavior:

- if a tanker trip includes both outside deliveries and own-station dump on the same run
- both should be included in trip settlement
- delivery revenue and own-station transfer value should be treated as separate settlement lines

Important rule:

- the trip should reflect the full business outcome of the load
- outside sales and internal station transfer should remain distinguishable in records and reports

### 20T. Tanker Trip Status Flow

Chosen option: `Option A`

Finalized first-version status flow:

- `draft`
- `active / in_transit`
- `partially_settled`
- `settled / closed`

### 20U. Tanker Dashboard And Report Priorities

Chosen option: `Option A`

Finalized first dashboard/report priorities:

- open trips
- remaining fuel
- outstanding customer balances
- trip profit
- recent deliveries

### 20V. Tanker Master Data Ownership

Chosen option: `Option A`

Finalized behavior:

- `StationAdmin` can create and manage tanker master data for their station scope where relevant
- `HeadOffice` can also create and manage tanker master data
- `HeadOffice` can manage tanker master data across stations inside the organization

Important direction:

- this should support both local station administration and organization-level fleet oversight

### 20W. Tanker Data Scope Rule

Chosen option: `Option A`

Finalized data-model direction:

- tanker operations should be organization-owned in the data model
- station linkage should exist where relevant

Reason:

- tankers can serve multiple stations and outside customers
- tanker business should not be artificially restricted to one station-only model
