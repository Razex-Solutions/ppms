from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.station import Station
from app.models.user import User
from app.schemas.customer import CustomerCreate, CustomerUpdate


def create_customer(db: Session, data: CustomerCreate, current_user: User) -> Customer:
    if current_user.role.name != "Admin" and current_user.station_id != data.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    existing = db.query(Customer).filter(Customer.code == data.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Customer code already exists")
    station = db.query(Station).filter(Station.id == data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")

    customer = Customer(
        name=data.name,
        code=data.code,
        customer_type=data.customer_type,
        phone=data.phone,
        address=data.address,
        credit_limit=data.credit_limit,
        outstanding_balance=0,
        station_id=data.station_id,
    )
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return customer


def update_customer(customer: Customer, data: CustomerUpdate, db: Session) -> Customer:
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(customer, field, value)
    db.commit()
    db.refresh(customer)
    return customer
