# PPMS Current Progress And Project Map

## Purpose
This document is the current handoff and progress map for the PPMS project.

It is meant to answer:
- what the project currently contains
- where each part lives
- what database tables exist
- what fields those tables contain
- which backend files own which behavior
- which Flutter files own which screens
- what is already implemented
- what is still planned
- where to edit when a specific business rule or UI behavior changes

This is the current local-first source of truth. The project is being completed on the local PC first, then it will be deployed online later.

## 1. Current Delivery State

### Backend
The FastAPI backend is already broad and feature-rich. It covers:
- authentication and sessions
- organizations, stations, users, roles
- MasterAdmin/platform foundation
- onboarding and station setup foundation
- fuel sales
- purchases and payments
- expenses
- parties: customers and suppliers
- inventory: tanks, dispensers, nozzles, dips
- hardware and meter adjustments
- tanker operations
- reports and exports
- notifications and delivery logs
- document templates and financial documents
- SaaS/module foundation
- attendance and payroll
- audit logs

Important note:
- the current backend still includes approval-oriented structures in some finance and governance areas
- the newer planning direction is to keep approvals optional and exception-based, not mandatory for normal operational facts

### Flutter
The existing Flutter app in `ppms_flutter` is now kept as a reference while the tenant UI is rebuilt cleanly in `ppms_tenant_flutter`.

The old Flutter app is beyond simple placeholders. It includes real workspaces for:
- login
- role-aware dashboards
- onboarding
- station setup
- admin
- sales
- shifts
- finance
- documents
- parties
- governance
- expenses
- hardware
- tankers
- reports
- payroll
- attendance
- notifications
- settings

Current Phase 9 tenant rebuild decision:
- keep `ppms_flutter` intact as a reference
- create `ppms_tenant_flutter` as the clean tenant app rebuild
- rebuild one vertical slice at a time from `TENANT_FLUTTER_REBUILD_PLAN.md`
- first slice is login, session context, tenant landing page, role-aware navigation, and HeadOffice worker creation

### Phase Progress

Current phased execution status:
- `Phase 1 - Setup Hierarchy Foundation`: complete locally
- `Phase 2 - Operations Core`: complete locally
- `Phase 3 - Finance, Ledgers, Payroll, Pricing`: complete locally
- `Phase 4 - Tanker and Extended Operations`: complete locally
- `Phase 5 - Notifications, Documents, Reports, Profit`: complete locally
- `Phase 6 - Roles, Permissions, Modules, SaaS Rules`: complete locally
- `Phase 7 - Flutter App Completion`: complete locally
- `Phase 8 - Master Admin Support Frontend`: complete locally
- next sequence: `Phase 9 - Local Stabilization and Acceptance`

Phase 1 completion now includes:
- setup-foundation backend summary endpoints for organizations and stations
- inheritance-aware branding and invoice identity resolution
- auto-generated tank, dispenser, and nozzle naming/coding support
- forecourt validation for tank/dispenser/nozzle/fuel mappings
- onboarding review summary and single-station inheritance-first behavior
- station setup checklist/progress guidance
- invoice default-following UX and override path
- targeted backend setup tests plus clean Flutter analyze/test validation

Phase 2 completion now includes:
- station shift templates for daily, hourly, custom, and 24-hour shift setup
- shift openings linked to templates plus shift-cash records created at open
- multiple cash submissions per shift with reconciliation at closeout
- explicit meter segment history built from sales and adjustment boundaries
- hardware workspace visibility for meter adjustments and meter segments
- meter-led fuel sales continuing to drive quantity derivation and stock deduction
- explicit internal fuel usage records with automatic tank-volume reduction
- station expenses aligned to direct operational recording by default
- targeted backend transaction/access/reporting coverage plus clean Flutter analyze/test validation

Phase 3 completion now includes:
- salary adjustments recorded separately and applied during payroll-run generation
- payroll workspace updated around monthly runs, line breakdowns, and adjustment-aware totals
- ledger summary endpoints for customers and suppliers with permission-scoped access
- parties workspace redesigned to show ledger-first balance snapshots for selected records
- finance workspace now surfaces selected customer and supplier ledger snapshots during payment work
- station fuel price history with role-based update/read permissions
- sales workspace now shows current station pricing and recent price history
- targeted backend finance/access validation plus clean Flutter analyze/test validation

Phase 4 completion now includes:
- tanker master records with ownership type, station scope, and fuel-type linkage
- tanker compartments with automatic equal-split setup support and explicit compartment management APIs
- trip summary entry with loaded quantity, purchase rate, compartment planning, and manual tanker-sale posting
- leftover fuel transfer from tanker trips into station tanks with recorded transfer facts
- tanker-linked expenses and supplier-to-station purchase conversion on trip completion
- manager-summary tanker workspace metrics for fleet mix, delivered fuel, leftovers, transfers, and purchase value
- tanker guidance surfaced in station setup when tanker operations are enabled
- targeted backend tanker/access/reporting coverage plus clean Flutter analyze/test validation

Phase 5 completion now includes:
- notification preferences, inbox summaries, delivery diagnostics, dead-letter visibility, retry flows, and process-due actions
- financial document generation, PDF/download flows, dispatch history, retry flows, and process-due dispatch handling
- filtered reports for daily closing, stock movement, balances, tanker profit/deliveries/expenses, and report export jobs
- saved report definitions for reusable report views
- filtered profit summary with station/organization scope and date filtering
- report, document, notification, and dashboard flows now working as one connected communications/reporting layer
- targeted backend reporting validation plus clean Flutter analyze/test validation

Phase 6 completion now includes:
- centralized effective capability resolution returned from `/auth/me`
- resolved backend, organization, station, and feature-flag module visibility for the active user session
- tenant shell navigation now shaped by effective capability state instead of global module assumptions
- admin capability controls for organization modules, station modules, subscription plans, and organization subscription state
- role-aware shell/menu separation so `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`, and `Operator` do not share the same control surfaces by default
- setup visibility now stays with station-control roles while governance visibility stays with oversight roles
- zero-ghost-module direction substantially enforced across shell and dashboard entry points
- clean targeted backend validation plus clean Flutter analyze/test validation across the Phase 6 batches

Phase 7 completion now includes:
- guided setup and station setup flows reshaped around review cards, next-action guidance, inheritance context, and summary-first setup decisions
- role-aware dashboard and shell behavior carried forward from the capability system into the tenant Flutter experience
- major workspaces refined into summary-first flows before forms: setup, admin, sales, shifts, finance, parties, inventory, tankers, payroll, reports, documents, notifications, attendance, POS, expenses, hardware, and governance
- financial, party, report, document, notification, tanker, shift, payroll, inventory, and sales pages now surface selected-record context before risky or posting actions
- POS and attendance now use the same review-first pattern as the rest of the operational client
- module and permission-aware visibility remains the guiding rule for workspace entry points and in-page actions
- clean Flutter analyze/test validation across the Phase 7 workspace batches

Phase 8 completion now includes:
- separate Next.js support console in `support_console` for MasterAdmin/platform support work
- Master Admin login through the existing backend auth flow and support proxy route
- organization search/open flow with station, user, staff, subscription, module, communication, and reporting context
- support-side organization and station correction forms kept separate from the tenant Flutter operations app
- package/subscription controls for plan, status, billing cycle, auto-renew, price override, and support notes
- organization and station module toggles for support/package visibility correction
- notification and financial document delivery health panels with process-due and retry support actions
- support reporting review for tenant profit summary, saved report definitions, and recent report export jobs
- clean support console `npm run lint` and `npm run build` validation across the Phase 8 batches

### Architecture Direction
Current direction is:
- local-first development
- GitHub as source of truth
- backend on FastAPI
- Flutter as the main operational client
- separate Node.js/Next.js support console for MasterAdmin/support work
- later deployment target:
  - backend on Amazon EC2
  - web frontend on Vercel
  - Flutter desktop/android/iOS as separate app builds

## 2. Repository Layout

Root: [C:\Fuel Management System](/C:/Fuel%20Management%20System)

### Important top-level folders
- [ppms](/C:/Fuel%20Management%20System/ppms)
  - FastAPI backend source
- [ppms_flutter](/C:/Fuel%20Management%20System/ppms_flutter)
  - existing Flutter desktop/mobile client kept as a reference during Phase 9
- [ppms_tenant_flutter](/C:/Fuel%20Management%20System/ppms_tenant_flutter)
  - clean tenant Flutter rebuild client
- [support_console](/C:/Fuel%20Management%20System/support_console)
  - Next.js MasterAdmin/support web console
- [alembic](/C:/Fuel%20Management%20System/alembic)
  - DB migrations
- [tests](/C:/Fuel%20Management%20System/tests)
  - backend and contract tests
- [Docs](/C:/Fuel%20Management%20System/Docs)
  - project docs/specs/plans
- [desktop_app](/C:/Fuel%20Management%20System/desktop_app)
  - older Python desktop prototype/reference client
- [backups](/C:/Fuel%20Management%20System/backups)
  - local backup outputs

### Important top-level files
- [README.md](/C:/Fuel%20Management%20System/README.md)
  - main project setup and status doc
- [.env.example](/C:/Fuel%20Management%20System/.env.example)
  - base env template
- [alembic.ini](/C:/Fuel%20Management%20System/alembic.ini)
  - Alembic config
- [requirements.txt](/C:/Fuel%20Management%20System/requirements.txt)
  - Python dependencies
- [run_local_server.py](/C:/Fuel%20Management%20System/run_local_server.py)
  - preferred local backend restart helper
- [ppms.db](/C:/Fuel%20Management%20System/ppms.db)
  - main local runtime database
- [ppms_smoke.db](/C:/Fuel%20Management%20System/ppms_smoke.db)
  - dedicated smoke/migration verification database

## 3. Backend Structure

Backend root: [ppms](/C:/Fuel%20Management%20System/ppms)

### Main backend folders
- [ppms/app/api](/C:/Fuel%20Management%20System/ppms/app/api)
  - route handlers / endpoints
- [ppms/app/models](/C:/Fuel%20Management%20System/ppms/app/models)
  - SQLAlchemy models / DB tables
- [ppms/app/schemas](/C:/Fuel%20Management%20System/ppms/app/schemas)
  - Pydantic request/response schemas
- [ppms/app/services](/C:/Fuel%20Management%20System/ppms/app/services)
  - business logic
- [ppms/app/core](/C:/Fuel%20Management%20System/ppms/app/core)
  - config, auth, DB, access control, permissions, logging

### Core backend files
- [ppms/app/main.py](/C:/Fuel%20Management%20System/ppms/app/main.py)
  - FastAPI app entry point
- [ppms/app/core/config.py](/C:/Fuel%20Management%20System/ppms/app/core/config.py)
  - app config/env values
- [ppms/app/core/database.py](/C:/Fuel%20Management%20System/ppms/app/core/database.py)
  - DB session/engine setup
- [ppms/app/core/security.py](/C:/Fuel%20Management%20System/ppms/app/core/security.py)
  - password hashing, token utilities
- [ppms/app/core/dependencies.py](/C:/Fuel%20Management%20System/ppms/app/core/dependencies.py)
  - request dependencies/current user logic
- [ppms/app/core/access.py](/C:/Fuel%20Management%20System/ppms/app/core/access.py)
  - scope and access helpers
- [ppms/app/core/permissions.py](/C:/Fuel%20Management%20System/ppms/app/core/permissions.py)
  - permission catalog and role logic

## 4. Backend API Modules

These route files live in [ppms/app/api](/C:/Fuel%20Management%20System/ppms/app/api).

### Identity / platform / governance
- [auth.py](/C:/Fuel%20Management%20System/ppms/app/api/auth.py)
  - login, refresh, logout, current user, sessions
- [role.py](/C:/Fuel%20Management%20System/ppms/app/api/role.py)
  - role management and permission catalog
- [user.py](/C:/Fuel%20Management%20System/ppms/app/api/user.py)
  - user management
- [employee_profile.py](/C:/Fuel%20Management%20System/ppms/app/api/employee_profile.py)
  - profile-only staff management
- [organization.py](/C:/Fuel%20Management%20System/ppms/app/api/organization.py)
  - organizations
- [station.py](/C:/Fuel%20Management%20System/ppms/app/api/station.py)
  - stations
- [brand_catalog.py](/C:/Fuel%20Management%20System/ppms/app/api/brand_catalog.py)
  - brand catalog for logos/branding
- [saas.py](/C:/Fuel%20Management%20System/ppms/app/api/saas.py)
  - plans/subscriptions
- [organization_module.py](/C:/Fuel%20Management%20System/ppms/app/api/organization_module.py)
  - org module toggles
- [station_module.py](/C:/Fuel%20Management%20System/ppms/app/api/station_module.py)
  - station module toggles

### Master data / setup
- [fuel_type.py](/C:/Fuel%20Management%20System/ppms/app/api/fuel_type.py)
  - fuel types
- [tank.py](/C:/Fuel%20Management%20System/ppms/app/api/tank.py)
  - tanks
- [dispenser.py](/C:/Fuel%20Management%20System/ppms/app/api/dispenser.py)
  - dispensers
- [nozzle.py](/C:/Fuel%20Management%20System/ppms/app/api/nozzle.py)
  - nozzles
- [invoice_profile.py](/C:/Fuel%20Management%20System/ppms/app/api/invoice_profile.py)
  - invoice/compliance profile
- [document_template.py](/C:/Fuel%20Management%20System/ppms/app/api/document_template.py)
  - document template APIs

### Operations
- [fuel_sale.py](/C:/Fuel%20Management%20System/ppms/app/api/fuel_sale.py)
  - fuel sale operations
- [shift.py](/C:/Fuel%20Management%20System/ppms/app/api/shift.py)
  - shift open/close/history
- [expense.py](/C:/Fuel%20Management%20System/ppms/app/api/expense.py)
  - expenses and approvals
- [purchase.py](/C:/Fuel%20Management%20System/ppms/app/api/purchase.py)
  - purchases and purchase approvals
- [customer_payment.py](/C:/Fuel%20Management%20System/ppms/app/api/customer_payment.py)
  - customer payments
- [supplier_payment.py](/C:/Fuel%20Management%20System/ppms/app/api/supplier_payment.py)
  - supplier payments
- [customer.py](/C:/Fuel%20Management%20System/ppms/app/api/customer.py)
  - customer management
- [supplier.py](/C:/Fuel%20Management%20System/ppms/app/api/supplier.py)
  - supplier management
- [tank_dip.py](/C:/Fuel%20Management%20System/ppms/app/api/tank_dip.py)
  - tank dip entry/history
- [hardware.py](/C:/Fuel%20Management%20System/ppms/app/api/hardware.py)
  - hardware, events, vendor poll, meter-related operations
- [tanker.py](/C:/Fuel%20Management%20System/ppms/app/api/tanker.py)
  - tankers, trips, deliveries, trip expenses, completion
- [pos_product.py](/C:/Fuel%20Management%20System/ppms/app/api/pos_product.py)
  - POS products
- [pos_sale.py](/C:/Fuel%20Management%20System/ppms/app/api/pos_sale.py)
  - POS sales
- [attendance.py](/C:/Fuel%20Management%20System/ppms/app/api/attendance.py)
  - attendance
- [payroll.py](/C:/Fuel%20Management%20System/ppms/app/api/payroll.py)
  - payroll runs/lines

### Reporting / support / integration
- [dashboard.py](/C:/Fuel%20Management%20System/ppms/app/api/dashboard.py)
  - dashboards and summary data
- [reports.py](/C:/Fuel%20Management%20System/ppms/app/api/reports.py)
  - reports
- [report_export.py](/C:/Fuel%20Management%20System/ppms/app/api/report_export.py)
  - exports
- [financial_document.py](/C:/Fuel%20Management%20System/ppms/app/api/financial_document.py)
  - invoices, receipts, vouchers, dispatch
- [notification.py](/C:/Fuel%20Management%20System/ppms/app/api/notification.py)
  - notifications, preferences, deliveries
- [online_api_hook.py](/C:/Fuel%20Management%20System/ppms/app/api/online_api_hook.py)
  - outbound/inbound hook integration
- [maintenance.py](/C:/Fuel%20Management%20System/ppms/app/api/maintenance.py)
  - backup/restore/health/integrity helpers
- [audit.py](/C:/Fuel%20Management%20System/ppms/app/api/audit.py)
  - audit trail
- [ledger.py](/C:/Fuel%20Management%20System/ppms/app/api/ledger.py)
  - accounting/ledger endpoints
- [accounting.py](/C:/Fuel%20Management%20System/ppms/app/api/accounting.py)
  - accounting-related endpoints

For a simpler endpoint list, also see [Docs/API_INVENTORY.txt](/C:/Fuel%20Management%20System/Docs/API_INVENTORY.txt).

## 5. Backend Business Services

These files live in [ppms/app/services](/C:/Fuel%20Management%20System/ppms/app/services).

### Core domain services
- [fuel_sales.py](/C:/Fuel%20Management%20System/ppms/app/services/fuel_sales.py)
- [purchases.py](/C:/Fuel%20Management%20System/ppms/app/services/purchases.py)
- [payments.py](/C:/Fuel%20Management%20System/ppms/app/services/payments.py)
- [expenses.py](/C:/Fuel%20Management%20System/ppms/app/services/expenses.py)
- [shifts.py](/C:/Fuel%20Management%20System/ppms/app/services/shifts.py)
- [tank_dips.py](/C:/Fuel%20Management%20System/ppms/app/services/tank_dips.py)
- [tanker_ops.py](/C:/Fuel%20Management%20System/ppms/app/services/tanker_ops.py)
- [pos.py](/C:/Fuel%20Management%20System/ppms/app/services/pos.py)
- [attendance.py](/C:/Fuel%20Management%20System/ppms/app/services/attendance.py)
- [payroll.py](/C:/Fuel%20Management%20System/ppms/app/services/payroll.py)

### Setup / documents / compliance
- [invoice_profiles.py](/C:/Fuel%20Management%20System/ppms/app/services/invoice_profiles.py)
- [compliance.py](/C:/Fuel%20Management%20System/ppms/app/services/compliance.py)
- [document_templates.py](/C:/Fuel%20Management%20System/ppms/app/services/document_templates.py)
- [document_template_seed.py](/C:/Fuel%20Management%20System/ppms/app/services/document_template_seed.py)
- [document_template_catalog.py](/C:/Fuel%20Management%20System/ppms/app/services/document_template_catalog.py)
- [document_rendering.py](/C:/Fuel%20Management%20System/ppms/app/services/document_rendering.py)
- [financial_documents.py](/C:/Fuel%20Management%20System/ppms/app/services/financial_documents.py)
- [pdf_renderer.py](/C:/Fuel%20Management%20System/ppms/app/services/pdf_renderer.py)

### Notifications / integration / platform
- [notifications.py](/C:/Fuel%20Management%20System/ppms/app/services/notifications.py)
- [delivery_channels.py](/C:/Fuel%20Management%20System/ppms/app/services/delivery_channels.py)
- [delivery_queue.py](/C:/Fuel%20Management%20System/ppms/app/services/delivery_queue.py)
- [delivery_worker.py](/C:/Fuel%20Management%20System/ppms/app/services/delivery_worker.py)
- [online_api_hooks.py](/C:/Fuel%20Management%20System/ppms/app/services/online_api_hooks.py)
- [saas.py](/C:/Fuel%20Management%20System/ppms/app/services/saas.py)
- [organization_modules.py](/C:/Fuel%20Management%20System/ppms/app/services/organization_modules.py)
- [station_modules.py](/C:/Fuel%20Management%20System/ppms/app/services/station_modules.py)
- [auth_sessions.py](/C:/Fuel%20Management%20System/ppms/app/services/auth_sessions.py)
- [employee_profiles.py](/C:/Fuel%20Management%20System/ppms/app/services/employee_profiles.py)
- [maintenance.py](/C:/Fuel%20Management%20System/ppms/app/services/maintenance.py)
- [reports.py](/C:/Fuel%20Management%20System/ppms/app/services/reports.py)
- [report_exports.py](/C:/Fuel%20Management%20System/ppms/app/services/report_exports.py)
- [audit.py](/C:/Fuel%20Management%20System/ppms/app/services/audit.py)

### Hardware
- [hardware.py](/C:/Fuel%20Management%20System/ppms/app/services/hardware.py)
- [hardware_adapters.py](/C:/Fuel%20Management%20System/ppms/app/services/hardware_adapters.py)
- [nozzle_meter.py](/C:/Fuel%20Management%20System/ppms/app/services/nozzle_meter.py)

## 6. Database Inventory

Main local DB:
- [ppms.db](/C:/Fuel%20Management%20System/ppms.db)

Smoke/test DB:
- [ppms_smoke.db](/C:/Fuel%20Management%20System/ppms_smoke.db)

Migration history:
- [alembic/versions](/C:/Fuel%20Management%20System/alembic/versions)

### Migration sequence currently present
- [0001_initial_schema.py](/C:/Fuel%20Management%20System/alembic/versions/0001_initial_schema.py)
- [0002_organizations.py](/C:/Fuel%20Management%20System/alembic/versions/0002_organizations.py)
- [0003_expense_approvals.py](/C:/Fuel%20Management%20System/alembic/versions/0003_expense_approvals.py)
- [0004_reversal_approvals.py](/C:/Fuel%20Management%20System/alembic/versions/0004_reversal_approvals.py)
- [0005_purchase_approvals.py](/C:/Fuel%20Management%20System/alembic/versions/0005_purchase_approvals.py)
- [0006_customer_credit_overrides.py](/C:/Fuel%20Management%20System/alembic/versions/0006_customer_credit_overrides.py)
- [0007_report_export_jobs.py](/C:/Fuel%20Management%20System/alembic/versions/0007_report_export_jobs.py)
- [0008_tanker_operations_module.py](/C:/Fuel%20Management%20System/alembic/versions/0008_tanker_operations_module.py)
- [0009_meter_adjustment_events.py](/C:/Fuel%20Management%20System/alembic/versions/0009_meter_adjustment_events.py)
- [0010_notifications.py](/C:/Fuel%20Management%20System/alembic/versions/0010_notifications.py)
- [0011_notification_preferences_and_documents.py](/C:/Fuel%20Management%20System/alembic/versions/0011_notification_preferences_and_documents.py)
- [0012_delivery_retry_state.py](/C:/Fuel%20Management%20System/alembic/versions/0012_delivery_retry_state.py)
- [0013_invoice_tax_and_sale_invoices.py](/C:/Fuel%20Management%20System/alembic/versions/0013_invoice_tax_and_sale_invoices.py)
- [0014_document_templates.py](/C:/Fuel%20Management%20System/alembic/versions/0014_document_templates.py)
- [0015_saas_foundation.py](/C:/Fuel%20Management%20System/alembic/versions/0015_saas_foundation.py)
- [0016_online_api_hooks.py](/C:/Fuel%20Management%20System/alembic/versions/0016_online_api_hooks.py)
- [0017_compliance_controls_and_hardware_vendor.py](/C:/Fuel%20Management%20System/alembic/versions/0017_compliance_controls_and_hardware_vendor.py)
- [0018_auth_sessions_and_lockout.py](/C:/Fuel%20Management%20System/alembic/versions/0018_auth_sessions_and_lockout.py)
- [0019_inbound_webhooks_and_hook_signatures.py](/C:/Fuel%20Management%20System/alembic/versions/0019_inbound_webhooks_and_hook_signatures.py)
- [0020_hardware_vendor_connection_fields.py](/C:/Fuel%20Management%20System/alembic/versions/0020_hardware_vendor_connection_fields.py)
- [0021_attendance_and_payroll.py](/C:/Fuel%20Management%20System/alembic/versions/0021_attendance_and_payroll.py)
- [0022_platform_foundation_and_station_setup.py](/C:/Fuel%20Management%20System/alembic/versions/0022_platform_foundation_and_station_setup.py)
- [0023_employee_profiles.py](/C:/Fuel%20Management%20System/alembic/versions/0023_employee_profiles.py)
- [0024_brand_catalog_and_branding_inheritance.py](/C:/Fuel%20Management%20System/alembic/versions/0024_brand_catalog_and_branding_inheritance.py)

### DB tables and current attributes

#### Platform / identity / governance
- `organizations`
  - `id, name, code, description, legal_name, brand_catalog_id, brand_name, brand_code, logo_url, contact_email, contact_phone, registration_number, tax_registration_number, onboarding_status, billing_status, station_target_count, inherit_branding_to_stations, is_active`
- `stations`
  - `id, name, code, address, city, organization_id, is_head_office, display_name, legal_name_override, brand_name, brand_code, logo_url, use_organization_branding, is_active, setup_status, setup_completed_at, has_shops, has_pos, has_tankers, has_hardware, allow_meter_adjustments, created_at`
- `roles`
  - `id, name, description`
- `users`
  - `id, full_name, username, email, phone, whatsapp_number, hashed_password, is_active, failed_login_attempts, last_failed_login_at, locked_until, last_login_at, monthly_salary, payroll_enabled, role_id, organization_id, station_id, created_by_user_id, scope_level, is_platform_user`
- `auth_sessions`
  - `id, user_id, refresh_token_hash, is_active, expires_at, revoked_at, last_seen_at, ip_address, user_agent, created_at, updated_at`
- `employee_profiles`
  - `id, organization_id, station_id, linked_user_id, full_name, staff_type, employee_code, phone, national_id, address, is_active, payroll_enabled, monthly_salary, can_login, notes, created_at, updated_at`
- `audit_logs`
  - `id, user_id, username, station_id, module, action, entity_type, entity_id, details_json, created_at`
- `brand_catalog`
  - `id, code, name, logo_url, primary_color, sort_order, is_active`

#### SaaS / feature toggles / support foundation
- `subscription_plans`
  - `id, name, code, description, monthly_price, yearly_price, max_stations, max_users, feature_summary, is_active, is_default`
- `organization_subscriptions`
  - `id, organization_id, plan_id, status, billing_cycle, start_date, end_date, trial_ends_at, auto_renew, price_override, notes, created_at, updated_at`
- `organization_module_settings`
  - `id, organization_id, module_name, is_enabled`
- `station_module_settings`
  - `id, station_id, module_name, is_enabled`
- `online_api_hooks`
  - `id, organization_id, name, event_type, target_url, auth_type, auth_token, secret_key, signature_header, is_active, last_status, last_detail, last_triggered_at, created_at, updated_at`
- `inbound_webhook_events`
  - `id, organization_id, hook_name, event_type, source, headers_json, payload_json, status, detail, received_at`

#### Master data / setup
- `fuel_types`
  - `id, name, description`
- `invoice_profiles`
  - `id, station_id, business_name, legal_name, logo_url, registration_no, tax_registration_no, tax_label_1, tax_value_1, tax_label_2, tax_value_2, default_tax_rate, tax_inclusive, region_code, currency_code, compliance_mode, enforce_tax_registration, contact_email, contact_phone, footer_text, invoice_prefix, invoice_series, invoice_number_width, payment_terms, sale_invoice_notes`
- `document_templates`
  - `id, station_id, document_type, name, header_html, body_html, footer_html, is_active`

#### Party management
- `customers`
  - `id, name, code, customer_type, phone, address, credit_limit, outstanding_balance, credit_override_status, credit_override_amount, credit_override_requested_amount, credit_override_requested_at, credit_override_requested_by, credit_override_reason, credit_override_reviewed_at, credit_override_reviewed_by, credit_override_rejection_reason, station_id`
- `suppliers`
  - `id, name, code, phone, address, payable_balance`

#### Inventory / forecourt
- `tanks`
  - `id, name, code, capacity, current_volume, low_stock_threshold, location, station_id, fuel_type_id`
- `dispensers`
  - `id, name, code, location, station_id`
- `nozzles`
  - `id, name, code, meter_reading, current_segment_start_reading, current_segment_started_at, dispenser_id, tank_id, fuel_type_id`
- `tank_dips`
  - `id, tank_id, dip_reading_mm, calculated_volume, system_volume, loss_gain, notes, created_at`
- `nozzle_readings`
  - `id, nozzle_id, reading, sale_id, created_at`
- `meter_adjustment_events`
  - `id, nozzle_id, station_id, old_reading, new_reading, reason, adjusted_by_user_id, adjusted_at`

#### Sales / shifts / finance
- `fuel_sales`
  - `id, nozzle_id, station_id, fuel_type_id, customer_id, opening_meter, closing_meter, quantity, rate_per_liter, total_amount, sale_type, shift_name, shift_id, is_reversed, reversal_request_status, reversal_requested_at, reversal_requested_by, reversal_request_reason, reversal_reviewed_at, reversal_reviewed_by, reversal_rejection_reason, reversed_at, reversed_by, created_at`
- `shifts`
  - `id, station_id, user_id, start_time, end_time, status, initial_cash, total_sales_cash, total_sales_credit, expected_cash, actual_cash_collected, difference, notes`
- `expenses`
  - `id, title, category, amount, notes, station_id, status, submitted_by_user_id, approved_by_user_id, approved_at, rejected_at, rejection_reason, created_at`
- `purchases`
  - `id, supplier_id, tank_id, fuel_type_id, tanker_id, quantity, rate_per_liter, total_amount, reference_no, notes, status, submitted_by_user_id, approved_by_user_id, approved_at, rejected_at, rejection_reason, is_reversed, reversal_request_status, reversal_requested_at, reversal_requested_by, reversal_request_reason, reversal_reviewed_at, reversal_reviewed_by, reversal_rejection_reason, reversed_at, reversed_by, created_at`
- `customer_payments`
  - `id, customer_id, station_id, amount, payment_method, reference_no, notes, is_reversed, reversal_request_status, reversal_requested_at, reversal_requested_by, reversal_request_reason, reversal_reviewed_at, reversal_reviewed_by, reversal_rejection_reason, reversed_at, reversed_by, created_at`
- `supplier_payments`
  - `id, supplier_id, station_id, amount, payment_method, reference_no, notes, is_reversed, reversal_request_status, reversal_requested_at, reversal_requested_by, reversal_request_reason, reversal_reviewed_at, reversal_reviewed_by, reversal_rejection_reason, reversed_at, reversed_by, created_at`

#### POS
- `pos_products`
  - `id, name, code, category, module, price, stock_quantity, track_inventory, is_active, station_id`
- `pos_sales`
  - `id, station_id, module, payment_method, customer_name, notes, total_amount, is_reversed, reversed_at, reversed_by, created_at`
- `pos_sale_items`
  - `id, sale_id, product_id, quantity, unit_price, line_total`

#### Tanker operations
- `tankers`
  - `id, registration_no, name, capacity, ownership_type, owner_name, driver_name, driver_phone, status, station_id, fuel_type_id`
- `tanker_trips`
  - `id, tanker_id, station_id, supplier_id, fuel_type_id, trip_type, status, settlement_status, linked_tank_id, linked_purchase_id, destination_name, notes, total_quantity, fuel_revenue, delivery_revenue, expense_total, net_profit, created_at, completed_at`
- `tanker_deliveries`
  - `id, trip_id, customer_id, destination_name, quantity, fuel_rate, fuel_amount, delivery_charge, sale_type, paid_amount, outstanding_amount, created_at`
- `tanker_trip_expenses`
  - `id, trip_id, expense_type, amount, notes, created_at`

#### Hardware / integration
- `hardware_devices`
  - `id, name, code, device_type, vendor_name, integration_mode, protocol, endpoint_url, device_identifier, api_key, status, is_active, station_id, dispenser_id, tank_id, last_seen_at, last_error`
- `hardware_events`
  - `id, device_id, station_id, event_type, source, status, dispenser_id, tank_id, nozzle_id, meter_reading, volume, temperature, notes, payload_json, recorded_at`

#### Reporting / documents / notifications
- `report_export_jobs`
  - `id, report_type, format, status, station_id, organization_id, requested_by_user_id, filters_json, file_name, content_type, content_text, created_at`
- `financial_document_dispatches`
  - `id, station_id, requested_by_user_id, document_type, entity_type, entity_id, channel, output_format, recipient_name, recipient_contact, status, detail, attempts_count, last_attempt_at, next_retry_at, processed_at, created_at`
- `notifications`
  - `id, recipient_user_id, actor_user_id, station_id, organization_id, event_type, title, message, entity_type, entity_id, is_read, created_at, read_at`
- `notification_preferences`
  - `id, user_id, event_type, in_app_enabled, email_enabled, sms_enabled, whatsapp_enabled`
- `notification_deliveries`
  - `id, notification_id, channel, destination, status, detail, attempts_count, last_attempt_at, next_retry_at, processed_at, created_at`

#### Attendance / payroll
- `attendance_records`
  - `id, station_id, user_id, attendance_date, status, check_in_at, check_out_at, notes, approved_by_user_id, created_at, updated_at`
- `payroll_runs`
  - `id, station_id, period_start, period_end, status, total_staff, total_gross_amount, total_deductions, total_net_amount, notes, generated_by_user_id, finalized_by_user_id, finalized_at, created_at, updated_at`
- `payroll_lines`
  - `id, payroll_run_id, user_id, present_days, leave_days, absent_days, payable_days, monthly_salary, gross_amount, deductions, net_amount`

## 7. Flutter Structure

Flutter root: [ppms_flutter](/C:/Fuel%20Management%20System/ppms_flutter)

### Core Flutter files
- [ppms_flutter/lib/core/config/app_config.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/core/config/app_config.dart)
  - base app config and API base URL
- [ppms_flutter/lib/core/network/api_client.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/core/network/api_client.dart)
  - all HTTP calls to backend
- [ppms_flutter/lib/core/network/api_exception.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/core/network/api_exception.dart)
  - API error wrapper
- [ppms_flutter/lib/core/session/session_controller.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/core/session/session_controller.dart)
  - auth state, current user, session-aware data access
- [ppms_flutter/lib/core/session/session_capabilities.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/core/session/session_capabilities.dart)
  - central capability/visibility rules
- [ppms_flutter/lib/core/widgets/responsive_split.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/core/widgets/responsive_split.dart)
  - responsive two-pane layout helper
- [ppms_flutter/lib/core/utils/document_file_actions.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/core/utils/document_file_actions.dart)
  - local save/open document helper

### Main Flutter screens
- [login_screen.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/auth/presentation/login_screen.dart)
  - sign in
- [app_shell.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/shell/presentation/app_shell.dart)
  - navigation shell, role-aware module layout
- [platform_dashboard_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/dashboard/presentation/platform_dashboard_page.dart)
  - MasterAdmin dashboard
- [dashboard_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/dashboard/presentation/dashboard_page.dart)
  - tenant dashboards by role
- [onboarding_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/onboarding/presentation/onboarding_page.dart)
  - organization onboarding
- [station_setup_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/setup/presentation/station_setup_page.dart)
  - detailed station setup and forecourt mapping
- [setup_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/setup/presentation/setup_page.dart)
  - tenant setup workspace
- [admin_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/admin/presentation/admin_page.dart)
  - users, staff, roles, stations, modules
- [sales_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/sales/presentation/sales_page.dart)
  - forecourt sales
- [shift_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/shifts/presentation/shift_page.dart)
  - shifts
- [finance_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/finance/presentation/finance_page.dart)
  - purchases, customer payments, supplier payments
- [documents_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/documents/presentation/documents_page.dart)
  - document center
- [parties_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/parties/presentation/parties_page.dart)
  - customers/suppliers
- [governance_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/governance/presentation/governance_page.dart)
  - approvals/review workspace
- [expenses_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/expenses/presentation/expenses_page.dart)
  - expense workspace
- [hardware_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/hardware/presentation/hardware_page.dart)
  - hardware and meter ops
- [tanker_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/tankers/presentation/tanker_page.dart)
  - tanker operations
- [reports_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/reports/presentation/reports_page.dart)
  - reports and exports
- [payroll_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/payroll/presentation/payroll_page.dart)
  - payroll
- [attendance_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/attendance/presentation/attendance_page.dart)
  - attendance
- [notifications_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/notifications/presentation/notifications_page.dart)
  - inbox, preferences, delivery health
- [settings_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/settings/presentation/settings_page.dart)
  - connection/session/settings
- [pos_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/pos/presentation/pos_page.dart)
  - POS sales
- [inventory_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/inventory/presentation/inventory_page.dart)
  - inventory master data

### Shared dashboard visual system
- [dashboard_widgets.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/dashboard/presentation/dashboard_widgets.dart)
  - hero cards
  - metric tiles
  - section cards
  - distribution/attention/ratio widgets

## 8. Current Role and Scope Direction

Reference docs:
- [Docs/ROLE_HIERARCHY_AND_ACCESS_MODEL.md](/C:/Fuel%20Management%20System/Docs/ROLE_HIERARCHY_AND_ACCESS_MODEL.md)
- [Docs/MASTER_ADMIN_ORGANIZATION_AND_PERMISSION_MODEL.md](/C:/Fuel%20Management%20System/Docs/MASTER_ADMIN_ORGANIZATION_AND_PERMISSION_MODEL.md)
- [Docs/NEXT_PHASE_IMPLEMENTATION_PLAN.md](/C:/Fuel%20Management%20System/Docs/NEXT_PHASE_IMPLEMENTATION_PLAN.md)

### Current intended hierarchy
- `MasterAdmin`
  - Razex/platform owner
  - platform-level access
  - onboarding, support, tenant oversight
- `HeadOffice`
  - organization admin / customer owner role
  - all stations inside the same organization
  - also acts as station admin when the organization has only one station
- `StationAdmin`
  - station-level setup and management
  - used when the organization has more than one station
- `Manager`
  - station operations control
- `Accountant`
  - finance/report/document focus
- `Operator`
  - daily operational tasks
- `Profile-only staff`
  - non-login staff record support through employee profiles

Current role cleanup decision:
- `MasterAdmin` is the only true platform-wide admin.
- `HeadOffice` is the tenant organization admin role.
- `StationAdmin` should be delegated only when a multi-station organization needs station-level control.
- the old generic `Admin` account/role has been removed from active seed data and should not be used for new customer organizations.

### Important UI rule
Menus, dashboards, and workspaces must be driven by:
- current role
- scope level
- enabled organization modules
- enabled station modules
- permission actions
- read-only vs editable state

If a module is off:
- no menu
- no dashboard card
- no visible trace

If read-only:
- visible only in read-only form

### Current planning adjustment
- approval-heavy day-to-day flows are no longer the preferred target
- future refactors should keep reversals, unusual overrides, and sensitive corrections as controlled actions
- but normal expenses, purchases, cash submissions, and operational records should move toward direct recording

## 9. Tests

Tests live in [tests](/C:/Fuel%20Management%20System/tests).

### Current test files
- [conftest.py](/C:/Fuel%20Management%20System/tests/conftest.py)
- [test_access_controls.py](/C:/Fuel%20Management%20System/tests/test_access_controls.py)
- [test_auth_flows.py](/C:/Fuel%20Management%20System/tests/test_auth_flows.py)
- [test_backend_alignment_smoke.py](/C:/Fuel%20Management%20System/tests/test_backend_alignment_smoke.py)
- [test_flutter_backend_contract.py](/C:/Fuel%20Management%20System/tests/test_flutter_backend_contract.py)
- [test_master_data_and_modules.py](/C:/Fuel%20Management%20System/tests/test_master_data_and_modules.py)
- [test_payroll_attendance.py](/C:/Fuel%20Management%20System/tests/test_payroll_attendance.py)
- [test_pos_and_hardware.py](/C:/Fuel%20Management%20System/tests/test_pos_and_hardware.py)
- [test_reporting_and_errors.py](/C:/Fuel%20Management%20System/tests/test_reporting_and_errors.py)
- [test_sales_workspace_payload.py](/C:/Fuel%20Management%20System/tests/test_sales_workspace_payload.py)
- [test_transactions.py](/C:/Fuel%20Management%20System/tests/test_transactions.py)
- [test_desktop_navigation.py](/C:/Fuel%20Management%20System/tests/test_desktop_navigation.py)

### What the test suite covers
- auth/session
- access controls
- backend route/database alignment
- Flutter/backend contract alignment
- transactions
- reports/errors
- hardware/POS
- payroll/attendance
- master data/modules

### Standard verification commands
Backend:
```powershell
venv\Scripts\python.exe -m pytest tests
```

Flutter:
```powershell
cd C:\Fuel Management System\ppms_flutter
flutter analyze
flutter test
```

## 10. Local Runtime And Workflow

### Preferred full stack restart

Use after code changes before manual Phase 9 testing:
```powershell
.\restart_local_dev.ps1
```

This helper:
- restarts the backend on `127.0.0.1:8012`
- opens a backend log monitor so HTTP `200`, `400`, `403`, and server errors are visible while testing
- restarts the support console dev server
- restarts Flutter Windows with `PPMS_API_BASE_URL=http://127.0.0.1:8012`
- opens support console and Flutter in separate PowerShell windows

Backend-only restart:
```powershell
.\restart_local_dev.ps1 -SkipSupportConsole -SkipFlutter
```

### Backend-only helper
Use:
```powershell
venv\Scripts\python.exe run_local_server.py
```

This helper:
- kills any previous listener on `127.0.0.1:8012`
- starts backend from the correct root
- avoids falling back to the wrong nested DB path
- checks `/health`

### Flutter run
```powershell
cd C:\Fuel Management System\ppms_flutter
flutter run -d windows --dart-define=PPMS_API_BASE_URL=http://127.0.0.1:8012
```

### Main local DB rule
Use:
- [ppms.db](/C:/Fuel%20Management%20System/ppms.db) for main local runtime
- [ppms_smoke.db](/C:/Fuel%20Management%20System/ppms_smoke.db) for smoke/migration checks

Do not create ad hoc new `.db` files unless there is a special reason.

### Seeded local users
- `masteradmin / master123`
- `headoffice / office123`
- `stationadmin / station123`
- `manager / manager123`
- `operator / operator123`
- `accountant / accountant123`


## 11. What To Edit For Common Changes

### If changing permissions or role visibility
Backend:
- [ppms/app/core/permissions.py](/C:/Fuel%20Management%20System/ppms/app/core/permissions.py)
- [ppms/app/core/access.py](/C:/Fuel%20Management%20System/ppms/app/core/access.py)
- [ppms/app/api/auth.py](/C:/Fuel%20Management%20System/ppms/app/api/auth.py)
- [ppms/app/api/user.py](/C:/Fuel%20Management%20System/ppms/app/api/user.py)

Flutter:
- [ppms_flutter/lib/core/session/session_capabilities.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/core/session/session_capabilities.dart)
- [ppms_flutter/lib/features/shell/presentation/app_shell.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/shell/presentation/app_shell.dart)
- affected workspace page

### If changing onboarding or station setup
Backend:
- [ppms/app/api/organization.py](/C:/Fuel%20Management%20System/ppms/app/api/organization.py)
- [ppms/app/api/station.py](/C:/Fuel%20Management%20System/ppms/app/api/station.py)
- [ppms/app/api/brand_catalog.py](/C:/Fuel%20Management%20System/ppms/app/api/brand_catalog.py)
- [ppms/app/models/organization.py](/C:/Fuel%20Management%20System/ppms/app/models/organization.py)
- [ppms/app/models/station.py](/C:/Fuel%20Management%20System/ppms/app/models/station.py)

Flutter:
- [onboarding_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/onboarding/presentation/onboarding_page.dart)
- [station_setup_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/setup/presentation/station_setup_page.dart)
- [api_client.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/core/network/api_client.dart)

### If changing fuel sales logic
Backend:
- [ppms/app/api/fuel_sale.py](/C:/Fuel%20Management%20System/ppms/app/api/fuel_sale.py)
- [ppms/app/services/fuel_sales.py](/C:/Fuel%20Management%20System/ppms/app/services/fuel_sales.py)
- [ppms/app/models/fuel_sale.py](/C:/Fuel%20Management%20System/ppms/app/models/fuel_sale.py)

Flutter:
- [sales_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/sales/presentation/sales_page.dart)
- [api_client.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/core/network/api_client.dart)

### If changing finance logic
Backend:
- [purchase.py](/C:/Fuel%20Management%20System/ppms/app/api/purchase.py)
- [customer_payment.py](/C:/Fuel%20Management%20System/ppms/app/api/customer_payment.py)
- [supplier_payment.py](/C:/Fuel%20Management%20System/ppms/app/api/supplier_payment.py)
- [purchases.py](/C:/Fuel%20Management%20System/ppms/app/services/purchases.py)
- [payments.py](/C:/Fuel%20Management%20System/ppms/app/services/payments.py)

Flutter:
- [finance_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/finance/presentation/finance_page.dart)

### If changing tanker logic
Backend:
- [ppms/app/api/tanker.py](/C:/Fuel%20Management%20System/ppms/app/api/tanker.py)
- [ppms/app/services/tanker_ops.py](/C:/Fuel%20Management%20System/ppms/app/services/tanker_ops.py)
- [ppms/app/models/tanker_compartment.py](/C:/Fuel%20Management%20System/ppms/app/models/tanker_compartment.py)
- [ppms/app/models/fuel_transfer.py](/C:/Fuel%20Management%20System/ppms/app/models/fuel_transfer.py)
- tanker models under [ppms/app/models](/C:/Fuel%20Management%20System/ppms/app/models)

Flutter:
- [tanker_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/tankers/presentation/tanker_page.dart)

### If changing hardware or meter rules
Backend:
- [ppms/app/api/hardware.py](/C:/Fuel%20Management%20System/ppms/app/api/hardware.py)
- [ppms/app/services/hardware.py](/C:/Fuel%20Management%20System/ppms/app/services/hardware.py)
- [ppms/app/services/hardware_adapters.py](/C:/Fuel%20Management%20System/ppms/app/services/hardware_adapters.py)
- [ppms/app/services/nozzle_meter.py](/C:/Fuel%20Management%20System/ppms/app/services/nozzle_meter.py)

Flutter:
- [hardware_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/hardware/presentation/hardware_page.dart)
- [station_setup_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/setup/presentation/station_setup_page.dart)

### If changing reports/documents
Backend:
- [reports.py](/C:/Fuel%20Management%20System/ppms/app/services/reports.py)
- [report_exports.py](/C:/Fuel%20Management%20System/ppms/app/services/report_exports.py)
- [financial_documents.py](/C:/Fuel%20Management%20System/ppms/app/services/financial_documents.py)
- [document_rendering.py](/C:/Fuel%20Management%20System/ppms/app/services/document_rendering.py)
- [document_templates.py](/C:/Fuel%20Management%20System/ppms/app/services/document_templates.py)

Flutter:
- [reports_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/reports/presentation/reports_page.dart)
- [documents_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/documents/presentation/documents_page.dart)

### If changing platform support / MasterAdmin flows
Backend:
- [organization.py](/C:/Fuel%20Management%20System/ppms/app/api/organization.py)
- [station.py](/C:/Fuel%20Management%20System/ppms/app/api/station.py)
- [saas.py](/C:/Fuel%20Management%20System/ppms/app/api/saas.py)
- [brand_catalog.py](/C:/Fuel%20Management%20System/ppms/app/api/brand_catalog.py)
- [permissions.py](/C:/Fuel%20Management%20System/ppms/app/core/permissions.py)

Flutter:
- [platform_dashboard_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/dashboard/presentation/platform_dashboard_page.dart)
- [onboarding_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/onboarding/presentation/onboarding_page.dart)
- [station_setup_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/setup/presentation/station_setup_page.dart)
- [admin_page.dart](/C:/Fuel%20Management%20System/ppms_flutter/lib/features/admin/presentation/admin_page.dart)

## 12. Current Visual/UI State

The Flutter app has moved away from being only raw CRUD pages.

### Already redesigned into stronger workspaces
- dashboards by role
- platform dashboard
- onboarding
- station setup
- admin
- finance
- documents
- parties
- governance
- sales
- shifts
- hardware
- expenses
- tankers
- attendance
- POS
- notifications

### Shared design system in active use
- hero cards
- metric tiles
- section cards
- ratio bars
- distribution bars
- attention lists
- responsive split layouts

### Important UX direction
- no ghost modules when a module is off
- read-only when visible but not editable
- dashboards should change by role/scope
- setup/mapping should become more visual
- drag/drop only where spatial/configuration logic truly benefits

## 13. Planned But Not Yet Fully Built

### Planned next major product pieces
- local stabilization and acceptance testing
  - migration validation
  - fresh database rebuild validation
  - role-by-role walkthroughs
  - support console walkthroughs
- cloud deployment
  - backend on EC2
  - web frontend on Vercel
  - GitHub-driven automation
- eventual production PostgreSQL deployment

### Node.js support console status
This is now implemented locally as a Next.js app under `support_console`.

Current purpose:
- Razex support dashboard
- open any organization
- inspect/fix data
- edit tenant values during support
- support billing/subscription views
- support module controls
- support communication delivery triage
- support reporting/profit review

## 14. Deployment Status

### Current status
- local-first development is still the active workflow
- AWS EC2 was prepared conceptually, but deployment is intentionally postponed until local work is more stable
- Vercel/web deployment is also deferred until local product logic is solid enough

### Current best practice
1. finish locally
2. commit to GitHub
3. deploy only after local review and stabilization

## 15. Related Docs

- [README.md](/C:/Fuel%20Management%20System/README.md)
- [Docs/API_INVENTORY.txt](/C:/Fuel%20Management%20System/Docs/API_INVENTORY.txt)
- [Docs/FLUTTER_CLIENT_FOUNDATION.md](/C:/Fuel%20Management%20System/Docs/FLUTTER_CLIENT_FOUNDATION.md)
- [Docs/IMPLEMENTATION_GAP_ANALYSIS.md](/C:/Fuel%20Management%20System/Docs/IMPLEMENTATION_GAP_ANALYSIS.md)
- [Docs/MASTER_ADMIN_ORGANIZATION_AND_PERMISSION_MODEL.md](/C:/Fuel%20Management%20System/Docs/MASTER_ADMIN_ORGANIZATION_AND_PERMISSION_MODEL.md)
- [Docs/ROLE_HIERARCHY_AND_ACCESS_MODEL.md](/C:/Fuel%20Management%20System/Docs/ROLE_HIERARCHY_AND_ACCESS_MODEL.md)
- [Docs/NEXT_PHASE_IMPLEMENTATION_PLAN.md](/C:/Fuel%20Management%20System/Docs/NEXT_PHASE_IMPLEMENTATION_PLAN.md)

## 16. Recommended Next Steps

### For product work
1. execute `Phase 9 - Local Stabilization and Acceptance` using [CHECKTESTINGPLAN.md](/C:/Fuel%20Management%20System/docs/CHECKTESTINGPLAN.md)
2. validate migrations and fresh database rebuilds
3. run role-by-role tenant Flutter walkthroughs
4. run MasterAdmin support console walkthroughs
5. record issues from each manual step, fix them, and retest before moving forward
6. prepare the local freeze gate before cloud deployment

### For deployment later
1. finalize local product behavior
2. prepare PostgreSQL deployment config
3. prepare Docker/deploy scripts
4. deploy backend to EC2
5. connect web frontend to Vercel
6. automate deploy through GitHub

## 17. Short Summary

This project is already far beyond an early prototype.

What exists now:
- large FastAPI backend
- broad database schema
- working Flutter operational client
- platform and tenant role model foundation
- onboarding, station setup, operations, finance, documents, reporting, payroll, notifications, hardware, tanker support

What still remains:
- local stabilization and acceptance testing
- deeper review/fix pass during Phase 9
- final deployment automation and production hosting

This file should be updated as the next major milestone source-of-truth whenever:
- new modules are added
- DB tables change
- role/scope rules change
- frontend architecture changes
- deployment approach changes
