# PPMS Role Hierarchy And Access Model

## Purpose

This document defines how roles should work in the Petrol Pump Management System before deeper permission changes are implemented in code.

The goal is to make role behavior clear for:

- organization-level control
- station-level operations
- employee/staff profiles
- login vs non-login users
- who can create which roles
- who can see and update which modules

This is a business and access-control specification first. It is intended to be edited before final implementation.

---

## Core Principles

### 1. Role hierarchy should be intentional

Not every role should be able to create every other role.

Example:

- `MasterAdmin` creates the first tenant `HeadOffice`
- `HeadOffice` creates `StationAdmin` only when the organization has more than one station
- `HeadOffice` creates `Manager`, `Accountant`, and `Operator` directly for single-station organizations
- `StationAdmin` creates station-level `Manager`, `Accountant`, and `Operator` for multi-station organizations
- lower roles should not create higher roles

### 2. Scope matters as much as role name

A role is not only "what someone is called", but also:

- what area they control
- what records they can see
- what they can change
- which stations or organizations they belong to

### 3. Some people are staff profiles, not system logins

Not every person in the company needs a username/password.

Examples:

- tanker drivers
- pump attendants
- helpers
- mechanics
- cleaners

These may exist as employee profiles for:

- payroll
- attendance
- assignment
- reporting

without having system login access.

### 4. View, create, update, approve, and delete are different permissions

The system should not treat all access as one single permission.

For each role, we should think separately about:

- view
- create
- update
- approve
- reverse
- delete
- export

### 5. Organization scope and station scope must stay separate

- `HeadOffice` is organization-wide
- station roles are limited to their own station unless explicitly expanded

---

## Role Categories

There should be two big categories of people in the system:

### A. System Login Roles

These roles can sign in to the application.

Examples:

- HeadOffice
- StationAdmin
- Manager
- Accountant
- Operator
- optional limited Driver login

### B. Staff Profile Roles

These roles may exist only as employee records and may not sign in.

Examples:

- Tanker Driver
- Pump Attendant
- Loader/Helper
- Mechanic
- Cleaner
- Security Guard

These profiles may be used in:

- payroll
- attendance
- staff assignment
- trip assignment
- expense reimbursement

---

## Recommended High-Level Hierarchy

### Level 0: Platform Control

- `MasterAdmin`

### Level 1: Organization Control

- `HeadOffice`

`HeadOffice` is the current code name for the customer organization's main admin/owner role.

### Level 2: Station Control

- `StationAdmin`

`StationAdmin` exists only when station-level delegation is useful, normally for multi-station organizations.

### Level 3: Station Management

- `Manager`
- `Accountant`

### Level 4: Station Operations

- `Operator`
- optional `DriverLogin`

### Level 5: Profile-Only Staff

- `TankerDriverProfile`
- `PumpAttendantProfile`
- other employee profiles

---

## Recommended Roles

## 1. HeadOffice

### Purpose

Organization-wide oversight and control.

### Scope

- all stations inside the same organization

### Login

- yes

### Created By

- system bootstrap or super admin setup

### Can Create

- StationAdmin for multi-station organizations
- Manager, Accountant, and Operator directly for single-station organizations
- organization-level staff if needed
- organizations, depending on final SaaS policy

### Can View

- all stations in the organization
- all users in the organization
- organization-wide dashboard
- organization-wide reports
- approvals
- audit logs
- station performance
- tanker performance
- payroll summaries

### Can Update

- organization settings
- station setup
- organization modules
- approvals
- selected financial controls

### Should Not Normally Do

- daily forecourt sales
- routine pump operations

### Notes

This role is for ownership, directors, or central office supervisors.

---

## 2. StationAdmin

### Purpose

Primary station-level administrative controller for multi-station organizations.

### Scope

- assigned station

### Login

- yes

### Created By

- HeadOffice

### Can Create

- Manager
- Accountant
- Operator
- employee/staff profiles

### Can View

- full station operational data
- station inventory
- parties
- finance activity
- payroll
- attendance
- hardware status for the station

### Can Update

- station users
- station modules
- inventory setup
- nozzles, dispensers, tanks
- customers, suppliers
- expense and purchase operational data where policy allows
- invoice/profile settings

### Cannot Create

- HeadOffice

### Notes

For a single-station organization, do not create a separate station-admin layer unless the customer explicitly needs it. In that case, `HeadOffice` should behave as the merged organization and station admin.

The old generic `Admin` role has been removed from active seed data and should not be the target business role for new organizations.

---

## 3. Manager

### Purpose

Daily operational leadership for the station.

### Scope

- assigned station

### Login

- yes

### Created By

- HeadOffice for single-station organizations
- StationAdmin for multi-station organizations

### Can Create

- selected staff profiles
- maybe operators if policy allows

### Can View

- sales
- shifts
- inventory status
- expenses
- purchases
- customer and supplier lists
- attendance
- some reports

### Can Update

- shifts
- certain expenses
- certain purchases
- some operational master data if allowed
- attendance corrections if policy allows

### Can Approve

- limited operational approvals if business wants this

### Cannot Create

- HeadOffice
- StationAdmin

### Notes

Manager should run daily operations but should not automatically have all finance and organization control.

---

## 4. Accountant

### Purpose

Finance-focused station user.

### Scope

- assigned station
- possibly organization finance view later if explicitly allowed

### Login

- yes

### Created By

- HeadOffice for single-station organizations
- StationAdmin for multi-station organizations

### Can View

- ledgers
- payments
- receivables
- payables
- reports
- customer balances
- supplier balances
- payroll data if permitted

### Can Update

- customer payments
- supplier payments
- some finance documents
- ledger-facing workflows

### Can Approve

- some finance workflows if business wants

### Should Not Control

- station configuration
- inventory structure
- high-level user management

---

## 5. Operator

### Purpose

Daily station operator for forecourt work.

### Scope

- assigned station

### Login

- yes

### Created By

- HeadOffice for single-station organizations
- StationAdmin for multi-station organizations
- optionally Manager if allowed

### Can View

- assigned operational screens
- own station operational data
- own shifts and related work

### Can Update

- fuel sales
- shifts
- attendance
- maybe basic expense submission
- maybe basic POS sales

### Cannot Control

- station setup
- role management
- finance administration
- organization-wide data

---

## 6. Tanker Driver

### Purpose

Tanker trip and delivery execution.

### Scope

- assigned tanker/trip/station context

### Login

Two possible models:

#### Option A: Profile-only

- no login
- only employee profile exists
- used for payroll, attendance, assignments, trip records

#### Option B: Limited login

- login allowed
- highly restricted screens only

### Created By

- HeadOffice for single-station organizations
- StationAdmin for multi-station organizations
- Manager

### Can View if Login Exists

- own trip assignments
- own attendance
- own delivery tasks
- limited delivery summaries

### Can Update if Login Exists

- trip progress
- delivery confirmation
- expense submission for trip

### Cannot Access

- full finance
- station setup
- broader admin areas
- organization-wide reports

### Recommended Direction

For now, treat tanker drivers as **profile-first**, not full system users by default.

If login is needed later, create a separate limited role such as:

- `DriverLogin`

instead of giving all driver profiles normal system accounts.

---

## 7. Employee Profile Roles

These roles may exist as staff types rather than app-login roles.

Examples:

- Tanker Driver
- Pump Attendant
- Cleaner
- Security
- Loader
- Mechanic

### Purpose

Used in:

- payroll
- attendance
- HR/staff records
- scheduling
- trip assignment

### Login

- no by default

### Notes

This separation is important because payroll and attendance often need many employees who do not need software access.

---

## Role Creation Hierarchy

Recommended default creation chain:

- `MasterAdmin` creates the organization and first `HeadOffice`
- if the organization has one station, `HeadOffice` creates `Manager`, `Accountant`, `Operator`, and staff profiles
- if the organization has more than one station, `HeadOffice` creates `StationAdmin`
- `StationAdmin` creates `Manager`, `Accountant`, `Operator`, and station staff profiles
- `Manager` may create selected profile-only staff if policy allows
- `StationAdmin` or `Manager` creates `DriverLogin` only if the business wants real driver login access

This means:

- lower roles should not create higher roles
- peer roles should not create peer roles unless explicitly allowed

---

## Login vs Profile Matrix

| Role | Login Allowed | Notes |
|---|---|---|
| HeadOffice | Yes | Organization-wide control |
| StationAdmin | Yes | Station admin control, mainly for multi-station organizations |
| Manager | Yes | Daily station leadership |
| Accountant | Yes | Finance-focused |
| Operator | Yes | Forecourt/daily ops |
| DriverLogin | Optional | Limited workflow access only |
| TankerDriverProfile | No by default | Payroll/attendance/assignment only |
| PumpAttendantProfile | No by default | Payroll/attendance only |

---

## Suggested Access By Module

## Dashboard

- HeadOffice: organization-wide
- StationAdmin: station-wide
- Manager: station-wide operational
- Accountant: finance-oriented station dashboard
- Operator: limited station view
- Driver: own relevant view only if login exists

## Sales

- Operator: yes
- Manager: yes
- StationAdmin: yes
- Accountant: view mostly, optionally create depending on policy
- HeadOffice: view only

## Shifts

- Operator: yes
- Manager: yes
- StationAdmin: yes
- HeadOffice: view only

## Finance

- Accountant: yes
- StationAdmin: yes
- Manager: partial depending on business
- Operator: limited or no
- HeadOffice: organization oversight

## Reports

- HeadOffice: organization reports
- StationAdmin: station reports
- Manager: operational station reports
- Accountant: finance reports
- Operator: limited reports only

## Governance / Approvals

- HeadOffice: yes
- StationAdmin: station-level governance where delegated
- Manager: partial depending on workflow
- Accountant: partial depending on workflow
- Operator: no

## Inventory / Setup

- StationAdmin: yes
- Manager: partial
- Operator: mostly no
- Accountant: mostly no
- HeadOffice: oversight or exceptional update

## Tanker Operations

- HeadOffice: oversight
- StationAdmin: full station tanker management
- Manager: operational control
- DriverLogin: only assigned trip actions
- TankerDriverProfile: no login access

## Payroll / Attendance

- StationAdmin: yes
- Manager: yes
- Accountant: payroll view or partial control
- Operator: self attendance only
- DriverLogin: self attendance and assigned trip-related workflows only

---

## Suggested Permission Model

Each role should eventually be expressed through actions, not only role names.

Examples:

- `users.create.admin`
- `users.create.manager`
- `users.view.station`
- `sales.create`
- `sales.reverse.request`
- `sales.reverse.approve`
- `purchases.approve`
- `expenses.approve`
- `attendance.self`
- `attendance.manage.station`
- `tankers.trip.update.assigned`
- `reports.view.organization`
- `reports.view.station`

This gives us cleaner long-term control than only checking role strings.

---

## Suggested Staff/User Model Separation

The system should eventually distinguish between:

### System User

Has:

- login credentials
- role
- access permissions

### Employee Profile

Has:

- name
- phone
- CNIC/NIC/passport if needed
- salary info
- attendance info
- department or staff type
- station assignment
- optional linked user account

This allows:

- an employee with no login
- or an employee with a linked user login later

This is especially useful for:

- tanker drivers
- attendants
- helpers

---

## Recommended Real-World Approach

### Phase 1

Keep these login roles:

- HeadOffice
- StationAdmin
- Manager
- Accountant
- Operator

Treat drivers and other field staff as employee profiles only.

### Phase 2

If needed, add limited-login roles:

- DriverLogin
- Supervisor
- PayrollOfficer

### Phase 3

Introduce more configurable policy rules and custom permission bundles.

---

## Important Business Questions To Finalize

Before implementation, these decisions should be confirmed:

1. Confirm the old generic `Admin` role remains removed from active seed data and UI flows.
2. Can `Manager` create `Operator`, or only `HeadOffice`/`StationAdmin`?
3. Should `Accountant` approve anything, or only process records?
4. Are tanker drivers login users or profile-only employees?
5. Should attendance require a login, or can profiles be marked by managers/admins?
6. Which roles can view payroll details?
7. Which roles can see customer/supplier balances?
8. Which roles can reverse transactions?
9. Which roles can approve reversals?
10. Which roles can change meter readings?

---

## Recommended Immediate Direction

For the next implementation phase, the safest business model is:

- `MasterAdmin` creates the first `HeadOffice`
- `HeadOffice` creates `StationAdmin` only for multi-station organizations
- single-station `HeadOffice` creates `Manager`, `Accountant`, and `Operator` directly
- multi-station `StationAdmin` creates station-level `Manager`, `Accountant`, and `Operator`
- tanker drivers remain profile-only by default
- employee profiles become separate from login users
- access is restricted by both role and scope

This is the cleanest path for a professional, real-world PPMS.

---

## Status

This file is a draft working specification and should be edited freely before final permission and UI changes are implemented.
