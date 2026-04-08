# Start Here

## Current Note

Both previous Flutter app folders were intentionally removed from the repository.

Keep using the backend, support console, scenario runner, matrix JSON files, and API smoke scripts as the active Phase 9 foundation while a new Flutter plan is defined.

When returning to this project, use these files in this order:

1. [FINAL_PHASED_MASTER_ROADMAP.md](FINAL_PHASED_MASTER_ROADMAP.md)
   - this is the main execution roadmap

2. [SIMPLIFIED_SETUP_AND_ROLE_PLAN.md](SIMPLIFIED_SETUP_AND_ROLE_PLAN.md)
   - this contains the business logic and product rules

3. [CURRENT_PROGRESS.md](CURRENT_PROGRESS.md)
   - this shows what already exists and where things are

4. [PHASE_EXECUTION_TEMPLATE.md](PHASE_EXECUTION_TEMPLATE.md)
   - this is the template to execute one phase properly

5. [TENANT_FLUTTER_REBUILD_PLAN.md](TENANT_FLUTTER_REBUILD_PLAN.md)
   - this is the clean tenant Flutter rebuild source of truth

6. [FLUTTER_UI_AUTOMATION_RECORD_AND_REBUILD_STRATEGY.md](FLUTTER_UI_AUTOMATION_RECORD_AND_REBUILD_STRATEGY.md)
   - this records the paused Flutter automation work and the new matrix-first rebuild strategy

7. [AUTOMATION_AND_MATRIX_BUNDLE.md](AUTOMATION_AND_MATRIX_BUNDLE.md)
   - this explains the app folders, automation scripts, JSON matrices, Flutter test files, and CI workflow

8. [CHECKTESTINGPLAN.md](CHECKTESTINGPLAN.md)
   - this is the Phase 9 manual testing and fix workflow

9. [PHASE9_SAMPLE_DATASET.md](PHASE9_SAMPLE_DATASET.md)
   - this defines the large sample data and expected totals for automated Phase 9 acceptance checks

10. [PHASE9_COVERAGE_AUDIT.md](PHASE9_COVERAGE_AUDIT.md)
   - this shows what the Phase 9 runner and clean tenant app cover, and what is still missing

## Current Recommended Next Step

Start with:

- `Phase 9 - Local Stabilization and Acceptance`
- use [FLUTTER_UI_AUTOMATION_RECORD_AND_REBUILD_STRATEGY.md](FLUTTER_UI_AUTOMATION_RECORD_AND_REBUILD_STRATEGY.md) before doing more Flutter work
- use [AUTOMATION_AND_MATRIX_BUNDLE.md](AUTOMATION_AND_MATRIX_BUNDLE.md) to understand current scripts, JSON matrices, Flutter automation record, and CI
- use [TENANT_FLUTTER_REBUILD_PLAN.md](TENANT_FLUTTER_REBUILD_PLAN.md) only after the next matrix-first UI slice is agreed
- use [CHECKTESTINGPLAN.md](CHECKTESTINGPLAN.md) as the step-by-step manual acceptance plan
- use [PHASE9_SAMPLE_DATASET.md](PHASE9_SAMPLE_DATASET.md) when expanding automated scenario data and expected calculations
- use [PHASE9_COVERAGE_AUDIT.md](PHASE9_COVERAGE_AUDIT.md) to choose the next missing batch without drifting off the roadmap

from:

- [FINAL_PHASED_MASTER_ROADMAP.md](FINAL_PHASED_MASTER_ROADMAP.md)

## Phase Status

- `Phase 1 - Setup Hierarchy Foundation`: complete locally
- `Phase 2 - Operations Core`: complete locally
- `Phase 3 - Finance, Ledgers, Payroll, Pricing`: complete locally
- `Phase 4 - Tanker and Extended Operations`: complete locally
- `Phase 5 - Notifications, Documents, Reports, Profit`: complete locally
- `Phase 6 - Roles, Permissions, Modules, SaaS Rules`: complete locally
- `Phase 7 - Flutter App Completion`: complete locally
- `Phase 8 - Master Admin Support Frontend`: complete locally
- next sequence: continue into `Phase 9 - Local Stabilization and Acceptance`

## Important Decision Already Made

Current direction:

- keep the existing project
- keep the Flutter automation, matrices, and CI knowledge in the repo for record/reference
- do not bring back the deleted Flutter app folders automatically
- pause broad Flutter building until each screen is discussed and defined in a backend/matrix contract
- use backend scenario data and matrix-first rules as the source of truth
- build modules separately first, then integrate after each module is proven
- optional SaaS modules must hide completely when disabled so the UI looks like the module was never installed
- complete locally first
- deploy later to EC2/Vercel after local stabilization

## Reminder

Do not try to do everything at once.

Work phase by phase.
