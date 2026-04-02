from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.permissions import require_permission
from app.models.customer import Customer
from app.models.customer_payment import CustomerPayment
from app.models.financial_document_dispatch import FinancialDocumentDispatch
from app.models.fuel_sale import FuelSale
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.supplier_payment import SupplierPayment
from app.models.user import User
from app.schemas.financial_document import (
    FinancialDocumentDispatchCreate,
    FinancialDocumentDispatchResponse,
    FinancialDocumentResponse,
)
from app.services.financial_documents import (
    dispatch_document,
    process_due_financial_document_dispatches,
    render_document_pdf_bytes,
    render_customer_ledger_statement,
    render_customer_payment_receipt,
    render_fuel_sale_invoice,
    render_supplier_ledger_statement,
    render_supplier_payment_voucher,
    retry_document_dispatch,
)

router = APIRouter(prefix="/financial-documents", tags=["Financial Documents"])


def _pdf_response(document: FinancialDocumentResponse) -> Response:
    filename = f"{document.document_number}.pdf"
    return Response(
        content=render_document_pdf_bytes(document),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/customer-payments/{payment_id}", response_model=FinancialDocumentResponse)
def get_customer_payment_receipt(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial documents")
    payment = db.query(CustomerPayment).filter(CustomerPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Customer payment not found")
    return render_customer_payment_receipt(db, payment, current_user)


@router.get("/fuel-sales/{sale_id}", response_model=FinancialDocumentResponse)
def get_fuel_sale_invoice(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial documents")
    sale = db.query(FuelSale).filter(FuelSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Fuel sale not found")
    return render_fuel_sale_invoice(db, sale, current_user)


@router.get("/fuel-sales/{sale_id}/pdf")
def download_fuel_sale_invoice_pdf(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial documents")
    sale = db.query(FuelSale).filter(FuelSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Fuel sale not found")
    return _pdf_response(render_fuel_sale_invoice(db, sale, current_user))


@router.post("/fuel-sales/{sale_id}/send", response_model=FinancialDocumentDispatchResponse)
def send_fuel_sale_invoice(
    sale_id: int,
    data: FinancialDocumentDispatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to send financial documents")
    sale = db.query(FuelSale).filter(FuelSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Fuel sale not found")
    document = render_fuel_sale_invoice(db, sale, current_user)
    return dispatch_document(
        db,
        current_user=current_user,
        document=document,
        entity_type="fuel_sale",
        entity_id=sale.id,
        channel=data.channel,
        output_format=data.format,
        recipient_name=data.recipient_name or document.recipient_name,
        recipient_contact=data.recipient_contact or document.recipient_contact,
    )


@router.get("/customer-payments/{payment_id}/pdf")
def download_customer_payment_receipt_pdf(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial documents")
    payment = db.query(CustomerPayment).filter(CustomerPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Customer payment not found")
    return _pdf_response(render_customer_payment_receipt(db, payment, current_user))


@router.post("/customer-payments/{payment_id}/send", response_model=FinancialDocumentDispatchResponse)
def send_customer_payment_receipt(
    payment_id: int,
    data: FinancialDocumentDispatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to send financial documents")
    payment = db.query(CustomerPayment).filter(CustomerPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Customer payment not found")
    document = render_customer_payment_receipt(db, payment, current_user)
    return dispatch_document(
        db,
        current_user=current_user,
        document=document,
        entity_type="customer_payment",
        entity_id=payment.id,
        channel=data.channel,
        output_format=data.format,
        recipient_name=data.recipient_name or document.recipient_name,
        recipient_contact=data.recipient_contact or document.recipient_contact,
    )


@router.get("/supplier-payments/{payment_id}", response_model=FinancialDocumentResponse)
def get_supplier_payment_voucher(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial documents")
    payment = db.query(SupplierPayment).filter(SupplierPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Supplier payment not found")
    return render_supplier_payment_voucher(db, payment, current_user)


@router.get("/supplier-payments/{payment_id}/pdf")
def download_supplier_payment_voucher_pdf(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial documents")
    payment = db.query(SupplierPayment).filter(SupplierPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Supplier payment not found")
    return _pdf_response(render_supplier_payment_voucher(db, payment, current_user))


@router.post("/supplier-payments/{payment_id}/send", response_model=FinancialDocumentDispatchResponse)
def send_supplier_payment_voucher(
    payment_id: int,
    data: FinancialDocumentDispatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to send financial documents")
    payment = db.query(SupplierPayment).filter(SupplierPayment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Supplier payment not found")
    document = render_supplier_payment_voucher(db, payment, current_user)
    return dispatch_document(
        db,
        current_user=current_user,
        document=document,
        entity_type="supplier_payment",
        entity_id=payment.id,
        channel=data.channel,
        output_format=data.format,
        recipient_name=data.recipient_name or document.recipient_name,
        recipient_contact=data.recipient_contact or document.recipient_contact,
    )


@router.get("/customer-ledgers/{customer_id}", response_model=FinancialDocumentResponse)
def get_customer_ledger_document(
    customer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial documents")
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return render_customer_ledger_statement(db, customer, current_user)


@router.get("/customer-ledgers/{customer_id}/pdf")
def download_customer_ledger_document_pdf(
    customer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial documents")
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return _pdf_response(render_customer_ledger_statement(db, customer, current_user))


@router.post("/customer-ledgers/{customer_id}/send", response_model=FinancialDocumentDispatchResponse)
def send_customer_ledger_document(
    customer_id: int,
    data: FinancialDocumentDispatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to send financial documents")
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    document = render_customer_ledger_statement(db, customer, current_user)
    return dispatch_document(
        db,
        current_user=current_user,
        document=document,
        entity_type="customer",
        entity_id=customer.id,
        channel=data.channel,
        output_format=data.format,
        recipient_name=data.recipient_name or document.recipient_name,
        recipient_contact=data.recipient_contact or document.recipient_contact,
    )


@router.get("/supplier-ledgers/{supplier_id}", response_model=FinancialDocumentResponse)
def get_supplier_ledger_document(
    supplier_id: int,
    station_id: int = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial documents")
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    return render_supplier_ledger_statement(db, supplier, station, current_user)


@router.get("/supplier-ledgers/{supplier_id}/pdf")
def download_supplier_ledger_document_pdf(
    supplier_id: int,
    station_id: int = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial documents")
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    return _pdf_response(render_supplier_ledger_statement(db, supplier, station, current_user))


@router.post("/supplier-ledgers/{supplier_id}/send", response_model=FinancialDocumentDispatchResponse)
def send_supplier_ledger_document(
    supplier_id: int,
    station_id: int = Query(...),
    data: FinancialDocumentDispatchCreate = ...,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to send financial documents")
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    document = render_supplier_ledger_statement(db, supplier, station, current_user)
    return dispatch_document(
        db,
        current_user=current_user,
        document=document,
        entity_type="supplier",
        entity_id=supplier.id,
        channel=data.channel,
        output_format=data.format,
        recipient_name=data.recipient_name or document.recipient_name,
        recipient_contact=data.recipient_contact or document.recipient_contact,
    )


@router.get("/dispatches", response_model=list[FinancialDocumentDispatchResponse])
def list_document_dispatches(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to view financial document dispatches")
    query = db.query(FinancialDocumentDispatch)
    if current_user.role.name == "Admin":
        pass
    elif current_user.role.name == "HeadOffice":
        query = query.join(Station, Station.id == FinancialDocumentDispatch.station_id).filter(Station.organization_id == current_user.station.organization_id)
    else:
        query = query.filter(FinancialDocumentDispatch.station_id == current_user.station_id)
    return query.order_by(FinancialDocumentDispatch.created_at.desc()).offset(skip).limit(limit).all()


@router.post("/dispatches/process-due")
def process_due_financial_document_dispatches_endpoint(
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "delivery_jobs", "process", detail="You do not have permission to process delivery jobs")
    return process_due_financial_document_dispatches(db, limit=limit)


@router.post("/dispatches/{dispatch_id}/retry", response_model=FinancialDocumentDispatchResponse)
def retry_financial_document_dispatch(
    dispatch_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_permission(current_user, "reports", "read", detail="You do not have permission to retry financial document dispatches")
    dispatch = db.query(FinancialDocumentDispatch).filter(FinancialDocumentDispatch.id == dispatch_id).first()
    if not dispatch:
        raise HTTPException(status_code=404, detail="Financial document dispatch not found")
    return retry_document_dispatch(db, dispatch=dispatch, current_user=current_user)
