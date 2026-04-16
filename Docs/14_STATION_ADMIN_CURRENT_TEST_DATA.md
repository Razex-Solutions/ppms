# StationAdmin Current Test Data

This file reflects the current local database state prepared for StationAdmin testing on `2026-04-15`.

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
| `1` | Petrol | `1` | `Playwright UI smoke price update 289289` |
| `2` | Diesel | `300` | `ch` |
| `3` | High Octane | no station price yet | none |

## Current Forecourt

### Tanks

| Tank ID | Name | Code | Fuel | Capacity | Current volume | Active |
| --- | --- | --- | --- | ---: | ---: | --- |
| `1` | Petrol Tank 1 | `HQ-T1` | Petrol | `20000` | `11588` | Yes |
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
| `13` | `D7-N1` | High Octane | `HQ-T3` | `0` | Yes |
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
| UI Lube 766154 | Lubricant | `950` | `1250` | `12` | Yes |
| UI Lube 919299 | Lubricant | `950` | `1250` | `12` | Yes |
| UI Lube 835016 | Lubricant | `0` | `1250` | `0` | Yes |

## Current Customers

| Customer | Code | Credit limit | Outstanding | Tanker outstanding |
| --- | --- | ---: | ---: | ---: |
| Smoke Customer | `F-SMOKE-CUST` | `9000` | `700` | `0` |
| Tanker Customer | `TANKER-CUST` | `0` | `0` | `482400` |
| Pump A | `CUST-PUMP-A` | `500000` | `85450` | `0` |
| Pump B | `CUST-PUMP-B` | `350000` | `93000` | `0` |

## Current Station Invoice Profile

- Business name: `Main Station`
- Legal name: `Main Station`
- Invoice prefix: `HQ`
- Sale invoice notes: empty

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
| `11` | `1` | `125121` | `125120` | `station admin smoke restore 1776024041` |
| `10` | `1` | `125120` | `125121` | `station admin smoke 1776024041` |
| `9` | `1` | `125121` | `125120` | `station admin smoke restore 1776018134` |
| `8` | `1` | `125120` | `125121` | `station admin smoke 1776018134` |
| `7` | `1` | `125121` | `125120` | `station admin smoke restore 1776017724` |
| `6` | `1` | `125120` | `125121` | `station admin smoke 1776017724` |
| `5` | `1` | `125121` | `125120` | `station admin smoke restore 1776017703` |
| `4` | `1` | `125120` | `125121` | `station admin smoke 1776017703` |
| `3` | `14` | `35000` | `50000` | `change` |
| `2` | `14` | `0` | `35000` | `chnage` |

## Current Tanker Data

### Tankers

| Tanker ID | Name | Registration | Ownership | Capacity | Status |
| --- | --- | --- | --- | ---: | --- |
| `1` | Fleet Tanker 1 | `TK-9001` | owned | `10000` | active |
| `2` | Fleet Tanker 2 | `TK-9002` | owned | `10000` | active |
| `3` | Smoke tanker | `SMOKE-TKR-1775717460` | owned | `2000` | active |
| `4` | Smoke tanker | `SMOKE-TKR-1775717495` | owned | `2000` | active |
| `5` | empty name | `THE-123` | owned | `50000` | active |

### Trips

| Trip ID | Tanker | Type | Status | Settlement | Loaded | Delivered | Remaining | Net profit |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| `6` | `1` | mixed_delivery | partially_settled | partial | `10` | `4` | `0` | `590` |
| `5` | `1` | mixed_delivery | partially_settled | partial | `10` | `4` | `0` | `590` |
| `4` | `1` | mixed_delivery | partially_settled | partial | `10` | `4` | `0` | `590` |
| `3` | `4` | supplier_to_station | active | paid | `300` | `0` | `180` | `0` |
| `2` | `3` | supplier_to_station | active | paid | `300` | `0` | `0` | `0` |
| `1` | `2` | mixed_delivery | partially_settled | partial | `4000` | `3000` | `0` | `30000` |

### Deliveries

| Delivery ID | Trip | Customer | Destination | Quantity | Fuel rate | Sale type | Paid | Outstanding |
| --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: |
| `4` | `6` | Tanker Customer | `Smoke Pump 1776024041` | `4` | `260` | credit | `240` | `800` |
| `3` | `5` | Tanker Customer | `Smoke Pump 1776018134` | `4` | `260` | credit | `240` | `800` |
| `2` | `4` | Tanker Customer | `Smoke Pump 1776017724` | `4` | `260` | credit | `240` | `800` |
| `1` | `1` | Tanker Customer | `Pump Route` | `3000` | `260` | credit | `300000` | `480000` |

### Later Payments

| Payment ID | Delivery | Amount | Reference |
| --- | --- | ---: | --- |
| `4` | `4` | `240` | `SA-SMOKE-1776024041` |
| `3` | `3` | `240` | `SA-SMOKE-1776018134` |
| `2` | `2` | `240` | `SA-SMOKE-1776017724` |
| `1` | `1` | `100000` | `REC-1` |

### Compartments

| Compartment ID | Tanker | Name | Capacity |
| --- | --- | --- | ---: |
| `1` | `1` | Compartment 1 | `5000` |
| `2` | `1` | Compartment 2 | `5000` |
| `3` | `2` | Compartment 1 | `5000` |
| `4` | `2` | Compartment 2 | `5000` |
| `5` | `3` | Compartment 1 | `2000` |
| `6` | `4` | Compartment 1 | `2000` |
| `7` | `5` | Compartment 1 | `10000` |
| `8` | `5` | Compartment 2 | `20000` |
| `9` | `5` | Compartment 3 | `10000` |
| `10` | `5` | Compartment 4 | `5000` |
| `11` | `5` | Compartment 5 | `5000` |

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
- nozzles = `6`

Safer check now:

- verify both High Octane nozzles are present on `Dispenser 3`
- `D7-N1` should be `0`
- `D7-N2` should be `50000`

Expected:

- nozzle count stays `6`
- both High Octane rows remain visible and correctly mapped to `HQ-T3`

If you edit any existing tank or nozzle:

- only that row should change
- existing active forecourt mapping must stay intact

### 4. Fuel pricing

Current starting values:

- Petrol = `1`
- Diesel = `300`
- High Octane = no station price

Recommended safer change:

- fuel type = `Diesel`
- new selling price = `301`
- reason = `station admin test`
- notes = `doc verification`

Expected:

- Diesel gets a current selling price of `301`
- a new price history row appears at the top
- manager rate-boundary logic will use this later for that fuel type in a live shift

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
- UI Lube 766154
- UI Lube 919299
- UI Lube 835016

Create one new item:

- name = `Coolant 1L`
- category = `Lubricants`
- module = `Service station`
- buying price = `900`
- selling price = `1200`
- stock = `15`
- active = `On`

Expected:

- item count becomes `3`
- row shows buying `900`
- row shows selling `1200`
- row shows stock `15` #add more options in pos modules

### 7. Settings / branding / reports / documents / templates

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

Reports:

- open `Reports`
- run `Daily closing`
- then switch to `Customer balances`
- then create one `CSV` export

Expected:

- report payload loads on screen, not an empty placeholder
- `Rows` and preview content update when you change the selected report
- one new export job appears under recent export jobs

Documents:

- open `Documents`
- choose `Customer ledger statement`
- choose `Pump A`
- then switch to `Supplier ledger statement`
- choose `PSO Supply`

Expected:

- a printable document preview loads for each selection
- document number and recipient fields are populated
- dispatch diagnostics section loads with live counts

### 8. Meter reversal / adjustment

Current known test nozzle:

- nozzle `HQ-D1-N1`
- current meter = `125120`

Test adjustment:

- nozzle = `HQ-D1-N1`
- old/current meter reading = `125120`
- new adjusted meter reading = `125130`
- reason = `station admin meter test`

Expected:

- nozzle live meter becomes `125130`
- a new meter adjustment event appears at the top of history
- newest event should show:
  - old = `125120`
  - new = `125130`
  - reason = `station admin meter test`

### 9. Tanker operations

Current tanker trip count in the screen should reflect at least:

- trip `6`
- trip `5`
- trip `4`
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
- use the `Trip operations` card for:
  - `Add delivery`
  - `Record payment`
  - `Add expense`
  - `Settle trip`

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
- the delivery should now appear under the selected trip inside `Trip operations`

Then record payment:

- amount = `20000`
- reference = `SA-TEST-REC`

Expected:

- outstanding reduces by `20000`
- the payment action should be used from the same trip’s `Trip operations` card

Then add expense:

- expense type = `Fuel / route`
- amount = `5000`

Expected:

- trip expense list/value updates
- the trip can then be settled from the same `Trip operations` card

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
