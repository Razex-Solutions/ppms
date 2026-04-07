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
- correction and reversal flows
- credit limit override flow
- meter adjustment and meter segment checks
- notifications
- documents
- report/export records

## Running Pump Dataset Shape

The dataset should feel like an actual operating station, not a tiny demo.

Minimum realistic shape for the current one-station `check` tenant:

- 1 `HeadOffice` tenant admin
- 2 `Manager` users
- 1 `Accountant` user
- 4 `Operator` users
- 2 pump attendant staff profiles
- 2 security staff profiles
- 2 tanker driver staff profiles
- 2 cleaner/helper staff profiles
- 3 tanks: petrol, diesel, and hi-octane
- 3 dispensers
- 6 nozzles with opening/current meter readings
- 3 shift templates: Morning, Evening, and Night
- at least 3 operational shifts: balanced, variance, and current/open
- multiple fuel sales across different nozzles and fuel types
- multiple cash submissions per shift
- at least 2 dips per tank: one matching system stock and one variance reading
- at least 2 fuel purchases from suppliers
- at least 2 normal station expenses
- at least 1 internal fuel usage record
- at least 1 meter adjustment / reset event
- at least 2 credit customers
- at least 2 suppliers
- customer payments and supplier payments
- payroll for staff with bonus, loan, and deduction examples
- attendance for staff and login users
- 2 tankers: one own tanker and one hired/supplier tanker
- tanker compartments for both tankers
- tanker trips with load, manual sale, expense, and leftover transfer
- POS/shop sample if module is enabled
- reversal examples for fuel sale, purchase, customer payment, supplier payment, and POS sale
- credit limit override request/approval example
- reports/documents/notifications sample records or verification checks

Expected formulas must be stored alongside the sample data so the runner can fail loudly when anything changes unexpectedly.

## Current Runner Coverage

The current automated runner now covers the first running-pump operations batch:

- prepares `check` tenant
- creates scenario-specific Manager and Operator login users
- creates profile-only staff records for pump attendants, security, tanker drivers, and cleaners/helpers
- opens multiple operator shifts
- records meter-based fuel sales across multiple nozzles
- records multiple cash submissions
- closes balanced and variance shifts
- leaves one current/open shift for cash-in-hand visibility testing
- creates multiple manager expenses
- creates suppliers and manager purchases
- confirms Manager purchases start as `pending`
- approves those purchases through HeadOffice
- verifies approved purchases update supplier payables and tank stock
- records supplier payments through Accountant
- verifies supplier ledger charges, payments, and balances
- creates credit customers
- records credit fuel sales through an Operator shift
- records customer payments through Accountant
- verifies customer ledger charges, payments, and balances
- records attendance for payroll-enabled worker login users
- records salary additions and deductions
- generates and finalizes a payroll run
- verifies payroll line net amounts and run net total
- creates POS/shop products
- records POS sale and verifies stock reduction
- creates own/hired tanker records with compartments
- creates supplier-to-customer tanker trips
- records tanker delivery and tanker expense
- completes tanker trips with leftover transfer to station tanks
- verifies scenario tanker loaded/delivered/transferred quantities
- verifies core reports load with scoped data
- creates a saved report definition
- creates a completed report export job
- renders financial documents for fuel sale, customer payment, supplier payment, customer ledger, and supplier ledger
- verifies notification summary can be read after report export notification creation
- requests and approves a customer payment reversal
- requests and approves a fuel sale reversal
- requests and approves a supplier payment reversal
- requests and approves a purchase reversal
- reverses a POS sale and verifies stock is restored
- requests and approves a customer credit override
- records a credit sale above the base limit using the approved override
- records internal fuel usage and verifies it is readable
- records a HeadOffice meter adjustment for the single-station tenant admin rule
- verifies meter adjustment history and meter segments are readable
- records multiple tank dips across all tanks
- prints expected vs actual totals

Known current backend behavior recorded by the runner:

- open shift cash expected does not include live sales until shift close
- closed shift cash expected and variance calculate correctly
- Manager purchases require HeadOffice approval before stock and supplier payable balances update
- payroll runs currently calculate from payroll-enabled login users, not profile-only staff records
- tanker workspace summary is cumulative for the station, so scenario checks validate newly created trips directly
- supplier-to-customer tanker trip completion currently transfers all leftover fuel when a transfer tank is provided and still reports the leftover quantity
- HeadOffice meter adjustment is allowed for the one-station tenant case because HeadOffice acts as station admin when there is no separate StationAdmin

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_phase9_scenario.ps1
```

## Remaining Dataset Blocks

The runner already covers users/staff, shift/meter/cash, purchases, credit customers, supplier payments, ledgers, expenses, attendance, payroll, POS/shop, tankers, reports, documents, notifications, corrections/reversals, credit override, internal fuel usage, meter adjustments, and tank dips at a first acceptance level.

It still needs these blocks added.

### 1. Users And Staff

Create:

- `HeadOffice` tenant admin
- `Manager`
- `Accountant`
- `Operator`
- profile-only pump attendant
- profile-only security guard
- profile-only tanker driver
- profile-only cleaner/helper
- second Manager user
- four Operator users total

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
- current/open shift
- morning/evening/night examples
- sales across at least three nozzles

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
- two dips per tank
- three fuel types represented across tanks/nozzles

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

Current automated coverage:

- credit customer
- second credit customer
- credit fuel sale
- customer payment
- customer ledger check

Still to add:

- cash customer sale if a named cash customer workflow is kept
- credit limit override rejection path

Expected formulas:

```text
customer_balance_after_credit_sale = previous_balance + sale_total
customer_balance_after_payment = previous_balance - payment_amount
receivables = sum(customer_balances)
```

### 5. Suppliers, Purchases, Payments, And Payables

Current automated coverage:

- supplier
- second supplier
- purchase
- second purchase
- purchase approval
- supplier payment
- supplier ledger check

Still to decide:

- whether normal tenant purchases should remain approval-based or become direct operational records based on tenant/module policy

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

Current automated coverage:

- attendance check-in/check-out
- salary adjustment bonus
- salary adjustment deduction
- monthly payroll run

Current backend behavior:

- payroll is calculated from payroll-enabled login users
- profile-only staff records are created as staff dataset coverage but do not enter payroll runs yet

Still to add or decide:

- profile-only staff payroll support, or a clear UI separation between staff profiles and payroll users
- explicit loan-type salary adjustment if this needs a separate business category instead of a normal deduction

Expected formulas:

```text
net_salary = base_salary + bonus - deduction - loan
payroll_total = sum(net_salary)
attendance_hours = checkout_time - checkin_time
```

### 8. Tankers

Current automated coverage:

- tanker master
- second tanker master
- compartments
- tanker trip
- second tanker trip
- manual tanker sale
- tanker expense
- leftover transfer into station tank

Current backend behavior:

- supplier-to-customer tanker trip completion transfers the full leftover quantity to a tank when `transfer_to_tank_id` is provided
- `leftover_quantity` is still reported after transfer
- station tanker workspace summary is cumulative across previous scenario runs

Expected formulas:

```text
tanker_loaded_quantity = sum(compartment_loads)
tanker_sold_quantity = sum(tanker_manual_sales)
tanker_leftover_quantity = loaded_quantity - sold_quantity - transferred_quantity
tank_volume_after_tanker_transfer = tank_volume_before + transferred_quantity
tanker_profit = tanker_sales - tanker_purchase_cost - tanker_expenses
```

Tanker dataset should include:

- own tanker
- hired/supplier tanker
- at least two compartments per tanker
- one trip with leftover transfer into station tank
- one trip with leftover still in tanker
- tanker driver profile reference where supported

### 9. POS / Shop

Current automated coverage:

- POS product
- POS sale
- POS sale item
- POS sale reversal

Expected formulas:

```text
pos_sale_total = sum(quantity * unit_price)
product_stock_after_sale = stock_before - quantity_sold
product_stock_after_reversal = stock_after_sale + quantity_sold
```

### 10. Corrections, Reversals, And Overrides

Current automated coverage:

- customer payment reversal request by Accountant
- customer payment reversal approval by HeadOffice
- fuel sale reversal request by Operator
- fuel sale reversal approval by HeadOffice
- supplier payment reversal request by Accountant
- supplier payment reversal approval by HeadOffice
- purchase reversal request by Manager
- purchase reversal approval by HeadOffice
- POS sale reversal by Manager
- credit override request by Manager
- credit override approval by HeadOffice
- credit sale above base limit using approved override
- internal fuel usage by Manager
- HeadOffice meter adjustment for the single-station tenant admin case
- meter adjustment history and meter segment readback

Still to add:

- rejection paths for reversal requests
- rejection path for credit override requests
- UI workflow for correction notes and approval messages

Expected formulas:

```text
customer_balance_after_payment_reversal = balance_before_reversal + payment_amount
customer_balance_after_sale_reversal = balance_before_reversal - sale_total
supplier_balance_after_payment_reversal = balance_before_reversal + payment_amount
supplier_balance_after_purchase_reversal = balance_before_reversal - purchase_total
pos_stock_after_reversal = stock_after_sale + sold_quantity
nozzle_meter_after_sale_reversal = sale_opening_meter
nozzle_meter_after_adjustment = requested_new_meter
tank_volume_after_internal_fuel = tank_volume_before - internal_fuel_quantity
```

### 11. Notifications, Documents, And Reports

Current automated coverage:

- notification summary
- notification inbox/delivery log
- financial document generation
- report export job
- saved report definition

Still to add:

- notification preference update
- due delivery processing/retry where useful
- direct dispatch send checks if we want to verify local/mock delivery records

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
