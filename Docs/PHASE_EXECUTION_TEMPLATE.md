# PPMS Phase Execution Template

## 1. Purpose

This file is the execution template for each roadmap phase.

Use it together with:

- [FINAL_PHASED_MASTER_ROADMAP.md](/C:/Fuel%20Management%20System/Docs/FINAL_PHASED_MASTER_ROADMAP.md)
- [SIMPLIFIED_SETUP_AND_ROLE_PLAN.md](/C:/Fuel%20Management%20System/Docs/SIMPLIFIED_SETUP_AND_ROLE_PLAN.md)
- [CURRENT_PROGRESS.md](/C:/Fuel%20Management%20System/Docs/CURRENT_PROGRESS.md)

The purpose is simple:

- read the roadmap phase
- understand the business rule
- identify the current files
- edit the correct code
- test the phase
- then move forward

This prevents us from:

- changing random files without plan
- mixing multiple phases together
- forgetting tests
- forgetting docs

## 2. How To Use This Template

For every implementation phase:

1. copy this structure into a working note or use it directly as a checklist
2. fill in the current phase number and title
3. list files to inspect first
4. list files expected to change
5. complete backend work first unless UI-only
6. test backend
7. complete Flutter/web frontend work
8. test frontend
9. update docs if plan or structure changed
10. mark the phase done only after acceptance checks pass

## 3. Standard Phase Template

### Phase Number and Title

Example:

- `Phase 1 - Setup Hierarchy Foundation`

### Goal

Write in one short paragraph:

- what this phase is trying to achieve
- what should work after this phase

### Business Rules Source

List the exact sections to follow from:

- [SIMPLIFIED_SETUP_AND_ROLE_PLAN.md](/C:/Fuel%20Management%20System/Docs/SIMPLIFIED_SETUP_AND_ROLE_PLAN.md)
- any supporting role or permission doc if needed

### Scope Included

List only the work included in this phase.

Example:

- organization setup
- station setup
- fuel type setup
- tank setup

### Scope Excluded

List what is intentionally not being done in this phase.

Example:

- payroll
- notifications
- cloud deployment

### Current Implementation Review

Before editing, answer:

1. what already exists?
2. which tables already exist?
3. which APIs already exist?
4. which screens already exist?
5. what can be reused?
6. what must be replaced?

Use:

- [CURRENT_PROGRESS.md](/C:/Fuel%20Management%20System/Docs/CURRENT_PROGRESS.md)

## 4. File Planning Section

### Files To Inspect First

List files to read before changing anything.

Typical backend files:

- models
- schemas
- services
- API routers
- migrations
- seed files
- tests

Typical Flutter files:

- screen/page file
- session/controller file
- API client
- shell/navigation
- shared widgets

### Files Expected To Change

Split by layer.

#### Backend

- model files
- schema files
- service files
- API files
- migration files
- seed/test fixtures

#### Flutter

- feature page files
- session/controller files
- API client
- shared widgets
- shell/navigation if needed

#### Support Frontend

- page files
- API hooks
- dashboard components

#### Docs

- roadmap if scope changes
- progress doc if structure changes

## 5. Backend Execution Checklist

Use this section while implementing backend work.

### Database and Model Work

Check all that apply:

- define new tables
- extend existing tables
- remove duplicate structure
- normalize relationships
- make PostgreSQL-safe
- preserve migration clarity

### Schema Work

Check all that apply:

- create request schemas
- create response schemas
- add summary schemas
- add validation rules

### Service Layer Work

Check all that apply:

- add business logic
- move logic out of API layer
- enforce permissions
- calculate summaries
- calculate derived values

### API Work

Check all that apply:

- create new endpoints
- reshape old endpoints
- add list/search/select-existing flow
- add summary endpoints
- add report/document/notification endpoints

### Backend Tests To Add or Update

Check all that apply:

- unit tests
- service tests
- API tests
- permission tests
- migration tests
- contract tests for Flutter/support frontend

## 6. Frontend Execution Checklist

Use this section for Flutter or support frontend work.

### UX Questions

Answer before building:

1. should this be question-based?
2. should this be dashboard-first?
3. should this be read-only for some roles?
4. should hidden modules leave no trace?
5. can existing master data be selected instead of re-entered?

### Screen Work

Check all that apply:

- add wizard flow
- add summary hero
- add side context panel
- add record detail view
- add create/edit flow
- add select-existing flow
- add create-new-in-context flow
- add role-aware visibility
- add module-aware visibility

### Shared Frontend Work

Check all that apply:

- update API client
- update session capability model
- update shell/navigation
- update shared widgets
- update empty states
- update validation messages

### Frontend Tests To Add or Update

Check all that apply:

- widget tests
- logic tests
- contract assumptions
- analyze pass

## 7. Data and Migration Checklist

Before marking a phase complete, confirm:

- fresh migration applies cleanly
- fresh seed works
- old data path is known
- required backfill logic exists if needed
- no local-only assumption blocks PostgreSQL later

## 8. Acceptance Checklist

Every phase should have explicit done rules.

### Functional Acceptance

Write concrete checks like:

- user can create X
- user can edit Y
- derived value Z calculates correctly
- role A cannot see module B
- single-station flow behaves differently from multi-station flow where expected

### Technical Acceptance

Confirm:

- backend tests pass
- `flutter analyze` passes if Flutter changed
- `flutter test` passes if Flutter changed
- no known blocking crash remains
- docs are still aligned

## 9. Phase Close-Out Checklist

Before moving to the next phase:

- code edits complete
- tests complete
- docs updated if needed
- roadmap scope unchanged or updated
- progress doc updated if important structure changed
- remaining issues listed clearly
- next phase identified clearly

## 10. Suggested Working Sequence Per Phase

Use this exact order unless a phase is documentation-only.

1. read the roadmap phase
2. read the matching business-rule sections
3. inspect current implementation
4. list files to inspect
5. list files to change
6. implement backend/database work
7. run backend tests
8. implement Flutter or support frontend work
9. run frontend tests
10. run end-to-end local check for that phase
11. update docs if needed
12. close the phase

## 11. Example Filled Template

### Example Phase

- `Phase 1 - Setup Hierarchy Foundation`

### Goal

Build the guided setup structure for brand, organization, station, invoice, tanks, dispensers, and nozzles so the product can be configured cleanly from the start.

### Business Rules Source

- setup flow sections in [SIMPLIFIED_SETUP_AND_ROLE_PLAN.md](/C:/Fuel%20Management%20System/Docs/SIMPLIFIED_SETUP_AND_ROLE_PLAN.md)

### Scope Included

- brand setup
- organization setup
- station setup
- fuel types
- tanks
- dispensers
- nozzles

### Scope Excluded

- payroll
- tanker trips
- cloud deployment

### Files To Inspect First

#### Backend

- current organization model
- current station model
- brand model
- invoice profile model
- tank/dispenser/nozzle models
- setup-related APIs
- setup-related tests

#### Flutter

- onboarding page
- station setup page
- app shell
- API client
- session controller

### Files Expected To Change

#### Backend

- model files
- schema files
- setup APIs
- migrations
- seed file
- setup tests

#### Flutter

- onboarding flow
- station setup flow
- setup widgets
- API client

### Functional Acceptance

- one organization can be created
- one station can inherit from organization
- multiple stations can override as needed
- nozzles map correctly to dispenser, tank, and fuel

### Technical Acceptance

- backend tests pass
- Flutter analyze/test pass
- no setup crash remains

## 12. Final Rule

If a phase starts touching too many unrelated modules, stop and split it.

If a phase cannot be explained simply, it is too large.

If a phase needs too many assumptions, return to the roadmap and simplify it.
