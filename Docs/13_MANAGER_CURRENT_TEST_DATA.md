# Manager Current Test Data

This file reflects the current local database state prepared for manager testing on `2026-04-09`.

## Logins

- `manager` / `manager123`
- `manager2` / `manager223`

## Current Active Manager Test Station

- Station: `HQ`
- Station ID: `3`
- Open shift owner: `manager2`
- Open shift ID: `3`
- Opening cash for current shift: `81221`
- Current accountable cash at shift start: `81221`
- Current cash submitted: `0`
- Current cash in hand: `81221`

## Current Opening Meter Values

These are the current local manager demo opening values.

| Nozzle | Code | Fuel | Opening Meter | Current Meter |
| --- | --- | --- | ---: | ---: |
| 1 | `HQ-D1-N1` | Petrol | `125000` | `125000` |
| 2 | `HQ-D1-N2` | Diesel | `98000` | `98000` |
| 3 | `HQ-D2-N1` | Petrol | `110500` | `110500` |
| 4 | `HQ-D2-N2` | Diesel | `87650` | `87650` |

## Current Tank Values

| Tank | Code | Fuel | Capacity | Current Volume |
| --- | --- | --- | ---: | ---: |
| Petrol Tank 1 | `HQ-T1` | Petrol | `20000` | `12000` |
| Diesel Tank 1 | `HQ-T2` | Diesel | `20000` | `14000` |

## Current Customer Values

| Customer | Code | Credit Limit | Outstanding |
| --- | --- | ---: | ---: |
| Smoke Customer | `F-SMOKE-CUST` | `9000` | `700` |
| Tanker Customer | `TANKER-CUST` | `0` | `0` |
| Pump A | `CUST-PUMP-A` | `500000` | `90000` |
| Pump B | `CUST-PUMP-B` | `450000` | `5000` |

## Recommended Step-By-Step Manager Test

Use `manager2` first because that user currently owns the open shift.

### Step 1: Confirm current shift baseline

Expected:

- status = `open`
- opening cash = `81221`
- cash in hand = `81221`
- all four nozzle opening meters match the values listed above

### Step 2: Record credit given

Enter:

- customer = `Pump A`
- credit amount = `5000`
- notes = `manager test credit`

Expected:

- Pump A outstanding changes from `90000` to `95000`
- `Credit given` card/metric increases by `5000`
- accountable cash changes from `81221` to `76221`
- cash in hand changes from `81221` to `76221`

### Step 3: Record credit recovery

Enter:

- customer = `Pump B`
- recovered amount = `2000`
- notes/reference optional

Expected:

- Pump B outstanding changes from `5000` to `3000`
- `Credit recovery` increases by `2000`
- accountable cash changes from `76221` to `78221`
- cash in hand changes from `76221` to `78221`

### Step 4: Record expense

Enter:

- category = `Food`
- amount = `1000`
- optional note = `manager test expense`

Expected:

- `Expenses` increases by `1000`
- accountable cash changes from `78221` to `77221`
- cash in hand changes from `78221` to `77221`

### Step 5: Submit cash

Enter:

- submit cash = `50000`

Expected:

- cash submitted changes from `0` to `50000`
- remaining cash in hand changes from `77221` to `27221`
- opening cash stays `81221`

### Step 6: Record dip

Use:

- tank = `Petrol Tank 1`
- dip reading = `1015`

Expected:

- calibration converts `1015 mm` to approximately `10150 liters`
- recent dip activity shows the new dip

### Step 7: Close shift with nozzle readings

Enter these closing meters:

| Nozzle | Closing Meter |
| --- | ---: |
| `HQ-D1-N1` | `125120` |
| `HQ-D1-N2` | `98110` |
| `HQ-D2-N1` | `110640` |
| `HQ-D2-N2` | `87725` |

Enter closing cash left in hand:

- `27221`

Expected:

- shift closes successfully if no blocking dip/meter issue remains
- next manager sees prepared/opening nozzle values carried forward exactly as:
  - `125120`
  - `98110`
  - `110640`
  - `87725`
- next manager opening cash preview becomes `27221`

## Handover Check

After Step 7:

1. log out from `manager2`
2. log in as `manager`

Expected:

- `manager` should no longer see `occupied`
- `manager` should see the next prepared shift
- opening cash preview should be `27221`
- opening nozzle readings should match the Step 7 closing values exactly

## Important Note

This file is the current local test baseline. If you enter extra records beyond the steps above, the expected values will change accordingly.
