from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user, is_master_admin
from app.core.time import utc_now
from app.models.fuel_type import FuelType
from app.models.purchase import Purchase
from app.models.supplier import Supplier
from app.models.tank import Tank
from app.models.tanker import Tanker
from app.models.user import User
from app.schemas.purchase import ManagerReceivingCreate, PurchaseCreate
from app.services.audit import log_audit_event
from app.services.notifications import notify_approval_requested, notify_decision


def ensure_purchase_access(purchase: Purchase, current_user: User) -> None:
    if is_master_admin(current_user):
        return
    station_id = purchase.tank.station_id
    if is_head_office_user(current_user):
        if purchase.tank.station.organization_id == get_user_organization_id(current_user):
            return
        raise HTTPException(status_code=403, detail="Not authorized for this purchase")
    if current_user.station_id != station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this purchase")


def _validate_purchase_inputs(db: Session, data: PurchaseCreate, current_user: User) -> tuple[Tank, Supplier, FuelType, Tanker | None, float]:
    tank = db.query(Tank).filter(Tank.id == data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")
    if not is_master_admin(current_user) and current_user.station_id != tank.station_id:
        raise HTTPException(status_code=403, detail="Not authorized for this tank")

    supplier = db.query(Supplier).filter(Supplier.id == data.supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")

    fuel_type = db.query(FuelType).filter(FuelType.id == data.fuel_type_id).first()
    if not fuel_type:
        raise HTTPException(status_code=404, detail="Fuel type not found")

    tanker = None
    if data.tanker_id is not None:
        tanker = db.query(Tanker).filter(Tanker.id == data.tanker_id).first()
        if not tanker:
            raise HTTPException(status_code=404, detail="Tanker not found")

    if tank.fuel_type_id != data.fuel_type_id:
        raise HTTPException(status_code=400, detail="Tank fuel type does not match purchase fuel type")
    if data.quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be greater than 0")
    if data.rate_per_liter <= 0:
        raise HTTPException(status_code=400, detail="Rate per liter must be greater than 0")
    if tank.current_volume + data.quantity > tank.capacity:
        raise HTTPException(status_code=400, detail="Tank capacity exceeded")

    total_amount = data.quantity * data.rate_per_liter
    return tank, supplier, fuel_type, tanker, total_amount


def _apply_purchase_effects(purchase: Purchase, tank: Tank, supplier: Supplier, tanker: Tanker | None) -> None:
    tank.current_volume += purchase.quantity
    supplier.payable_balance += purchase.total_amount
    if tanker:
        tanker.status = "active"


def create_purchase(db: Session, data: PurchaseCreate, current_user: User) -> Purchase:
    tank, supplier, _, tanker, total_amount = _validate_purchase_inputs(db, data, current_user)
    is_auto_approved = current_user.role.name in {"HeadOffice", "StationAdmin", "Manager"} or is_master_admin(current_user)

    purchase = Purchase(
        supplier_id=data.supplier_id,
        tank_id=data.tank_id,
        fuel_type_id=data.fuel_type_id,
        tanker_id=data.tanker_id,
        quantity=data.quantity,
        rate_per_liter=data.rate_per_liter,
        total_amount=total_amount,
        reference_no=data.reference_no,
        notes=data.notes,
        status="approved" if is_auto_approved else "pending",
        submitted_by_user_id=current_user.id,
        approved_by_user_id=current_user.id if is_auto_approved else None,
        approved_at=utc_now() if is_auto_approved else None,
    )
    db.add(purchase)
    db.flush()
    if is_auto_approved:
        _apply_purchase_effects(purchase, tank, supplier, tanker)
    log_audit_event(
        db,
        current_user=current_user,
        module="purchases",
        action="purchases.create",
        entity_type="purchase",
        entity_id=purchase.id,
        station_id=tank.station_id,
        details={"total_amount": total_amount, "quantity": data.quantity, "status": purchase.status},
    )
    if not is_auto_approved:
        notify_approval_requested(
            db,
            actor_user=current_user,
            station_id=tank.station_id,
            organization_id=tank.station.organization_id if tank.station else None,
            entity_type="purchase",
            entity_id=purchase.id,
            title="Purchase approval requested",
            message=f"{current_user.full_name} submitted purchase #{purchase.id} for approval.",
            event_type="purchase.pending_approval",
        )
    db.commit()
    db.refresh(purchase)
    return purchase


def create_manager_receiving(
    db: Session,
    data: ManagerReceivingCreate,
    current_user: User,
) -> Purchase:
    tank = db.query(Tank).filter(Tank.id == data.tank_id).first()
    if not tank:
        raise HTTPException(status_code=404, detail="Tank not found")

    rate_query = (
        db.query(Purchase)
        .join(Tank, Tank.id == Purchase.tank_id)
        .filter(
            Purchase.supplier_id == data.supplier_id,
            Purchase.fuel_type_id == data.fuel_type_id,
            Purchase.status == "approved",
            Purchase.is_reversed.is_(False),
            Tank.station_id == tank.station_id,
        )
        .order_by(Purchase.created_at.desc(), Purchase.id.desc())
    )
    latest_purchase = rate_query.first()
    if latest_purchase is None:
        latest_purchase = (
            db.query(Purchase)
            .filter(
                Purchase.supplier_id == data.supplier_id,
                Purchase.fuel_type_id == data.fuel_type_id,
                Purchase.status == "approved",
                Purchase.is_reversed.is_(False),
            )
            .order_by(Purchase.created_at.desc(), Purchase.id.desc())
            .first()
        )
    if latest_purchase is None:
        raise HTTPException(
            status_code=400,
            detail="No receiving rate is configured for this supplier and fuel type yet. Ask admin to set it first.",
        )

    return create_purchase(
        db,
        PurchaseCreate(
            supplier_id=data.supplier_id,
            tank_id=data.tank_id,
            fuel_type_id=data.fuel_type_id,
            quantity=data.quantity,
            rate_per_liter=latest_purchase.rate_per_liter,
            reference_no=data.reference_no,
            notes=data.notes,
        ),
        current_user,
    )


def approve_purchase(db: Session, purchase: Purchase, current_user: User, reason: str | None = None) -> Purchase:
    ensure_purchase_access(purchase, current_user)
    if purchase.status == "approved":
        raise HTTPException(status_code=400, detail="Purchase is already approved")
    if purchase.status == "rejected":
        raise HTTPException(status_code=400, detail="Rejected purchases cannot be approved")

    tank = db.query(Tank).filter(Tank.id == purchase.tank_id).first()
    supplier = db.query(Supplier).filter(Supplier.id == purchase.supplier_id).first()
    tanker = db.query(Tanker).filter(Tanker.id == purchase.tanker_id).first() if purchase.tanker_id is not None else None
    if tank is None or supplier is None:
        raise HTTPException(status_code=400, detail="Cannot approve purchase because related records are missing")
    if tank.current_volume + purchase.quantity > tank.capacity:
        raise HTTPException(status_code=400, detail="Approving this purchase would exceed tank capacity")

    purchase.status = "approved"
    purchase.approved_by_user_id = current_user.id
    purchase.approved_at = utc_now()
    purchase.rejected_at = None
    purchase.rejection_reason = None
    _apply_purchase_effects(purchase, tank, supplier, tanker)
    log_audit_event(
        db,
        current_user=current_user,
        module="purchases",
        action="purchases.approve",
        entity_type="purchase",
        entity_id=purchase.id,
        station_id=tank.station_id,
        details={"reason": reason, "total_amount": purchase.total_amount},
    )
    notify_decision(
        db,
        recipient_user_id=purchase.submitted_by_user_id,
        actor_user=current_user,
        station_id=tank.station_id,
        organization_id=tank.station.organization_id if tank.station else None,
        entity_type="purchase",
        entity_id=purchase.id,
        title="Purchase approved",
        message=f"Purchase #{purchase.id} was approved.",
        event_type="purchase.approved",
    )
    db.commit()
    db.refresh(purchase)
    return purchase


def reject_purchase(db: Session, purchase: Purchase, current_user: User, reason: str | None = None) -> Purchase:
    ensure_purchase_access(purchase, current_user)
    if purchase.status == "approved":
        raise HTTPException(status_code=400, detail="Approved purchases cannot be rejected")
    if purchase.status == "rejected":
        raise HTTPException(status_code=400, detail="Purchase is already rejected")

    purchase.status = "rejected"
    purchase.approved_by_user_id = None
    purchase.approved_at = None
    purchase.rejected_at = utc_now()
    purchase.rejection_reason = reason
    log_audit_event(
        db,
        current_user=current_user,
        module="purchases",
        action="purchases.reject",
        entity_type="purchase",
        entity_id=purchase.id,
        station_id=purchase.tank.station_id,
        details={"reason": reason},
    )
    notify_decision(
        db,
        recipient_user_id=purchase.submitted_by_user_id,
        actor_user=current_user,
        station_id=purchase.tank.station_id,
        organization_id=purchase.tank.station.organization_id if purchase.tank and purchase.tank.station else None,
        entity_type="purchase",
        entity_id=purchase.id,
        title="Purchase rejected",
        message=f"Purchase #{purchase.id} was rejected.",
        event_type="purchase.rejected",
    )
    db.commit()
    db.refresh(purchase)
    return purchase


def reverse_purchase(db: Session, purchase: Purchase, current_user: User) -> Purchase:
    ensure_purchase_access(purchase, current_user)
    if purchase.status != "approved":
        raise HTTPException(status_code=400, detail="Only approved purchases can be reversed")
    if purchase.reversal_request_status != "approved" and not is_master_admin(current_user):
        raise HTTPException(status_code=400, detail="Purchase reversal must be approved first")
    if purchase.is_reversed:
        raise HTTPException(status_code=400, detail="Purchase is already reversed")

    tank = db.query(Tank).filter(Tank.id == purchase.tank_id).first()
    supplier = db.query(Supplier).filter(Supplier.id == purchase.supplier_id).first()
    if tank is None or supplier is None:
        raise HTTPException(status_code=400, detail="Cannot reverse purchase because related records are missing")
    if tank.current_volume < purchase.quantity:
        raise HTTPException(status_code=400, detail="Purchase cannot be reversed because stock has already been consumed")
    if supplier.payable_balance < purchase.total_amount:
        raise HTTPException(status_code=400, detail="Purchase cannot be reversed after supplier balance has been settled")

    tank.current_volume -= purchase.quantity
    supplier.payable_balance -= purchase.total_amount
    purchase.is_reversed = True
    purchase.reversed_at = utc_now()
    purchase.reversed_by = current_user.id
    log_audit_event(
        db,
        current_user=current_user,
        module="purchases",
        action="purchases.reverse",
        entity_type="purchase",
        entity_id=purchase.id,
        station_id=tank.station_id,
        details={"total_amount": purchase.total_amount, "quantity": purchase.quantity},
    )
    db.commit()
    db.refresh(purchase)
    return purchase


def request_purchase_reversal(db: Session, purchase: Purchase, current_user: User, reason: str | None = None) -> Purchase:
    ensure_purchase_access(purchase, current_user)
    if purchase.status != "approved":
        raise HTTPException(status_code=400, detail="Only approved purchases can request reversal")
    if purchase.is_reversed:
        raise HTTPException(status_code=400, detail="Purchase is already reversed")
    if purchase.reversal_request_status == "pending":
        raise HTTPException(status_code=400, detail="Purchase reversal is already pending approval")
    purchase.reversal_request_status = "pending"
    purchase.reversal_requested_at = utc_now()
    purchase.reversal_requested_by = current_user.id
    purchase.reversal_request_reason = reason
    purchase.reversal_reviewed_at = None
    purchase.reversal_reviewed_by = None
    purchase.reversal_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="purchases",
        action="purchases.request_reversal",
        entity_type="purchase",
        entity_id=purchase.id,
        station_id=purchase.tank.station_id,
        details={"reason": reason},
    )
    notify_approval_requested(
        db,
        actor_user=current_user,
        station_id=purchase.tank.station_id,
        organization_id=purchase.tank.station.organization_id if purchase.tank and purchase.tank.station else None,
        entity_type="purchase",
        entity_id=purchase.id,
        title="Purchase reversal requested",
        message=f"{current_user.full_name} requested reversal for purchase #{purchase.id}.",
        event_type="purchase.reversal_requested",
    )
    db.commit()
    db.refresh(purchase)
    return purchase


def approve_purchase_reversal(db: Session, purchase: Purchase, current_user: User, reason: str | None = None) -> Purchase:
    ensure_purchase_access(purchase, current_user)
    if purchase.is_reversed:
        raise HTTPException(status_code=400, detail="Purchase is already reversed")
    if purchase.reversal_request_status not in {"pending", "approved"}:
        raise HTTPException(status_code=400, detail="Purchase reversal has not been requested")
    purchase.reversal_request_status = "approved"
    purchase.reversal_reviewed_at = utc_now()
    purchase.reversal_reviewed_by = current_user.id
    purchase.reversal_rejection_reason = None
    log_audit_event(
        db,
        current_user=current_user,
        module="purchases",
        action="purchases.approve_reversal",
        entity_type="purchase",
        entity_id=purchase.id,
        station_id=purchase.tank.station_id,
        details={"reason": reason},
    )
    notify_decision(
        db,
        recipient_user_id=purchase.reversal_requested_by,
        actor_user=current_user,
        station_id=purchase.tank.station_id,
        organization_id=purchase.tank.station.organization_id if purchase.tank and purchase.tank.station else None,
        entity_type="purchase",
        entity_id=purchase.id,
        title="Purchase reversal approved",
        message=f"Reversal for purchase #{purchase.id} was approved.",
        event_type="purchase.reversal_approved",
    )
    db.flush()
    return reverse_purchase(db, purchase, current_user)


def reject_purchase_reversal(db: Session, purchase: Purchase, current_user: User, reason: str | None = None) -> Purchase:
    ensure_purchase_access(purchase, current_user)
    if purchase.is_reversed:
        raise HTTPException(status_code=400, detail="Purchase is already reversed")
    if purchase.reversal_request_status != "pending":
        raise HTTPException(status_code=400, detail="Purchase reversal is not pending approval")
    purchase.reversal_request_status = "rejected"
    purchase.reversal_reviewed_at = utc_now()
    purchase.reversal_reviewed_by = current_user.id
    purchase.reversal_rejection_reason = reason
    log_audit_event(
        db,
        current_user=current_user,
        module="purchases",
        action="purchases.reject_reversal",
        entity_type="purchase",
        entity_id=purchase.id,
        station_id=purchase.tank.station_id,
        details={"reason": reason},
    )
    notify_decision(
        db,
        recipient_user_id=purchase.reversal_requested_by,
        actor_user=current_user,
        station_id=purchase.tank.station_id,
        organization_id=purchase.tank.station.organization_id if purchase.tank and purchase.tank.station else None,
        entity_type="purchase",
        entity_id=purchase.id,
        title="Purchase reversal rejected",
        message=f"Reversal for purchase #{purchase.id} was rejected.",
        event_type="purchase.reversal_rejected",
    )
    db.commit()
    db.refresh(purchase)
    return purchase
