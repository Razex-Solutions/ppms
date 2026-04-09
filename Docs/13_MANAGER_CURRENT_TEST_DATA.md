# Manager Current Test Data

This file reflects the current local database state prepared for manager testing on `2026-04-10`.

## Logins

- `manager` / `manager123`
- `manager2` / `manager223`

## Current Active Manager Test Station

- Station: `HQ`
- Station ID: `3`
- Open shift owner: `manager`
- Open shift ID: `2`
- Opening cash for current shift: `32221`
- Current accountable cash at shift start: `32221`
- Current cash submitted: `0`
- Current cash in hand: `32221`

## Current Opening Meter Values

These are the current local manager demo opening values.

| Nozzle | Code | Fuel | Opening Meter | Current Meter |
| --- | --- | --- | ---: | ---: |
| 1 | `HQ-D1-N1` | Petrol | `125120` | `125120` |
| 2 | `HQ-D1-N2` | Diesel | `98110` | `98110` |
| 3 | `HQ-D2-N1` | Petrol | `110640` | `110640` |
| 4 | `HQ-D2-N2` | Diesel | `87725` | `87725` |

## Current Tank Values

| Tank | Code | Fuel | Capacity | Current Volume |
| --- | --- | --- | ---: | ---: |
| Petrol Tank 1 | `HQ-T1` | Petrol | `20000` | `11390` |
| Diesel Tank 1 | `HQ-T2` | Diesel | `20000` | `14000` |

## Current Customer Values

| Customer | Code | Credit Limit | Outstanding |
| --- | --- | ---: | ---: |
| Smoke Customer | `F-SMOKE-CUST` | `9000` | `700` |
| Tanker Customer | `TANKER-CUST` | `0` | `0` |
| Pump A | `CUST-PUMP-A` | `500000` | `185450` |
| Pump B | `CUST-PUMP-B` | `350000` | `93000` |

## Recommended Step-By-Step Manager Test

Use `manager` first because that user currently owns the open shift.

### Step 1: Confirm current shift baseline

Expected:

- status = `open`
- opening cash = `32221`
- cash in hand = `32221`
- all four nozzle opening meters match the values listed above

### Step 2: Record credit given

Enter:

- customer = `Pump A`
- nozzle = `HQ-D1-N1`
- credit quantity = `20`
- notes = `manager test credit`

Expected:

- Pump A outstanding changes from `185450` to `190900`
- the system derives this as `20 liters x 272.5 = 5450`
- `Credit given` card/metric increases by `5450`
- credit entry shows petrol / nozzle `HQ-D1-N1`
- accountable cash stays unchanged during the open shift
- cash in hand stays unchanged during the open shift

### Step 3: Record credit recovery

Enter:

- customer = `Pump B`
- recovered amount = `2000`
- notes/reference optional

Expected:

- Pump B outstanding changes from `93000` to `91000`
- `Credit recovery` increases by `2000`
- accountable cash changes from `32221` to `34221`
- cash in hand changes from `32221` to `34221`

### Step 4: Record expense

Enter:

- category = `Food`
- amount = `1000`
- optional note = `manager test expense`

Expected:

- `Expenses` increases by `1000`
- accountable cash changes from `34221` to `33221`
- cash in hand changes from `34221` to `33221`

### Step 5: Submit cash

Enter:

- submit cash = `10000`

Expected:

- cash submitted changes from `0` to `10000`
- remaining cash in hand changes from `33221` to `23221`
- opening cash stays `32221`

### Step 6: Record dip

Use:

- tank = `Petrol Tank 1`
- dip reading = `1015`

Expected:

- calibration converts `1015 mm` to approximately `10150 liters`
- recent dip activity shows the new dip
- remaining fuel card for `HQ-T1` updates to around `10150 liters`

## Additional Remaining Manager Checks

### Own tanker receiving

Current local smoke baseline already added one own-tanker receiving entry successfully.

Current expected station value:

- `HQ-T1` current volume is now `11390`

You can verify:

- receiving source can switch to `Own tanker`
- an eligible own-tanker trip appears when available
- liters are recorded into the target tank
- manager receiving card still shows liters only

### Rate change during active shift

Current local smoke baseline already created a petrol rate change during the active shift.

Expected:

- a rate-change boundary card/banner appears in the manager workspace
- only affected petrol nozzles require boundary readings
- unaffected diesel nozzles are not disturbed
- if only one affected nozzle gets a boundary reading, close-check still blocks the remaining affected nozzle(s)

### Meter adjustment visibility

Current local smoke baseline already created a meter-adjustment event on one petrol nozzle.

Expected:

- at least one nozzle row shows `Meter adjusted`
- workspace status also shows a meter-adjustment review hint

### Step 7: Capture rate-change boundary for affected petrol nozzles

Because the current local DB now includes a live petrol rate change during the shift, do this before close:

- capture boundary reading for `HQ-D1-N1`
- capture boundary reading for `HQ-D2-N1`

Expected:

- rate-change boundary warning becomes resolved for the affected petrol nozzles
- unaffected diesel nozzles still require no boundary action

### Step 8: Close shift with nozzle readings

Enter these closing meters:

| Nozzle | Closing Meter |
| --- | ---: |
| `HQ-D1-N1` | `125140` |
| `HQ-D1-N2` | `98110` |
| `HQ-D2-N1` | `110640` |
| `HQ-D2-N2` | `87725` |

Enter closing cash left in hand:

- `23221`

Expected:

- close check should pass with no blocking credit/meter issue from the credit-given entry
- `10,000 submitted + 23,221 closing cash = 33,221`
- final close accountability should keep customer credit in ledger/sale classification, not subtract it again from manager cash
- shift closes successfully if no other blocking dip/meter issue remains
- next manager sees prepared/opening nozzle values carried forward exactly as:
  - `125140`
  - `98110`
  - `110640`
  - `87725`
- next manager opening cash preview becomes `23221`

## Handover Check

After Step 7:

1. close the current shift from `manager`
2. log out from `manager`
3. log in as `manager2`

Expected:

- `manager2` should no longer see `occupied`
- `manager2` should see the next prepared shift
- opening cash preview should equal the closing cash left in hand from the completed shift
- opening nozzle readings should match the closing values exactly

## Important Note

This file is the current local test baseline. If you enter extra records beyond the steps above, the expected values will change accordingly.

Pending later-role test:

- once the admin/station-admin meter-adjustment flow is available in the app, run a dedicated scenario for:
  shift opening meter -> mid-shift admin nozzle reset/adjustment -> manager close -> next-manager opening handover
- expected behavior:
  - pre-adjustment liters and post-adjustment liters reconcile into one valid shift total
  - close-check does not raise a false abnormal lower-meter issue
  - next manager opens from the final closing snapshot after adjustment, not the old pre-reset meter
