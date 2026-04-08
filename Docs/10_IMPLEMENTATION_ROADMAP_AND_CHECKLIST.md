# Implementation Roadmap And Checklist

This document converts the finalized product direction into execution phases.

Use this as the working delivery plan for Flutter and backend alignment.

## 1. Delivery Strategy

We will build in this order:

1. foundation
2. onboarding and setup
3. operator and manager operational core
4. accountant finance core
5. station admin controls
6. head office controls
7. tanker module
8. notifications, reports, documents, exports
9. optional business modules
10. deployment hardening and release prep

Important rule:

- each phase must work end to end before the next phase expands scope

## 2. Cross-Cutting Build Rules

- Flutter uses one responsive codebase
- backend remains schema-first and PostgreSQL-safe
- permissions and module visibility are capability-driven
- localization structure exists from the beginning
- audit-sensitive actions must emit logs/events
- disabled modules preserve historical records

## 3. Phase 0 - Product And Backend Alignment

Goal:

- convert planning into implementation-ready contracts

Backend checklist:

- confirm active schema vs future schema
- confirm auth and session endpoints
- confirm capability payload shape for role, scope, and enabled modules
- confirm station setup read/write endpoints
- confirm shift, meter, dip, receiving, customer, supplier, expense, payroll, notification, and tanker endpoints
- identify missing endpoints required by the finalized workflows
- define audit/event behavior for edits, removals, and meter adjustments

Flutter checklist:

- finalize package choices
- finalize state management
- finalize routing and shell approach
- finalize localization package and translation key structure

Done when:

- no major product flow depends on unknown backend behavior

## 4. Phase 1 - Flutter Foundation

Goal:

- create the reusable app base

Flutter deliverables:

- app bootstrap
- environment config
- auth session management
- login flow
- `/auth/me` and capability load
- module-aware navigation shell
- compact / medium / expanded breakpoints
- design system primitives
- global notification center shell
- localization scaffolding for English and Urdu

Screen checklist:

- login
- session restore/loading
- unauthorized/forbidden
- shell with role/module navigation
- profile shell
- notification center shell

Backend deliverables:

- stable auth responses
- capability payload with:
  - user
  - access role
  - scope
  - organization
  - station
  - enabled modules
  - key feature flags

Done when:

- a user can log in and see only the correct app areas

## 5. Phase 2 - Onboarding And Setup

Goal:

- make tenant and station setup real

Backend deliverables:

- create/edit organization
- organization branding data
- station create/edit
- station setup status
- fuel type CRUD
- tank CRUD
- dispenser CRUD
- nozzle CRUD
- station module settings
- invoice profile CRUD
- setup draft-save behavior

Flutter deliverables:

- `MasterAdmin` onboarding workspace
- organization create/edit wizard
- station count and station details step
- module enablement step
- first-admin assignment step
- onboarding progress view
- station forecourt setup wizard
- setup checklist and next-actions dashboard

Screen checklist:

- `MasterAdmin` onboarding home
- create organization wizard
- edit organization
- station setup wizard
- fuel types screen
- tanks screen
- dispensers/nozzles screen
- station settings basics
- invoice settings
- module toggles

Done when:

- an organization and station can be fully configured without direct database work

## 6. Phase 3 - Operator Self-Service

Goal:

- give the simplest role a complete usable slice

Backend deliverables:

- own profile endpoint
- attendance check-in/check-out endpoints
- own payroll summary endpoint

Flutter deliverables:

- operator home
- own profile
- own attendance
- own payroll summary

Screen checklist:

- operator home
- profile details
- attendance check-in/out
- payroll summary

Done when:

- operator can log in and use all self-service functions end to end

## 7. Phase 4 - Manager Operational Core

Goal:

- build the real forecourt operating loop

Backend deliverables:

- shift template and current-shift endpoints
- shift open/current/close
- opening cash carry-forward
- opening nozzle carry-forward
- nozzle close reading submission
- meter abnormality handling
- rate-change boundary reading support
- cash submission records
- dip entry with calibration conversion
- supplier receiving
- own-tanker receiving base path
- customer recovery entry
- credit increase audit/notification
- expense entry
- lubricant sale entry
- internal fuel usage entry
- manager task feed

Flutter deliverables:

- manager shift workspace
- dispenser-grouped nozzle checklist
- close-shift flow
- cash-in-hand and submissions flow
- dip entry flow
- supplier receiving flow
- customer recovery flow
- expense entry flow
- lubricant sale flow
- internal fuel usage flow
- live totals cards with drill-down

Screen checklist:

- manager home / active shift workspace
- nozzle checklist
- close shift review
- cash submission history
- dip history and entry
- receive fuel
- credit list and recovery
- expenses
- lubricant sales
- internal usage
- task list

Done when:

- a manager can run a real shift and close it correctly

## 8. Phase 5 - Accountant Finance Core

Goal:

- build finance workflows around the operational records

Backend deliverables:

- customer ledger summary/detail
- customer payment CRUD
- supplier ledger summary/detail
- supplier payment CRUD
- expense list/filter/edit/remove
- payroll list
- payroll run create/finalize
- finance alerts

Flutter deliverables:

- accountant finance workspace
- customer ledger screens
- supplier ledger screens
- customer payment entry/edit/remove
- supplier payment entry/edit/remove
- expense list and summaries
- payroll workspace
- accountant alerts

Screen checklist:

- accountant home
- customer ledgers
- supplier ledgers
- payment entry forms
- expenses with filters
- payroll list
- payroll run details
- finance alerts

Done when:

- accountant can manage finance operations without leaving the app

## 9. Phase 6 - StationAdmin Controls

Goal:

- give full station-level administration

Backend deliverables:

- staff CRUD
- access role assignment
- staff title CRUD
- login enable/disable
- payroll basics update
- meter adjustment events
- forecourt edit/deactivate endpoints
- branding and invoice setting updates

Flutter deliverables:

- station admin dashboard
- staff management
- role assignment
- forecourt management after onboarding
- branding settings
- invoice settings
- meter reversal/adjustment flow

Screen checklist:

- station admin dashboard
- staff list
- create/edit staff
- staff title management
- access role assignment
- forecourt management
- meter adjustment event form
- branding settings
- invoice settings

Done when:

- a station can be fully managed by station-side admins

## 10. Phase 7 - HeadOffice Controls

Goal:

- enable multi-station organization oversight

Backend deliverables:

- organization dashboard summaries
- cross-station reporting endpoints
- station creation/edit endpoints for org admins
- station admin assignment
- station mode context switching

Flutter deliverables:

- head office dashboard
- station list and health view
- organization reports
- station drill-down mode
- cross-station staff view

Screen checklist:

- head office home
- organization dashboard
- station directory
- station detail
- station mode switcher
- cross-station staff management
- organization reports

Done when:

- `HeadOffice` can oversee and manage the organization cleanly

## 11. Phase 8 - Tanker Module

Goal:

- implement the finalized tanker business model

Backend deliverables:

- tanker master data CRUD
- driver pool links
- compartment definitions
- tanker trip CRUD
- compartment line tracking
- multi-stop delivery entries
- tanker payment entries
- separate tanker ledger tracking
- own-station leftover transfer
- trip expense entries
- trip profitability calculation
- trip status flow
- tanker dashboard/report endpoints

Flutter deliverables:

- tanker dashboard
- tanker master data management
- trip creation
- compartment load view
- delivery entry flow
- payment and outstanding view
- leftover-to-station transfer
- trip expenses
- trip settlement view

Screen checklist:

- tanker dashboard
- tanker list
- tanker detail
- driver assignment view
- create/edit trip
- trip deliveries
- tanker customer ledger view
- leftover transfer
- trip expenses
- trip settlement

Done when:

- tanker business can be run and reported from inside the app

## 12. Phase 9 - Notifications, Reports, Documents, Exports

Goal:

- complete read-heavy and communication-heavy workflows

Backend deliverables:

- in-app notification delivery
- report query endpoints
- report export jobs
- document template support
- invoice/challan dispatch prep

Flutter deliverables:

- in-app notification center
- operational reports
- finance reports
- payroll reports
- exception reports
- export actions
- printable invoice/challan views

Screen checklist:

- notifications center
- operational report list/detail
- finance report list/detail
- payroll report list/detail
- variance report list/detail
- export/download screens
- printable documents

Done when:

- the app supports reliable reporting and document output

## 13. Phase 10 - Optional Business Units

Goal:

- add optional modules one by one without harming the core app

Order recommendation:

1. shop / mart
2. workshop / service station
3. rented units / lease
4. restaurant
5. tyre shop
6. ATM / third-party units

Rule:

- each optional module gets its own mini-spec before implementation

## 14. Phase 11 - Release Hardening And Deployment

Goal:

- stabilize locally, then prepare deployment

Checklist:

- audit responsive behavior on compact, medium, expanded layouts
- complete localization pass for released modules
- test exports and print views
- review audit-sensitive actions
- verify PostgreSQL-safe behavior
- verify provider-ready notification architecture
- prepare EC2 Ubuntu deployment path
- prepare production database path

Done when:

- the product is stable locally and ready for deployment packaging

## 15. Backend Worklist By Module

High-priority backend implementation areas:

- auth and capability payload
- organization/station onboarding APIs
- setup draft and status tracking
- shift lifecycle and close validation
- per-nozzle meter workflows
- tank calibration and dip conversion
- customer/supplier ledgers
- payment edit/remove audit trails
- payroll runs and summaries
- tanker trip and compartment model
- notification event model
- report/export jobs

## 16. Flutter Worklist By Module

High-priority Flutter implementation areas:

- responsive shell
- role/module-aware navigation
- localization scaffold
- setup wizards
- shift workspace
- finance workspace
- station admin workspace
- head office workspace
- tanker workspace
- reports and documents

## 17. Definition Of Done Per Feature Packet

Every feature packet should satisfy:

1. schema and endpoint confirmed
2. repository implemented
3. state/controller implemented
4. permissions and module gating enforced
5. compact, medium, and expanded UI reviewed
6. loading, error, and empty states present
7. audit-sensitive actions handled safely
8. localization keys added
9. major success path tested
10. major correction path tested

## 18. Recommended Immediate Next Build Steps

Do these next:

1. freeze and review backend contract gaps against the finalized workflows
2. scaffold the new Flutter app foundation
3. implement auth, capability load, shell, and localization base
4. implement onboarding and setup
5. implement operator self-service
6. implement manager shift core

If we follow that order, we will get to a real usable product faster without creating rewrite-heavy UI debt.
