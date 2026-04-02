# PPMS Implementation Gap Analysis

## Purpose

This document compares the product vision in `Docs/PUMP MANAGEMENT SYSTEM.docx` with the current codebase in `ppms/` and translates that gap into a realistic delivery roadmap.

## Executive Summary

The DOCX describes a full commercial PPMS platform:

- Windows desktop application
- Android mobile application
- cloud backend
- offline-first local operation with synchronization
- hardware integrations
- accounting, payroll, POS, notifications, compliance, and SaaS expansion

The current repository is still not that full platform yet.

It is now a substantially hardened backend pilot focused on:

- authentication
- organizations, stations, roles, and users
- fuel types, tanks, dispensers, nozzles
- fuel sales
- customers and suppliers
- purchases and payments
- shifts
- tank dips
- dashboard, reports, audit logs, ledger/profit reporting
- POS product and sale workflows
- hardware device registry and simulator ingestion
- approval workflows for expenses

That means the project is currently in a **late Phase 1 / early Phase 2 backend pilot** stage, not in the full product stage described in the DOCX.

## Current System Snapshot

### What exists today

- FastAPI backend in `ppms/app`
- SQLite persistence
- Alembic migrations
- JWT login plus password change/reset
- CRUD APIs for core operational entities
- role and permission enforcement with organization/station scoping
- audit logging
- modular startup with `ENABLED_MODULES`
- service-layer business logic for major operational flows
- dashboard, reports, accounting summaries, and organization-aware read paths
- expense approval workflow
- POS backend module
- hardware backend module with simulator endpoints
- seed script for initial data
- automated API test coverage across modules

### What does not exist today

- desktop client
- mobile client
- sync engine
- real device vendor adapters
- notification services
- payroll
- compliance / invoicing
- SaaS tenancy and billing

## Module Status Matrix

Status definitions:

- `Done`: present and usable at a basic product level
- `Partial`: present but materially incomplete versus the DOCX
- `Missing`: not implemented in this repository

| Module / Capability | Status | Notes |
| --- | --- | --- |
| Authentication | Partial | Login, password change, and admin reset exist; session control, lockout, MFA, and richer auth security still do not |
| Role-based access control | Partial | Permission matrix and enforcement are much stronger now, including `HeadOffice`, but not yet fully data-driven or enterprise-grade |
| Multi-station support | Partial | Organization model and head-office read scope now exist, but this is not yet a full tenant / centralized governance design |
| User management | Partial | CRUD exists with admin-only mutations and head-office read scope; delegated provisioning and approval flows are still missing |
| Fuel sales management | Partial | Core sale entry, validation, safe reversal, and reporting exist, but no real device integration, approval workflow, or invoice layer |
| Nozzle monitoring / reading history | Partial | Manual reading progression exists through sales and history records |
| Tank inventory management | Partial | Tanks, dips, and stock movement reporting exist, plus hardware probe simulation; calibration charts and deeper reconciliation are still missing |
| Purchase management | Partial | Purchases and safe reversal exist, but no purchase approvals, returns, shortage workflows, or vendor performance tracking |
| Customer credit management | Partial | Basic credit sales and payments exist, but no vehicle/company hierarchy, monthly billing, statements workflow, or reminder engine |
| Supplier management | Partial | Basic supplier CRUD and payments exist, but no richer supplier operations or performance tracking |
| Accounting module | Partial | Profit summary, ledgers, payments, and approved-expense handling exist; no chart of accounts, bank/cash, statements, or rules engine |
| Shift management | Partial | Open/close shift and variance reporting exist, but no supervisor approval, attendance tie-in, or richer shift governance |
| Reporting and analytics | Partial | Dashboard and organization-aware operational reports exist; no scheduled reports, export system, comparative analytics, or BI layer |
| Audit trail / fraud prevention | Partial | Audit log exists and critical actions are recorded, but fraud rules, anomaly detection, and deeper review workflows are still missing |
| Attendance and payroll | Missing | Not modeled |
| POS for shop/services | Partial | POS product and sale backend exists, but no richer retail workflows, UI, or advanced stock/accounting integration |
| Notification system | Missing | No SMS, WhatsApp, email, push, or in-app alerts |
| Government compliance / digital invoicing / tax | Missing | Not modeled |
| Desktop application | Missing | No Windows application in this repo |
| Android mobile application | Missing | No mobile app in this repo |
| Offline-first local operation | Missing | SQLite exists, but not as a designed offline-sync architecture |
| Synchronization engine | Missing | No sync jobs, queue, conflict resolution, or local/cloud reconciliation |
| Hardware integration | Partial | Hardware device registry, event logging, and simulated dispenser/tank-probe ingestion exist; no real vendor adapters yet |
| SaaS subscription platform | Missing | No tenant onboarding, subscription billing, or customer management portal |
| Monitoring / observability | Partial | Structured logging, request IDs, centralized error handling, and health checks exist; no alerts or ops dashboard |

## What The Codebase Is Ignoring Today

These are the most important DOCX expectations that the current implementation largely ignores:

### 1. Product shape

The DOCX is centered on a hybrid product:

- station desktop app
- cloud backend
- mobile monitoring app
- offline operation and sync

The current repo only contains the backend API.

### 2. Offline-first design

The DOCX treats offline mode and synchronization as critical. The current SQLite usage is just local persistence, not a real offline-first architecture.

Missing pieces include:

- local event queue
- sync scheduler
- conflict resolution rules
- station sync status
- backup-before-sync flow
- cloud/local separation

### 3. Hardware integration

The DOCX repeatedly treats dispenser, tank probe, printer, and device integration as major project phases. The codebase now has a hardware foundation, but still not true live integration.

### 4. Security depth

The DOCX expects:

- audit trails
- suspicious activity monitoring
- approval workflows
- session control
- detailed permissions

The current implementation has only the early RBAC foundation.
The current implementation is now beyond the early RBAC foundation, but it still lacks the full security depth expected by the DOCX.

### 5. Commercial SaaS features

The DOCX goes beyond operations and aims for a subscription SaaS business. None of the following exist yet:

- tenant model
- subscription plans
- billing
- onboarding
- tenant provisioning
- deployment isolation strategy

## What Is Wrong or Misaligned

### 1. The scope is much larger than the implementation

The document reads like a full product roadmap, but the repository currently holds only one backend service. That is fine for an MVP, but it needs explicit phase boundaries.

### 2. The service layer is only partially established

The project now has meaningful services for major workflows, but the architecture is still mixed between route-layer decisions and service-layer business rules. If the project is going to grow toward desktop/mobile/offline/hardware/SaaS, more of the domain logic should keep moving into service/domain modules.

### 3. The data model is still pilot-grade, but less so than before

Examples of missing enterprise-level modeling:

- vehicle-level credit accounts
- company / branch billing structures
- chart of accounts
- transaction approval records beyond expenses
- sync state and external device state
- product inventory beyond fuel

### 4. The test strategy is still thin

Automated testing is now materially stronger and split by module, but there is still room for broader scenario coverage, migration smoke coverage, and more complex reconciliation cases.

## Recommended Product Framing

To keep the project realistic, the PPMS roadmap should be reframed into delivery phases.

### Phase 1: Pilot Backend MVP

Goal:
Deliver a stable backend for one real petrol pump pilot with manual operational entry.

Includes:

- authentication
- station/user/role management
- fuel sales
- tank stock
- customer credit
- suppliers and purchases
- expenses and payments
- shifts
- dashboard
- basic reports
- strong validation and tests

Current assessment:

- largely complete
- still missing a few policy-heavy workflows and richer exports

### Phase 2: Operational Hardening

Goal:
Make the backend reliable enough for daily business operations at the pilot station.

Includes:

- audit logs
- approval workflows
- better permissions
- better reconciliation
- export/reporting
- production configuration
- backups
- observability

Current assessment:

- in active progress
- audit logs, structured logging, permissions, migrations, and the first approval workflow are already in place

### Phase 3: Multi-Station and Head Office

Goal:
Support centralized reporting and management across multiple stations.

Includes:

- proper organization / tenant model
- head-office roles
- station comparison reports
- stronger data isolation
- cross-station operations governance

Current assessment:

- early implementation started
- organization model, head-office role behavior, and organization-aware dashboards/reports are now present

### Phase 4: Desktop Operations App + Offline Sync

Goal:
Build the real station-side application model described in the DOCX.

Includes:

- Windows desktop client
- local operational database
- sync queue
- sync conflict handling
- offline-safe workflows

### Phase 5: Hardware Integration

Goal:
Reduce manual entry and connect real devices.

Includes:

- dispenser integrations
- tank probes
- receipt printers
- biometric or attendance device support if needed

### Phase 6: Mobile Monitoring

Goal:
Provide owner / manager remote monitoring.

Includes:

- Android mobile app
- summary dashboards
- alerts
- mobile-safe read-only and limited write workflows

### Phase 7: SaaS Expansion

Goal:
Turn the pilot product into a scalable commercial platform.

Includes:

- subscription plans
- tenant onboarding
- billing
- deployment automation
- support operations

## Realistic Delivery Status

If we classify the project today against that roadmap:

- Phase 1: **mostly complete**
- Phase 2: **in progress**
- Phase 3: **early implementation**
- Phase 4: **not started**
- Phase 5: **foundational backend work only**
- Phase 6: **not started**
- Phase 7: **not started**

## Recommended Backlog

## Phase 1 Backlog: Finish the Pilot Backend

Priority order should be:

### 1. Security and access cleanup

- complete the remaining endpoint-by-endpoint authorization audit
- keep tightening permission boundaries for approval-style actions
- continue replacing route-local checks with reusable authorization helpers
- expand auth hardening beyond password change/reset into lockout/session policy

### 2. Data integrity and workflow rules

- prevent invalid cross-entity references across station/fuel/tank/nozzle/customer flows
- add stock reconciliation checks
- add purchase-to-tank and sale-to-nozzle consistency validation everywhere
- block destructive deletes when dependent records exist
- add status fields where workflows need state transitions

### 3. Reporting and accounting correctness

- keep refining exact accounting rules for receivables, payables, approvals, and profit
- introduce a clearer export/report job model
- add CSV/PDF-ready export endpoints
- add more comparative and head-office reporting

### 4. Test coverage

- expand the current module-based API tests into deeper workflow and migration scenarios
- add more coverage for approval flows, accounting edge cases, and reconciliation
- add migration smoke tests and broader seeded data scenarios

### 5. Developer and deployment hygiene

- continue improving `.env`-driven config and deployment readiness
- keep moving mixed route/service logic into clearer domain services
- maintain Alembic-first schema changes
- extend structured logging and operational docs

## Phase 2 Backlog: Operational Hardening

### 1. Audit and approval model

- expand the existing `audit_log` coverage where needed
- add more approval workflows for purchases, credit overrides, reversals, and higher-risk changes

### 2. Operational reliability

- add soft delete or archival rules where needed
- add backup/restore documentation and scripts
- extend the existing structured error handling and correlation IDs into stronger ops workflows
- add health/readiness checks for production use

### 3. Richer permissions

- deepen the current module/action permissions
- support owner, manager, supervisor, accountant, operator, head-office admin
- eventually move from code-defined policy toward database/config-driven permission control

### 4. Better business reporting

- daily closing reports
- shift variance reports
- stock gain/loss reports
- customer aging
- supplier aging
- station comparison reports

Note:

- some of these reports now already exist at a basic backend level
- the remaining gap is depth, exports, scheduling, and comparative analytics

## Phase 3 Backlog: Multi-Station / Head Office

### 1. Organization and tenancy design

- extend the new organization/company model above stations
- continue associating users, roles, data, and reports with organization-aware rules
- define whether suppliers/customers are global or station-owned long term

### 2. Centralized management

- head-office dashboard
- consolidated reporting
- station benchmark views
- centralized user provisioning

Note:

- dashboard/report scoping now exists
- true centralized operations workflows are still ahead

### 3. Isolation and scale

- tenant-safe querying patterns
- tenant-aware testing
- database strategy review for scale beyond SQLite

## Phase 4 Backlog: Desktop + Offline

### 1. Architecture decisions

- choose desktop stack
- define local database responsibilities
- define API sync contract
- define offline transaction queue structure

### 2. Sync engine

- outbound local event queue
- inbound cloud refresh
- conflict resolution rules
- sync monitoring UI
- retry and error handling

### 3. Desktop workflows

- fast fuel sale entry
- shift console
- tank and nozzle monitoring
- receipt printing hooks

## Phase 5 Backlog: Hardware Integration

### 1. Integration foundation

- hardware abstraction layer
- vendor adapter interface
- simulator/mock device support for testing

### 2. Device support

- dispenser polling or event capture
- tank probe reading ingestion
- receipt printer support
- optional biometric attendance input

### 3. Operational safety

- device health monitoring
- fallback to manual mode
- reconciliation between device data and manual corrections

## Phase 6 Backlog: Mobile Monitoring

### 1. Mobile MVP

- owner dashboard
- sales summary
- low stock alerts
- credit customer alerts
- station switcher

### 2. Secure access

- mobile auth
- limited role-specific capabilities
- session timeout and device awareness

## Phase 7 Backlog: SaaS Productization

### 1. Commercial platform features

- subscription plans
- billing and invoicing
- tenant onboarding
- support/admin console

### 2. Platform operations

- deployment automation
- environment separation
- customer support tooling
- telemetry and uptime monitoring

## Suggested Immediate Next Milestones

If the goal is to build this professionally, the next milestones should be:

1. Finish Phase 1 backend quality
2. Freeze the pilot scope
3. Finish the Phase 2 approval / governance layer
4. Define the target desktop/offline architecture before writing desktop code
5. Treat SaaS expansion as a later commercialization phase, not an immediate coding target

## Recommended Immediate Engineering Tasks

These are the best next engineering tasks for the current repo:

1. Add environment-based config and remove hardcoded secrets
2. Complete the remaining authorization consistency audit
3. Continue extracting mixed route/service logic into clearer domain services
4. Expand automated API tests for deeper approval, reporting, and migration flows
5. Define the next missing domain entities and workflows:
   - transaction approval records beyond expenses
   - report/export jobs
   - notification/event delivery
   - offline/sync state
6. Write a formal Phase 2 scope document so the project stops drifting against the much larger DOCX vision

## Final Assessment

The DOCX is not wrong. It describes a strong long-term product vision.

The problem is that the codebase is currently much smaller than that vision and does not yet declare a phased boundary. Without a phase-based plan, the project will feel like it is always "missing everything."

The correct framing is:

- **Current reality:** hardened backend pilot with early head-office and hardware/POS foundations
- **Immediate target:** finish Phase 2 operational hardening and approval/governance workflows
- **Next expansion:** stronger centralized operations, exports, desktop/offline architecture
- **Later product layers:** desktop, offline sync, hardware, mobile, SaaS
