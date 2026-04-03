# PPMS Flutter Client

This is the main shared Flutter client for the Petrol Pump Management System. It is intended to become the real desktop and mobile frontend on top of the PPMS backend.

## Current Purpose

- Use one shared Flutter codebase for Windows desktop and Android/mobile
- Keep the backend as the source of truth for business rules and data
- Build operational station workflows on top of the existing PPMS API

## Current Status

The Flutter app is no longer just a scaffold. It already has working screens connected to the backend.

### Implemented Screens

- Login
- Dashboard
- Sales
- Shifts
- POS
- Attendance
- Expenses
- Parties
- Inventory
- Setup
- Finance
- Payroll
- Reports
- Documents
- Notifications
- Hardware
- Tankers
- Governance
- Admin
- Settings

### Implemented Capabilities

- configurable backend base URL
- persisted session restore
- role-aware navigation
- module-aware navigation
- live dashboard loading
- forecourt fuel sale creation
- shift open/close workflows
- POS sales and reversal flow
- customer and supplier create/update flows
- tank, dispenser, and nozzle create/update flows
- expense creation and status filtering
- purchase and payment workflows
- governance review actions for approvals
- hardware polling, simulation, and nozzle meter adjustments
- tanker trip, delivery, expense, and completion workflows
- invoice/profile setup flows
- report viewing and export jobs
- document preview and local save/open actions
- notification inbox and preference management
- admin user/station/role/module management
- responsive split layouts for larger operational screens
- search/filter on heavier lists

## Backend Contract Status

Flutter/backend alignment is now checked with dedicated tests:

- [test_flutter_backend_contract.py](/C:/Fuel%20Management%20System/tests/test_flutter_backend_contract.py)
- [test_backend_alignment_smoke.py](/C:/Fuel%20Management%20System/tests/test_backend_alignment_smoke.py)

These verify that important response keys and representative routes used by Flutter match the backend behavior.

## Backend Module Mapping

| Flutter Feature | Backend Area |
| --- | --- |
| Auth | `/auth/*` |
| Dashboard | `/dashboard/` |
| Sales | `/fuel-sales/*`, `/customers/*`, `/nozzles/*`, `/stations/*` |
| Shifts | `/shifts/*` |
| POS | `/pos-products/*`, `/pos-sales/*` |
| Attendance | `/attendance/*` |
| Expenses | `/expenses/*` |
| Parties | `/customers/*`, `/suppliers/*` |
| Inventory | `/tanks/*`, `/dispensers/*`, `/nozzles/*`, `/fuel-types/*` |
| Setup | `/fuel-types/*`, `/invoice-profiles/*` |
| Finance | `/purchases/*`, `/customer-payments/*`, `/supplier-payments/*` |
| Payroll | `/payroll/*` |
| Reports | `/reports/*`, `/report-exports/*` |
| Documents | `/financial-documents/*`, `/report-exports/*` |
| Notifications | `/notifications/*` |
| Hardware | `/hardware/*`, `/nozzles/*` |
| Tankers | `/tankers/*`, `/station-modules/*` |
| Governance | `/expenses/*`, `/purchases/*`, `/customers/*` |
| Admin | `/users/*`, `/stations/*`, `/roles/*`, `/station-modules/*` |
| Settings | `/auth/me`, `/`, local app configuration |

## What Is Done

The Flutter app is already good enough to:

- sign in against the live PPMS backend
- navigate by permissions and enabled modules
- perform core operational workflows
- review approvals and governance queues
- open and save generated business documents
- run as the active frontend direction for desktop and mobile

## What Is Still Remaining

The next work is no longer foundation work. It is product polish and deeper workflow completeness.

### Near-Term Remaining Steps

1. Safe delete/archive flows where the backend supports them
2. Richer document preview and dispatch actions from more screens
3. More record detail panels in finance, inventory, and admin areas
4. Better mobile-specific layout polish for dense workspaces
5. Better desktop ergonomics for Windows usage
6. Native file/share/open improvements for desktop and mobile
7. More visual polish, empty states, validation hints, and loading states

### Later Flutter Expansion

1. dedicated mobile-first screens for smaller devices
2. customer-facing or supplier-facing portal flows if needed
3. push-notification handling for mobile
4. offline-aware UX only if the product later needs hybrid operation

## Run Locally

Make sure the backend is running first. Current local backend example:

- `http://127.0.0.1:8012`

Then run Flutter:

```bash
cd ppms_flutter
flutter pub get
flutter run -d windows
```

Or pass the backend URL explicitly:

```bash
flutter run -d windows --dart-define=PPMS_API_BASE_URL=http://127.0.0.1:8012
```

For Android later:

```bash
flutter run -d android --dart-define=PPMS_API_BASE_URL=http://127.0.0.1:8012
```

## Local Login

Default seeded local login:

- Username: `admin`
- Password: `admin123`

## Notes

- The older Python desktop client is only a prototype/reference now.
- Flutter is the real frontend direction going forward.
- The PPMS backend remains the main source of truth for business logic.
