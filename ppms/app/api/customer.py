from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.customer import Customer
from app.models.customer_payment import CustomerPayment
from app.models.fuel_sale import FuelSale
from app.models.user import User
from app.schemas.customer import CustomerCreate, CustomerUpdate, CustomerResponse
from app.services.customers import create_customer as create_customer_service
from app.services.customers import update_customer as update_customer_service

router = APIRouter(prefix="/customers", tags=["Customers"])


@router.post("/", response_model=CustomerResponse)
def create_customer(
    customer_data: CustomerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return create_customer_service(db, customer_data, current_user)


@router.get("/", response_model=list[CustomerResponse])
def list_customers(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    customer_type: str | None = Query(None),
    search: str | None = Query(None, description="Search by name or code"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role.name != "Admin":
        station_id = current_user.station_id

    q = db.query(Customer)
    if station_id:
        q = q.filter(Customer.station_id == station_id)
    if customer_type:
        q = q.filter(Customer.customer_type == customer_type)
    if search:
        q = q.filter((Customer.name.ilike(f"%{search}%")) | (Customer.code.ilike(f"%{search}%")))
    return q.offset(skip).limit(limit).all()


@router.get("/{customer_id}", response_model=CustomerResponse)
def get_customer(
    customer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    require_station_access(current_user, customer.station_id, detail="Not authorized for this customer")
    return customer


@router.put("/{customer_id}", response_model=CustomerResponse)
def update_customer(
    customer_id: int,
    data: CustomerUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    require_station_access(current_user, customer.station_id, detail="Not authorized for this customer")
    return update_customer_service(customer, data, db)


@router.delete("/{customer_id}")
def delete_customer(
    customer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    require_station_access(current_user, customer.station_id, detail="Not authorized for this customer")
    has_sales = db.query(FuelSale).filter(FuelSale.customer_id == customer.id).first()
    has_payments = db.query(CustomerPayment).filter(CustomerPayment.customer_id == customer.id).first()
    if has_sales or has_payments:
        raise HTTPException(status_code=400, detail="Customer cannot be deleted while transaction history exists")
    db.delete(customer)
    db.commit()
    return {"message": "Customer deleted"}
