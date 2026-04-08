# Backend Task List

This document converts the backend gap audit into an actionable execution queue.

Use this as the active backend worklist.

Related docs:

- [09_MASTER_PRODUCT_SPEC.md](/C:/Fuel%20Management%20System/Docs/09_MASTER_PRODUCT_SPEC.md)
- [10_IMPLEMENTATION_ROADMAP_AND_CHECKLIST.md](/C:/Fuel%20Management%20System/Docs/10_IMPLEMENTATION_ROADMAP_AND_CHECKLIST.md)
- [11_BACKEND_GAP_AUDIT.md](/C:/Fuel%20Management%20System/Docs/11_BACKEND_GAP_AUDIT.md)

## 1. Working Rules

- finish blocker contracts before deep Flutter feature work
- prefer backend-calculated business rules over frontend-trusted calculations
- keep PostgreSQL-safe design
- keep audit-sensitive changes traceable
- do not widen scope during implementation unless it removes a near-term blocker

## 2. Priority Legend

- `P0` = blocks Flutter foundation or core manager flow
- `P1` = should be done before the related feature packet is called complete
- `P2` = useful improvement, but not a day-one blocker
- `Later` = intentionally deferred

## 3. Active Backend Queue

## Epic A - Auth And Capability Contract

### A1. Freeze Flutter capability payload contract

- Priority: `P0`
- Goal: give Flutter one stable typed capability payload from `/auth/me`
- Current state: rich payload exists, but not yet frozen as a frontend contract
- Deliverables:
  - confirm field list
  - confirm nullability
  - confirm role naming
  - confirm module and feature-flag naming
  - document one canonical response example
- Done when:
  - Flutter can build auth/session/capability models without guessing

### A2. Normalize role naming and role mapping

- Priority: `P0`
- Goal: align backend role checks with the finalized product role language
- Current issue:
  - backend still mixes `Admin` and `MasterAdmin` style concepts in code paths
- Deliverables:
  - confirm active role names in DB and permissions
  - confirm whether `Admin` remains internal alias or should be retired
  - document exact mapping for:
    - `MasterAdmin`
    - `HeadOffice`
    - `StationAdmin`
    - `Manager`
    - `Accountant`
    - `Operator`
- Done when:
  - permissions and UI routing can rely on one role vocabulary

## Epic B - Onboarding And Setup Contract

### B1. Design onboarding progress/status model

- Priority: `P0`
- Goal: support wizard-based onboarding and incomplete-step tracking
- Current issue:
  - CRUD exists, but onboarding step progress is not strongly modeled
- Deliverables:
  - define onboarding status shape
  - define step keys
  - define pending issue structure
  - define who must complete each missing step
- Done when:
  - Flutter can show onboarding progress and blocked modules cleanly

### B2. Add wizard-friendly onboarding endpoints where needed

- Priority: `P0`
- Goal: reduce frontend orchestration complexity
- Possible deliverables:
  - create organization wizard endpoint
  - update onboarding progress endpoint
  - fetch onboarding workspace summary endpoint
  - first-admin assignment endpoint if not cleanly covered already
- Done when:
  - `MasterAdmin` onboarding can be built without stitching many unrelated CRUD calls

### B3. Normalize auto-generation rules

- Priority: `P1`
- Goal: centralize generated defaults for:
  - organization codes
  - station codes
  - tank/dispenser/nozzle defaults
- Current issue:
  - some generation happens ad hoc
- Done when:
  - generated setup data is predictable and backend-owned

## Epic C - Shift Workflow Redesign

### C1. Replace manager-created shifts with prepared shift workflow

- Priority: `P0`
- Goal: shift system should match finalized product behavior
- Current issue:
  - manager opens shift manually via `POST /shifts/`
- Deliverables:
  - define prepared shift/current shift endpoint
  - support template-based current shift selection
  - manager closes/works current shift, not manually creates it
- Done when:
  - manager can land on the current prepared shift workspace contract

### C2. Add opening cash carry-forward logic

- Priority: `P0`
- Goal: opening cash should come from previous shift closing remainder
- Deliverables:
  - carry-forward rule
  - validation for missing previous shift state
  - support for first-live-shift bootstrap case
- Done when:
  - new shift opening cash is backend-derived, not manager-entered

### C3. Add opening nozzle carry-forward logic

- Priority: `P0`
- Goal: opening nozzle state should be derived from prior close or prior meter segment
- Deliverables:
  - carry-forward source of truth
  - per-nozzle opening snapshot logic
- Done when:
  - the manager shift workspace can show opening readings without manual setup

### C4. Strengthen shift-close blockers

- Priority: `P0`
- Goal: backend enforces real shift-close rules
- Required blockers:
  - missing nozzle readings
  - missing required dips
  - unresolved abnormal meter entries
  - required cash summary mismatch
- Done when:
  - shift close cannot succeed while violating agreed rules

### C5. Add manager shift workspace summary endpoint

- Priority: `P0`
- Goal: give Flutter one primary screen payload for manager home
- Suggested contents:
  - shift header
  - cash in hand
  - dispenser-grouped nozzle checklist summary
  - pending tasks
  - live totals
  - blocking banners
- Done when:
  - Flutter manager home does not need to assemble everything from many unrelated endpoints

## Epic D - Fuel Sale And Pricing Workflow

### D1. Define shift-close fuel sale posting contract

- Priority: `P0`
- Goal: support review then auto-post behavior from meter readings
- Current issue:
  - fuel sale creation exists, but not clearly as shift-close posting workflow
- Deliverables:
  - close preview payload
  - final post behavior
  - traceability from nozzle readings to posted sales
- Done when:
  - sales posting is backend-owned and reproducible

### D2. Add active fuel pricing API

- Priority: `P0`
- Goal: expose the active station fuel rate at a point in time
- Deliverables:
  - read active rate endpoint
  - update/schedule rate endpoint if missing
  - clear response shape for station, fuel type, channel, effective time
- Done when:
  - Flutter can price sales from backend truth

### D3. Add mid-shift rate change handling

- Priority: `P0`
- Goal: support boundary reading workflow when rate changes during active shift
- Deliverables:
  - detect affected fuel-type nozzles
  - create required rate-boundary reading task
  - split sale calculations across old/new rates
- Done when:
  - midnight or active-shift rate changes are handled safely

## Epic E - Tank Dips And Calibration

### E1. Move dip volume calculation to backend

- Priority: `P0`
- Goal: stop trusting client-provided calculated volume
- Current issue:
  - `TankDipCreate` currently accepts `calculated_volume`
- Deliverables:
  - accept `mm` input
  - compute volume server-side
  - update tank stock from backend-calculated volume
- Done when:
  - dip math lives entirely in backend logic

### E2. Add tank calibration chart model and API

- Priority: `P0`
- Goal: support tank-specific dip-to-volume conversion
- Deliverables:
  - chart header model
  - chart line model
  - chart CRUD endpoints
  - active chart selection logic
- Done when:
  - each tank can have its own chart and the dip service uses it

### E3. Add dip-required threshold and warning logic

- Priority: `P1`
- Goal: support the "<100 usage can skip dip with warning" rule
- Deliverables:
  - usage threshold logic
  - admin warning notification event
  - hidden manager simplification
- Done when:
  - dip exceptions behave like the finalized product

## Epic F - Finance Corrections And Summaries

### F1. Decide direct edit/remove versus reversal model

- Priority: `P0`
- Goal: align finance UX with accountability-first design
- Current issue:
  - current routes emphasize reversal approval patterns
- Decision output needed for:
  - customer payments
  - supplier payments
  - expenses
  - possibly purchases
- Done when:
  - one consistent correction model is chosen for first release

### F2. Implement allowed edit/remove endpoints with audit trail

- Priority: `P1`
- Goal: support authorized finance/admin correction flows
- Deliverables:
  - update endpoints where needed
  - delete/remove endpoints where needed
  - audit payloads for before/after values
- Done when:
  - Flutter finance screens can support the finalized correction behavior safely

### F3. Make payroll manual by default

- Priority: `P0`
- Goal: align payroll generation with finalized business rule
- Current issue:
  - current documentation suggests attendance-driven payroll behavior
- Deliverables:
  - review payroll service
  - gate attendance impact behind explicit linkage flag
- Done when:
  - payroll does not auto-change simply because attendance exists

### F4. Add accountant workspace summary endpoint

- Priority: `P1`
- Goal: give Flutter a clean finance home payload
- Suggested contents:
  - overdue customer balances
  - supplier dues
  - unusual expense activity
  - payroll issues
  - admin notifications
- Done when:
  - accountant landing screen can be built with one primary data call

## Epic G - StationAdmin And HeadOffice Alignment

### G1. Separate access roles from staff titles in backend flows

- Priority: `P1`
- Goal: support finalized HR/admin model cleanly
- Deliverables:
  - review employee profile and user creation flows
  - ensure custom staff titles do not leak into permission logic
- Done when:
  - staff title is metadata, access role is authority

### G2. Prefer deactivation over destructive delete for live forecourt data

- Priority: `P1`
- Goal: protect history while supporting real admin operations
- Deliverables:
  - review delete endpoints for tanks/dispensers/nozzles
  - add deactivate flow if missing
- Done when:
  - live forecourt history is not lost through normal admin actions

### G3. Expand HeadOffice writable organization controls

- Priority: `P1`
- Goal: align backend permissions with finalized HeadOffice scope
- Deliverables:
  - review routes currently read-only for `HeadOffice`
  - widen only the intended organization-scoped controls
- Done when:
  - `HeadOffice` can manage stations and station admins as planned

### G4. Add organization dashboard summary endpoint

- Priority: `P1`
- Goal: provide one backend payload for HeadOffice home
- Suggested contents:
  - station summaries
  - setup status
  - module status
  - org-wide alerts
- Done when:
  - HeadOffice dashboard does not need many stitched calls

## Epic H - Tanker Schema And Service Alignment

### H1. Redesign tanker ownership scope

- Priority: `P1`
- Goal: align tanker model with organization-owned fleet
- Current issue:
  - tanker is still station-owned in the current schema
- Deliverables:
  - schema migration plan
  - service and permission updates
  - station linkage retained where operationally relevant
- Done when:
  - tanker fleet can serve multi-station organization flow cleanly

### H2. Move tanker cost basis fully to compartment-level logic

- Priority: `P1`
- Goal: support mixed-fuel mixed-rate real business behavior
- Current issue:
  - trip model still carries trip-level fuel/cost fields
- Deliverables:
  - compartment cost basis as source of truth
  - trip aggregates derived from compartments
- Done when:
  - profitability and remaining stock are correct for mixed loads

### H3. Add shared driver pool assignment model

- Priority: `P1`
- Goal: replace simple driver text fields with assignment-ready structure
- Deliverables:
  - driver pool or staff-link strategy
  - trip-to-driver assignment records
- Done when:
  - tanker trip accountability matches the finalized workflow

### H4. Confirm and enforce separate tanker ledger treatment

- Priority: `P1`
- Goal: keep tanker credit distinct from forecourt/customer credit where needed
- Deliverables:
  - ledger category strategy
  - service enforcement
  - report distinction
- Done when:
  - tanker receivables are not mixed confusingly with normal station ledgers

### H5. Normalize tanker trip statuses

- Priority: `P1`
- Goal: align with finalized tanker state flow
- Target flow:
  - `draft`
  - `active / in_transit`
  - `partially_settled`
  - `settled / closed`
- Done when:
  - statuses and settlement behavior match the product spec

## Epic I - Reports, Notifications, And Documents

### I1. Verify report coverage against first release families

- Priority: `P2`
- Goal: confirm backend report endpoints match:
  - operational
  - finance
  - staff/payroll
  - exception/variance
- Done when:
  - Flutter reporting plan can map to real endpoints with minimal gaps

### I2. Normalize standard report filters

- Priority: `P2`
- Goal: reduce inconsistent filtering behavior across report endpoints
- Standard target filters:
  - date range
  - station
  - fuel type
  - staff/user
  - status where relevant
- Done when:
  - report filters feel consistent across modules

### I3. Keep notification event/template naming stable

- Priority: `P2`
- Goal: support future WhatsApp/Firebase extension without backend churn
- Done when:
  - channels can evolve without rewriting business event names

## 4. Recommended Execution Order

Do backend work in this order:

1. `A1`
2. `A2`
3. `B1`
4. `C1`
5. `C2`
6. `C3`
7. `C4`
8. `D1`
9. `E1`
10. `E2`
11. `D2`
12. `D3`
13. `F1`
14. `F3`
15. `C5`

That gives us the critical path for:

- Flutter foundation
- onboarding/setup
- manager shift core

## 5. Suggested First Coding Sprint

If we want to start coding immediately, the first sprint should cover:

1. `A1` Freeze capability contract
2. `A2` Normalize role mapping
3. `B1` Design onboarding progress/status model
4. `C1` Prepared shift workflow design
5. `E1` Move dip calculation server-side

These five items will remove the most Flutter rework risk.

## 6. What To Start Coding First

The best first code task is:

- `A1` Freeze capability contract

Reason:

- it is small enough to complete quickly
- it unlocks Flutter auth/session work
- it gives us a stable foundation before we touch the bigger shift redesign
