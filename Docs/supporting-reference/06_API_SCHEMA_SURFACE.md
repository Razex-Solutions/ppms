# API Schema Surface

This file lists the main Pydantic schema objects that the new Flutter app should model directly.

The point is not to mirror every Python class name in widgets. The point is to build typed frontend DTOs and repositories from these real contracts.

## Auth And Session

- `LoginRequest`
  - `username`, `password`

- `TokenResponse`
  - `access_token`, `refresh_token`, `token_type`
  - `user_id`, `username`, `full_name`
  - `role_id`, `role_name`
  - `station_id`, `organization_id`
  - `scope_level`, `is_platform_user`

- `SessionResponse`
  - `id`, `is_active`, `created_at`, `expires_at`, `revoked_at`, `last_seen_at`, `ip_address`, `user_agent`

## Organization And Station Setup

- `OrganizationCreate`, `OrganizationUpdate`, `OrganizationResponse`
  - name/code/legal/brand/contact/registration/billing/onboarding fields

- `StationCreate`, `StationUpdate`, `StationResponse`
  - identity fields, branding override fields, setup status, module booleans, `allow_meter_adjustments`

- `OrganizationModuleSettingUpdate`, `OrganizationModuleSettingResponse`
  - `module_name`, `is_enabled`

- `StationModuleSettingUpdate`, `StationModuleSettingResponse`
  - `module_name`, `is_enabled`

- `InvoiceProfileUpdate`, `InvoiceProfileResponse`
  - full invoice identity, tax, compliance, footer, numbering, contact fields

- `FuelTypeCreate`, `FuelTypeUpdate`, `FuelTypeResponse`
  - `name`, `description`

- `FuelPriceHistoryCreate`, `FuelPriceHistoryResponse`
  - `station_id`, `price`, `effective_at`, `reason`, `notes`

- `TankCreate`, `TankUpdate`, `TankResponse`
  - `name`, `code`, `capacity`, `current_volume`, `low_stock_threshold`, `location`, `station_id`, `fuel_type_id`

- `DispenserCreate`, `DispenserUpdate`, `DispenserResponse`
  - `name`, `code`, `location`, `station_id`

- `NozzleCreate`, `NozzleUpdate`, `NozzleResponse`
  - `name`, `code`, `meter_reading`, `dispenser_id`, `tank_id`, `fuel_type_id`

- `StationShiftTemplateCreate`, `StationShiftTemplateUpdate`, `StationShiftTemplateResponse`
  - `name`, `start_time`, `end_time`, `is_active`

- `OrganizationSetupFoundationResponse`
  - organization summary plus station setup summaries

- `StationSetupFoundationResponse`
  - station summary, resolved branding, invoice identity, fuel types, tanks, dispensers, counts

## Users And Staff

- `UserCreate`, `UserUpdate`, `UserResponse`
  - identity, role, scope, organization/station, salary, payroll fields

- `EmployeeProfileCreate`, `EmployeeProfileUpdate`, `EmployeeProfileResponse`
  - profile-only or linked-user staff records

- `RoleResponse`, `RoleCreate`, `RoleUpdate`
  - role catalog management

- `PermissionCatalogResponse`
  - `core_roles`, `role_summaries`, `permission_matrix`

- `RolePermissionResponse`
  - `role_name`, `summary`, `permissions`

## Shift And Sales

- `ShiftCreate`, `ShiftUpdate`, `ShiftResponse`
  - station, shift template, initial cash, closeout fields

- `ShiftCashResponse`
  - expected cash, submitted cash, cash in hand, difference, submission count

- `CashSubmissionCreate`, `CashSubmissionResponse`
  - `amount`, `notes`

- `FuelSaleCreate`
  - `nozzle_id`, `station_id`, `fuel_type_id`, `customer_id`
  - `closing_meter`, `rate_per_liter`, `sale_type`, `shift_name`, `shift_id`

- `FuelSaleResponse`
  - includes `opening_meter`, `closing_meter`, `quantity`, `total_amount`, reversal state

- `MeterAdjustmentRequest`, `MeterAdjustmentEventResponse`
  - `new_reading`, `reason`

- `MeterSegmentResponse`
  - meter segment summary for reading history

- `InternalFuelUsageCreate`, `InternalFuelUsageResponse`
  - tank/fuel/quantity/purpose flow

- `TankDipCreate`, `TankDipResponse`
  - physical dip and variance fields

## Parties And Finance

- `CustomerCreate`, `CustomerUpdate`, `CustomerResponse`
  - credit and station-scoped customer record

- `SupplierCreate`, `SupplierUpdate`, `SupplierResponse`
  - supplier master record

- `CreditOverrideRequest`
  - `amount`, `reason`

- `PurchaseCreate`, `PurchaseResponse`
  - supplier/tank/fuel/tanker/quantity/rate/reference/notes plus approval and reversal state

- `ExpenseCreate`, `ExpenseUpdate`, `ExpenseResponse`
  - title/category/amount/notes plus approval state

- `CustomerPaymentCreate`, `CustomerPaymentResponse`
  - amount, payment method, reference, notes, reversal state

- `SupplierPaymentCreate`, `SupplierPaymentResponse`
  - amount, payment method, reference, notes, reversal state

- `ReversalRequest`
  - `reason`

- `LedgerSummaryResponse`
  - totals and balance snapshot for a customer or supplier

- `LedgerResponse`
  - summary plus detailed ledger entries

- `ProfitSummaryResponse`
  - accounting totals and net profit response

## Attendance And Payroll

- `AttendanceCheckInRequest`
  - `station_id`, `notes`

- `AttendanceCheckOutRequest`
  - `notes`

- `AttendanceRecordCreate`, `AttendanceRecordUpdate`, `AttendanceRecordResponse`
  - record-level attendance administration

- `SalaryAdjustmentCreate`, `SalaryAdjustmentResponse`
  - `station_id`, `user_id`, `employee_profile_id`, `effective_date`, `impact`, `amount`, `reason`, `notes`

- `PayrollRunCreate`, `PayrollRunResponse`
  - station and period creation

- `PayrollLineResponse`
  - per-user or per-profile payroll calculations

- `PayrollFinalizeRequest`
  - `notes`

## Tankers, POS, And Hardware

- `TankerCreate`, `TankerUpdate`, `TankerResponse`
  - tanker identity plus compartments

- `TankerTripCreate`, `TankerTripResponse`
  - trip creation and summary state

- `TankerDeliveryCreate`, `TankerDeliveryResponse`
  - quantity, sale type, charge, outstanding amount

- `TankerTripExpenseCreate`, `TankerTripExpenseResponse`
  - trip expense payloads

- `TankerTripComplete`
  - `reason`, `transfer_to_tank_id`, `transfer_quantity`

- `TankerWorkspaceSummaryResponse`
  - top-level tanker workspace metrics

- `POSProductCreate`, `POSProductUpdate`, `POSProductResponse`
  - product catalog contract

- `POSSaleCreate`, `POSSaleResponse`, `POSSaleItemCreate`, `POSSaleItemResponse`
  - sale plus item payloads

- `HardwareDeviceCreate`, `HardwareDeviceUpdate`, `HardwareDeviceResponse`
  - device registry contract

- `HardwareEventResponse`
  - recorded hardware event payload

- `SimulatedDispenserReadingCreate`
  - `device_id`, `nozzle_id`, `meter_reading`, `volume`, `status`, `notes`

- `SimulatedTankProbeReadingCreate`
  - `device_id`, `volume`, `temperature`, `status`, `notes`

## Reporting, Documents, Notifications, And Hooks

- `ReportDefinitionCreate`, `ReportDefinitionUpdate`, `ReportDefinitionResponse`
  - saved report configuration

- `ReportExportCreate`, `ReportExportResponse`
  - export request and job summary

- `FinancialDocumentResponse`
  - rendered document metadata and HTML payload

- `FinancialDocumentDispatchCreate`, `FinancialDocumentDispatchResponse`
  - channel/output/recipient/dispatch status

- `DocumentTemplateUpsert`, `DocumentTemplateResponse`
  - reusable document template contract

- `DocumentTemplatePreviewRequest`, `DocumentTemplatePreviewResponse`
  - preview render contract

- `NotificationResponse`
  - in-app notification record

- `NotificationDeliveryResponse`
  - delivery attempt history

- `NotificationPreferenceUpdate`, `NotificationPreferenceResponse`
  - per-event delivery settings

- `OnlineAPIHookCreate`, `OnlineAPIHookUpdate`, `OnlineAPIHookResponse`
  - outbound hook management

- `OnlineAPIHookPing`
  - payload for test trigger

- `InboundWebhookEventResponse`
  - stored inbound event detail

## Frontend Rule

The Flutter repositories should map these backend schemas into app-side DTOs and view models.

Do not let widget code talk directly in terms of raw JSON maps.
