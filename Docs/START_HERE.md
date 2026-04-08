# Start Here

This is the active documentation set for the frontend restart.

The old planning and Phase 1-9 docs were archived to [old-Docs](/C:/Fuel%20Management%20System/Docs/old-Docs). Use them only as historical reference, not as the current plan.

Supporting reference docs that still matter, but are not part of the main working set anymore, were moved to [supporting-reference](/C:/Fuel%20Management%20System/Docs/supporting-reference).

## Active Working Set

Read these files in this order:

1. [09_MASTER_PRODUCT_SPEC.md](/C:/Fuel%20Management%20System/Docs/09_MASTER_PRODUCT_SPEC.md)
   - the clean consolidated product specification

2. [10_IMPLEMENTATION_ROADMAP_AND_CHECKLIST.md](/C:/Fuel%20Management%20System/Docs/10_IMPLEMENTATION_ROADMAP_AND_CHECKLIST.md)
   - the phased Flutter/backend execution roadmap and checklists

3. [08_FINALIZED_PRODUCT_DIRECTION_SO_FAR.md](/C:/Fuel%20Management%20System/Docs/08_FINALIZED_PRODUCT_DIRECTION_SO_FAR.md)
   - the detailed decision log behind the master spec

## Supporting Reference Docs

Use these when deeper backend/schema/architecture reference is needed:

1. [01_PROJECT_RESET_AND_GOALS.md](/C:/Fuel%20Management%20System/Docs/supporting-reference/01_PROJECT_RESET_AND_GOALS.md)
   - explains what was removed, what remains, and the new delivery goal

2. [02_BACKEND_SOURCE_OF_TRUTH.md](/C:/Fuel%20Management%20System/Docs/supporting-reference/02_BACKEND_SOURCE_OF_TRUTH.md)
   - lists the real backend modules, route families, and frontend-facing API contract direction

3. [03_DATA_MODEL_AND_PERMISSIONS.md](/C:/Fuel%20Management%20System/Docs/supporting-reference/03_DATA_MODEL_AND_PERMISSIONS.md)
   - lists the real tables, important attributes, role scopes, and permission matrix

4. [04_FLUTTER_ARCHITECTURE_PLAN.md](/C:/Fuel%20Management%20System/Docs/supporting-reference/04_FLUTTER_ARCHITECTURE_PLAN.md)
   - defines how to build the new Flutter app so desktop can later expand to Android and iOS with minimal rework

5. [05_FLUTTER_DELIVERY_PHASES.md](/C:/Fuel%20Management%20System/Docs/supporting-reference/05_FLUTTER_DELIVERY_PHASES.md)
   - gives the step-by-step execution sequence for the new app

6. [06_API_SCHEMA_SURFACE.md](/C:/Fuel%20Management%20System/Docs/supporting-reference/06_API_SCHEMA_SURFACE.md)
   - lists the main request and response schemas the frontend should model directly

7. [07_SCHEMA_STATUS_AND_FUTURE_PLAN.md](/C:/Fuel%20Management%20System/Docs/supporting-reference/07_SCHEMA_STATUS_AND_FUTURE_PLAN.md)
   - separates what already exists, what should be added soon, and what should stay future-only

## Current Direction

- backend is the source of truth
- old desktop, web, and Flutter frontends are gone
- old docs are archived
- active working docs are kept at the top level of `Docs`
- supporting reference docs are grouped separately
- new frontend work starts from real backend contracts, not past UI behavior
- build one clean Flutter codebase with responsive layouts and shared domain logic
- optimize for future Windows, Android, and iOS reuse from day one
- use the master product spec and implementation roadmap as the active execution docs

## First Working Rule

Do not start coding screens from memory.

For each frontend slice:

1. confirm the role and workflow
2. confirm the table and schema contract
3. confirm the permission and module rule
4. design the shared state/data layer
5. build the UI
6. test on desktop first
7. keep the structure portable for mobile later
