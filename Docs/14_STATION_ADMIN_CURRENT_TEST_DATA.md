# StationAdmin Current Test Data

This file reflects the current local database state prepared for StationAdmin testing on `2026-04-12`.

## Login

- `stationadmin` / `station123`

## Station Scope

- Station: `Main Station`
- Station code: `HQ`
- Station ID: `3`
- Branding inheritance: `On`
- Station active: `Yes`
- Setup status: `active`
- Shops enabled: `Yes`
- POS enabled: `Yes`
- Tankers enabled: `Yes`
- Hardware enabled: `Yes`
- Meter adjustments allowed: `Yes`

## Current Staff Users

| Username | Full name | Role | Active | Monthly salary |
| --- | --- | --- | --- | ---: |
| `stationadmin` | Station Administrator | `StationAdmin` | Yes | `140000` |
| `manager` | Shift Manager A | `Manager` | Yes | `90000` |
| `operator` | Forecourt Operator | `Operator` | Yes | `52000` |
| `accountant` | Station Accountant | `Accountant` | Yes | `80000` |
| `manager2` | Shift Manager B | `Manager` | Yes | `90000` |

## Current Employee Profiles

| Profile | Staff title | Employee code | Payroll enabled | Can login | Active | Monthly salary |
| --- | --- | --- | --- | --- | --- | ---: |
| Shift Manager A | `Shift Manager A` | `EMP-MG-001` | Yes | Yes | Yes | `90000` |
| Station Administrator | `Station Admin` | `EMP-SA-001` | Yes | Yes | Yes | `140000` |
| Forecourt Operator | `Pump Operator` | `EMP-OP-001` | Yes | Yes | Yes | `52000` |
| Station Accountant | `Accountant` | `EMP-AC-001` | Yes | Yes | Yes | `80000` |
| Shift Manager B | `Shift Manager B` | `EMP-MG-002` | Yes | Yes | Yes | `90000` |

## Current Fuel Types

| Fuel type ID | Name | Current station selling price | Latest reason |
| --- | --- | ---: | --- |
| `1` | Petrol | `100` | `price change` |
| `2` | Diesel | `300` | `ch` |
| `3` | High Octane | no station price yet | none |

## Current Forecourt

### Tanks

| Tank ID | Name | Code | Fuel | Capacity | Current volume | Active |
| --- | --- | --- | --- | ---: | ---: | --- |
| `1` | Petrol Tank 1 | `HQ-T1` | Petrol | `20000` | `11570` | Yes |
| `2` | Diesel Tank 1 | `HQ-T2` | Diesel | `20000` | `14000` | Yes |
| `8` | Tank 3 | `HQ-T3` | High Octane | `25000` | `0` | Yes |

### Dispensers

| Dispenser ID | Name | Active |
| --- | --- | --- |
| `1` | Dispenser 1 | Yes |
| `2` | Dispenser 2 | Yes |
| `7` | Dispenser 3 | Yes |

### Nozzles

| Nozzle ID | Code | Fuel | Tank | Meter reading | Active |
| --- | --- | --- | --- | ---: | --- |
| `1` | `HQ-D1-N1` | Petrol | `HQ-T1` | `125120` | Yes |
| `2` | `HQ-D1-N2` | Diesel | `HQ-T2` | `98110` | Yes |
| `3` | `HQ-D2-N1` | Petrol | `HQ-T1` | `110640` | Yes |
| `4` | `HQ-D2-N2` | Diesel | `HQ-T2` | `87725` | Yes |
| `14` | `D7-N2` | High Octane | `HQ-T3` | `50000` | Yes |

## Current Suppliers

| Supplier | Code | Payable balance |
| --- | --- | ---: |
| Smoke Supplier | `F-SMOKE-SUP` | `1200` |
| Tanker Supplier | `TANKER-SUP` | `0` |
| PSO Supply | `SUP-PSO` | `492500` |
| Shell Bulk | `SUP-SHELL` | `150000` |

## Current Inventory Items

| Item | Category | Buying price | Selling price | Stock | Active |
| --- | --- | ---: | ---: | ---: | --- |
| Lubricant 20W50 1L | Lubricants | `0` | `1800` | `24` | Yes |
| 2T Oil 500ml | Lubricants | `0` | `650` | `40` | Yes |

## Current Customers

| Customer | Code | Credit limit | Outstanding | Tanker outstanding |
| --- | --- | ---: | ---: | ---: |
| Smoke Customer | `F-SMOKE-CUST` | `9000` | `700` | `0` |
| Tanker Customer | `TANKER-CUST` | `0` | `0` | `480000` |
| Pump A | `CUST-PUMP-A` | `500000` | `85450` | `0` |
| Pump B | `CUST-PUMP-B` | `350000` | `93000` | `0` |

## Current Station Invoice Profile

- Business name: `Main Station`
- Legal name: `Main Station`
- Invoice prefix: `HQ`

## Current Document Templates For Station 3

Expected active templates:

- `Default Customer Payment Receipt`
- `Default Supplier Payment Voucher`
- `Default Customer Ledger Statement`
- `Default Supplier Ledger Statement`
- `Default Fuel Sale Invoice`

## Current Meter Adjustment History

| Event ID | Nozzle ID | Old reading | New reading | Reason |
| --- | --- | ---: | ---: | --- |
| `3` | `14` | `35000` | `50000` | `change` |
| `2` | `14` | `0` | `35000` | `chnage` |
| `1` | `1` | `125120` | `125120` | `smoke adjustment visibility` |

## Current Tanker Data

### Tankers

| Tanker ID | Name | Registration | Ownership | Capacity | Status |
| --- | --- | --- | --- | ---: | --- |
| `1` | Fleet Tanker 1 | `TK-9001` | owned | `10000` | active |
| `2` | Fleet Tanker 2 | `TK-9002` | owned | `10000` | active |
| `3` | Smoke tanker | `SMOKE-TKR-1775717460` | owned | `2000` | active |
| `4` | Smoke tanker | `SMOKE-TKR-1775717495` | owned | `2000` | active |
| `5` | empty-name tanker | `THE-123` | owned | `50000` | active |

### Trips

| Trip ID | Tanker | Type | Status | Settlement | Loaded | Delivered | Remaining | Net profit |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| `3` | `4` | supplier_to_station | active | paid | `300` | `0` | `180` | `0` |
| `2` | `3` | supplier_to_station | active | paid | `300` | `0` | `0` | `0` |
| `1` | `2` | mixed_delivery | partially_settled | partial | `4000` | `3000` | `0` | `30000` |

### Deliveries

| Delivery ID | Trip | Customer | Destination | Quantity | Fuel rate | Sale type | Paid | Outstanding |
| --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: |
| `1` | `1` | Tanker Customer | `Pump Route` | `3000` | `260` | credit | `300000` | `480000` |

### Later Payments

| Payment ID | Delivery | Amount | Reference |
| --- | --- | ---: | --- |
| `1` | `1` | `100000` | `REC-1` |

## Recommended StationAdmin Test Sequence

Use this order so the checks stay clear and easy to verify.

### 1. Dashboard / overview

Expected:

- `Workflow pages` card is visible
- `Operations` and `Finance` appear as their own StationAdmin workflows
- station snapshot matches:
  - station code `HQ`
  - station active `Yes`
  - meter adjustments allowed `Yes`

### 2. Staff management

Check current rows first:

- users count should be `5`
- employee profiles count should be `5`

Create test user:

- full name = `Station Test Cashier`
- username = `stationcashier`
- password = `cash123`
- role = `Operator`
- salary = `45000`
- payroll enabled = `On`

Expected:

- user count becomes `6`
- new row appears in staff users
- role shows `Operator`

Then create linked profile:

- full name = `Station Test Cashier`
- linked user = `stationcashier`
- staff type = `Staff`
- staff title = `Cashier`
- employee code = `EMP-TEST-001`
- salary = `45000`
- can login = `On`

Expected:

- profile count becomes `6`
- profile row appears with title `Cashier`
- employee code shows `EMP-TEST-001`

### 3. Forecourt management

Current forecourt counts:

- tanks = `3`
- dispensers = `3`
- nozzles = `5`

Create one new high octane nozzle on existing dispenser if the UI allows:

- choose `Dispenser 3`
- fuel = `High Octane`
- tank = `HQ-T3`
- meter reading = `0`

Expected:

- nozzle count becomes `6`
- new nozzle appears under station forecourt

If you edit any existing tank or nozzle:

- only that row should change
- existing active forecourt mapping must stay intact

### 4. Fuel pricing

Current starting values:

- Petrol = `100`
- Diesel = `300`
- High Octane = no station price

Test change:

- fuel type = `High Octane`
- new selling price = `350`
- reason = `station admin test`
- notes = `doc verification`

Expected:

- High Octane gets a current selling price of `350`
- a new price history row appears at the top
- manager rate-boundary logic will use this later when High Octane is sold in a live shift

### 5. Suppliers

Current supplier count:

- `4`

Create one supplier:

- name = `Station Test Supplier`
- code = `SUP-TEST-SA`
- phone = `0300-0000000`

Expected:

- supplier count becomes `5`
- new supplier appears in supplier list
- payable balance starts at `0`

### 6. Inventory pricing

Current items:

- Lubricant 20W50 1L
- 2T Oil 500ml

Create one new item:

- name = `Coolant 1L`
- category = `Lubricants`
- module = `lubricant`
- buying price = `900`
- selling price = `1200`
- stock = `15`
- active = `On`

Expected:

- item count becomes `3`
- row shows buying `900`
- row shows selling `1200`
- row shows stock `15`

### 7. Settings / branding / invoice / document templates

Current invoice profile baseline:

- business name = `Main Station`
- legal name = `Main Station`
- invoice prefix = `HQ`

Edit invoice profile:

- invoice prefix = `HQA`
- sale invoice notes = `Station admin test note`

Expected:

- invoice prefix changes from `HQ` to `HQA`
- notes save successfully

Document templates:

- station 3 should already have `5` default templates
- if you open and update one template name or active flag, that exact template row should update without affecting the others

### 8. Meter reversal / adjustment

Current known test nozzle:

- nozzle `D7-N2`
- current meter = `50000`

Test adjustment:

- nozzle = `D7-N2`
- old/current meter reading = `50000`
- new adjusted meter reading = `51000`
- reason = `station admin meter test`

Expected:

- nozzle live meter becomes `51000`
- a new meter adjustment event appears at the top of history
- newest event should show:
  - old = `50000`
  - new = `51000`
  - reason = `station admin meter test`

### 9. Tanker operations

Current tanker trip count in the screen should reflect:

- trip `3`
- trip `2`
- trip `1`

Create one supplier-to-station trip:

- tanker = `Fleet Tanker 1`
- trip type = `supplier_to_station`
- supplier = `PSO Supply`
- destination tank = `Petrol Tank 1`
- loaded quantity = `500`
- purchase rate = `100`

Expected:

- trip count increases by `1`
- new trip appears in tanker operations
- trip starts open/active

Then add delivery only if you create a customer-facing trip.

For a customer trip test:

- tanker = `Fleet Tanker 2`
- trip type = `supplier_to_customer`
- destination name = `Test Route`
- loaded quantity = `1000`
- purchase rate = `100`

Expected:

- new trip appears

Then add delivery:

- customer = `Tanker Customer`
- quantity = `200`
- sale rate = `260`
- sale type = `credit`
- paid amount = `0`

Expected:

- tanker delivery appears
- tanker customer tanker outstanding increases by `52000`

Then record payment:

- amount = `20000`
- reference = `SA-TEST-REC`

Expected:

- outstanding reduces by `20000`

Then add expense:

- expense type = `Fuel / route`
- amount = `5000`

Expected:

- trip expense list/value updates

### 10. Operations and Finance embedded pages

Expected:

- `Operations` opens the live manager workflow inside StationAdmin
- `Finance` opens the live accountant workflow inside StationAdmin
- these are not summary-only cards anymore

## Suggested Cleanup After Testing

If you create the suggested test records above, remove or revert:

- user `stationcashier`
- employee code `EMP-TEST-001`
- supplier `SUP-TEST-SA`
- inventory item `Coolant 1L`
- High Octane test price if you do not want to keep it
- tanker test trips and deliveries if they were only for verification
