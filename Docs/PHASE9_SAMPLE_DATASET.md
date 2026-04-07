# PPMS Phase 9 Sample Dataset Plan

## Purpose

This file defines the larger Phase 9 dataset we should use for local stabilization.

The goal is to stop guessing during manual testing.

Instead, we should create known data, run known business actions, and compare expected totals against actual backend results.

## Source Documents

This dataset follows:

- [START_HERE.md](START_HERE.md)
- [FINAL_PHASED_MASTER_ROADMAP.md](FINAL_PHASED_MASTER_ROADMAP.md)
- [SIMPLIFIED_SETUP_AND_ROLE_PLAN.md](SIMPLIFIED_SETUP_AND_ROLE_PLAN.md)
- [CURRENT_PROGRESS.md](CURRENT_PROGRESS.md)
- [ROLE_HIERARCHY_AND_ACCESS_MODEL.md](ROLE_HIERARCHY_AND_ACCESS_MODEL.md)
- [MASTER_ADMIN_ORGANIZATION_AND_PERMISSION_MODEL.md](MASTER_ADMIN_ORGANIZATION_AND_PERMISSION_MODEL.md)
- [TENANT_FLUTTER_REBUILD_PLAN.md](TENANT_FLUTTER_REBUILD_PLAN.md)
- [CHECKTESTINGPLAN.md](CHECKTESTINGPLAN.md)

## Dataset Principle

The normal bootstrap seed is not enough for Phase 9.

Bootstrap seed should only prepare:

- brands
- core roles
- platform user
- basic organization/station
- default modules/plans
- default document templates

The Phase 9 sample dataset should create operational data for acceptance testing:

- org and station setup
- role users and profile-only staff
- fuel types
- tanks
- dispensers
- nozzles
- shift templates
- shifts
- meter-based fuel sales
- cash submissions and cash-in-hand checks
- purchases
- supplier payable behavior
- expenses
- internal fuel usage
- tank dips
- credit customers
- customer payments
- supplier payments
- customer/supplier ledger checks
- payroll and salary adjustments
- attendance
- tankers, compartments, trips, trip expenses, deliveries, and fuel transfers
- POS products and POS sales
- notifications
- documents
- report/export records

## Current Runner Coverage

The current automated runner covers a first operations loop:

- prepares `check` tenant
- creates a unique scenario operator
- opens an operator shift
- records a meter-based fuel sale
- records a cash submission
- closes the shift with zero difference
- creates a manager expense
- creates a supplier
- creates a manager purchase
- records a tank dip
- prints expected vs actual totals

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_phase9_scenario.ps1
```

## Missing Dataset Blocks

The runner still needs these blocks added.

### 1. Users And Staff

Create:

- `HeadOffice` tenant admin
- `Manager`
- `Accountant`
- `Operator`
- profile-only pump attendant
- profile-only tanker driver
- profile-only cleaner/helper

Expected checks:

- single-station tenant has no `StationAdmin`
- HeadOffice can create station worker roles
- Manager/Accountant/Operator cannot create higher roles
- profile-only staff cannot log in
- users and staff are scoped to organization/station `check`

### 2. Shift, Meter, And Cash

Create:

- opening cash
- meter sale
- multiple cash submissions
- closing cash
- balanced shift
- variance shift

Expected formulas:

```text
sale_quantity = closing_meter - opening_meter
sale_total = sale_quantity * rate_per_liter
expected_cash = opening_cash + cash_sales
cash_submitted = sum(cash_submissions)
difference = actual_cash_collected - expected_cash
cash_in_hand_after_submission = expected_cash - cash_submitted
```

### 3. Tank Stock, Purchases, Internal Fuel, And Dips

Create:

- fuel purchase
- internal fuel usage
- fuel sale
- tank dip matching system stock
- tank dip with positive/negative variance

Expected formulas:

```text
tank_volume_after_sale = tank_volume_before - sale_quantity
tank_volume_after_internal_use = tank_volume_before - internal_fuel_quantity
tank_volume_after_approved_purchase = tank_volume_before + purchase_quantity
dip_loss_gain = calculated_volume - system_volume
```

Current backend rule to remember:

- Manager-created purchases are currently `pending`
- pending purchases calculate totals but do not update tank stock until approved
- this conflicts with the preferred docs direction, where normal purchases should be direct operational records
- Phase 9 should decide whether to keep this approval rule or change it

### 4. Customers, Credit, And Receivables

Create:

- cash customer sale
- credit customer
- credit fuel sale
- customer payment
- customer ledger check

Expected formulas:

```text
customer_balance_after_credit_sale = previous_balance + sale_total
customer_balance_after_payment = previous_balance - payment_amount
receivables = sum(customer_balances)
```

### 5. Suppliers, Purchases, Payments, And Payables

Create:

- supplier
- purchase
- supplier payment
- supplier ledger check

Expected formulas:

```text
purchase_total = quantity * rate_per_liter
supplier_balance_after_approved_purchase = previous_balance + purchase_total
supplier_balance_after_payment = previous_balance - payment_amount
payables = sum(supplier_balances)
```

### 6. Expenses

Create:

- normal station expense
- tanker-linked expense
- payroll-related adjustment if needed

Expected formulas:

```text
total_expenses = sum(expenses)
profit = sales - purchase_cost - expenses - internal_fuel_cost
```

### 7. Payroll And Attendance

Create:

- employee profiles
- attendance check-in/check-out
- salary adjustment bonus
- salary adjustment deduction
- salary adjustment loan
- monthly payroll run

Expected formulas:

```text
net_salary = base_salary + bonus - deduction - loan
payroll_total = sum(net_salary)
attendance_hours = checkout_time - checkin_time
```

### 8. Tankers

Create:

- tanker master
- compartments
- tanker trip
- trip load
- manual tanker sale
- tanker expense
- leftover transfer into station tank

Expected formulas:

```text
tanker_loaded_quantity = sum(compartment_loads)
tanker_sold_quantity = sum(tanker_manual_sales)
tanker_leftover_quantity = loaded_quantity - sold_quantity - transferred_quantity
tank_volume_after_tanker_transfer = tank_volume_before + transferred_quantity
tanker_profit = tanker_sales - tanker_purchase_cost - tanker_expenses
```

### 9. POS / Shop

Create:

- POS product
- POS sale
- POS sale item

Expected formulas:

```text
pos_sale_total = sum(quantity * unit_price)
product_stock_after_sale = stock_before - quantity_sold
```

### 10. Notifications, Documents, And Reports

Create or verify:

- notification preference
- notification inbox/delivery log
- financial document generation
- report export job
- saved report definition

Expected checks:

- records are scoped to the `check` organization/station
- local/mock delivery does not require production provider credentials
- report totals match source transactions
- documents reference the correct transaction/customer/supplier/payroll context

## Acceptance Rule

The big dataset runner should eventually print:

```text
Phase 9 full dataset scenario passed.
```

It should fail loudly if any expected total, scope rule, permission rule, or module rule is wrong.

