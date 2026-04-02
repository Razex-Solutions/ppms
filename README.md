# Petrol Pump Management System (PPMS)

A comprehensive backend API for managing petrol pump operations, including sales, inventory, accounting, employee shifts, and organization-aware oversight. Built with FastAPI and SQLAlchemy.

## Overview

The Petrol Pump Management System (PPMS) provides a robust RESTful API to streamline the daily operations of a fuel station. Key features include:
- **Authentication & Authorization**: Role-based access control (`Admin`, `HeadOffice`, `Manager`, `Operator`, `Accountant`) with organization-aware and station-level data isolation.
- **Asset Management**: Tracking stations, tanks, dispensers, and nozzles.
- **Sales Tracking**: Monitoring fuel sales (cash/credit), shift-wise nozzle readings, and daily summaries.
- **Inventory Management**: Handling fuel types, purchases, tanker deliveries, and tank dip readings.
- **POS & Hardware Foundations**: Supporting POS stock/sales workflows plus simulator-friendly hardware device registration and reading ingestion.
- **Financials**: Managing customer/supplier payments, expenses, and ledger entries with profit analysis.
- **Monitoring**: Real-time dashboard for sales, expenses, net profit, low-stock alerts, and credit-limit notifications.
- **Multi-station Governance**: Admins can manage all organizations, `HeadOffice` users can read across their own organization, and station roles remain restricted to their assigned station.
- **Organization Foundation**: Stations belong to organizations, support head-office station designation, and power organization-level dashboards and reports.

## API Endpoints & Features

### Dashboard
- **GET /dashboard/**: Real-time summaries including total sales (cash/credit), expenses, net profit, and total fuel stock.
  - Supports station-level and organization-level views depending on role and filters.
- **Alerts**: Automated alerts for low fuel stock and customers approaching their credit limit.

### Core Modules
- **Authentication**: JWT-based login, role management (Admin, Manager, Operator, Accountant), and station assignment.
  - Password management includes self-service password change and admin password reset endpoints.
- **Shift Management**: Tracking employee shifts, including initial cash, sales, and end-of-shift cash reconciliation with difference detection.
- **Sales**: Management of fuel sales (cash/credit), automatic meter reading updates, and nozzle history.
- **Inventory & Assets**: 
  - Full CRUD for organizations, stations, tanks, dispensers, and nozzles.
  - Tracking fuel types and real-time stock levels.
  - **Tanker Management**: Managing fuel deliveries and associated tanker information.
- **Operations**:
  - **Nozzle Readings**: Shift-wise tracking of start and end meter readings.
  - **Tank Dips**: Manual stick readings (mm) with automated volume calculation and loss/gain (evaporation/leakage) analysis.
  - **Hardware Module**: Registry and event logging for dispenser and tank-probe devices, including safe simulator endpoints for backend testing.
- **Accounting & Financials**:
  - **Ledgers**: Detailed customer and supplier ledgers with running balances.
  - **Payments**: Processing customer payments (receivables) and supplier payments (payables).
  - **Expenses**: Tracking station-wise operational expenses with approval workflow support.
  - **Profit Analysis**: Real-time calculation of net profit based on sales and expenses.
  - **Reports**: Daily closing, shift variance, stock movement, customer balances, and supplier balances with organization-aware filters.

## Requirements

- Python 3.10+
- SQLite (default) or any SQLAlchemy-supported database.
- Dependencies listed in `requirements.txt`.

## Project Structure

```text
.
├── ppms/
│   ├── app/
│   │   ├── api/          # API Route handlers (Auth, Dashboard, Inventory, Accounting, etc.)
│   │   ├── core/         # Database engine, Security (JWT/Hashing), and Config
│   │   ├── models/       # SQLAlchemy models defining the schema
│   │   ├── schemas/      # Pydantic models for data validation and API documentation
│   │   ├── services/     # Business logic layer (currently minimal)
│   │   └── main.py       # FastAPI application entry point
│   ├── seed.py           # Initial data seeding script
│   └── requirements.txt  # (Empty, use root requirements.txt)
├── Docs/                 # Project documentation (PDF/DOCX)
├── main.py               # (Empty/TBD)
├── requirements.txt      # Project dependencies
└── ppms.db               # SQLite database (generated)
```

## Setup and Installation

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd <repository-name>
    ```

2.  **Create and activate a virtual environment**:
    ```bash
    python -m venv venv
    .\venv\Scripts\activate  # Windows
    # source venv/bin/activate  # Linux/Mac
    ```

3.  **Install dependencies**:
    ```bash
    pip install -r requirements.txt
    ```

4.  **Run database migrations**:
    ```bash
    venv\Scripts\python.exe -m alembic upgrade head
    ```

5.  **Initialize seed data**:
    Run the seeding script to create the initial roles, default organization, head-office station, and admin user.
    ```bash
    cd ppms
    python seed.py
    ```
- Default Admin Username: `admin`
- Default Admin Password: `admin123`

## Running the Application

To start the FastAPI server, use `uvicorn`:

```bash
cd ppms
uvicorn app.main:app --reload --port 8000
```

The API will be available at `http://127.0.0.1:8000`.
- **Interactive Documentation (Swagger UI)**: `http://127.0.0.1:8000/docs`
- **Alternative Documentation (Redoc)**: `http://127.0.0.1:8000/redoc`

## Scripts

-   **`ppms/seed.py`**: Initializes the database with default roles, a head office station, and a system administrator account.
-   **`ppms/post.py`**: A comprehensive testing and demonstration script for creating all system entities (stations, users, fuel sales, tankers, etc.) and checking the profit summary.
-   **`read_docx.py`**: Helper script to read project documentation from `.docx` files.
-   **`main.py`**: Entry point for running the application if not using `uvicorn` directly (Note: current root `main.py` is placeholder).

## Configuration & Environment Variables

The application uses `ppms/app/core/config.py` for configuration.
- **DATABASE_URL**: The database connection string.
  - Default: `sqlite:///./ppms.db`
  - To use a different database, set the environment variable before running Alembic or the app.
- **SECRET_KEY**: JWT signing secret for authentication tokens.
- **ACCESS_TOKEN_EXPIRE_MINUTES**: Token lifetime in minutes.
- **ENABLED_MODULES**: Comma-separated module list to enable selected backend areas for testing.
  - Default: `*`
  - Example: `ENABLED_MODULES=auth,customers,expenses,hardware`
- **APP_ENV**: Runtime environment label used in health output and structured logs.
- **LOG_LEVEL**: Logging verbosity for structured app logs.

## Modular Testing

The backend now supports module-based startup for focused testing. The `/health` and `/` endpoints report the active module set.

Example:

```bash
set ENABLED_MODULES=auth,customers,expenses,hardware
uvicorn app.main:app --reload --port 8000
```

## Tests

Use automated tests instead of hardcoded localhost verification scripts. The project now includes the dependencies needed for in-process API testing with FastAPI's test client.

```bash
venv\Scripts\python.exe -m pytest tests
```

## Organization-Aware Access

- `Admin` can read and manage all organizations, stations, users, and reports.
- `HeadOffice` is a read-focused organization role. It can view stations, users, dashboards, and reports within its own organization.
- `Manager`, `Operator`, and `Accountant` remain station-scoped for operational safety.
- Report endpoints support `station_id` and `organization_id` filters, but non-admin users are automatically constrained to their allowed scope.

## Expense Approval Workflow

- Station finance users create expenses in `pending` status.
- `Admin` can create auto-approved expenses.
- `HeadOffice` and `Admin` can approve or reject submitted expenses.
- Only approved expenses are included in dashboard and financial report totals.
- Endpoints:
  - `POST /expenses/`
  - `POST /expenses/{expense_id}/approve`
  - `POST /expenses/{expense_id}/reject`

## Reversal Approval Workflow

- Station roles can request reversals for fuel sales, purchases, customer payments, and supplier payments.
- `HeadOffice` and `Admin` approve or reject those reversal requests.
- Actual stock and balance rollback only happens after approval.
- Endpoints:
  - `POST /fuel-sales/{id}/reverse`
  - `POST /fuel-sales/{id}/approve-reversal`
  - `POST /fuel-sales/{id}/reject-reversal`
  - `POST /purchases/{id}/reverse`
  - `POST /purchases/{id}/approve-reversal`
  - `POST /purchases/{id}/reject-reversal`
  - `POST /customer-payments/{id}/reverse`
  - `POST /customer-payments/{id}/approve-reversal`
  - `POST /customer-payments/{id}/reject-reversal`
  - `POST /supplier-payments/{id}/reverse`
  - `POST /supplier-payments/{id}/approve-reversal`
  - `POST /supplier-payments/{id}/reject-reversal`

## Purchase Approval Workflow

- Station roles create purchases in `pending` status.
- `HeadOffice` and `Admin` approve or reject those purchases.
- Only approved purchases affect tank stock, supplier payables, dashboard totals, and reporting.
- Endpoints:
  - `POST /purchases/`
  - `POST /purchases/{id}/approve`
  - `POST /purchases/{id}/reject`

## Customer Credit Override Workflow

- Station finance roles can request a temporary credit override for a customer.
- `HeadOffice` and `Admin` can approve or reject the override.
- Approved override headroom is consumed by over-limit credit sales.
- Endpoints:
  - `POST /customers/{id}/request-credit-override`
  - `POST /customers/{id}/approve-credit-override`
  - `POST /customers/{id}/reject-credit-override`

## Auth Password Management

- `POST /auth/change-password`: authenticated user changes their own password by supplying the current password.
- `POST /auth/admin-reset-password/{user_id}`: admin resets another user's password.

## Database Migrations

Schema changes are now managed with Alembic instead of automatic table creation at app startup.

```bash
venv\Scripts\python.exe -m alembic upgrade head
venv\Scripts\python.exe -m alembic current
```

## Logging And Error Handling

- Requests now emit structured JSON logs with method, path, status, duration, and `request_id`.
- Responses include `X-Request-ID` to help trace failures.
- Validation errors, HTTP exceptions, and unexpected server errors are handled centrally.

## License

TODO: Specify the license for this project.
