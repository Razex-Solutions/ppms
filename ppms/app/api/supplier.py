from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.supplier import Supplier
from app.models.purchase import Purchase
from app.models.supplier_payment import SupplierPayment
from app.schemas.supplier import SupplierCreate, SupplierUpdate, SupplierResponse

router = APIRouter(prefix="/suppliers", tags=["Suppliers"])


@router.post("/", response_model=SupplierResponse)
def create_supplier(
    data: SupplierCreate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    existing = db.query(Supplier).filter(Supplier.code == data.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Supplier already exists")

    supplier = Supplier(**data.dict())
    db.add(supplier)
    db.commit()
    db.refresh(supplier)
    return supplier


@router.get("/", response_model=list[SupplierResponse])
def list_suppliers(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    station_id: int | None = Query(None),
    search: str | None = Query(None, description="Search by name or code"),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    q = db.query(Supplier)
    if search:
        q = q.filter((Supplier.name.ilike(f"%{search}%")) | (Supplier.code.ilike(f"%{search}%")))
    return q.offset(skip).limit(limit).all()


@router.get("/{supplier_id}", response_model=SupplierResponse)
def get_supplier(
    supplier_id: int, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")

    return supplier


@router.put("/{supplier_id}", response_model=SupplierResponse)
def update_supplier(
    supplier_id: int, 
    data: SupplierUpdate, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(supplier, field, value)
    db.commit()
    db.refresh(supplier)
    return supplier


@router.delete("/{supplier_id}")
def delete_supplier(
    supplier_id: int, 
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")

    has_purchases = db.query(Purchase).filter(Purchase.supplier_id == supplier.id).first()
    has_payments = db.query(SupplierPayment).filter(SupplierPayment.supplier_id == supplier.id).first()
    if has_purchases or has_payments:
        raise HTTPException(status_code=400, detail="Supplier cannot be deleted while transaction history exists")

    db.delete(supplier)
    db.commit()
    return {"message": "Supplier deleted"}
