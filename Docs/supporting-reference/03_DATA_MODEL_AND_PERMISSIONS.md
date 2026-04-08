# Data Model And Permissions

This file is the active source of truth for the new frontend build.

Everything below was taken from the actual backend models, schemas, and permission code.

## Role Scope Rules

From [ppms/app/core/permissions.py](/C:/Fuel%20Management%20System/ppms/app/core/permissions.py):

- `MasterAdmin`
  - scope level: `platform`
  - requires organization: `false`
  - requires station: `false`
  - platform only: `true`

- `HeadOffice`
  - scope level: `organization`
  - requires organization: `true`
  - requires station: `false`
  - platform only: `false`

- `StationAdmin`
  - scope level: `station`
  - requires organization: `true`
  - requires station: `true`

- `Manager`
  - scope level: `station`
  - requires organization: `true`
  - requires station: `true`

- `Accountant`
  - scope level: `station`
  - requires organization: `true`
  - requires station: `true`

- `Operator`
  - scope level: `station`
  - requires organization: `true`
  - requires station: `true`

## Role Creation Rules

- `MasterAdmin` can create: `MasterAdmin`, `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`, `Operator`
- `HeadOffice` can create: `StationAdmin`, `Manager`, `Accountant`, `Operator`
- `StationAdmin` can create: `Manager`, `Accountant`, `Operator`
- `Manager` can create: `Operator`

## Permission Matrix By Module

These are the real module/action definitions in backend code.

- `users`
  - `create`, `update`, `delete`, `read`
  - allowed: `HeadOffice`, `StationAdmin`

- `employee_profiles`
  - `create`, `update`: `MasterAdmin`, `HeadOffice`, `StationAdmin`, `Manager`
  - `delete`: `MasterAdmin`, `HeadOffice`, `StationAdmin`
  - `read`: `MasterAdmin`, `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`

- `organizations`
  - `create`, `update`, `delete`, `read`
  - allowed: `HeadOffice`

- `organization_modules`
  - `read`, `update`
  - allowed: `HeadOffice`

- `online_api_hooks`
  - `read`, `update`, `trigger`
  - allowed: `HeadOffice`

- `roles`
  - `create`, `update`, `delete`: `HeadOffice`
  - `read`: `HeadOffice`, `StationAdmin`

- `stations`
  - `create`, `update`, `delete`, `read`
  - allowed: `HeadOffice`

- `station_modules`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Operator`, `Accountant`
  - `update`: `HeadOffice`, `StationAdmin`

- `invoice_profiles`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`
  - `update`: `HeadOffice`, `StationAdmin`, `Manager`

- `document_templates`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`
  - `update`: `HeadOffice`, `StationAdmin`, `Manager`

- `maintenance`
  - `read`, `execute`
  - allowed: `MasterAdmin`, `HeadOffice`

- `saas`
  - `read`, `manage`
  - allowed: `HeadOffice`

- `fuel_types`
  - `create`, `update`, `delete`
  - allowed: `HeadOffice`, `StationAdmin`

- `fuel_pricing`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Operator`, `Accountant`
  - `update`: `HeadOffice`, `StationAdmin`, `Manager`

- `tanks`
  - `create`, `update`, `delete`
  - allowed: `StationAdmin`, `Manager`

- `dispensers`
  - `create`, `update`, `delete`
  - allowed: `StationAdmin`, `Manager`

- `nozzles`
  - `create`, `update`, `delete`: `StationAdmin`, `Manager`
  - `adjust_meter`: `HeadOffice`, `StationAdmin`
  - `read_meter_history`: `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`

- `tankers`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Operator`, `Accountant`
  - `create`, `update`, `delete`: `StationAdmin`, `Manager`
  - `trip_create`, `delivery_create`, `expense_create`, `complete`: station operations roles

- `customers`
  - `create`, `update`: `StationAdmin`, `Manager`, `Accountant`
  - `delete`: `StationAdmin`, `Manager`
  - `request_credit_override`: `StationAdmin`, `Manager`, `Accountant`
  - `approve_credit_override`, `reject_credit_override`: `HeadOffice`, `StationAdmin`

- `suppliers`
  - `create`, `update`: `StationAdmin`, `Manager`, `Accountant`
  - `delete`: `StationAdmin`, `Manager`

- `fuel_sales`
  - `create`, `reverse`: `StationAdmin`, `Manager`, `Operator`
  - `approve_reverse`, `reject_reverse`: `HeadOffice`, `StationAdmin`

- `purchases`
  - `create`, `reverse`: `StationAdmin`, `Manager`, `Operator`
  - `approve`, `reject`, `approve_reverse`, `reject_reverse`: `HeadOffice`, `StationAdmin`

- `internal_fuel_usage`
  - `create`: `StationAdmin`, `Manager`, `Operator`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Operator`, `Accountant`

- `customer_payments`
  - `create`, `reverse`: `StationAdmin`, `Manager`, `Operator`, `Accountant`
  - `approve_reverse`, `reject_reverse`: `HeadOffice`, `StationAdmin`

- `supplier_payments`
  - `create`, `reverse`: `StationAdmin`, `Manager`, `Operator`, `Accountant`
  - `approve_reverse`, `reject_reverse`: `HeadOffice`, `StationAdmin`

- `ledger`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`

- `shifts`
  - `read`: all tenant roles except platform-only logic
  - `open`, `close`, `submit_cash`: `StationAdmin`, `Manager`, `Operator`

- `attendance`
  - `check_in`, `check_out`: `StationAdmin`, `Manager`, `Operator`, `Accountant`
  - `create`, `update`, `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`

- `payroll`
  - `create`: `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`
  - `finalize`: `HeadOffice`, `StationAdmin`, `Accountant`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`

- `tank_dips`
  - `create`: `StationAdmin`, `Manager`, `Operator`

- `pos_products`
  - `create`, `update`, `delete`: `StationAdmin`, `Manager`

- `pos_sales`
  - `create`, `reverse`: `StationAdmin`, `Manager`, `Operator`

- `audit_logs`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`

- `notifications`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Operator`, `Accountant`

- `delivery_jobs`
  - `process`: `HeadOffice`, `StationAdmin`

- `reports`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Accountant`

- `expenses`
  - `create`, `update`, `delete`: `StationAdmin`, `Manager`, `Accountant`
  - `approve`, `reject`: `HeadOffice`, `StationAdmin`

- `hardware`
  - `read`: `HeadOffice`, `StationAdmin`, `Manager`, `Operator`, `Accountant`
  - `create`, `update`, `delete`: `StationAdmin`, `Manager`

## Actual Tables And Key Attributes

These are grouped by domain so the frontend plan stays readable.

### Identity And Governance

- `roles`
  - `id`, `name`, `description`

- `users`
  - `id`, `full_name`, `username`, `email`, `phone`, `whatsapp_number`, `hashed_password`, `is_active`
  - `failed_login_attempts`, `last_failed_login_at`, `locked_until`, `last_login_at`
  - `monthly_salary`, `payroll_enabled`
  - `role_id`, `organization_id`, `station_id`, `created_by_user_id`
  - `scope_level`, `is_platform_user`

- `auth_sessions`
  - `id`, `user_id`, `refresh_token_hash`, `is_active`, `expires_at`, `revoked_at`, `last_seen_at`, `ip_address`, `user_agent`

- `audit_logs`
  - `id`, `user_id`, `username`, `station_id`, `module`, `action`, `entity_type`, `entity_id`, `details_json`, `created_at`

### Organization, Subscription, And Module Control

- `brand_catalog`
  - `id`, `code`, `name`, `logo_url`, `primary_color`, `sort_order`, `is_active`

- `organizations`
  - `id`, `name`, `code`, `description`, `legal_name`
  - `brand_catalog_id`, `brand_name`, `brand_code`, `logo_url`
  - `contact_email`, `contact_phone`
  - `registration_number`, `tax_registration_number`
  - `onboarding_status`, `billing_status`, `station_target_count`
  - `inherit_branding_to_stations`, `is_active`

- `organization_module_settings`
  - `id`, `organization_id`, `module_name`, `is_enabled`

- `subscription_plans`
  - `id`, `name`, `code`, `description`, `monthly_price`, `yearly_price`
  - `max_stations`, `max_users`, `feature_summary`, `is_active`, `is_default`

- `organization_subscriptions`
  - `id`, `organization_id`, `plan_id`, `status`, `billing_cycle`
  - `start_date`, `end_date`, `trial_ends_at`
  - `auto_renew`, `price_override`, `notes`, `created_at`, `updated_at`

### Station Setup

- `stations`
  - `id`, `name`, `code`, `address`, `city`, `organization_id`, `is_head_office`
  - `display_name`, `legal_name_override`
  - `brand_name`, `brand_code`, `logo_url`, `use_organization_branding`
  - `is_active`, `setup_status`, `setup_completed_at`
  - `has_shops`, `has_pos`, `has_tankers`, `has_hardware`, `allow_meter_adjustments`
  - `created_at`

- `station_module_settings`
  - `id`, `station_id`, `module_name`, `is_enabled`

- `invoice_profiles`
  - `id`, `station_id`, `business_name`, `legal_name`, `logo_url`
  - `registration_no`, `tax_registration_no`
  - `tax_label_1`, `tax_value_1`, `tax_label_2`, `tax_value_2`
  - `default_tax_rate`, `tax_inclusive`
  - `region_code`, `currency_code`, `compliance_mode`, `enforce_tax_registration`
  - `contact_email`, `contact_phone`, `footer_text`
  - `invoice_prefix`, `invoice_series`, `invoice_number_width`
  - `payment_terms`, `sale_invoice_notes`

- `station_shift_templates`
  - `id`, `station_id`, `name`, `start_time`, `end_time`, `is_active`, `created_at`

- `fuel_types`
  - `id`, `name`, `description`

- `fuel_price_history`
  - `id`, `station_id`, `fuel_type_id`, `price`, `effective_at`, `reason`, `notes`, `created_by_user_id`, `created_at`

- `tanks`
  - `id`, `name`, `code`, `capacity`, `current_volume`, `low_stock_threshold`, `location`, `station_id`, `fuel_type_id`

- `dispensers`
  - `id`, `name`, `code`, `location`, `station_id`

- `nozzles`
  - `id`, `name`, `code`, `meter_reading`
  - `current_segment_start_reading`, `current_segment_started_at`
  - `dispenser_id`, `tank_id`, `fuel_type_id`

### Shift And Forecourt Operations

- `shifts`
  - `id`, `station_id`, `user_id`, `shift_template_id`, `shift_name`
  - `start_time`, `end_time`, `status`, `initial_cash`
  - `total_sales_cash`, `total_sales_credit`, `expected_cash`, `actual_cash_collected`, `difference`, `notes`

- `shift_cash`
  - `id`, `station_id`, `shift_id`, `manager_id`, `opening_cash`, `cash_sales`, `expected_cash`, `cash_submitted`, `closing_cash`, `difference`, `notes`, `created_at`

- `cash_submissions`
  - `id`, `shift_cash_id`, `amount`, `submitted_by`, `submitted_at`, `notes`

- `fuel_sales`
  - `id`, `nozzle_id`, `station_id`, `fuel_type_id`, `customer_id`
  - `opening_meter`, `closing_meter`, `quantity`, `rate_per_liter`, `total_amount`
  - `sale_type`, `shift_name`, `shift_id`
  - reversal workflow fields
  - `created_at`

- `nozzle_readings`
  - `id`, `nozzle_id`, `reading`, `sale_id`, `created_at`

- `meter_adjustment_events`
  - `id`, `nozzle_id`, `station_id`, `old_reading`, `new_reading`, `reason`, `adjusted_by_user_id`, `adjusted_at`

- `tank_dips`
  - `id`, `tank_id`, `dip_reading_mm`, `calculated_volume`, `system_volume`, `loss_gain`, `notes`, `created_at`

- `internal_fuel_usage`
  - `id`, `station_id`, `tank_id`, `fuel_type_id`, `quantity`, `purpose`, `notes`, `used_by_user_id`, `created_at`

### Parties And Finance

- `customers`
  - `id`, `name`, `code`, `customer_type`, `phone`, `address`, `credit_limit`, `outstanding_balance`
  - credit override workflow fields
  - `station_id`

- `suppliers`
  - `id`, `name`, `code`, `phone`, `address`, `payable_balance`

- `purchases`
  - `id`, `supplier_id`, `tank_id`, `fuel_type_id`, `tanker_id`
  - `quantity`, `rate_per_liter`, `total_amount`, `reference_no`, `notes`
  - `status`, approval fields, reversal fields, `created_at`

- `expenses`
  - `id`, `title`, `category`, `amount`, `notes`, `station_id`
  - `status`, `submitted_by_user_id`, `approved_by_user_id`, `approved_at`, `rejected_at`, `rejection_reason`, `created_at`

- `customer_payments`
  - `id`, `customer_id`, `station_id`, `amount`, `payment_method`, `reference_no`, `notes`
  - reversal workflow fields
  - `created_at`

- `supplier_payments`
  - `id`, `supplier_id`, `station_id`, `amount`, `payment_method`, `reference_no`, `notes`
  - reversal workflow fields
  - `created_at`

### HR And Payroll

- `employee_profiles`
  - `id`, `organization_id`, `station_id`, `linked_user_id`, `full_name`, `staff_type`, `employee_code`
  - `phone`, `national_id`, `address`
  - `is_active`, `payroll_enabled`, `monthly_salary`, `can_login`, `notes`
  - `created_at`, `updated_at`

- `attendance_records`
  - `id`, `station_id`, `user_id`, `employee_profile_id`
  - `attendance_date`, `status`, `check_in_at`, `check_out_at`, `notes`, `approved_by_user_id`, `created_at`, `updated_at`

- `salary_adjustments`
  - `id`, `station_id`, `user_id`, `employee_profile_id`, `effective_date`, `impact`, `amount`, `reason`, `notes`, `created_by_user_id`, `created_at`

- `payroll_runs`
  - `id`, `station_id`, `period_start`, `period_end`, `status`
  - `total_staff`, `total_gross_amount`, `total_deductions`, `total_net_amount`
  - `notes`, `generated_by_user_id`, `finalized_by_user_id`, `finalized_at`, `created_at`, `updated_at`

- `payroll_lines`
  - `id`, `payroll_run_id`, `user_id`, `employee_profile_id`
  - `present_days`, `leave_days`, `absent_days`, `payable_days`
  - `monthly_salary`, `gross_amount`, `attendance_deductions`
  - `adjustment_additions`, `adjustment_deductions`, `deductions`, `net_amount`

### Tankers, POS, And Hardware

- `tankers`
  - `id`, `registration_no`, `name`, `capacity`, `ownership_type`, `owner_name`, `driver_name`, `driver_phone`, `status`, `station_id`, `fuel_type_id`

- `tanker_compartments`
  - `id`, `tanker_id`, `code`, `name`, `capacity`, `position`, `is_active`

- `tanker_trips`
  - `id`, `tanker_id`, `station_id`, `supplier_id`, `fuel_type_id`, `trip_type`, `status`, `settlement_status`
  - `linked_tank_id`, `linked_purchase_id`, `transfer_tank_id`, `destination_name`, `notes`
  - `loaded_quantity`, `purchase_rate`, `purchase_total`
  - `total_quantity`, `leftover_quantity`, `transferred_quantity`
  - `fuel_revenue`, `delivery_revenue`, `expense_total`, `net_profit`
  - `created_at`, `completed_at`

- `tanker_deliveries`
  - `id`, `trip_id`, `customer_id`, `destination_name`, `quantity`, `fuel_rate`, `fuel_amount`, `delivery_charge`, `sale_type`, `paid_amount`, `outstanding_amount`, `created_at`

- `tanker_trip_expenses`
  - `id`, `trip_id`, `expense_type`, `amount`, `notes`, `created_at`

- `fuel_transfers`
  - `id`, `station_id`, `tank_id`, `tanker_trip_id`, `fuel_type_id`, `quantity`, `transfer_type`, `notes`, `created_at`

- `pos_products`
  - `id`, `name`, `code`, `category`, `module`, `price`, `stock_quantity`, `track_inventory`, `is_active`, `station_id`

- `pos_sales`
  - `id`, `station_id`, `module`, `payment_method`, `customer_name`, `notes`, `total_amount`, `is_reversed`, `reversed_at`, `reversed_by`, `created_at`

- `pos_sale_items`
  - `id`, `sale_id`, `product_id`, `quantity`, `unit_price`, `line_total`

- `hardware_devices`
  - `id`, `name`, `code`, `device_type`, `vendor_name`, `integration_mode`, `protocol`, `endpoint_url`, `device_identifier`, `api_key`, `status`, `is_active`, `station_id`, `dispenser_id`, `tank_id`, `last_seen_at`, `last_error`

- `hardware_events`
  - `id`, `device_id`, `station_id`, `event_type`, `source`, `status`, `dispenser_id`, `tank_id`, `nozzle_id`, `meter_reading`, `volume`, `temperature`, `notes`, `payload_json`, `recorded_at`

### Documents, Notifications, Reports, And Hooks

- `document_templates`
  - `id`, `station_id`, `document_type`, `name`, `header_html`, `body_html`, `footer_html`, `is_active`

- `financial_document_dispatches`
  - `id`, `station_id`, `requested_by_user_id`, `document_type`, `entity_type`, `entity_id`, `channel`, `output_format`
  - `recipient_name`, `recipient_contact`, `status`, `detail`
  - `attempts_count`, `last_attempt_at`, `next_retry_at`, `processed_at`, `created_at`

- `notifications`
  - `id`, `recipient_user_id`, `actor_user_id`, `station_id`, `organization_id`, `event_type`, `title`, `message`, `entity_type`, `entity_id`, `is_read`, `created_at`, `read_at`

- `notification_deliveries`
  - `id`, `notification_id`, `channel`, `destination`, `status`, `detail`, `attempts_count`, `last_attempt_at`, `next_retry_at`, `processed_at`, `created_at`

- `notification_preferences`
  - `id`, `user_id`, `event_type`, `in_app_enabled`, `email_enabled`, `sms_enabled`, `whatsapp_enabled`

- `report_definitions`
  - `id`, `name`, `report_type`, `station_id`, `organization_id`, `created_by_user_id`, `is_shared`, `filters_json`, `created_at`, `updated_at`

- `report_export_jobs`
  - `id`, `report_type`, `format`, `status`, `station_id`, `organization_id`, `requested_by_user_id`, `filters_json`, `file_name`, `content_type`, `content_text`, `created_at`

- `online_api_hooks`
  - `id`, `organization_id`, `name`, `event_type`, `target_url`, `auth_type`, `auth_token`, `secret_key`, `signature_header`, `is_active`, `last_status`, `last_detail`, `last_triggered_at`, `created_at`, `updated_at`

- `inbound_webhook_events`
  - `id`, `organization_id`, `hook_name`, `event_type`, `source`, `headers_json`, `payload_json`, `status`, `detail`, `received_at`

## Frontend Planning Implications

- role, scope, module, and feature flags must be first-class state
- setup domain is broad and should not be mixed into shift operations state
- shift and sale flows must treat meter data and cash as operational truth
- finance pages need reversal-aware UI, not only create flows
- optional modules must be physically removable from navigation and feature trees
- every feature packet should be built from the real schema list above
