from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.fuel_type import FuelType
from app.schemas.fuel_type import FuelTypeCreate, FuelTypeUpdate, FuelTypeResponse

router = APIRouter(prefix="/fuel-types", tags=["Fuel Types"])


@router.post("/", response_model=FuelTypeResponse)
def create_fuel_type(fuel_data: FuelTypeCreate, db: Session = Depends(get_db)):
    existing = db.query(FuelType).filter(FuelType.name == fuel_data.name).first()
    if existing:
        raise HTTPException(status_code=400, detail="Fuel type already exists")

    fuel_type = FuelType(
        name=fuel_data.name,
        description=fuel_data.description
    )
    db.add(fuel_type)
    db.commit()
    db.refresh(fuel_type)
    return fuel_type


@router.get("/", response_model=list[FuelTypeResponse])
def list_fuel_types(skip: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=500), db: Session = Depends(get_db)):
    return db.query(FuelType).offset(skip).limit(limit).all()


@router.get("/{fuel_type_id}", response_model=FuelTypeResponse)
def get_fuel_type(fuel_type_id: int, db: Session = Depends(get_db)):
    ft = db.query(FuelType).filter(FuelType.id == fuel_type_id).first()
    if not ft:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    return ft


@router.put("/{fuel_type_id}", response_model=FuelTypeResponse)
def update_fuel_type(fuel_type_id: int, data: FuelTypeUpdate, db: Session = Depends(get_db)):
    ft = db.query(FuelType).filter(FuelType.id == fuel_type_id).first()
    if not ft:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(ft, field, value)
    db.commit()
    db.refresh(ft)
    return ft


@router.delete("/{fuel_type_id}")
def delete_fuel_type(fuel_type_id: int, db: Session = Depends(get_db)):
    ft = db.query(FuelType).filter(FuelType.id == fuel_type_id).first()
    if not ft:
        raise HTTPException(status_code=404, detail="Fuel type not found")
    db.delete(ft)
    db.commit()
    return {"message": "Fuel type deleted"}