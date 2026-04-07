# PPMS Tenant Flutter

Clean tenant-app rebuild for PPMS.

This app is intentionally separate from `ppms_flutter` during Phase 9. The old Flutter app stays in the repository as a reference while this app is rebuilt one vertical slice at a time.

## Current Slice

- Login
- Session context
- Tenant landing page
- Role-aware navigation
- HeadOffice worker creation for Manager, Accountant, and Operator

## Rules

- No dashboards until real action flows are stable.
- No MasterAdmin daily-work screens in the tenant app.
- No separate StationAdmin for one-station tenants.
- Every slice must be tested, committed, and pushed before moving on.
