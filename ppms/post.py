import requests

BASE_URL = "http://127.0.0.1:8000"


def print_response(label, response):
    print(f"\n{label}")
    print("Status:", response.status_code)
    print("Response:", response.text)


#-------------------- CORE --------------------

def create_role():
    response = requests.post(f"{BASE_URL}/roles/", json={
        "name": "Owner",
        "description": "Full access"
    })
    print_response("Role", response)


def create_station():
    response = requests.post(f"{BASE_URL}/stations/", json={
        "name": "Main Pump",
        "code": "ST001",
        "address": "Main Road",
        "city": "Lahore"
    })
    print_response("Station", response)


def create_user():
    response = requests.post(f"{BASE_URL}/users/", json={
        "full_name": "Ali Khan",
        "username": "alikhan",
        "email": "ali@example.com",
        "password": "123456",
        "role_id": 1,
        "station_id": 1
    })
    print_response("User", response)


# -------------------- FUEL SETUP --------------------

def create_fuel_type():
    response = requests.post(f"{BASE_URL}/fuel-types/", json={
        "name": "Petrol",
        "description": "Regular petrol"
    })
    print_response("Fuel Type", response)


def create_tank():
    response = requests.post(f"{BASE_URL}/tanks/", json={
        "name": "Tank A",
        "code": "TNK001",
        "capacity": 10000,
        "current_volume": 2000,
        "location": "Underground",
        "station_id": 1,
        "fuel_type_id": 1
    })
    print_response("Tank", response)


# -------------------- DISPENSER --------------------

def create_dispenser():
    response = requests.post(f"{BASE_URL}/dispensers/", json={
        "name": "Dispenser 1",
        "code": "DSP001",
        "location": "Front",
        "station_id": 1
    })
    print_response("Dispenser", response)


def create_nozzle():
    response = requests.post(f"{BASE_URL}/nozzles/", json={
        "name": "Nozzle 1",
        "code": "NZ001",
        "meter_reading": 1000,
        "dispenser_id": 1,
        "tank_id": 1,
        "fuel_type_id": 1
    })
    print_response("Nozzle", response)


# -------------------- CUSTOMER --------------------

def create_customer():
    response = requests.post(f"{BASE_URL}/customers/", json={
        "name": "ABC Transport",
        "code": "CUST001",
        "customer_type": "company",
        "phone": "03001112222",
        "address": "Lahore",
        "credit_limit": 50000,
        "station_id": 1
    })
    print_response("Customer", response)


# -------------------- SALES --------------------

def create_cash_sale():
    response = requests.post(f"{BASE_URL}/fuel-sales/", json={
        "nozzle_id": 1,
        "station_id": 1,
        "fuel_type_id": 1,
        "closing_meter": 1050,
        "rate_per_liter": 275,
        "sale_type": "cash",
        "shift_name": "Morning"
    })
    print_response("Cash Sale", response)


def create_credit_sale():
    response = requests.post(f"{BASE_URL}/fuel-sales/", json={
        "nozzle_id": 1,
        "station_id": 1,
        "fuel_type_id": 1,
        "customer_id": 1,
        "closing_meter": 1100,
        "rate_per_liter": 275,
        "sale_type": "credit",
        "shift_name": "Morning"
    })
    print_response("Credit Sale", response)


# -------------------- SUPPLIER --------------------

def create_supplier():
    response = requests.post(f"{BASE_URL}/suppliers/", json={
        "name": "PSO Supplier",
        "code": "SUP001",
        "phone": "03001112222",
        "address": "Karachi"
    })
    print_response("Supplier", response)


# -------------------- TANKER --------------------

def create_tanker():
    response = requests.post(f"{BASE_URL}/tankers/", json={
        "registration_no": "LEA-1234",
        "name": "Tanker 1",
        "capacity": 12000,
        "owner_name": "ABC Logistics",
        "driver_name": "Usman",
        "driver_phone": "03001234567",
        "status": "active",
        "station_id": 1,
        "fuel_type_id": 1
    })
    print_response("Tanker", response)


# -------------------- PURCHASE --------------------

def create_purchase():
    response = requests.post(f"{BASE_URL}/purchases/", json={
        "supplier_id": 1,
        "tank_id": 1,
        "fuel_type_id": 1,
        "tanker_id": 1,
        "quantity": 2000,
        "rate_per_liter": 260,
        "reference_no": "PO-001",
        "notes": "Delivered via tanker"
    })
    print_response("Purchase", response)
def create_expense():
    response = requests.post(f"{BASE_URL}/expenses/", json={
        "title": "Electricity Bill",
        "category": "Utilities",
        "amount": 15000,
        "notes": "Monthly electricity expense",
        "station_id": 1
    })
    print_response("Expense", response)


def get_profit_summary():
    response = requests.get(f"{BASE_URL}/accounting/profit-summary")
    print_response("Profit Summary", response)


def create_customer_payment():
    response = requests.post(f"{BASE_URL}/customer-payments/", json={
        "customer_id": 1,
        "station_id": 1,
        "amount": 5000,
        "payment_method": "cash",
        "reference_no": "PAY-001",
        "notes": "Partial recovery from customer"
    })
    print_response("Customer Payment", response)
def create_supplier_payment():
    response = requests.post(f"{BASE_URL}/supplier-payments/", json={
        "supplier_id": 1,
        "station_id": 1,
        "amount": 3000,
        "payment_method": "cash",
        "reference_no": "SUP-PAY-001",
        "notes": "Partial payment to supplier"
    })
    print_response("Supplier Payment", response)


def list_supplier_payments():
    response = requests.get(f"{BASE_URL}/supplier-payments/")
    print_response("Supplier Payments List", response)
# -------------------- RUN ALL --------------------

if __name__ == "__main__":
    print("🚀 Running FULL system setup...\n")

    create_role()
    create_station()
    create_user()

    create_fuel_type()
    create_tank()

    create_dispenser()
    create_nozzle()

    create_customer()

    create_cash_sale()
    create_credit_sale()

    create_supplier()
    create_tanker()

    create_purchase()
    create_expense()
    get_profit_summary()
    create_supplier_payment()
    list_supplier_payments()





