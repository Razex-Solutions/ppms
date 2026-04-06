from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin, require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.customer import Customer
from app.models.customer_payment import CustomerPayment
from app.models.fuel_sale import FuelSale
from app.models.purchase import Purchase
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.supplier_payment import SupplierPayment
from app.models.tank import Tank
from app.models.user import User
from app.schemas.ledger import LedgerEntryResponse, LedgerResponse, LedgerSummaryResponse

router = APIRouter(prefix="/ledger", tags=["Ledger"])


def _serialize_summary(
    *,
    party_id: int,
    party_type: str,
    party_name: str,
    party_code: str | None,
    station_id: int | None,
    station_name: str | None,
    total_charges: float,
    total_payments: float,
    current_balance: float,
    transaction_count: int,
    last_activity_at,
) -> dict[str, object]:
    return {
        "party_id": party_id,
        "party_type": party_type,
        "party_name": party_name,
        "party_code": party_code,
        "station_id": station_id,
        "station_name": station_name,
        "total_charges": round(total_charges, 2),
        "total_payments": round(total_payments, 2),
        "current_balance": round(current_balance, 2),
        "transaction_count": transaction_count,
        "last_activity_at": last_activity_at,
    }


def _ensure_customer_access(db: Session, *, customer: Customer, current_user: User) -> Station | None:
    station = db.query(Station).filter(Station.id == customer.station_id).first()
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        return station
    if is_head_office_user(current_user):
        if station and station.organization_id == get_user_organization_id(current_user):
            return station
        raise HTTPException(status_code=403, detail="Not authorized for this customer")
    require_station_access(current_user, customer.station_id, detail="Not authorized for this customer")
    return station


def _build_customer_entries(db: Session, customer: Customer) -> list[dict[str, object]]:
    transactions: list[dict[str, object]] = []

    sales = (
        db.query(FuelSale)
        .filter(
            FuelSale.customer_id == customer.id,
            FuelSale.sale_type == "credit",
            FuelSale.is_reversed.is_(False),
        )
        .all()
    )
    for sale in sales:
        transactions.append(
            {
                "date": sale.created_at,
                "type": "credit_sale",
                "amount": round(sale.total_amount, 2),
                "description": f"Fuel sale #{sale.id}",
                "reference": sale.shift_name,
            }
        )

    payments = (
        db.query(CustomerPayment)
        .filter(
            CustomerPayment.customer_id == customer.id,
            CustomerPayment.is_reversed.is_(False),
        )
        .all()
    )
    for payment in payments:
        transactions.append(
            {
                "date": payment.created_at,
                "type": "payment",
                "amount": round(-payment.amount, 2),
                "description": f"Customer payment #{payment.id}",
                "reference": payment.reference_no,
            }
        )

    transactions.sort(key=lambda item: item["date"])
    running_balance = 0.0
    for transaction in transactions:
        running_balance = round(running_balance + float(transaction["amount"]), 2)
        transaction["balance"] = running_balance
    return transactions


def _resolve_supplier_station_scope(
    db: Session,
    *,
    station_id: int | None,
    current_user: User,
) -> Station | None:
    if current_user.role.name == "Admin" or is_master_admin(current_user):
        if station_id is None:
            return None
        station = db.query(Station).filter(Station.id == station_id).first()
        if not station:
            raise HTTPException(status_code=404, detail="Station not found")
        return station

    if is_head_office_user(current_user):
        if station_id is None:
            return None
        station = db.query(Station).filter(Station.id == station_id).first()
        if not station:
            raise HTTPException(status_code=404, detail="Station not found")
        if station.organization_id != get_user_organization_id(current_user):
            raise HTTPException(status_code=403, detail="Not authorized for this station")
        return station

    if current_user.station_id is None:
        raise HTTPException(status_code=403, detail="Station access required")
    require_station_access(current_user, current_user.station_id)
    station = db.query(Station).filter(Station.id == current_user.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    return station


def _build_supplier_entries(
    db: Session,
    *,
    supplier_id: int,
    station: Station | None,
    current_user: User,
) -> tuple[list[dict[str, object]], int | None, str | None]:
    transactions: list[dict[str, object]] = []

    purchase_query = db.query(Purchase).filter(
        Purchase.supplier_id == supplier_id,
        Purchase.status == "approved",
        Purchase.is_reversed.is_(False),
    )
    payment_query = db.query(SupplierPayment).filter(
        SupplierPayment.supplier_id == supplier_id,
        SupplierPayment.is_reversed.is_(False),
    )

    if station is not None:
        purchase_query = purchase_query.join(Tank, Tank.id == Purchase.tank_id).filter(Tank.station_id == station.id)
        payment_query = payment_query.filter(SupplierPayment.station_id == station.id)
    elif is_head_office_user(current_user):
        organization_id = get_user_organization_id(current_user)
        purchase_query = (
            purchase_query.join(Tank, Tank.id == Purchase.tank_id)
            .join(Station, Station.id == Tank.station_id)
            .filter(Station.organization_id == organization_id)
        )
        payment_query = payment_query.join(Station, Station.id == SupplierPayment.station_id).filter(Station.organization_id == organization_id)
    elif current_user.role.name not in {"Admin", "MasterAdmin"} and not is_master_admin(current_user):
        purchase_query = purchase_query.join(Tank, Tank.id == Purchase.tank_id).filter(Tank.station_id == current_user.station_id)
        payment_query = payment_query.filter(SupplierPayment.station_id == current_user.station_id)

    purchases = purchase_query.all()
    for purchase in purchases:
        transactions.append(
            {
                "date": purchase.created_at,
                "type": "purchase",
                "amount": round(purchase.total_amount, 2),
                "description": f"Purchase #{purchase.id}",
                "reference": purchase.reference_no,
            }
        )

    payments = payment_query.all()
    for payment in payments:
        transactions.append(
            {
                "date": payment.created_at,
                "type": "payment",
                "amount": round(-payment.amount, 2),
                "description": f"Supplier payment #{payment.id}",
                "reference": payment.reference_no,
            }
        )

    transactions.sort(key=lambda item: item["date"])
    running_balance = 0.0
    for transaction in transactions:
        running_balance = round(running_balance + float(transaction["amount"]), 2)
        transaction["balance"] = running_balance

    return transactions, station.id if station else None, station.name if station else None


@router.get("/customer/{customer_id}/summary", response_model=LedgerSummaryResponse)
def customer_ledger_summary(
    customer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "ledger", "read", detail="You do not have permission to view ledgers")
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    station = _ensure_customer_access(db, customer=customer, current_user=current_user)

    entries = _build_customer_entries(db, customer)
    total_charges = sum(float(entry["amount"]) for entry in entries if float(entry["amount"]) > 0)
    total_payments = sum(abs(float(entry["amount"])) for entry in entries if float(entry["amount"]) < 0)
    last_activity_at = entries[-1]["date"] if entries else None
    return _serialize_summary(
        party_id=customer.id,
        party_type="customer",
        party_name=customer.name,
        party_code=customer.code,
        station_id=customer.station_id,
        station_name=station.name if station else None,
        total_charges=total_charges,
        total_payments=total_payments,
        current_balance=customer.outstanding_balance or 0.0,
        transaction_count=len(entries),
        last_activity_at=last_activity_at,
    )


@router.get("/customer/{customer_id}", response_model=LedgerResponse)
def customer_ledger(
    customer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "ledger", "read", detail="You do not have permission to view ledgers")
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    station = _ensure_customer_access(db, customer=customer, current_user=current_user)

    entries = _build_customer_entries(db, customer)
    total_charges = sum(float(entry["amount"]) for entry in entries if float(entry["amount"]) > 0)
    total_payments = sum(abs(float(entry["amount"])) for entry in entries if float(entry["amount"]) < 0)
    last_activity_at = entries[-1]["date"] if entries else None
    summary = _serialize_summary(
        party_id=customer.id,
        party_type="customer",
        party_name=customer.name,
        party_code=customer.code,
        station_id=customer.station_id,
        station_name=station.name if station else None,
        total_charges=total_charges,
        total_payments=total_payments,
        current_balance=customer.outstanding_balance or 0.0,
        transaction_count=len(entries),
        last_activity_at=last_activity_at,
    )
    return {
        "party_id": customer.id,
        "party_type": "customer",
        "party_name": customer.name,
        "party_code": customer.code,
        "station_id": customer.station_id,
        "station_name": station.name if station else None,
        "summary": summary,
        "ledger": entries,
    }


@router.get("/supplier/{supplier_id}/summary", response_model=LedgerSummaryResponse)
def supplier_ledger_summary(
    supplier_id: int,
    station_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "ledger", "read", detail="You do not have permission to view ledgers")
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")

    station = _resolve_supplier_station_scope(db, station_id=station_id, current_user=current_user)
    entries, resolved_station_id, resolved_station_name = _build_supplier_entries(
        db,
        supplier_id=supplier.id,
        station=station,
        current_user=current_user,
    )
    total_charges = sum(float(entry["amount"]) for entry in entries if float(entry["amount"]) > 0)
    total_payments = sum(abs(float(entry["amount"])) for entry in entries if float(entry["amount"]) < 0)
    last_activity_at = entries[-1]["date"] if entries else None
    current_balance = entries[-1]["balance"] if entries else 0.0
    if resolved_station_id is None and (current_user.role.name == "Admin" or is_master_admin(current_user)):
        current_balance = supplier.payable_balance or 0.0
    return _serialize_summary(
        party_id=supplier.id,
        party_type="supplier",
        party_name=supplier.name,
        party_code=supplier.code,
        station_id=resolved_station_id,
        station_name=resolved_station_name,
        total_charges=total_charges,
        total_payments=total_payments,
        current_balance=current_balance,
        transaction_count=len(entries),
        last_activity_at=last_activity_at,
    )


@router.get("/supplier/{supplier_id}", response_model=LedgerResponse)
def supplier_ledger(
    supplier_id: int,
    station_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "ledger", "read", detail="You do not have permission to view ledgers")
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")

    station = _resolve_supplier_station_scope(db, station_id=station_id, current_user=current_user)
    entries, resolved_station_id, resolved_station_name = _build_supplier_entries(
        db,
        supplier_id=supplier.id,
        station=station,
        current_user=current_user,
    )
    total_charges = sum(float(entry["amount"]) for entry in entries if float(entry["amount"]) > 0)
    total_payments = sum(abs(float(entry["amount"])) for entry in entries if float(entry["amount"]) < 0)
    last_activity_at = entries[-1]["date"] if entries else None
    current_balance = entries[-1]["balance"] if entries else 0.0
    if resolved_station_id is None and (current_user.role.name == "Admin" or is_master_admin(current_user)):
        current_balance = supplier.payable_balance or 0.0
    summary = _serialize_summary(
        party_id=supplier.id,
        party_type="supplier",
        party_name=supplier.name,
        party_code=supplier.code,
        station_id=resolved_station_id,
        station_name=resolved_station_name,
        total_charges=total_charges,
        total_payments=total_payments,
        current_balance=current_balance,
        transaction_count=len(entries),
        last_activity_at=last_activity_at,
    )
    return {
        "party_id": supplier.id,
        "party_type": "supplier",
        "party_name": supplier.name,
        "party_code": supplier.code,
        "station_id": resolved_station_id,
        "station_name": resolved_station_name,
        "summary": summary,
        "ledger": entries,
    }
