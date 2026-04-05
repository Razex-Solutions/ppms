# Next Phase Implementation Plan

## Purpose

This document defines the next implementation phase for PPMS after the current backend and Flutter foundation work. The goal is to stop working in an ad hoc way and move into a structured delivery plan that:

1. finishes the product properly on the local development machine first
2. simplifies and restructures setup around question-based onboarding and configuration
3. stabilizes roles, permissions, dashboards, and workflows
4. improves the UX from form-heavy CRUD into an operational product
5. adds a dedicated support-facing Master Admin web console in Node.js
6. prepares the codebase for a later automated online deployment flow

This plan is intentionally local-first for now. Online hosting, automation, and production deployment are part of the later phases, not the current execution focus.

End-state goal:
- Master Admin should be able to sign in through the frontend using the platform account
- open any organization account
- inspect and edit what the organization needs corrected
- provide customer support directly from the support-facing frontend
- while the backend remains FastAPI-based and PostgreSQL-compatible for later cloud deployment

---

## Current Direction

The product is now split into three future-facing layers:

1. Backend API
   - FastAPI
   - PostgreSQL-ready data model
   - permissions, modules, organizations, stations, staff, documents, reports, governance

2. Main operational client
   - Flutter
   - Windows desktop now
   - Android/iOS later
   - role-aware operational client for tenant organizations and stations

3. Platform support console
   - Node.js frontend, to be created next
   - specifically for Razex Solutions platform support / Master Admin work
   - used to inspect, fix, override, and support customer organizations and stations
   - Master Admin logs in with platform credentials and can open tenant accounts to support-edit values when needed

Later deployment target:
- backend on Amazon EC2
- web frontend on Vercel
- source code on GitHub
- automated delivery after local completion and stabilization
- notification providers such as WhatsApp/SMS/Email connected with real credentials later

This plan must now also follow the newer simplification rules from:
- [Docs/SIMPLIFIED_SETUP_AND_ROLE_PLAN.md](/C:/Fuel%20Management%20System/Docs/SIMPLIFIED_SETUP_AND_ROLE_PLAN.md)

That means:
- setup becomes question-based
- single-station organizations must stay simpler than multi-station organizations
- unnecessary tenant admin layers should be avoided when only one station exists
- fuel, shifts, meters, cash, and tank volume should be treated as one connected operating model

---

## Core Working Principle

We will not try to finish all roles, dashboards, API reshaping, drag-and-drop mapping, and deployment at the same time.

The correct order is:

1. lock the simplified setup and operating model
2. stabilize architecture and role behavior
3. complete role experiences one by one
4. improve visuals and dashboard quality
5. add the Master Admin support web frontend
6. only then move to cloud deployment and automation

---

## Simplified Setup And Operations Rule

This is now a core planning rule, not an optional refinement.

The setup/configuration side must move toward:
- brand -> organization -> station -> invoice -> tank -> dispenser -> nozzle
- guided questions instead of large forms
- inheritance-first data entry
- simpler role trees for single-station organizations
- richer role trees only when multi-station complexity actually exists

The operating model must also move toward:
- fuel-type setup
- shift-template setup
- meter-based sales
- shift cash tracking
- multiple cash submissions
- meter adjustment handling
- meter segment handling
- automatic tank-volume movement from purchases and sales
- monthly payroll with adjustments
- customer and supplier ledger tracking
- fuel price history
- notification templates and channel settings
- PDF/document registry and attachments
- reporting and profit-summary architecture
- reusable master-data selection flows with create-new-in-context behavior

This means the next phase is not only “dashboard polish.”
It is also a setup and operations redesign phase.

For tankers, the first target should be:
- a simplified manager-based tanker module
- summary trip entry
- automatic compartment mapping
- manual trip sales separate from forecourt meter sales
- leftover fuel transfer into station tanks

It should not start as a full telematics-heavy fleet system.

Another core UX rule:
- users should select existing master records where possible
- and only create new customers, suppliers, tankers, employees, or similar masters when needed
- those records should then carry forward for later selection instead of being re-entered repeatedly

---

## Dynamic Module and Permission-Driven UI Rule

This is now a hard product rule for both Flutter and the future Node.js support frontend.

The UI must be driven by:

1. enabled organization modules
2. enabled station modules
3. actual role permissions/actions
4. scope level
5. read-only versus editable access

This means:

- if a module is off, it should disappear from menus, dashboards, shell navigation, and entry points
- if a module is on, its menu/dashboard presence should appear automatically
- if a user only has read access, the module may remain visible, but only in a read-only form
- if a user has no access at all, there should be no visible trace of that module
- dashboards must change automatically based on currently enabled modules and actual granted rights
- onboarding/setup changes must flow through to the visible app structure without needing manual frontend rewiring each time

Examples:

- if `tankers` is off for a station, no `Tankers` tab, cards, totals, or setup prompts should appear
- if `hardware` is off, no hardware panel or meter tools should appear
- if `payroll` is read-only, the payroll workspace can appear but should not show create/finalize controls
- if `governance` actions are not granted, approval queues should disappear
- if `HeadOffice` can read reports but not edit setup, reports remain visible while setup controls do not

This rule applies to:

- shell navigation
- dashboard cards
- quick actions
- detail panels
- setup wizards
- admin pages
- support console pages

This also means we should reduce hardcoded frontend assumptions like:
- “all users see the same module tabs”
- “if one role sees a module, all similar roles should see it”
- “menu is static and only the inner page changes”

Instead, the product should behave as a dynamic capability-driven application.

---

## Default Automation Rule

The next phase should assume that most station operations are recorded directly once they happen.

Default product stance:
- operational events should be automated and post-fact
- approval should not be the normal path for everyday station work

This applies especially to:
- expenses that are already spent
- purchases that already happened
- cash submissions already received
- tanker deliveries already unloaded
- normal operating records

Approval should be treated as optional and limited to exceptional controls such as:
- reversals
- unusual credit overrides
- sensitive support/admin corrections
- exceptional write-offs

---

## Product Layers and Ownership

## 1. Backend

The backend remains the source of truth for:
- auth and sessions
- organizations and stations
- role and permission enforcement
- module toggles
- dashboards and reports
- sales, shifts, payroll, finance, POS, tankers, hardware, documents
- auditability and support overrides

Backend work still expected during the next phase:
- API reshaping for Flutter and web dashboards
- role-specific dashboard summary endpoints
- support/admin override endpoints where appropriate
- cleaner setup and mapping APIs
- bug fixes revealed by role-by-role UI testing

## 2. Flutter client

Flutter remains the main customer-facing operational app for:
- tenant organizations
- station teams
- daily operations
- role-scoped dashboards and workflows

Flutter is not yet considered complete.

Remaining work is not just bug fixing:
- role-specific flow completion
- better dashboards
- more visual interactions
- less raw CRUD feeling
- platform-appropriate mobile/desktop behavior
- dynamic shell/menu/dashboard composition based on modules and granted actions

## 3. Master Admin support frontend

We will create a separate Node.js frontend for Razex Solutions only.

This is not the same as the Flutter tenant-facing app.

It will be used for:
- organization onboarding oversight
- subscription/trial visibility
- tenant support and troubleshooting
- direct inspection and controlled edits
- emergency overrides and operational support
- customer-service workflows
- system-level dashboards across all customer organizations

This frontend should not be mixed into the tenant Flutter UX.

---

## Local-First Rule

For the next major phase:

- all main feature work happens locally
- all role and workflow fixing happens locally
- all UI and API alignment happens locally
- GitHub remains source control, not the primary runtime environment
- EC2 and Vercel are deferred until the local product is stable enough

Deployment planning is included in this document, but deployment execution comes later.

---

## Phase 0. Lock The Simplified Setup And Operating Model

Goal:
- finalize the new simplified setup direction before more UI patching spreads old assumptions further

Tasks:
1. lock brand, organization, station, invoice inheritance rules
2. lock single-station vs multi-station role behavior
3. lock question-based setup flow
4. lock fuel-type setup behavior
5. lock shift setup behavior
6. lock meter-based sales behavior
7. lock shift cash and multiple cash submissions behavior
8. lock meter adjustment and meter segment behavior
9. lock automatic tank-volume logic

Expected output:
- one stable business/architecture model for setup and operations
- fewer conflicting assumptions between backend and Flutter

Backend impact:
- high, because this phase decides what later APIs and schema reshaping must support

Priority:
- immediate

---

## High-Level Execution Order

## Phase 1. Stabilize the Flutter foundation

Goal:
- remove crashes
- remove stale dropdown/state issues
- ensure each workspace respects role and scope correctly
- make navigation and dashboard composition capability-driven

Tasks:
1. audit all major dropdown-driven screens for stale selection bugs
2. normalize list loading and selected-value validation
3. audit all role-aware screens for fake edit/delete power
4. fix shell transitions between platform users and tenant users
5. ensure support for empty states and missing setup data
6. centralize module/permission visibility rules for menus, dashboards, and quick actions

Expected output:
- stable app shell
- stable station setup
- stable sales/setup/admin list screens
- dynamic visibility rules used consistently across the app

Backend impact:
- minimal, mostly bug fixes if API responses reveal inconsistencies

Priority:
- immediate

---

## Phase 2. Complete role and scope model in the UI

Goal:
- make the app feel genuinely different for each role
- remove shared generic screens pretending to support everyone the same way

Execution order:
1. MasterAdmin
2. HeadOffice
3. StationAdmin
4. Manager
5. Accountant
6. Operator
7. profile-only staff flows

For each role we must define:
- default dashboard
- visible navigation
- read-only vs editable modules
- creation rights
- approval rights
- reporting rights
- support-only capabilities
- module-on/module-off behavior
- read-only visibility behavior

Expected output:
- real role-specific experience
- fewer permission surprises
- less need for users to guess what they can do

Backend impact:
- role summary expansion
- role-specific dashboard endpoints
- permission metadata cleanup

Priority:
- immediate after stabilization

---

## Phase 3. MasterAdmin in Flutter: complete platform experience

Goal:
- finish the platform-side operational experience inside Flutter first

MasterAdmin must support:
1. platform dashboard
   - total organizations
   - active trials
   - expiring plans
   - setup-pending organizations
   - outstanding support signals

2. onboarding flow
   - create organization through question-based setup
   - pick brand
   - create first stations
   - simplify admin creation for single-station organizations
   - create first org-level admin path for multi-station organizations

3. station setup flow
   - station flags
   - fuel types
   - shift model
   - tank/dispenser/nozzle setup
   - invoice identity basics
   - module toggles

4. operating model setup
   - meter-based sales configuration
   - shift cash model visibility
   - cash submission behavior
   - meter adjustment behavior

5. organization inspection
   - open company profile
   - inspect stations
   - inspect users
   - inspect setup completeness

6. support tools
   - controlled fixes
   - value correction
   - support note flows later

Expected output:
- platform side becomes complete enough for internal use

Backend impact:
- likely need richer org/station summary endpoints
- likely support-facing override endpoints

Priority:
- high

---

## Phase 4. HeadOffice experience

Goal:
- make HeadOffice an oversight role, not a station operator clone

HeadOffice dashboard should focus on:
- organization-wide sales
- cash vs credit mix
- receivables and payables
- expense approvals
- station comparison
- tanker summary
- alerts and exceptions

HeadOffice workflows:
- reports
- governance/approvals
- documents
- user and station visibility
- organization-level views

HeadOffice should avoid:
- forecourt-heavy direct entry screens by default
- raw setup/control that belongs to MasterAdmin or StationAdmin

Expected output:
- oversight-oriented UI

Backend impact:
- stronger org summary APIs
- richer multi-station report payloads

Priority:
- high

---

## Phase 5. StationAdmin experience

Goal:
- make StationAdmin the real station-control user

StationAdmin dashboard should focus on:
- station readiness
- live stock
- sales
- shifts
- staff
- modules enabled
- local alerts

StationAdmin workflows:
- station setup and maintenance
- inventory
- parties
- users/staff
- finance visibility
- documents

Expected output:
- station control center

Backend impact:
- maybe convenience endpoints for station summary

Priority:
- high

---

## Phase 6. Manager experience

Goal:
- make Manager the daily operations role

Manager dashboard:
- today’s sales
- shifts
- handover/cash context
- low stock alerts
- pending operational work

Manager workflows:
- sales
- shifts
- expenses
- selected finance flows
- tanker ops if enabled

Expected output:
- faster daily operating flow

Backend impact:
- cash handover APIs may be needed later
- shift summary APIs likely helpful

Priority:
- medium-high

---

## Phase 7. Accountant experience

Goal:
- make Accountant finance-first and cleaner

Accountant dashboard:
- collections
- receivables
- payables
- expense summaries
- document dispatches
- profit trends

Accountant workflows:
- customer payments
- supplier payments
- reports
- financial documents
- expense review visibility

Expected output:
- finance workspace without operational clutter

Backend impact:
- finance summary payload refinement

Priority:
- medium-high

---

## Phase 8. Operator experience

Goal:
- make Operator minimal and fast

Operator dashboard:
- current station
- active shift
- today’s sales
- attendance prompt

Operator workflows:
- sales
- shifts
- attendance
- maybe limited hardware visibility

Expected output:
- simple workflow for daily station use

Backend impact:
- low

Priority:
- medium

---

## Phase 9. Staff profile and profile-only flows

Goal:
- support non-login staff properly

Profile-only staff examples:
- tanker driver
- helper
- attendant
- mechanic
- cleaner

Needed work:
- staff listing and editing
- optional link-to-login path
- role separation from app logins
- later payroll/attendance support via staff profile model if required

Expected output:
- cleaner employee model

Backend impact:
- possible payroll/attendance expansion to employee profiles later

Priority:
- medium

---

## Phase 10. Dashboard redesign and visual quality

Goal:
- move away from a heavy form wall
- make dashboards graphical and easier to understand

Visual upgrade targets:
1. charts
   - pie charts
   - bar charts
   - trend charts
   - status cards

2. interactive operational surfaces
   - station setup summary panels
   - mapping summary blocks
   - review side panels
   - detail drawers

3. drag-and-drop where it actually helps
   - tank/dispenser/nozzle mapping
   - maybe dashboard card ordering later

Do not force drag-and-drop on everything.

Best candidates:
- forecourt mapping
- visual station layout mapping

Bad candidates:
- customers
- suppliers
- finance forms
- user creation forms

Expected output:
- more modern operational product feel
- dashboards automatically shape themselves around enabled modules and granted actions

Backend impact:
- maybe dedicated mapping payloads
- maybe richer dashboard analytics endpoints
- maybe explicit capability/menu payloads for frontend composition

Priority:
- after role flows are stable

---

## Phase 11. Node.js Master Admin support frontend

Goal:
- create a separate support console for Razex Solutions

Why separate:
- Flutter should stay tenant-facing and operations-oriented
- platform support needs a web tool that is faster to iterate for customer service

Suggested stack:
- Next.js
- TypeScript
- Tailwind or component system of choice
- connect directly to PPMS backend APIs

Core features:
1. platform login for MasterAdmin/support
2. organization search and open
3. subscription/trial visibility
4. station setup inspection
5. user and staff inspection
6. support-side edits and overrides
7. global issue dashboard
8. customer service tooling
9. role-aware dashboards, reports, and notification controls for support operations

Additional expected support capabilities:
- open a tenant account from the support console
- inspect customer/supplier/employee/tanker/ledger state
- correct values the organization requests corrected
- review documents, notifications, and reporting health

Expected output:
- support console separate from tenant app

Backend impact:
- may require support/admin endpoints
- may require platform search/list APIs
- may require safer override logging

Priority:
- after Flutter role completion reaches a stable state

---

## Phase 12. Backend API refinement for frontends

Goal:
- reduce frontend complexity
- make backend payloads more suitable for dashboards and support tools

Likely backend API improvements needed:
1. role-specific dashboard summary endpoints
2. organization summary endpoint
3. station setup completeness endpoint
4. forecourt mapping summary endpoint
5. question-based setup payloads for organization/station creation
6. shift-template setup endpoints
7. meter-based sales and shift cash endpoints
8. support/admin override endpoints
9. better search/filter endpoints
10. more compact list payloads
11. richer detail payloads for selected-item side panels
12. explicit module/capability payloads for dynamic menu and dashboard composition
13. payroll-adjustment and ledger summary endpoints
14. fuel-price history endpoints
15. notification template and send-log endpoints
16. document registry / attachment endpoints
17. report-definition and profit-summary endpoints
18. search-select-create-new endpoints/patterns for reusable master data

API direction should also prefer:
- direct operational posting endpoints for real-world facts
- optional policy checks instead of mandatory approval queues
- lighter approval usage only for exceptional controls

Expected output:
- less frontend data stitching
- better performance and maintainability

Priority:
- ongoing throughout Phases 2 to 11

---

## Phase 13. Local full review and acceptance pass

Goal:
- treat local as staging before real online deployment

Review checklist:
1. MasterAdmin full onboarding flow
2. Station setup flow
3. HeadOffice role review
4. StationAdmin role review
5. Manager role review
6. Accountant role review
7. Operator role review
8. staff-profile review
9. documents and dispatch review
10. charts/dashboard review
11. support-console review once built

Expected output:
- product stable enough for real deployment

Priority:
- mandatory before cloud deployment

---

## Phase 14. Cloud deployment preparation

This phase starts only after local completion is good enough.

Target:
- backend on Amazon EC2
- web frontend on Vercel
- code on GitHub
- automated deployment

Steps:
1. production env file strategy
2. Docker Compose or equivalent deployment setup
3. PostgreSQL on EC2 first
4. domain and HTTPS
5. GitHub Actions deployment workflow
6. Vercel hookup for web frontend
7. later Flutter CI/CD for desktop/mobile builds
8. real notification-provider integration such as WhatsApp API, SMS, and email credentials
9. full automated pipeline from GitHub to EC2/Vercel where appropriate

Important:
- deployment is a later phase, not current main work

---

## Recommended Immediate Working Order

This is the practical order we should follow next:

1. lock simplified setup and operating rules
2. backend data-model and API reshaping for setup/operations
3. Flutter stabilization pass
4. MasterAdmin completion in Flutter
5. HeadOffice completion
6. StationAdmin completion
7. Manager completion
8. Accountant completion
9. Operator completion
10. staff-profile flow refinement
11. dashboard/chart redesign
12. Node.js Master Admin support frontend
13. backend API refinement where UI needs it
14. full local review pass
15. deployment preparation
16. online automation

---

## Immediate Next Steps

The next actions after this plan are:

1. compare the simplified setup and operating plan against the current backend schema
2. list exact model/API mismatches before editing
3. finish the current Flutter crash/stability fixes
4. create a centralized module/permission visibility map for Flutter
5. create a role-by-role implementation checklist for Flutter
6. begin with MasterAdmin and complete it fully before moving lower
7. note every backend API gap discovered during each role pass
8. implement backend adjustments only when justified by the UI flow

---

## Notes

- Local machine remains the main development environment.
- GitHub remains the source-control hub.
- EC2 is prepared for later deployment, not the current main runtime.
- Vercel is for future web frontends, not for Flutter desktop/mobile.
- The Node.js frontend is a separate support/admin product surface, not a replacement for Flutter.
