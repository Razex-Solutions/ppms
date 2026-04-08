# Backend Gap Audit

This document compares the finalized product plan against the current backend implementation.

It is the first execution document after planning.

Use it together with:

- [09_MASTER_PRODUCT_SPEC.md](/C:/Fuel%20Management%20System/Docs/09_MASTER_PRODUCT_SPEC.md)
- [10_IMPLEMENTATION_ROADMAP_AND_CHECKLIST.md](/C:/Fuel%20Management%20System/Docs/10_IMPLEMENTATION_ROADMAP_AND_CHECKLIST.md)

## 1. Executive Summary

The backend is already substantial and gives us a strong starting point.

Good news:

- auth and session handling already exist
- capability loading already exists
- role/module-aware backend structure already exists
- station setup CRUD mostly exists
- finance/payments/payroll already exist
- notifications already exist
- tanker support is much stronger than expected
- meter adjustment already has a dedicated nozzle endpoint

Main reality:

- the backend is not empty or early-stage
- it is already usable as a real API base for the new Flutter app

Main gaps:

- some workflows do not yet match the finalized product behavior
- some schema support exists without the right API shape
- some important business rules still live in frontend assumptions instead of backend enforcement
- some planned flows are still station-scoped where the product now wants stronger organization-aware behavior

## 2. Audit Method

This audit is based on direct inspection of:

- router registry
- FastAPI app composition
- key route files
- key services
- selected models and schemas

Primary files checked:

- [ppms/app/main.py](/C:/Fuel%20Management%20System/ppms/app/main.py)
- [ppms/app/api/__init__.py](/C:/Fuel%20Management%20System/ppms/app/api/__init__.py)
- [ppms/app/api/auth.py](/C:/Fuel%20Management%20System/ppms/app/api/auth.py)
- [ppms/app/services/capabilities.py](/C:/Fuel%20Management%20System/ppms/app/services/capabilities.py)
- [ppms/app/api/station.py](/C:/Fuel%20Management%20System/ppms/app/api/station.py)
- [ppms/app/api/station_shift_template.py](/C:/Fuel%20Management%20System/ppms/app/api/station_shift_template.py)
- [ppms/app/api/shift.py](/C:/Fuel%20Management%20System/ppms/app/api/shift.py)
- [ppms/app/services/shifts.py](/C:/Fuel%20Management%20System/ppms/app/services/shifts.py)
- [ppms/app/api/tank_dip.py](/C:/Fuel%20Management%20System/ppms/app/api/tank_dip.py)
- [ppms/app/services/tank_dips.py](/C:/Fuel%20Management%20System/ppms/app/services/tank_dips.py)
- [ppms/app/api/nozzle.py](/C:/Fuel%20Management%20System/ppms/app/api/nozzle.py)
- [ppms/app/api/tanker.py](/C:/Fuel%20Management%20System/ppms/app/api/tanker.py)
- [ppms/app/models/tanker.py](/C:/Fuel%20Management%20System/ppms/app/models/tanker.py)
- [ppms/app/models/tanker_trip.py](/C:/Fuel%20Management%20System/ppms/app/models/tanker_trip.py)

## 3. Current Backend Coverage

### 3.1 Clearly Ready Or Strong

These areas already have a strong backend base:

- auth login, refresh, logout, sessions, password change/reset
- `/auth/me` capability payload
- module-aware backend router loading
- organization, station, fuel type, tank, dispenser, nozzle CRUD
- station setup foundation read endpoint
- station shift template CRUD
- shift cash and cash submission support
- customer and supplier payment flows
- payroll runs and payroll finalization
- attendance check-in/check-out and attendance management
- notification center, preferences, delivery diagnostics
- invoice profiles and document-related modules
- nozzle meter adjustment endpoint and adjustment history
- tanker CRUD, tanker compartments, tanker trips, deliveries, expenses, completion, summary

### 3.2 Present But Only Partial Against Finalized Product

These areas exist, but do not yet fully match the finalized product spec:

- onboarding and setup
- shift lifecycle
- tank dip workflow
- fuel sale posting workflow
- manager dashboard/task model
- finance edit/remove behavior
- organization-wide tanker data model
- fuel pricing workflow
- localization support

## 4. Key Gaps By Product Phase

## 4.1 Phase 1 - Flutter Foundation

### Status

Mostly ready.

### Already supported

- login
- refresh token flow
- session listing
- `/auth/me`
- permissions and capability context
- effective enabled modules
- feature flags

### Gap items

1. The Flutter app will need a normalized capability contract document.
   Current backend is rich, but the frontend needs one stable typed model for:
   - role
   - scope
   - station
   - organization
   - effective modules
   - feature flags
   - creatable roles
   - permissions

2. Role naming and role behavior should be reviewed before UI work begins.
   Current backend still mixes checks such as `Admin`, `HeadOffice`, and `StationAdmin`.
   The new product language is:
   - `MasterAdmin`
   - `HeadOffice`
   - `StationAdmin`
   - `Manager`
   - `Accountant`
   - `Operator`

3. Localization is not yet a backend concern.
   That is fine, but enum labels, module names, and event labels should stay stable and language-neutral.

## 4.2 Phase 2 - Onboarding And Setup

### Status

Partially ready.

### Already supported

- organizations API exists
- stations API exists
- station setup foundation read exists
- fuel types, tanks, dispensers, nozzles CRUD exist
- station shift templates exist
- invoice profile support exists
- station and organization module settings exist

### Gap items

1. Wizard-native onboarding flow is not yet represented as a backend-first process.
   We have CRUD, but not a dedicated onboarding orchestration shape.

2. Draft-save and step-by-step onboarding progress need clearer backend support.
   The station model has `setup_status` and `setup_completed_at`, but the product plan wants more explicit step tracking and incomplete-module blocking.

3. Organization creation still looks CRUD-first, not wizard-first.
   The final product wants:
   - station count flow
   - default brand attachment
   - first admin creation
   - module enablement during onboarding
   - progress and pending setup issues

4. Auto-generation rules for organization codes, station codes, tank/dispenser/nozzle defaults should be verified and normalized.
   Some auto-generation exists in CRUD routes like nozzles, but the full onboarding generation rules are not yet centrally modeled.

## 4.3 Phase 3 - Operator Self-Service

### Status

Mostly ready.

### Already supported

- auth
- attendance check-in/check-out
- payroll run and payroll line data model
- employee profile foundations

### Gap items

1. A dedicated "my profile / my payroll / my attendance" frontend-friendly payload is not obvious yet.
   The backend may support this through existing user, attendance, and payroll endpoints, but a simplified self-service read surface may still help the Flutter app.

2. Payroll visibility rules for hiding zero-value bonus/loan sections are frontend work, but we should verify the backend returns enough detail cleanly.

## 4.4 Phase 4 - Manager Operational Core

### Status

Partially ready, but this is the biggest workflow gap area.

### Already supported

- shifts API exists
- shift cash and cash submissions exist
- fuel sales API exists
- tank dips API exists
- nozzle reading history exists
- customer payments exist
- expenses exist
- internal fuel usage exists

### Major gap items

1. Shifts are still manually opened.
   Current backend:
   - `POST /shifts/` opens a shift directly
   - service creates a shift from explicit input

   Final product wants:
   - pre-generated shift templates
   - manager lands on the prepared shift
   - manager closes, not creates

2. Shift opening cash carry-forward is not aligned with the finalized product.
   Current backend uses `initial_cash` input when creating a shift.
   Final product wants opening cash to flow from previous shift closing cash automatically.

3. Opening nozzle carry-forward is not visible as a formal shift-start workflow.
   This likely needs a dedicated service rule or prepared shift snapshot logic.

4. Shift-close validation is too light relative to the finalized rules.
   Final product requires blocking on:
   - missing nozzle readings
   - missing required dips
   - unresolved abnormal meter entries
   - required cash summary mismatch

5. Fuel sales are still explicit sale records, not clearly auto-posted from shift close.
   Final product wants:
   - meter-based review
   - safe validation
   - auto-post on successful shift close

6. Mid-shift fuel rate change handling is not yet represented as a product workflow.
   Current backend has `FuelPriceHistory` model support, but no first-class pricing API/workflow is visible for:
   - active rate by time
   - midnight rate split
   - mandatory rate-change boundary reading

7. Tank dip calculation is still frontend-trusted.
   Current backend:
   - `TankDipCreate` requires `calculated_volume`
   - service updates `tank.current_volume` directly from client-provided value

   Final product wants:
   - manager enters dip in `mm`
   - backend uses tank-specific calibration chart
   - backend calculates volume itself

8. Tank calibration chart support is missing from the operational API surface.

9. Manager task feed and shift workspace summary are not clearly exposed as a dedicated endpoint.
   The Flutter app can assemble some of it from multiple endpoints, but a manager workspace endpoint would reduce frontend complexity.

10. Customer credit increase notification/exception logic should be verified.
    The product wants alerts and auditability, not default approval flow.

11. The product rule for "<100 usage can skip dip with admin warning" is not yet visible in backend logic.

## 4.5 Phase 5 - Accountant Finance Core

### Status

Strong base, but not fully aligned with the simplified correction model.

### Already supported

- customer payments
- supplier payments
- ledger endpoints
- payroll runs
- payroll finalization
- expense tracking
- reports

### Gap items

1. Payment edit/remove support needs verification.
   The finalized product wants authorized finance/admin roles to edit/remove with full audit trail.
   Current visible routes emphasize reversal flows more than direct edit/remove routes.

2. The finalized product moved away from approval-heavy default workflows.
   The current backend still includes reversal request / approve / reject patterns across financial modules.
   This is not wrong, but it no longer matches the intended default UX.

3. Payroll is currently attendance-linked in README behavior, but finalized product wants payroll manual by default.
   This needs a clear configuration decision in backend logic before Flutter implementation begins.

4. Accountant workspace summary endpoints may still need a cleaner frontend-facing aggregate surface.

## 4.6 Phase 6 - StationAdmin Controls

### Status

Mostly ready, with some important workflow alignment still needed.

### Already supported

- staff/user management base exists
- station edit exists
- fuel setup CRUD exists
- nozzle meter adjustment endpoint exists
- module toggles exist
- branding/invoice structures exist

### Gap items

1. Staff management should be reviewed for the finalized split between:
   - access roles
   - staff titles

2. Safe deactivate-over-delete behavior should be normalized across forecourt assets.
   Current APIs expose delete endpoints.
   Final product prefers deactivation where history exists.

3. Branding and invoice settings are backend-ready, but a station-admin-oriented settings bundle may still help the Flutter app.

## 4.7 Phase 7 - HeadOffice Controls

### Status

Partially ready.

### Already supported

- organization-aware access exists
- HeadOffice restrictions exist
- cross-station read behavior exists in several modules
- stations can be listed and filtered by organization

### Gap items

1. HeadOffice is still partly read-limited in places that the finalized product now wants to be writable.

2. Station-mode context switching is a product-level behavior, not a dedicated backend contract yet.

3. Organization dashboard summary endpoints may need a cleaner aggregate surface for:
   - station health
   - setup status
   - module status
   - org-wide alerts

## 4.8 Phase 8 - Tanker Module

### Status

Stronger than expected, but still not fully aligned with the finalized tanker design.

### Already supported

- tanker CRUD
- compartment CRUD
- tanker trip CRUD
- trip deliveries
- trip expenses
- trip completion
- summary endpoint
- leftover transfer support in trip completion
- profitability fields in the model

### Major gap items

1. Tanker is still station-owned in the data model.
   Current models:
   - `Tanker.station_id`
   - `TankerTrip.station_id`

   Final product wants:
   - organization-owned tanker model
   - station linkage where relevant

2. Tanker trip model still includes trip-level `fuel_type_id`, `loaded_quantity`, and `purchase_rate`.
   Final product wants compartment-level cost basis and mixed-fuel trip behavior as the real source of truth.

3. Flexible driver-pool linkage is not yet obvious in the persisted model.
   Current tanker model still includes simple `driver_name` and `driver_phone` fields.
   Final product wants shared driver pool assignment for accountability.

4. Separate tanker ledgers versus normal station ledgers need explicit confirmation in backend data/service logic.

5. Tanker customer sharing with normal customer master is a product rule that should be verified in implementation.

6. Trip status flow does not yet match the finalized plan exactly.
   Final product wants:
   - `draft`
   - `active / in_transit`
   - `partially_settled`
   - `settled / closed`

   Current model uses fields such as `status` and `settlement_status`, but the exact workflow should be normalized.

## 4.9 Phase 9 - Notifications, Reports, Documents, Exports

### Status

Strong base.

### Already supported

- in-app notifications
- notification preferences
- notification deliveries and diagnostics
- report exports
- reports module
- financial documents
- invoice/document foundations

### Gap items

1. Customer-facing WhatsApp messaging is future-ready in planning, but not active in first release.
   This is fine.

2. Report family coverage should be verified against the finalized report groups:
   - operational
   - finance
   - staff/payroll
   - exception/variance

3. Standard shared filters should be normalized across reports if not already consistent.

## 5. Immediate Backend Priorities Before Flutter Build

These are the most important backend tasks to do first because they sit directly on the critical path.

### Priority 1

- normalize auth/capability response contract for Flutter
- document active role names and final role mapping

### Priority 2

- design onboarding progress and setup-step status shape
- confirm or add wizard-friendly onboarding endpoints where needed

### Priority 3

- redesign shift workflow to support prepared shifts instead of manual manager-created shifts
- support opening cash carry-forward and nozzle carry-forward

### Priority 4

- move dip volume calculation to backend using tank calibration charts
- add calibration chart model/API if not yet implemented

### Priority 5

- add or normalize fuel pricing API and active-rate-by-time logic
- support mid-shift rate split and boundary readings

### Priority 6

- review finance correction model
- decide where direct edit/remove replaces request/approve/reject for first-release UX

### Priority 7

- review tanker schema alignment against:
  - organization ownership
  - compartment-level cost basis
  - driver pool assignment
  - separate tanker ledger treatment

## 6. Flutter Start Decision

The Flutter rebuild can start before every backend gap is finished, but only after we settle these minimum blockers:

- final auth/capability payload contract
- final setup foundation response shape
- final shift workspace contract direction
- final dip calculation ownership decision
- final pricing/rate-change contract direction

Without those, Phase 4 frontend work will create avoidable rework.

## 7. Recommended Next Action

The next best step is:

1. review this gap audit against the actual backend team understanding
2. turn the gap items into backend tasks
3. then scaffold the new Flutter foundation immediately

Recommended execution split:

- backend first for the blocker items above
- Flutter foundation in parallel once auth/capability shape is stable
