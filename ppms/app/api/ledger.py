from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.customer import Customer
from app.models.fuel_sale import FuelSale
from app.models.customer_payment import CustomerPayment

from app.models.supplier import Supplier
from app.models.purchase import Purchase
from app.models.supplier_payment import SupplierPayment

router = APIRouter(prefix="/ledger", tags=["Ledger"])


# ---------------- CUSTOMER LEDGER ----------------

@router.get("/customer/{customer_id}")
def customer_ledger(customer_id: int, db: Session = Depends(get_db)):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    transactions = []

    # Credit sales
    sales = db.query(FuelSale).filter(
        FuelSale.customer_id == customer_id,
        FuelSale.sale_type == "credit",
        FuelSale.is_reversed.is_(False)
    ).all()

    for s in sales:
        transactions.append({
            "date": s.created_at,
            "type": "credit_sale",
            "amount": s.total_amount,
            "description": f"Fuel Sale ID {s.id}"
        })

    # Payments
    payments = db.query(CustomerPayment).filter(
        CustomerPayment.customer_id == customer_id,
        CustomerPayment.is_reversed.is_(False)
    ).all()

    for p in payments:
        transactions.append({
            "date": p.created_at,
            "type": "payment",
            "amount": -p.amount,
            "description": f"Payment ID {p.id}"
        })

    # sort by date
    transactions.sort(key=lambda x: x["date"])

    # running balance
    balance = 0
    for t in transactions:
        balance += t["amount"]
        t["balance"] = balance

    return {
        "customer_id": customer_id,
        "customer_name": customer.name,
        "ledger": transactions,
        "final_balance": balance
    }


# ---------------- SUPPLIER LEDGER ----------------

@router.get("/supplier/{supplier_id}")
def supplier_ledger(supplier_id: int, db: Session = Depends(get_db)):
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")

    transactions = []

    # Purchases
    purchases = db.query(Purchase).filter(
        Purchase.supplier_id == supplier_id,
        Purchase.is_reversed.is_(False)
    ).all()

    for p in purchases:
        transactions.append({
            "date": p.created_at,
            "type": "purchase",
            "amount": p.total_amount,
            "description": f"Purchase ID {p.id}"
        })

    # Payments
    payments = db.query(SupplierPayment).filter(
        SupplierPayment.supplier_id == supplier_id,
        SupplierPayment.is_reversed.is_(False)
    ).all()

    for p in payments:
        transactions.append({
            "date": p.created_at,
            "type": "payment",
            "amount": -p.amount,
            "description": f"Payment ID {p.id}"
        })

    # sort by date
    transactions.sort(key=lambda x: x["date"])

    # running balance
    balance = 0
    for t in transactions:
        balance += t["amount"]
        t["balance"] = balance

    return {
        "supplier_id": supplier_id,
        "supplier_name": supplier.name,
        "ledger": transactions,
        "final_balance": balance
    }
