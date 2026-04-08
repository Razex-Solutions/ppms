# Project Reset And Goals

## What Changed

The following frontend codebases were intentionally removed from the repository:

- `desktop_app`
- `support_console`
- `ppms_flutter`
- `ppms_tenant_flutter`

The purpose of the reset is simple:

- stop carrying confusing UI history forward
- stop patching unstable frontend code
- restart from the real backend instead of old screen assumptions

## What Still Exists

The active product base is now:

- FastAPI backend in [ppms](/C:/Fuel%20Management%20System/ppms)
- database models and migrations
- Pydantic schemas
- permission and capability logic
- scenario runner and API smoke scripts
- archived docs in [old-Docs](/C:/Fuel%20Management%20System/Docs/old-Docs)

## Product Goal

Build one new Flutter app that:

- works well on Windows first
- uses responsive layouts, not desktop-only assumptions
- keeps domain logic separate from visual layout
- can later expand to Android and iOS without a rewrite
- uses backend contracts directly
- hides disabled modules completely
- respects role scope and permission rules exactly

## Engineering Goal

The new app should separate:

- app shell and navigation
- auth and session
- permissions and capability resolution
- data repositories and DTO mapping
- feature workflows
- reusable responsive widgets

This is what will keep future platform expansion cheap.

## Non-Goals Right Now

Do not do these first:

- rebuild the old dashboards
- rebuild every feature at once
- design for mobile-only first
- create platform-specific code early
- invent frontend-only business logic
- drift away from actual backend tables and schemas

## Immediate Planning Goal

Before new Flutter code:

1. lock the real backend truth
2. lock the role and module rules
3. group the backend into frontend domains
4. define the Flutter architecture
5. define the delivery order

Only then start feature implementation.
