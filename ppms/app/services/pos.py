from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.time import utc_now
from app.models.pos_product import POSProduct
from app.models.pos_sale import POSSale
from app.models.pos_sale_item import POSSaleItem
from app.models.station import Station
from app.models.user import User
from app.schemas.pos_product import POSProductCreate, POSProductUpdate
from app.schemas.pos_sale import POSSaleCreate


VALID_POS_MODULES = {"mart", "service_station", "tyre_shop", "other"}


def ensure_pos_station_access(station_id: int, current_user: User) -> None:
    if current_user.role.name != "Admin" and current_user.station_id != station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")


def ensure_pos_sale_access(sale: POSSale, current_user: User) -> None:
    ensure_pos_station_access(sale.station_id, current_user)


def create_pos_product(db: Session, data: POSProductCreate, current_user: User) -> POSProduct:
    ensure_pos_station_access(data.station_id, current_user)
    if data.module not in VALID_POS_MODULES:
        raise HTTPException(status_code=400, detail="Invalid POS module")
    if data.price <= 0:
        raise HTTPException(status_code=400, detail="Price must be greater than 0")
    if data.stock_quantity < 0:
        raise HTTPException(status_code=400, detail="Stock quantity cannot be negative")
    station = db.query(Station).filter(Station.id == data.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    existing = db.query(POSProduct).filter(POSProduct.code == data.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="POS product code already exists")

    product = POSProduct(**data.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


def update_pos_product(db: Session, product: POSProduct, data: POSProductUpdate) -> POSProduct:
    updates = data.model_dump(exclude_unset=True)
    if "module" in updates and updates["module"] not in VALID_POS_MODULES:
        raise HTTPException(status_code=400, detail="Invalid POS module")
    if "price" in updates and updates["price"] <= 0:
        raise HTTPException(status_code=400, detail="Price must be greater than 0")
    if "stock_quantity" in updates and updates["stock_quantity"] < 0:
        raise HTTPException(status_code=400, detail="Stock quantity cannot be negative")
    for field, value in updates.items():
        setattr(product, field, value)
    db.commit()
    db.refresh(product)
    return product


def create_pos_sale(db: Session, data: POSSaleCreate, current_user: User) -> POSSale:
    ensure_pos_station_access(data.station_id, current_user)
    if data.module not in VALID_POS_MODULES:
        raise HTTPException(status_code=400, detail="Invalid POS module")
    if not data.items:
        raise HTTPException(status_code=400, detail="POS sale requires at least one item")

    sale_items: list[tuple[POSProduct, float, float]] = []
    total_amount = 0.0
    for item in data.items:
        if item.quantity <= 0:
            raise HTTPException(status_code=400, detail="Item quantity must be greater than 0")
        product = db.query(POSProduct).filter(POSProduct.id == item.product_id).first()
        if not product:
            raise HTTPException(status_code=404, detail=f"POS product {item.product_id} not found")
        if product.station_id != data.station_id:
            raise HTTPException(status_code=400, detail="POS product does not belong to the selected station")
        if product.module != data.module:
            raise HTTPException(status_code=400, detail="POS product does not belong to the selected POS module")
        if not product.is_active:
            raise HTTPException(status_code=400, detail="Inactive POS product cannot be sold")
        if product.track_inventory and product.stock_quantity < item.quantity:
            raise HTTPException(status_code=400, detail="Insufficient POS product stock")

        line_total = item.quantity * product.price
        sale_items.append((product, item.quantity, line_total))
        total_amount += line_total

    sale = POSSale(
        station_id=data.station_id,
        module=data.module,
        payment_method=data.payment_method,
        customer_name=data.customer_name,
        notes=data.notes,
        total_amount=total_amount,
    )
    db.add(sale)
    db.flush()

    for product, quantity, line_total in sale_items:
        if product.track_inventory:
            product.stock_quantity -= quantity
        db.add(
            POSSaleItem(
                sale_id=sale.id,
                product_id=product.id,
                quantity=quantity,
                unit_price=product.price,
                line_total=line_total,
            )
        )

    db.commit()
    db.refresh(sale)
    sale.items = db.query(POSSaleItem).filter(POSSaleItem.sale_id == sale.id).all()
    return sale


def reverse_pos_sale(db: Session, sale: POSSale, current_user: User) -> POSSale:
    ensure_pos_sale_access(sale, current_user)
    if sale.is_reversed:
        raise HTTPException(status_code=400, detail="POS sale is already reversed")

    items = db.query(POSSaleItem).filter(POSSaleItem.sale_id == sale.id).all()
    for item in items:
        product = db.query(POSProduct).filter(POSProduct.id == item.product_id).first()
        if product and product.track_inventory:
            product.stock_quantity += item.quantity

    sale.is_reversed = True
    sale.reversed_at = utc_now()
    sale.reversed_by = current_user.id
    db.commit()
    db.refresh(sale)
    sale.items = items
    return sale
