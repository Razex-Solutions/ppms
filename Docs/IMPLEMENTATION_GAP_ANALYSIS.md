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

The current repository is not that full platform yet.

It is an early backend MVP focused on:

- authentication
- stations and users
- fuel types, tanks, dispensers, nozzles
- fuel sales
- customers and suppliers
- purchases and payments
- shifts
- tank dips
- dashboard and simple ledger/profit reporting

That means the project is currently in a **Phase 1 backend prototype / pilot API** stage, not in the full product stage described in the DOCX.

## Current System Snapshot

### What exists today

- FastAPI backend in `ppms/app`
- SQLite persistence
- basic JWT login
- CRUD APIs for core operational entities
- basic station-scoped access control
- simple dashboard and accounting summaries
- seed script for initial data
- minimal automated regression coverage

### What does not exist today

- desktop client
- mobile client
- sync engine
- device integration layer
- notification services
- payroll
- POS
- compliance / invoicing
- SaaS tenancy and billing
- audit/event logging

## Module Status Matrix

Status definitions:

- `Done`: present and usable at a basic product level
- `Partial`: present but materially incomplete versus the DOCX
- `Missing`: not implemented in this repository

| Module / Capability | Status | Notes |
| --- | --- | --- |
| Authentication | Partial | Login exists, but no password reset, lockout, session controls, or full permission matrix |
| Role-based access control | Partial | Roles exist, but granular permissions and complete enforcement are still incomplete |
| Multi-station support | Partial | Stations exist and some routes are station-scoped, but this is not a complete head-office / tenant model |
| User management | Partial | Basic CRUD exists; admin enforcement was just tightened; role/permission design is still basic |
| Fuel sales management | Partial | Core sale entry exists, but no automatic dispenser integration, approvals, invoice workflows, or advanced reporting |
| Nozzle monitoring / reading history | Partial | Manual reading progression exists through sales and history records |
| Tank inventory management | Partial | Tanks and dips exist, but no calibration charts, probe integration, warehouse/product inventory, or strong reconciliation workflows |
| Purchase management | Partial | Basic purchases exist, but no purchase invoices, returns, approvals, shortage workflows, or vendor performance tracking |
| Customer credit management | Partial | Basic credit sales and payments exist, but no vehicle/company hierarchy, monthly billing, statements workflow, or reminder engine |
| Supplier management | Partial | Basic supplier CRUD and payments exist, but no richer supplier operations or performance tracking |
| Accounting module | Partial | Profit summary, expenses, and ledgers exist; no chart of accounts, bank/cash, statements, or accounting rules engine |
| Shift management | Partial | Open/close shift exists, but no supervisor approval, attendance tie-in, or richer reconciliation/reporting |
| Reporting and analytics | Partial | Dashboard and a few summaries exist; no scheduled reports, export system, comparative analytics, or deep operational reporting |
| Audit trail / fraud prevention | Missing | No activity log, audit events, or change history layer |
| Attendance and payroll | Missing | Not modeled |
| POS for shop/services | Missing | Not modeled |
| Notification system | Missing | No SMS, WhatsApp, email, push, or in-app alerts |
| Government compliance / digital invoicing / tax | Missing | Not modeled |
| Desktop application | Missing | No Windows application in this repo |
| Android mobile application | Missing | No mobile app in this repo |
| Offline-first local operation | Missing | SQLite exists, but not as a designed offline-sync architecture |
| Synchronization engine | Missing | No sync jobs, queue, conflict resolution, or local/cloud reconciliation |
| Hardware integration | Missing | No dispenser, tank probe, printer, or biometric integration layer |
| SaaS subscription platform | Missing | No tenant onboarding, subscription billing, or customer management portal |
| Monitoring / observability | Missing | No structured app logging, audit monitoring, alerts, or ops dashboard |

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

The DOCX repeatedly treats dispenser, tank probe, printer, and device integration as major project phases. The codebase currently uses manual data entry only.

### 4. Security depth

The DOCX expects:

- audit trails
- suspicious activity monitoring
- approval workflows
- session control
- detailed permissions

The current implementation has only the early RBAC foundation.

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

### 2. The service layer is not really being used

Most business logic lives in API route files. If the project is going to grow toward desktop/mobile/offline/hardware/SaaS, business rules should move into a service/domain layer.

### 3. The data model is still pilot-grade

Examples of missing enterprise-level modeling:

- vehicle-level credit accounts
- company / branch billing structures
- chart of accounts
- approval records
- audit events
- sync state and external device state
- product inventory beyond fuel

### 4. The test strategy is still thin

Automated testing now exists for recent security regressions, but there is still no broad test suite for operational flows, permissions, accounting integrity, or data reconciliation.

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

### Phase 3: Multi-Station and Head Office

Goal:
Support centralized reporting and management across multiple stations.

Includes:

- proper organization / tenant model
- head-office roles
- station comparison reports
- stronger data isolation
- cross-station operations governance

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

- Phase 1: **partially complete**
- Phase 2: **not complete**
- Phase 3: **early groundwork only**
- Phase 4: **not started**
- Phase 5: **not started**
- Phase 6: **not started**
- Phase 7: **not started**

## Recommended Backlog

## Phase 1 Backlog: Finish the Pilot Backend

Priority order should be:

### 1. Security and access cleanup

- review every API for station scoping and role enforcement
- define which roles can create/update/delete each entity
- add reusable authorization helpers instead of scattered checks
- move secrets and config into environment-based settings
- implement password change / reset flow for admins

### 2. Data integrity and workflow rules

- prevent invalid cross-entity references across station/fuel/tank/nozzle/customer flows
- add stock reconciliation checks
- add purchase-to-tank and sale-to-nozzle consistency validation everywhere
- block destructive deletes when dependent records exist
- add status fields where workflows need state transitions

### 3. Reporting and accounting correctness

- define exact accounting rules for receivables, payables, expenses, and profit
- introduce a clearer transaction ledger model
- add daily shift report, station sales report, tank movement report
- add export endpoints for CSV/PDF-ready output

### 4. Test coverage

- add API tests for auth and authorization
- add tests for sales, purchases, tank volume, credit limits, shift closing
- add regression tests for station isolation
- add seed/data factory helpers for tests

### 5. Developer and deployment hygiene

- add `.env`-driven config
- split route logic into service modules
- add migration tooling such as Alembic
- add basic logging
- document setup, seed, and test flows properly

## Phase 2 Backlog: Operational Hardening

### 1. Audit and approval model

- add `audit_log` table
- record create/update/delete and critical business actions
- add approval workflow for purchases, expenses, credit overrides, and user creation if needed

### 2. Operational reliability

- add soft delete or archival rules where needed
- add backup/restore documentation and scripts
- add structured error handling and correlation IDs
- add health/readiness checks for production use

### 3. Richer permissions

- define permissions by module and action
- support owner, manager, supervisor, accountant, operator, head-office admin
- store permissions in the database or config-driven policy layer

### 4. Better business reporting

- daily closing reports
- shift variance reports
- stock gain/loss reports
- customer aging
- supplier aging
- station comparison reports

## Phase 3 Backlog: Multi-Station / Head Office

### 1. Organization and tenancy design

- add organization/company model above stations
- associate users, roles, data, and reports with organization
- define whether suppliers/customers are global or station-owned

### 2. Centralized management

- head-office dashboard
- consolidated reporting
- station benchmark views
- centralized user provisioning

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
3. Define the target desktop/offline architecture before writing desktop code
4. Delay hardware integration until the core workflows are stable
5. Treat SaaS expansion as a later commercialization phase, not an immediate coding target

## Recommended Immediate Engineering Tasks

These are the best next engineering tasks for the current repo:

1. Add environment-based config and remove hardcoded secrets
2. Audit every endpoint for authorization consistency
3. Add a service layer for sales, purchases, shifts, and accounting
4. Add Alembic migrations
5. Expand automated API tests for all core flows
6. Define missing domain entities:
   - audit logs
   - organization/company
   - permission model
   - report/export jobs
7. Write a formal Phase 1 scope document so the project stops drifting against the much larger DOCX vision

## Final Assessment

The DOCX is not wrong. It describes a strong long-term product vision.

The problem is that the codebase is currently much smaller than that vision and does not yet declare a phased boundary. Without a phase-based plan, the project will feel like it is always "missing everything."

The correct framing is:

- **Current reality:** backend MVP for a pilot station
- **Immediate target:** make the backend production-safe for pilot operations
- **Next expansion:** multi-station, audit, permissions, reporting
- **Later product layers:** desktop, offline sync, hardware, mobile, SaaS
