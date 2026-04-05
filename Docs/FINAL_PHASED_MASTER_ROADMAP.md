# PPMS Final Phased Master Roadmap

## 1. Purpose

This document is the final phased execution roadmap for PPMS.

It exists so we do **not** try to redesign:

- backend
- database
- Flutter app
- support console
- dashboards
- reports
- automation
- cloud deployment

all at once.

The goal is to build this system in controlled phases, with clear boundaries, so that:

- each phase is usable and testable
- each phase can be reviewed locally before moving on
- backend and frontend stay aligned
- deployment happens only after the local product is stable

This file should be treated as the main execution roadmap.

## 2. Final Goal

The final target system is:

- FastAPI backend
- PostgreSQL-compatible database design
- Flutter app for desktop/mobile operational use
- separate web support/admin frontend for Master Admin and support work
- GitHub as source control
- Vercel for web frontend hosting
- Amazon EC2 for backend hosting
- automated deployment through GitHub workflows
- later provider integrations such as WhatsApp API, SMS, email, and PDF/document delivery

The product should support:

- SaaS tenant management
- organization and station setup
- dynamic modules
- role-based dashboards
- role-based permissions
- fuel operations
- tankers
- payroll
- ledgers
- reports
- notifications
- documents
- customer support editing from the platform side

## 3. Main Decision: Refactor Current Project or Start New Project?

### Recommendation

**Do not start a new project right now.**

Use the current project as the base and refactor it phase by phase.

### Why

The current project already has:

- backend models
- migrations
- APIs
- service layer
- tests
- Flutter shell and many working screens
- role/module capability work
- local runtime flow

That means we are not starting from zero. A full restart would throw away:

- real progress
- tested paths
- existing design decisions
- current working flows

### When a new project would be justified

Create a new project only if one of these becomes true:

1. the current schema becomes more expensive to reshape than to replace
2. current migration history becomes too broken to maintain cleanly
3. old backend assumptions block the simplified operating model everywhere
4. Flutter screens become so tightly coupled to old APIs that controlled refactor is no longer practical
5. support console and Flutter require a totally separate frontend architecture that cannot be layered cleanly

### Current Call

Right now the correct call is:

- keep the current project
- refactor in phases
- use decision gates
- only branch into a clean-slate rebuild if a later phase proves the current structure too costly

## 4. Working Principle

We will build using this rule:

1. finalize the business rule for a phase
2. update database/model design for that phase
3. update backend API/service layer
4. test locally
5. update Flutter or support frontend for that phase
6. test locally again
7. freeze the phase
8. move to the next phase

We will not build all modules together.

We will not deploy unfinished logic.

We will not redesign everything in one pass.

## 5. Core Product Principles

These principles should guide all later implementation:

### 5.1 Setup Should Be Question-Based

The system setup should feel like a guided business interview, not a wall of forms.

Examples:

- Do you own tankers?
- How many stations do you have?
- Do you use hourly shifts or daily shifts?
- Do you sell lubricants?
- Do you want payroll?
- Do you want optional modules like shop or rental?

Answers should drive:

- shown fields
- module enablement
- dashboard content
- menu visibility
- setup sequence

### 5.2 Hidden Means Hidden

If a module is off:

- no menu item
- no dashboard card
- no section
- no report trace
- no dead placeholder

If a module is read-only:

- it may be visible
- but only in read-only form

### 5.3 Master Data Must Be Reusable

If a customer, supplier, employee, tanker, station, or tank already exists:

- user should select it
- not retype it

Every operational screen should follow:

- choose existing
- or create new in context
- then reuse later

### 5.4 Real Events Should Usually Be Recorded, Not Approved

If something already happened:

- expense happened
- purchase happened
- cash was submitted
- fuel was unloaded

the normal flow should be direct recording.

Approvals should mainly remain for:

- reversals
- corrections
- unusual overrides
- sensitive changes

### 5.5 Operational Truth Must Come From Operational Facts

Examples:

- fuel sales from meter readings
- tank stock from opening + purchase - sales - internal usage
- payroll from base salary + adjustments
- profit from sales - purchase cost - expenses - internal fuel cost

## 6. Build Tracks

This roadmap is split into parallel but controlled tracks.

### Track A - Domain and Database

Focus:

- table design
- relationships
- inheritance rules
- ledger logic
- setup logic
- PostgreSQL-safe structure

### Track B - Backend

Focus:

- FastAPI APIs
- services
- validation
- permissions
- summary endpoints
- report/document/notification endpoints

### Track C - Flutter App

Focus:

- guided setup
- role dashboards
- operations workspaces
- read/write control
- station workflows

### Track D - Master Admin Support Frontend

Focus:

- web frontend for platform support
- organization support tools
- edit/fix tenant values
- platform dashboards
- billing/subscription/module control

### Track E - Deployment and Automation

Focus:

- GitHub workflow
- EC2 deployment
- PostgreSQL migration
- Vercel deployment
- automation and provider integrations

## 7. Phase Structure Overview

This roadmap is divided into controlled phases:

0. lock final business model
1. reshape setup hierarchy
2. reshape operations core
3. reshape finance, ledgers, payroll, and pricing
4. reshape tanker and extended operations
5. reshape notifications, documents, and reports
6. complete role and module system
7. complete Flutter guided setup and workspaces
8. build Master Admin support frontend
9. local stabilization and full acceptance testing
10. cloud deployment and automation

Each phase below includes:

- objective
- included work
- excluded work
- expected edits
- acceptance criteria
- decision gate

## 8. Phase 0 - Lock the Business Model

### Objective

Freeze the final high-level operating model before more coding.

### Included

- finalize setup hierarchy:
  - brand
  - organization
  - station
  - invoice
  - tanks
  - dispensers
  - nozzles
- finalize fuel types and module questions
- finalize role hierarchy:
  - Master Admin
  - Organization Admin
  - Station Admin
  - Shift Manager
  - Accountant optional
- finalize single-station merge rule
- finalize operations logic:
  - meter-based fuel sales
  - shift cash
  - meter adjustments
  - internal fuel
  - purchases
  - customer/supplier reuse
- finalize tanker phase-1 model
- finalize payroll and ledger direction
- finalize notification/report/document direction

### Excluded

- production deployment
- deep UI polishing
- full support console implementation

### Expected Edits

- documentation only
- maybe small naming cleanups

### Acceptance Criteria

- docs match each other
- no major business contradictions remain
- setup questions are agreed
- roles and module rules are agreed

### Decision Gate

Do not start heavy backend refactors until this phase is accepted.

## 9. Phase 1 - Setup Hierarchy Foundation

### Objective

Build the final setup structure for brand, organization, station, invoice, and forecourt base.

### Included

- brand catalog
- organization setup
- station setup
- single-station vs multi-station inheritance
- invoice profile inheritance/override
- fuel type setup
- tank setup
- dispenser setup
- nozzle setup
- prerequisite reuse model

### Required Database Work

- normalize:
  - brands
  - organizations
  - stations
  - invoice_profiles
  - fuel_types
  - tanks
  - dispensers
  - nozzles
- make fields PostgreSQL-safe
- add clear inheritance/override rules

### Required Backend Work

- setup wizard APIs
- create/update/select existing flows
- inheritance-aware summary payloads
- validation for tank/dispenser/nozzle mapping

### Required Flutter Work

- replace heavy setup forms with guided setup flow
- add question-based steps
- add summary/review step
- visual forecourt mapping board

### Excluded

- full payroll
- full tanker analytics
- advanced notifications

### Acceptance Criteria

- one organization can be created cleanly
- one or multiple stations can be configured cleanly
- tanks, dispensers, and nozzles can be created without duplicate entry confusion
- invoice identity resolves correctly

### Decision Gate

If setup flow becomes too tangled in the current codebase, stop and decide whether setup should be isolated into a clean dedicated module first.

## 10. Phase 2 - Operations Core

### Objective

Make daily fuel-station operations correct and fact-based.

### Included

- shift templates
- daily/hourly/custom shift model
- 24 hour shift support
- shift creation rules
- automatic carry forward
- opening cash
- cash submission
- multiple deposit support
- meter readings
- meter segments
- meter adjustments
- meter reverse permission rules
- meter-based fuel sales
- tank-volume calculation
- internal fuel usage
- station expense recording

### Required Database Work

- define or reshape:
  - shifts
  - meter_readings
  - meter_segments
  - shift_cash
  - cash_submissions
  - meter_adjustments
  - internal_fuel_usage
  - expenses

### Required Backend Work

- shift APIs
- opening/closing flows
- meter-read validation
- sales quantity derivation
- stock update logic
- shift cash reconciliation endpoints

### Required Flutter Work

- shift setup wizard and station setting flows
- shift console redesign
- meter opening/closing screens
- cash handover/submission UX
- sales views should become fact-led, not manual-entry led

### Excluded

- final advanced reports
- support-console editing

### Acceptance Criteria

- a station can run a full shift locally
- fuel sales derive from meter facts
- cash and meter flows match
- tank quantities update correctly

### Decision Gate

If existing sales APIs are too manual-entry-based to refactor safely, isolate a new operations service layer instead of patching business logic in UI-facing endpoints.

## 11. Phase 3 - Finance, Ledgers, Payroll, Pricing

### Objective

Build the minimum real finance layer required for operations and reporting.

### Included

- customers with reusable master records
- suppliers with reusable master records
- customer auto code generation
- customer ledger
- supplier ledger
- payments
- credit balances
- fuel price history
- employees
- salary adjustments
- payroll runs and lines

### Required Database Work

- normalize existing customers/suppliers instead of parallel duplicate tables where possible
- introduce or refine:
  - customer ledger entries
  - supplier ledger entries
  - fuel_prices
  - employees
  - salary_adjustments
  - payroll_runs
  - payroll_lines

### Required Backend Work

- customer/supplier select-or-create APIs
- ledger-summary endpoints
- pricing-history endpoints
- payroll generation endpoints
- payroll adjustment flows

### Required Flutter Work

- parties workspace redesign around reusable master records
- finance workspace redesign around ledger-first views
- payroll workspace redesign around monthly runs, not isolated rows only

### Excluded

- full BI/analytics
- external accounting integration

### Acceptance Criteria

- customer and supplier balances are traceable
- payments affect ledgers correctly
- employee monthly payroll can be generated
- salary adjustments work correctly

### Decision Gate

If current customer/supplier models are too fragmented, pause and merge them cleanly before more finance UI work.

## 12. Phase 4 - Tanker and Extended Operations

### Objective

Build the simplified manager-based tanker module without over-engineering logistics.

### Included

- tanker ownership question
- tanker master
- compartment definition
- tanker trip entry
- manager-summary fuel purchases
- automatic compartment mapping
- manual tanker sales
- leftover fuel transfer to station tanks
- tanker-linked expenses

### Required Database Work

- normalize or add:
  - tankers
  - tanker_compartments
  - tanker_trips
  - fuel_purchases or trip-specific purchase structure
  - tanker_trip_loads
  - fuel_sales_manual
  - fuel_transfers
- extend expenses with optional tanker references if required

### Required Backend Work

- tanker setup APIs
- trip summary entry APIs
- automatic load assignment logic
- leftover transfer logic
- tanker summary/report endpoints

### Required Flutter Work

- tanker setup questions inside organization/station configuration when relevant
- tanker workspace redesign around trip summary
- separation between station forecourt sales and tanker manual sales

### Excluded

- advanced fleet telematics
- GPS tracking
- route optimization

### Acceptance Criteria

- manager can record a tanker trip
- load, sale, and transfer facts are stored correctly
- tanker leftovers can be moved into station tanks

### Decision Gate

If tanker complexity starts distorting the core station product, keep it modular and behind a tanker-enabled organization module only.

## 13. Phase 5 - Notifications, Documents, Reports, Profit

### Objective

Build communication and reporting on top of stable operational facts.

### Included

- notification settings
- message templates
- send logs
- PDF/document registry
- attachments
- report definitions or report engine
- report filters
- multi-station reporting
- profit summaries
- dashboard summary services

### Required Database Work

- extend or normalize:
  - notification settings
  - message templates
  - notification logs
  - document registry
  - attachments
  - saved reports/report definitions
  - optional profit cache

### Required Backend Work

- template endpoints
- notification dispatch/log APIs
- document generation/download/send APIs
- filtered report endpoints
- profit summary endpoints
- dashboard aggregation endpoints

### Required Flutter Work

- notification settings UX
- document center improvements
- report filter screens
- role dashboard data refinement

### Excluded

- final provider integration credentials in production
- heavy BI tooling

### Acceptance Criteria

- reports are filterable and meaningful
- document flows work locally
- notifications can be templated and logged
- dashboard summaries reflect real operational data

### Decision Gate

Do not integrate external providers yet if the local template and dispatch model is not stable.

## 14. Phase 6 - Roles, Permissions, Modules, SaaS Rules

### Objective

Finish dynamic visibility, package logic, and role hierarchy.

### Included

- Master Admin
- Organization Admin
- Station Admin
- Shift Manager
- Accountant optional
- single-station merge rule
- package model
- module model
- organization subscriptions
- dynamic role and module visibility
- dip chart/calibration permission rules
- dip chart calibration permission
- meter reverse permission rules

### Required Database Work

- normalize:
  - packages
  - package_modules
  - organization_subscriptions
  - modules
  - organization_modules
- confirm role and scope relationships

### Required Backend Work

- package APIs
- subscription APIs
- module activation APIs
- role-assignment rules
- capability summary endpoints

### Required Flutter Work

- visibility driven by capability map only
- role-aware setup questions
- role-aware dashboards and menus
- zero ghost modules

### Required Support Frontend Work

- package and subscription controls
- module toggles
- tenant activation/deactivation

### Acceptance Criteria

- module changes change the app immediately and correctly
- single-station organizations do not carry useless admin duplication
- role scope is clear and enforced

### Decision Gate

If permissions remain scattered across backend files, centralize them before adding more role-specific UI.

## 15. Phase 7 - Flutter App Completion

### Objective

Make Flutter the complete tenant/station operations app.

### Included

- guided setup flow
- role dashboards
- refined workspaces:
  - setup
  - admin
  - sales
  - shifts
  - finance
  - parties
  - inventory
  - tankers
  - payroll
  - reports
  - documents
  - notifications
- question-based setup and configuration
- visual summaries instead of form-only screens

### UX Direction

- dashboards first
- summary cards first
- context panels first
- create/edit forms secondary
- drag-and-drop only where truly useful

Good drag/drop candidates:

- forecourt mapping
- dashboard widget layout later

Bad drag/drop candidates:

- customer create
- supplier create
- salary entry
- expense entry

### Acceptance Criteria

- each role has a coherent dashboard
- each workspace respects modules and permissions
- app is locally reviewable end-to-end

### Decision Gate

If Flutter setup/admin flows become too support-heavy, move those capabilities into the separate web support frontend instead of overloading the operations app.

## 16. Phase 8 - Master Admin Support Frontend

### Objective

Build a dedicated web frontend for Master Admin and support work.

### Why Separate

Flutter should remain the tenant/station operational product.

The support console should be optimized for:

- support
- editing
- investigation
- package control
- subscription management
- issue fixing
- dashboard and report review

### Included

- Node.js web frontend
- Master Admin login
- platform dashboard
- organization search/open
- tenant profile editing
- station editing
- module toggling
- support-side value correction tools
- report viewing
- notification configuration
- customer support workflows

### Required Backend Work

- support-focused summary APIs
- support edit endpoints where appropriate
- audit-safe correction flows

### Acceptance Criteria

- Master Admin can log in
- open tenant accounts
- inspect and edit what the organization needs corrected
- control packages/modules/subscriptions cleanly

### Decision Gate

If support flows start to overlap too heavily with tenant-admin flows, keep the data shared but keep the UI separate.

## 17. Phase 9 - Local Stabilization and Acceptance

### Objective

Freeze the product locally before cloud deployment.

### Included

- local PostgreSQL compatibility testing
- migration validation
- fresh database rebuild validation
- test data seeding
- role-by-role walkthroughs
- setup walkthroughs
- end-to-end operational walkthroughs
- report and document generation testing
- notification mock testing
- bug fixing

### Required Checks

- backend tests
- Flutter analyze/test
- local smoke flows
- fresh setup from empty database
- single-station scenario
- multi-station scenario
- tanker-enabled scenario
- minimal-module scenario

### Acceptance Criteria

- product can be demoed locally from empty database
- setup flow is stable
- no major role confusion remains
- no major duplicate-entry problems remain

### Decision Gate

Do not start production deployment until this phase is signed off.

## 18. Phase 10 - Deployment, Automation, and Integrations

### Objective

Move the stable local system online in a controlled way.

### Included

- EC2 backend deployment
- PostgreSQL deployment
- environment configuration
- GitHub source-of-truth workflow
- GitHub Actions for deployment
- Vercel deployment for support/web frontend
- migration automation
- backup automation
- later WhatsApp/SMS/email provider integration

### Deployment Target

- backend on Amazon EC2
- PostgreSQL-compatible schema migrated cleanly
- web support frontend on Vercel
- GitHub for code submissions
- automated deployment after local stability

### Acceptance Criteria

- backend deploys from GitHub cleanly
- support frontend deploys from GitHub cleanly
- database migrations run safely
- backups exist
- notifications can later be connected to real providers without redesign

## 19. Editing Estimate by Phase

### Light

- Phase 0
- parts of Phase 5 docs and settings

### Medium

- Phase 1
- Phase 6
- Phase 8

### Medium to Heavy

- Phase 3
- Phase 7

### Heavy

- Phase 2
- Phase 4
- Phase 9 stabilization

This means the biggest change areas are:

- operations core
- tanker logic
- finance/ledger normalization
- final local stabilization

## 20. Recommended Immediate Order

This is the correct order to start now:

1. finish Phase 0 document cleanup and lock
2. execute Phase 1 setup hierarchy foundation
3. execute Phase 2 operations core
4. execute Phase 3 finance, ledgers, payroll, pricing
5. execute Phase 4 tanker module
6. execute Phase 5 notifications, documents, reports
7. execute Phase 6 role/module/package completion
8. execute Phase 7 Flutter completion
9. execute Phase 8 support frontend
10. execute Phase 9 local freeze
11. execute Phase 10 deployment

## 21. What We Should Not Do

We should not:

- rebuild everything at once
- deploy before local stabilization
- create parallel duplicate models when existing ones can be normalized
- let Flutter become both station app and full support console
- tie UI too tightly to unstable APIs
- add real provider integrations before local behavior is correct

## 22. First Action After This Roadmap

The first practical action after this file is:

### Action 1

Clean and lock the planning docs:

- this roadmap
- simplified setup and role plan
- next phase plan
- current progress

### Action 2

Start actual implementation with:

**Phase 1 - Setup Hierarchy Foundation**

because that is the cleanest place to begin the controlled refactor.

## 23. Final Summary

The correct call is:

- keep the current project
- refactor it in phases
- do not start a new project yet
- use the current backend and Flutter work as the foundation
- build the support frontend separately later
- deploy only after local completion and acceptance

This roadmap is the main execution guide for that work.
