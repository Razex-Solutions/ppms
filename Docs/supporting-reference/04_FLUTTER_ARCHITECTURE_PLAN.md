# Flutter Architecture Plan

## Goal

Build one Flutter codebase that is:

- desktop-ready first
- mobile-safe by architecture
- backend-driven
- role-aware
- module-aware
- easy to extend to Android and iOS later

## Main Rule

Do not build a Windows app and later try to squeeze it into mobile.

Instead, build a shared app with:

- responsive shell
- feature-level domain isolation
- reusable state and repository layers
- platform-agnostic form, list, and detail patterns

## Recommended App Structure

Use a structure like this:

```text
lib/
  app/
    app.dart
    routes.dart
    theme/
  core/
    api/
    auth/
    capabilities/
    errors/
    models/
    widgets/
    utils/
  features/
    auth/
    shell/
    setup/
    shifts/
    sales/
    finance/
    parties/
    payroll/
    attendance/
    tankers/
    pos/
    reports/
    documents/
    notifications/
    hardware/
    settings/
```

## Required Architectural Layers

### 1. Transport Layer

Responsibilities:

- HTTP client
- token injection
- token refresh
- typed request and response parsing
- backend error normalization

This layer must not know about widget trees.

### 2. Repository Layer

Responsibilities:

- convert raw schema payloads into frontend models
- group backend endpoints into feature repositories
- keep feature code from scattering HTTP calls everywhere

### 3. Capability Layer

Responsibilities:

- current user identity
- role name
- scope level
- station context
- enabled modules
- feature flags
- permission checks

This should be loaded early and exposed centrally so every screen does not reinvent access logic.

### 4. Feature State Layer

Responsibilities:

- screen state
- pagination/filter state
- optimistic or guarded updates where safe
- loading/error/retry handling

Keep this per feature, not global.

### 5. Responsive UI Layer

Responsibilities:

- adapt layout for narrow, medium, and wide screens
- reuse the same widgets for desktop and mobile where possible
- avoid desktop-only assumptions like persistent wide side panels everywhere

## Layout Strategy For Future Platform Reuse

Use three layout targets from day one:

- compact
  - phones
  - bottom navigation or drawer
  - single-column forms

- medium
  - tablets and small landscape windows
  - mixed drawer and top actions
  - two-step flows where needed

- expanded
  - desktop and large tablets
  - navigation rail or side nav
  - list-detail layouts

The important part is this:

- same feature state
- same repositories
- same DTO mapping
- only layout changes by breakpoint

## Navigation Rule

Navigation must be capability-driven.

Each destination should declare:

- required module
- required action or read permission
- scope requirements

Then the shell decides if the destination exists at all.

Do not render dead menu items.

## Feature Design Pattern

Each feature packet should have:

- `api` models mapped from backend schemas
- repository
- controller or state notifier
- screen widgets
- reusable subwidgets

## Form Rule

Forms must follow backend schema objects.

That means:

- required frontend fields should match required backend fields
- optional frontend fields should stay optional
- derived values should not become free text if backend calculates them

Examples:

- fuel sale quantity must stay derived from meters
- payroll totals must stay derived
- reversal approval notes must map to real workflow fields

## State Management Recommendation

Use a state solution that works well across desktop and mobile and keeps rebuild behavior predictable.

Good fit:

- Riverpod with code generation if desired
- or another strongly structured reactive state system already preferred by the team

What matters more than the package:

- testable controllers
- repository injection
- clear async loading states
- no business logic buried in widgets

## Shared Design System Rule

Build a reusable design system early:

- page scaffold
- section header
- empty state
- error state
- filter bar
- table/list cards
- detail cards
- status chips
- action bars
- confirmation dialogs
- form field wrappers

This prevents every feature from inventing a new look and behavior.

## Testing Strategy

Start with:

- repository tests
- controller or state tests
- widget tests for shell and critical screens
- golden tests later for stable layouts

Keep this backend-linked:

- use real schema shapes from backend
- use mocked repositories that mirror backend payloads
- add smoke tests by feature packet, not giant end-to-end UI chaos first

## Architecture Guardrails

- no direct HTTP calls inside widgets
- no permission logic duplicated per button when capability selectors can centralize it
- no module toggle logic hardcoded in random screens
- no platform-specific UI branching unless there is a real platform need
- no rebuilding the old dashboard-heavy structure first

## First Technical Deliverables

Before business screens:

1. app shell
2. auth/session handling
3. capability loader
4. responsive layout primitives
5. navigation policy
6. shared design system primitives

That foundation is what will make later Android and iOS expansion much cheaper.
