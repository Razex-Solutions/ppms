# Backend Source Of Truth

## Core Rule

The new frontend must treat the backend as the source of truth.

That means the frontend is built from:

- route registry
- Pydantic request and response schemas
- SQLAlchemy data model
- role scope rules
- permission matrix
- capability and module toggles

## Active Backend Route Families

These come from [ppms/app/api/__init__.py](/C:/Fuel%20Management%20System/ppms/app/api/__init__.py).

- `auth`
- `brands`
- `audit_logs`
- `attendance`
- `roles`
- `organizations`
- `organization_modules`
- `stations`
- `station_shift_templates`
- `station_modules`
- `users`
- `fuel_types`
- `tanks`
- `dispensers`
- `nozzles`
- `notifications`
- `online_api_hooks`
- `online_api_hooks_public`
- `fuel_sales`
- `financial_documents`
- `saas`
- `hardware`
- `invoice_profiles`
- `internal_fuel_usage`
- `document_templates`
- `employee_profiles`
- `customers`
- `suppliers`
- `purchases`
- `pos_products`
- `pos_sales`
- `payroll`
- `salary_adjustments`
- `tankers`
- `expenses`
- `accounting`
- `reports`
- `report_exports`
- `report_definitions`
- `customer_payments`
- `supplier_payments`
- `ledger`
- `maintenance`
- `shifts`
- `tank_dips`
- `dashboard`

## Backend Modules Known To Capability Resolution

These come from [ppms/app/services/capabilities.py](/C:/Fuel%20Management%20System/ppms/app/services/capabilities.py).

- `accounting`
- `attendance`
- `audit_logs`
- `auth`
- `brands`
- `customer_payments`
- `customers`
- `dashboard`
- `dispensers`
- `document_templates`
- `employee_profiles`
- `expenses`
- `financial_documents`
- `fuel_sales`
- `fuel_types`
- `hardware`
- `internal_fuel_usage`
- `invoice_profiles`
- `ledger`
- `maintenance`
- `notifications`
- `nozzles`
- `online_api_hooks`
- `online_api_hooks_public`
- `organization_modules`
- `organizations`
- `payroll`
- `pos_products`
- `pos_sales`
- `purchases`
- `report_definitions`
- `report_exports`
- `reports`
- `roles`
- `saas`
- `salary_adjustments`
- `shifts`
- `station_modules`
- `station_shift_templates`
- `stations`
- `supplier_payments`
- `suppliers`
- `tank_dips`
- `tankers`
- `tanks`
- `users`

## Special Module And Feature Flag Notes

- `tanker_operations` is a station-level module toggle alias that maps to the `tankers` frontend capability
- `meter_adjustments` is controlled partly by station feature flag `allow_meter_adjustments`
- station entity also contains direct booleans:
  - `has_shops`
  - `has_pos`
  - `has_tankers`
  - `has_hardware`
  - `allow_meter_adjustments`

## Frontend Domain Buckets

The new frontend should not mirror backend files one by one. It should group them into stable product domains:

- App Foundation
  - `auth`, `roles`, `users`, capabilities from `/auth/me`

- Organization And Station Setup
  - `organizations`, `stations`, `organization_modules`, `station_modules`, `station_shift_templates`, `brands`, `invoice_profiles`, `fuel_types`, `tanks`, `dispensers`, `nozzles`

- Shift And Forecourt Operations
  - `shifts`, `fuel_sales`, `internal_fuel_usage`, `tank_dips`, `hardware`

- Finance And Party Management
  - `customers`, `suppliers`, `customer_payments`, `supplier_payments`, `ledger`, `purchases`, `expenses`, `accounting`, `fuel_price_history`

- HR And Payroll
  - `employee_profiles`, `attendance`, `salary_adjustments`, `payroll`

- Tanker And POS Optional Modules
  - `tankers`, `pos_products`, `pos_sales`

- Reporting And Communication
  - `reports`, `report_exports`, `report_definitions`, `financial_documents`, `document_templates`, `notifications`

- Platform And Operations Admin
  - `saas`, `maintenance`, `audit_logs`, `online_api_hooks`

## Frontend Contract Rule

Every feature must use:

- schema-driven request objects
- schema-driven response objects
- permission-driven action availability
- module-driven screen visibility

Do not infer create, update, delete, approve, or reverse actions just because a list screen exists.
