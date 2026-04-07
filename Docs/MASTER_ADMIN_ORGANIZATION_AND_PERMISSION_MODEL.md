# PPMS Master Admin, Organization Setup, And Permission Model

## Purpose

This document defines the bigger PPMS product model requested for the next stage of the system.

It covers:

- Razex Solutions as the platform owner
- a `Master Admin` / platform super-user layer
- organizations as customer companies
- one or more stations under each organization
- brand/company/station setup
- station-by-station operational configuration
- module enable/disable behavior
- hierarchical role creation
- module-level permissions
- how dashboards should differ by role

This is a planning and design specification first.

It should be reviewed and edited before major backend or Flutter permission changes are implemented.

---

## 1. Product Ownership Model

There are two different levels in the platform:

### Level A: Platform Owner

This is **Razex Solutions**.

Razex Solutions owns the software platform and can:

- create customer organizations
- assign subscriptions
- manage SaaS plans
- enable or disable platform features
- troubleshoot customer data
- fix or update configuration
- override or repair setup issues
- inspect and manage the system at full depth

This level needs a special role:

- `MasterAdmin`

### Level B: Customer Organization

This is the actual fuel business using the software.

Examples:

- a PSO dealer company
- a Shell franchise company
- a Caltex operator
- any independent petroleum company

Each customer organization can have:

- one station
- or multiple stations

Each organization is a tenant/customer of the SaaS system.

---

## 2. Highest-Level Role Structure

Recommended hierarchy:

1. `MasterAdmin`
2. `HeadOffice`
3. `StationAdmin`
4. `Manager`
5. `Accountant`
6. `Operator`
7. optional `DriverLogin`
8. profile-only employees

This means the system should no longer think only in terms of:

- admin
- manager
- operator

It should think in terms of:

- platform level
- organization level
- station level
- operational staff level

---

## 3. Master Admin

## Purpose

`MasterAdmin` is Razex Solutions’ own platform super-user.

This role is above customer organizations.

## Scope

- all organizations
- all stations
- all users
- all subscriptions
- all modules
- all data if platform support requires it

## What Master Admin Can Do

- create organization accounts
- configure organization details
- assign subscription or free trial
- activate/suspend subscriptions
- create the first `HeadOffice` or organization owner account
- inspect all organization and station data
- repair broken configurations
- edit data if support intervention is needed
- delete or archive data if business/policy allows
- manage platform-wide module availability
- control SaaS plan entitlements
- troubleshoot hardware, integration, and data issues

## Master Admin Dashboard Should Show

- organizations count
- active subscriptions
- free trials
- expired subscriptions
- pending payments
- plan usage
- company onboarding status
- station count by organization
- platform alerts
- support/admin intervention items

## Important Note

`MasterAdmin` is **not** a customer role.

It belongs to Razex Solutions only.

---

## 4. Organization Model

An organization is the customer company.

Examples:

- Shell XYZ Pvt Ltd
- PSO ABC Fuels
- Caltex Highway Energy

## Organization Should Store

- organization name
- legal name
- brand name
- selected brand template
- logo
- registration details
- NTN / tax information
- contact details
- subscription plan
- subscription status
- billing status
- free-trial dates if applicable
- number of stations
- organization-level modules
- organization-level branding

## Brand Concept

The organization may belong to a known fuel brand such as:

- Shell
- Caltex
- PSO
- Total
- Attock
- Hascol
- Other / custom

This should affect:

- default branding
- logo presets
- invoice look
- default color style if desired

But the organization should still be able to override:

- logo
- company name
- invoice footer
- legal/tax details

---

## 5. Organization Onboarding Flow

## Step 1: Master Admin creates a new organization

Master Admin enters:

- fuel brand
- organization name
- legal details
- logo/branding
- subscription type
- free trial or paid start
- number of stations

## Step 2: Master Admin creates first organization-level account

This should typically be:

- `HeadOffice`

or

- organization owner account

## Step 3: Station creation

If number of stations is:

### 1 station

The organization can:

- inherit organization details
- or provide separate station details

### more than 1 station

The system should ask for each station:

- station name
- station code
- address
- city
- whether it is head office station
- whether it inherits organization branding/details

---

## 6. Station Setup Wizard / Mapping Model

After station creation, the platform should support a setup flow for each station.

That setup should map the station according to its real-world needs.

## Station Setup Areas

### A. Basic station profile

- station name
- station code
- address
- city
- organization link
- branding override if any

### B. Tank and dispenser mapping

The station setup must support:

- creating tanks
- creating dispensers
- creating nozzles
- linking tank to dispenser flow via nozzles

Important operational rule:

- one tank may feed more than one dispenser
- one dispenser has one or more nozzles
- each nozzle must map to a tank and fuel type

This setup should include:

- tank capacity
- tank fuel type
- dispenser count
- nozzle count
- nozzle code/name
- opening reading
- whether meter adjustment is enabled

### C. Fuel types

The setup must allow:

- selecting existing fuel types
- creating station-supported fuel types
- linking fuel types to tanks and nozzles

### D. Shops / rented spaces / own shops

A station may have:

- one or more shops
- tyre shop
- service station
- tuck shop / mart
- workshop
- rented outlet

For each shop:

- shop name
- shop type
- own or rented

If rented:

- renter name
- rent amount
- due cycle
- electricity charged or not
- sub-meter reading or not
- separate utility billing or not

If own:

- whether shop sales should go into main ledger
- whether it uses POS
- whether stock/products should be tracked

### E. Other products / POS stock

Station may sell:

- engine oil
- lubricants
- additives
- accessories
- snacks / retail products

The setup should ask:

- does station sell non-fuel products?
- if yes, enable POS/inventory products
- if no, hide or disable POS-related setup

### F. Hardware / automation

Ask:

- does station have automated dispenser reading?
- does station have tank probes?
- does station have printer?
- does station have supported hardware integration?

If yes:

- enable relevant hardware module
- collect vendor/device details

If no:

- keep manual flow only

### G. Meter adjustment policy

Ask:

- is manual nozzle meter adjustment/reset allowed?

If yes:

- enable meter-adjustment workflows

If no:

- keep that feature off

### H. Tankers owned

Ask:

- does organization/station own fuel tankers?

If yes:

- enable tanker module
- allow tanker master data
- allow trips, deliveries, tanker expenses

If no:

- hide tanker operations

---

## 7. Cash And Shift Handling Requirements

You described an important real-world need:

- when shifts change
- how much cash one manager/operator handed over
- how much cash was submitted to the office or safe
- how much remained in hand

This means station shift logic should eventually include:

- opening cash in hand
- closing cash in hand
- submitted cash
- carried-forward cash
- handover to next shift/user
- who handed over
- who received
- timestamp
- variance/explanation

This is beyond a simple open/close shift.

It becomes a **cash control workflow**.

---

## 8. Permission Model Direction

The system should move away from simple role-name logic only.

We need:

- hierarchical role creation
- module permissions
- action permissions
- per-role visibility
- per-role edit/create/delete controls

## Permission Layers

### Layer 1: platform permission

Example:

- can create organizations
- can edit subscriptions
- can inspect any tenant

This is for `MasterAdmin`.

### Layer 2: organization permission

Example:

- can create station admins
- can view all stations inside organization
- can manage branding and company settings

This is for `HeadOffice`.

### Layer 3: station permission

Example:

- can create manager
- can manage station inventory
- can manage station staff
- can enable modules at station level if allowed

This is for `StationAdmin`.

### Layer 4: operational permission

Example:

- can create sales
- can open shifts
- can add expenses
- can post receipts
- can view reports

This is for manager/accountant/operator/driver login based on scope.

---

## 9. Proposed Role Creation Chain

Recommended:

- `MasterAdmin` creates organization
- `MasterAdmin` creates first `HeadOffice`
- if the organization has one station, `HeadOffice` also acts as the station admin
- if the organization has more than one station, `HeadOffice` creates `StationAdmin`
- `HeadOffice` creates Manager, Accountant, Operator, and staff profiles directly for single-station organizations
- `StationAdmin` creates Manager, Accountant, Operator, optional DriverLogin, and staff profiles for assigned stations in multi-station organizations

This means:

- customer companies do not create platform users
- station admins do not create organization head-office users
- lower users do not create higher users
- the old generic `Admin` role should be treated as legacy/bootstrap compatibility, not the target customer role

---

## 10. Proposed Roles And Their Main Purpose

## 10.1 MasterAdmin

Platform owner and global support controller.

## 10.2 HeadOffice

Organization-wide owner/controller for one customer company.

For a single-station organization, this role is also the station administrator.

## 10.3 StationAdmin

Full controller of one station’s setup, staff, modules, and operations.

This role should normally appear only for multi-station organizations.

## 10.4 Manager

Daily station operational leader.

## 10.5 Accountant

Finance and ledger-focused station user.

## 10.6 Operator

Forecourt and shift-level daily operator.

## 10.7 DriverLogin

Very limited login for assigned tanker/field workflows only.

## 10.8 StaffProfile

Profile-only employees with no login by default.

---

## 11. Module Permission Thinking

Permissions should be grouped by module.

Examples:

### Organization module permissions

- organization.view
- organization.update
- organization.branding.update
- organization.subscription.view

### Station module permissions

- station.create
- station.view
- station.update
- station.delete

### User and staff permissions

- users.create.station_admin
- users.create.manager
- users.create.accountant
- users.create.operator
- staff_profiles.create
- staff_profiles.update

### Inventory permissions

- tanks.view
- tanks.create
- tanks.update
- tanks.delete
- dispensers.view
- dispensers.create
- nozzles.adjust_meter

### Sales permissions

- fuel_sales.create
- fuel_sales.view
- fuel_sales.reverse.request
- fuel_sales.reverse.approve

### Finance permissions

- purchases.create
- purchases.approve
- customer_payments.create
- supplier_payments.create
- ledger.view

### Governance permissions

- expenses.approve
- purchases.approve
- credit_override.approve
- reversal.approve

### Hardware permissions

- hardware.view
- hardware.configure
- hardware.simulate
- nozzle.adjust_meter

### Tanker permissions

- tankers.view
- tankers.create
- tanker_trips.manage
- tanker_deliveries.manage
- tanker_expenses.manage

### Payroll / attendance permissions

- attendance.self
- attendance.manage
- payroll.view
- payroll.run
- payroll.finalize

### POS permissions

- pos_products.manage
- pos_sales.create
- pos_sales.reverse

---

## 12. Example Dashboard Differences By Role

## MasterAdmin dashboard

Should show:

- organizations
- plans
- subscription statuses
- overdue payments
- free-trial expiring
- platform-wide issues
- company onboarding progress
- support alerts

## HeadOffice dashboard

Should show:

- organization performance
- all stations summary
- pending approvals
- station comparison
- financial summaries
- alerts from all stations

## StationAdmin dashboard

Should show:

- station operations overview
- sales
- stock
- expenses
- pending approvals
- staff status
- cash/shift status

## Manager dashboard

Should show:

- current shift
- daily sales
- low stock
- expenses
- purchase status
- handover and cash controls

## Accountant dashboard

Should show:

- receivables
- payables
- payments
- pending finance actions
- profit summary
- payroll summaries if allowed

## Operator dashboard

Should show:

- current shift
- assigned operational actions
- sales shortcut
- attendance
- limited alerts

## DriverLogin dashboard

Should show:

- assigned tanker trips
- own attendance
- delivery tasks
- own trip expenses

---

## 13. Station Setup Wizard Proposed Flow

Recommended future setup flow:

### Step 1

Organization details

### Step 2

Subscription / free trial / SaaS plan

### Step 3

Branding

- Shell / PSO / Caltex / custom

### Step 4

Number of stations

### Step 5

Create station(s)

### Step 6

Per-station operational setup:

- tanks
- dispensers
- nozzles
- fuel types
- meter adjustment policy
- hardware policy
- tanker policy
- POS policy
- shop/rented shop policy

### Step 7

Create first station admin(s)

### Step 8

Create staff and role permissions

### Step 9

Review mapping summary before activation

---

## 14. Important Product Rule

The system should not expose every module to every organization or station.

It should behave like:

- configure what the customer actually uses
- disable what they do not use
- shape dashboards, forms, and permissions around that configuration

This avoids:

- confusing UI
- unnecessary fields
- incorrect workflows
- bad permissions

---

## 15. What This Means For The Current Codebase

Your requested model implies a major design expansion beyond the current simplified role structure.

The current backend/frontend already has foundations for:

- organizations
- stations
- roles
- users
- station modules
- organization modules
- subscriptions
- invoice branding
- hardware toggles
- tanker toggles
- POS toggles

But the following still need redesign or expansion later:

- add `MasterAdmin` as true platform role
- organization onboarding wizard flow
- station setup wizard flow
- module-aware onboarding decisions
- role-creation hierarchy enforcement
- profile-only staff model
- per-module permission matrix editable by upper roles
- dashboard separation by role level
- company/brand/station inheritance rules
- shop/rental model
- cash handover model

---

## 16. Recommended Implementation Order

To avoid mistakes, this should be implemented in phases.

### Phase 1

Finalize this document and role/business rules.

### Phase 2

Introduce `MasterAdmin` and platform/customer separation in backend.

### Phase 3

Redesign organization/station onboarding data model.

### Phase 4

Add permission matrix by module/action.

### Phase 5

Add employee profile model separate from login user.

### Phase 6

Rebuild dashboards and UI access around the new model.

### Phase 7

Add station setup wizard and onboarding experience in Flutter/desktop.

---

## 17. Recommended Immediate Direction

Before writing code, this document should be reviewed and edited to confirm:

1. exact role names
2. who creates whom
3. `HeadOffice` and `StationAdmin` are merged for single-station organizations and separate for multi-station organizations
4. whether drivers are login users or profile-only
5. whether module permissions are fixed by role or editable by superior users
6. how station setup inheritance should work
7. how shop/rental and cash handover should be modeled

Only after that should we redesign backend permissions and rebuild the desktop/flutter flows.

---

## 18. Plain-English Summary

What you want is not just "better permissions".

You want the system to behave like a real SaaS platform with:

- Razex Solutions at the platform level
- customer companies under it
- one or more stations inside each company
- setup that changes according to each company’s real operations
- modules that appear only if needed
- different dashboards for different kinds of users
- role creation flowing top to bottom
- support for both login users and profile-only staff

That is the correct professional direction.

It is bigger than a simple role tweak, so defining it in MD first is the safest approach.
