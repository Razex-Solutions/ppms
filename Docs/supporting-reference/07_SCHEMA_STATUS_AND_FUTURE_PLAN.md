# Schema Status And Future Plan

This file separates:

- what already exists in the backend now
- what is still missing but should be added soon
- what is future enterprise expansion and should not block the new Flutter app

Use this as the schema planning reference for the frontend rebuild.

## 1. Already In Backend Now

These tables already exist in the current backend.

### Access, tenancy, SaaS

- `roles`
- `users`
- `organizations`
- `stations`
- `organization_module_settings`
- `station_module_settings`
- `subscription_plans`
- `organization_subscriptions`
- `auth_sessions`

### Fuel setup and station operations

- `fuel_types`
- `tanks`
- `tank_dips`
- `dispensers`
- `nozzles`
- `shifts`
- `fuel_sales`
- `nozzle_readings`
- `meter_adjustment_events`
- `station_shift_templates`
- `shift_cash`
- `cash_submissions`
- `internal_fuel_usage`
- `fuel_price_history`

### Customers, suppliers, purchases, payments, expenses

- `customers`
- `customer_payments`
- `suppliers`
- `supplier_payments`
- `purchases`
- `expenses`

### Tanker operations

- `tankers`
- `tanker_compartments`
- `tanker_trips`
- `tanker_deliveries`
- `tanker_trip_expenses`
- `fuel_transfers`

### POS and retail modules

- `pos_products`
- `pos_sales`
- `pos_sale_items`

### Notifications, invoicing, documents, exports

- `notifications`
- `notification_deliveries`
- `notification_preferences`
- `invoice_profiles`
- `document_templates`
- `financial_document_dispatches`
- `report_export_jobs`
- `report_definitions`

### Integrations, hardware, audit, branding

- `online_api_hooks`
- `inbound_webhook_events`
- `hardware_devices`
- `hardware_events`
- `audit_logs`
- `brand_catalog`

### HR and payroll

- `employee_profiles`
- `attendance_records`
- `payroll_runs`
- `payroll_lines`
- `salary_adjustments`

## 2. Already In Backend But Important Schema Notes

These already exist, but the frontend plan should remember the real backend fields.

### `shifts`

Actual backend includes:

- `shift_template_id`
- `shift_name`
- `initial_cash`
- `total_sales_cash`
- `total_sales_credit`
- `expected_cash`
- `actual_cash_collected`
- `difference`

### `attendance_records`

Actual backend includes:

- `employee_profile_id`
- not just `user_id`

### `payroll_lines`

Actual backend includes:

- `employee_profile_id`
- `attendance_deductions`
- `adjustment_additions`
- `adjustment_deductions`
- `deductions`
- `net_amount`

### `tanker_trips`

Actual backend includes:

- `settlement_status`
- `linked_tank_id`
- `linked_purchase_id`
- `transfer_tank_id`
- `loaded_quantity`
- `purchase_rate`
- `purchase_total`
- `leftover_quantity`
- `transferred_quantity`

### `stations`

Actual backend includes feature and module-driving fields:

- `has_shops`
- `has_pos`
- `has_tankers`
- `has_hardware`
- `allow_meter_adjustments`

## 3. Missing But Recommended Soon

These are the best near-term additions if we want to strengthen operations without overloading the first Flutter build.

## 3A. Daily Close, Shift Handover, Reconciliation

- `daily_closes`
  - `id`
  - `station_id -> stations.id`
  - `business_date`
  - `shift_mode`
  - `status`
  - `opened_by_user_id -> users.id`
  - `closed_by_user_id -> users.id nullable`
  - `fuel_cash_sales`
  - `fuel_credit_sales`
  - `pos_cash_sales`
  - `pos_credit_sales`
  - `customer_recoveries`
  - `supplier_payments`
  - `expense_payments`
  - `expected_cash`
  - `actual_cash`
  - `cash_variance`
  - `notes`
  - `opened_at`
  - `closed_at nullable`

- `daily_close_nozzle_summaries`
  - `id`
  - `daily_close_id -> daily_closes.id`
  - `nozzle_id -> nozzles.id`
  - `opening_meter`
  - `closing_meter`
  - `sold_quantity`
  - `rate_applied`
  - `sale_amount`

- `daily_close_tank_summaries`
  - `id`
  - `daily_close_id -> daily_closes.id`
  - `tank_id -> tanks.id`
  - `opening_volume`
  - `purchases_in`
  - `transfers_in`
  - `sales_out`
  - `transfers_out`
  - `expected_system_volume`
  - `dip_volume`
  - `variance_volume`

- `daily_close_payment_summaries`
  - `id`
  - `daily_close_id -> daily_closes.id`
  - `payment_method`
  - `amount`

- `cash_drops`
  - `id`
  - `station_id -> stations.id`
  - `shift_id -> shifts.id nullable`
  - `daily_close_id -> daily_closes.id nullable`
  - `dropped_by_user_id -> users.id`
  - `received_by_user_id -> users.id nullable`
  - `amount`
  - `drop_type`
  - `reference_no nullable`
  - `notes`
  - `created_at`

- `shift_handovers`
  - `id`
  - `station_id -> stations.id`
  - `outgoing_shift_id -> shifts.id`
  - `incoming_shift_id -> shifts.id`
  - `cash_opening_transferred`
  - `meter_opening_transferred`
  - `notes`
  - `verified_by_user_id -> users.id nullable`
  - `created_at`

Why soon:

- this is highly valuable for real station operations
- it improves shift reconciliation and day closing without requiring a full accounting rewrite

## 3B. Inventory And Stock Movement Ledger

- `fuel_inventory_movements`
  - `id`
  - `station_id -> stations.id`
  - `tank_id -> tanks.id`
  - `fuel_type_id -> fuel_types.id`
  - `movement_type`
  - `quantity_in`
  - `quantity_out`
  - `unit_rate nullable`
  - `reference_type`
  - `reference_id`
  - `notes`
  - `created_by_user_id -> users.id nullable`
  - `created_at`

- `pos_inventory_movements`
  - `id`
  - `station_id -> stations.id`
  - `product_id -> pos_products.id`
  - `movement_type`
  - `quantity_in`
  - `quantity_out`
  - `unit_cost nullable`
  - `reference_type`
  - `reference_id`
  - `notes`
  - `created_by_user_id -> users.id nullable`
  - `created_at`

- `inventory_adjustments`
  - `id`
  - `station_id -> stations.id`
  - `module_name`
  - `reason`
  - `status`
  - `created_by_user_id -> users.id`
  - `approved_by_user_id -> users.id nullable`
  - `created_at`
  - `posted_at nullable`

- `inventory_adjustment_lines`
  - `id`
  - `adjustment_id -> inventory_adjustments.id`
  - `product_id -> pos_products.id nullable`
  - `tank_id -> tanks.id nullable`
  - `system_quantity`
  - `physical_quantity`
  - `variance_quantity`
  - `unit_rate nullable`
  - `notes`

Why soon:

- strong auditability
- cleaner stock history
- better reporting

## 3C. Attachments And Evidence

- `attachments`
  - `id`
  - `organization_id -> organizations.id nullable`
  - `station_id -> stations.id nullable`
  - `module_name`
  - `entity_type`
  - `entity_id`
  - `file_name`
  - `stored_name`
  - `file_url`
  - `mime_type`
  - `file_size`
  - `uploaded_by_user_id -> users.id`
  - `created_at`

- `attachment_tags`
  - `id`
  - `attachment_id -> attachments.id`
  - `tag_name`

Why soon:

- practical for receipts, proofs, repairs, and tanker evidence

## 3D. Exception Tracking

- `exception_events`
  - `id`
  - `organization_id -> organizations.id nullable`
  - `station_id -> stations.id nullable`
  - `module_name`
  - `entity_type`
  - `entity_id`
  - `exception_type`
  - `severity`
  - `description`
  - `status`
  - `reported_by_user_id -> users.id nullable`
  - `resolved_by_user_id -> users.id nullable`
  - `resolved_at nullable`
  - `created_at`

Why soon:

- gives us structured handling for variances, credit breaches, negative stock, and meter resets

## 4. Future Enterprise Schema

These are good future schemas, but they should not block the first clean Flutter app.

## 4A. Granular Permissions And Approval Control

- `permissions`
- `role_permissions`
- `user_permission_overrides`
- `approval_policies`
- `approval_policy_steps`
- `approval_requests`
- `approval_request_steps`

Why future:

- powerful but heavy
- current backend already has a code-based permission model
- we should first stabilize product workflows before adding full policy engines

## 4B. Proper Accounting Ledger

- `account_categories`
- `accounts`
- `journal_entries`
- `journal_entry_lines`
- `cash_accounts`
- `bank_accounts`
- `bank_transactions`
- `party_ledgers`

Why future:

- this is a major accounting architecture layer
- useful later, but not needed to start the new Flutter app

## 4C. Tank Calibration And Dip Chart Master

- `tank_calibration_charts`
- `tank_calibration_chart_lines`
- `tank_calibration_adjustments`

Why future:

- important for advanced fuel accuracy
- not needed before basic setup, sales, dips, and inventory become stable

## 4D. Fuel Price Scheduling And Supplier Rate Contracts

- `fuel_price_schedules`
- `supplier_fuel_rates`

Why future:

- current `fuel_price_history` covers the basic need
- schedule-based pricing can come later

## 4E. Pump-To-Pump, Station-To-Station, Bulk Fuel Selling

- `station_transfers`
- `station_transfer_lines`
- `bulk_fuel_orders`
- `bulk_fuel_order_payments`
- `tanker_trip_settlements`

Why future:

- valuable for larger networks
- not required for the first clean station app

## 4F. Shops, Rented Units, Restaurants, Service Station Modules

- `station_business_units`
- `lease_contracts`
- `lease_invoices`
- `service_work_orders`
- `service_work_order_items`

Why future:

- useful if business wants true multi-business operation inside stations
- should stay modular and optional

## 5. Suggested Build Priority

### Build now from current schema

- access and session
- station and fuel setup
- shifts
- fuel sales
- meter history and adjustments
- tank dips
- suppliers and purchases
- customers and payments
- expenses
- tankers
- POS
- notifications and documents
- attendance and payroll

### Add soon after core app is stable

- daily close and reconciliation
- inventory movement ledgers
- attachments
- exception events

### Add later only when product needs it

- granular permission engine
- approval policy engine
- full accounting ledger
- advanced calibration charts
- rate scheduling
- station-to-station transfers
- bulk fuel order flows
- business units and lease/service modules

## 6. Frontend Rule

For the new Flutter app:

- treat Section 1 as active schema
- treat Section 3 as near-term backend roadmap
- treat Section 4 as future architecture only

This keeps the plan ambitious without making the first build impossible.
