from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.access import is_master_admin, require_station_access
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.customer import Customer
from app.models.customer_credit_issue import CustomerCreditIssue
from app.models.customer_payment import CustomerPayment
from app.models.fuel_sale import FuelSale
from app.models.user import User
from app.schemas.customer import CreditOverrideRequest, CustomerCreate, CustomerResponse, CustomerUpdate, ManagerCreditAdjustmentRequest
from app.schemas.customer import ManagerCreditIssueRequest
from app.schemas.customer_credit_issue import CustomerCreditIssueResponse
from app.services.customers import approve_credit_override as approve_credit_override_service
from app.services.customers import create_customer as create_customer_service
from app.services.customers import manager_adjust_credit_limit as manager_adjust_credit_limit_service
from app.services.customers import manager_record_credit_issue as manager_record_credit_issue_service
from app.services.customers import reject_credit_override as reject_credit_override_service
from app.services.customers import request_credit_override as request_credit_override_service
from app.services.customers import update_customer as update_customer_service

router = APIRouter(prefix="/customers", tags=["Customers"])


@router.post("/", response_model=CustomerResponse)
def create_customer(
    customer_data: CustomerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    require_permission(current_user, "customers", "create", detail="You do not have permission to create customers")
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
    if not is_master_admin(current_user):
        station_id = current_user.station_id

    q = db.query(Customer)
    if station_id:
        q = q.filter(Customer.station_id == station_id)
    if customer_type:
        q = q.filter(Customer.customer_type == customer_type)
    if search:
        q = q.filter((Customer.name.ilike(f"%{search}%")) | (Customer.code.ilike(f"%{search}%")))
    return q.offset(skip).limit(limit).all()


@router.get("/credit-issues/", response_model=list[CustomerCreditIssueResponse])
def list_customer_credit_issues(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    customer_id: int | None = Query(None),
    shift_id: int | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not is_master_admin(current_user):
        station_id = current_user.station_id

    q = db.query(CustomerCreditIssue)
    if station_id:
        q = q.filter(CustomerCreditIssue.station_id == station_id)
    if customer_id:
        q = q.filter(CustomerCreditIssue.customer_id == customer_id)
    if shift_id:
        q = q.filter(CustomerCreditIssue.shift_id == shift_id)
    return q.order_by(CustomerCreditIssue.created_at.desc(), CustomerCreditIssue.id.desc()).offset(skip).limit(limit).all()


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
    require_permission(current_user, "customers", "update", detail="You do not have permission to update customers")
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
    require_permission(current_user, "customers", "delete", detail="You do not have permission to delete customers")
    has_sales = db.query(FuelSale).filter(FuelSale.customer_id == customer.id).first()
    has_payments = db.query(CustomerPayment).filter(CustomerPayment.customer_id == customer.id).first()
    if has_sales or has_payments:
        raise HTTPException(status_code=400, detail="Customer cannot be deleted while transaction history exists")
    db.delete(customer)
    db.commit()
    return {"message": "Customer deleted"}


@router.post("/{customer_id}/request-credit-override", response_model=CustomerResponse)
def request_credit_override(
    customer_id: int,
    data: CreditOverrideRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    require_station_access(current_user, customer.station_id, detail="Not authorized for this customer")
    require_permission(current_user, "customers", "request_credit_override", detail="You do not have permission to request credit overrides")
    return request_credit_override_service(customer, data, db, current_user)


@router.post("/{customer_id}/manager-credit-adjustment", response_model=CustomerResponse)
def manager_adjust_credit_limit(
    customer_id: int,
    data: ManagerCreditAdjustmentRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    require_station_access(current_user, customer.station_id, detail="Not authorized for this customer")
    require_permission(current_user, "customers", "update", detail="You do not have permission to adjust customer credit")
    return manager_adjust_credit_limit_service(customer, data, db, current_user)


@router.post("/{customer_id}/manager-credit-issue", response_model=CustomerCreditIssueResponse)
def manager_record_credit_issue(
    customer_id: int,
    data: ManagerCreditIssueRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    require_station_access(current_user, customer.station_id, detail="Not authorized for this customer")
    require_permission(current_user, "customers", "update", detail="You do not have permission to record customer credit")
    return manager_record_credit_issue_service(customer, data, db, current_user)


@router.post("/{customer_id}/approve-credit-override", response_model=CustomerResponse)
def approve_credit_override(
    customer_id: int,
    data: CreditOverrideRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    require_permission(current_user, "customers", "approve_credit_override", detail="You do not have permission to approve credit overrides")
    return approve_credit_override_service(customer, data, db, current_user)


@router.post("/{customer_id}/reject-credit-override", response_model=CustomerResponse)
def reject_credit_override(
    customer_id: int,
    data: CreditOverrideRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    require_permission(current_user, "customers", "reject_credit_override", detail="You do not have permission to reject credit overrides")
    return reject_credit_override_service(customer, data, db, current_user)
