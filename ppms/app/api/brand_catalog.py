from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.brand_catalog import BrandCatalog
from app.models.user import User
from app.schemas.brand_catalog import BrandCatalogResponse

router = APIRouter(prefix="/brands", tags=["Brands"])


@router.get("/", response_model=list[BrandCatalogResponse])
def list_brands(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    del current_user
    return (
        db.query(BrandCatalog)
        .filter(BrandCatalog.is_active.is_(True))
        .order_by(BrandCatalog.sort_order.asc(), BrandCatalog.name.asc())
        .all()
    )
