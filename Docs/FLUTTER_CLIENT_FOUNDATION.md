# PPMS Flutter Client Foundation

## Purpose

This document explains how the Flutter client is intended to sit on top of the current PPMS backend.

## Current Direction

- Backend remains the main source of truth
- Flutter becomes the real long-term desktop and mobile client
- The older Python desktop shell can stay as a prototype/reference tool, but it is not the target frontend stack

## Flutter App Location

- [ppms_flutter](/C:/Fuel%20Management%20System/ppms_flutter)

## Current Foundation

The Flutter app currently includes:

- app theme and bootstrap
- configurable backend base URL
- shared API client
- stored auth session restore
- login screen
- responsive shell for desktop/mobile
- dashboard screen
- first working operational screen for:
  - sales
- second working operational screen for:
  - attendance
- third working operational screen for:
  - payroll
- fourth working operational screen for:
  - reports
- fifth working operational screen for:
  - notifications
- sixth working operational screen for:
  - settings
- seventh working operational screen for:
  - documents

## Backend Module Mapping

| Flutter Feature | Backend Area |
| --- | --- |
| Auth | `/auth/*` |
| Dashboard | `/dashboard/` |
| Sales | `/fuel-sales/*`, `/nozzles/*`, `/customers/*` |
| Attendance | `/attendance/*` |
| Payroll | `/payroll/*` |
| Reports | `/reports/*`, `/report-exports/*` |
| Notifications | `/notifications/*` |
| Documents | `/financial-documents/*`, `/report-exports/*`, `/invoice-profiles/*`, `/document-templates/*` |
| Governance | `/expenses/*`, `/purchases/*`, reversal approval endpoints |
| Head Office | organization-aware dashboard/report/user/station endpoints |

## Recommended Next Flutter Steps

1. Add platform-specific polish for Windows and Android
2. Add native/open/share flows for PDF and CSV downloads

## Local Run

```bash
cd ppms_flutter
flutter pub get
flutter run -d windows
```

The backend should already be running locally, for example at:

- `http://127.0.0.1:8012`

You can override the API URL at build/run time:

```bash
flutter run -d windows --dart-define=PPMS_API_BASE_URL=http://127.0.0.1:8012
```
