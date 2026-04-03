from fastapi import HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.access import get_user_organization_id, is_head_office_user
from app.core.time import utc_now
from app.models.customer import Customer
from app.models.customer_payment import CustomerPayment
from app.models.financial_document_dispatch import FinancialDocumentDispatch
from app.models.fuel_sale import FuelSale
from app.models.invoice_profile import InvoiceProfile
from app.models.purchase import Purchase
from app.models.station import Station
from app.models.supplier import Supplier
from app.models.supplier_payment import SupplierPayment
from app.models.user import User
from app.schemas.financial_document import FinancialDocumentResponse
from app.services.audit import log_audit_event
from app.services.compliance import (
    build_document_number,
    build_numbered_suffix,
    calculate_tax_breakdown,
    get_business_display_name,
    get_tax_label,
)
from app.services.delivery_queue import next_retry_time, should_retry
from app.services.delivery_channels import deliver_email, deliver_sms, deliver_whatsapp
from app.services.document_rendering import build_profile_header, compose_document_html, get_document_template
from app.services.notifications import notify_actor
from app.services.pdf_renderer import render_financial_document_pdf


def _ensure_station_access(current_user: User, station: Station) -> None:
    if current_user.role.name == "Admin":
        return
    if is_head_office_user(current_user):
        if station.organization_id == get_user_organization_id(current_user):
            return
        raise HTTPException(status_code=403, detail="Not authorized for this station")
    if current_user.station_id != station.id:
        raise HTTPException(status_code=403, detail="Not authorized for this station")


def _get_profile(db: Session, station: Station) -> InvoiceProfile | None:
    return db.query(InvoiceProfile).filter(InvoiceProfile.station_id == station.id).first()


def render_customer_payment_receipt(db: Session, payment: CustomerPayment, current_user: User | None = None) -> FinancialDocumentResponse:
    station = payment.station
    if current_user is not None:
        _ensure_station_access(current_user, station)
    profile = _get_profile(db, station)
    template = get_document_template(db, station, "customer_payment_receipt")
    customer = payment.customer
    document_number = build_document_number(profile, build_numbered_suffix(profile, "CP", payment.id))
    context = {
        "business_name": profile.business_name if profile else station.name,
        "legal_name": get_business_display_name(profile, station),
        "document_title": "Customer Payment Receipt",
        "document_number": document_number,
        "created_at": payment.created_at.isoformat(),
        "customer_name": customer.name,
        "recipient_name": customer.name,
        "recipient_contact": customer.phone or "-",
        "amount_received": f"{payment.amount:.2f}",
        "payment_method": payment.payment_method,
        "reference_no": payment.reference_no or "-",
        "notes": payment.notes or "-",
        "outstanding_balance": f"{customer.outstanding_balance:.2f}",
        "footer_text": profile.footer_text if profile and profile.footer_text else "",
    }
    default_body_html = f"""
    <h3>Customer Payment Receipt</h3>
    <div>Receipt No: {document_number}</div>
    <div>Date: {context['created_at']}</div>
    <div>Customer: {context['customer_name']}</div>
    <div>Amount Received: {context['amount_received']}</div>
    <div>Method: {context['payment_method']}</div>
    <div>Reference: {context['reference_no']}</div>
    <div>Notes: {context['notes']}</div>
    <div>Current Outstanding Balance: {context['outstanding_balance']}</div>
    """
    rendered_html = compose_document_html(
        template=template,
        default_header_html=build_profile_header(profile, station),
        default_body_html=default_body_html,
        default_footer_html=f"<div>{context['footer_text']}</div>",
        context=context,
    )
    return FinancialDocumentResponse(
        document_type="customer_payment_receipt",
        station_id=station.id,
        title="Customer Payment Receipt",
        document_number=document_number,
        recipient_name=customer.name,
        recipient_contact=customer.phone,
        total_amount=round(payment.amount, 2),
        balance=round(customer.outstanding_balance, 2),
        generated_at=utc_now(),
        rendered_html=rendered_html,
    )


def render_supplier_payment_voucher(db: Session, payment: SupplierPayment, current_user: User | None = None) -> FinancialDocumentResponse:
    station = payment.station
    if current_user is not None:
        _ensure_station_access(current_user, station)
    profile = _get_profile(db, station)
    template = get_document_template(db, station, "supplier_payment_voucher")
    supplier = db.query(Supplier).filter(Supplier.id == payment.supplier_id).first()
    document_number = build_document_number(profile, build_numbered_suffix(profile, "SP", payment.id))
    context = {
        "business_name": profile.business_name if profile else station.name,
        "legal_name": get_business_display_name(profile, station),
        "document_title": "Supplier Payment Voucher",
        "document_number": document_number,
        "created_at": payment.created_at.isoformat(),
        "supplier_name": supplier.name if supplier else f"Supplier {payment.supplier_id}",
        "recipient_name": supplier.name if supplier else f"Supplier {payment.supplier_id}",
        "recipient_contact": supplier.phone if supplier and supplier.phone else "-",
        "amount_paid": f"{payment.amount:.2f}",
        "payment_method": payment.payment_method,
        "reference_no": payment.reference_no or "-",
        "notes": payment.notes or "-",
        "payable_balance": f"{(supplier.payable_balance if supplier else 0):.2f}",
        "footer_text": profile.footer_text if profile and profile.footer_text else "",
    }
    default_body_html = f"""
    <h3>Supplier Payment Voucher</h3>
    <div>Voucher No: {document_number}</div>
    <div>Date: {context['created_at']}</div>
    <div>Supplier: {context['supplier_name']}</div>
    <div>Amount Paid: {context['amount_paid']}</div>
    <div>Method: {context['payment_method']}</div>
    <div>Reference: {context['reference_no']}</div>
    <div>Notes: {context['notes']}</div>
    <div>Current Payable Balance: {context['payable_balance']}</div>
    """
    rendered_html = compose_document_html(
        template=template,
        default_header_html=build_profile_header(profile, station),
        default_body_html=default_body_html,
        default_footer_html=f"<div>{context['footer_text']}</div>",
        context=context,
    )
    return FinancialDocumentResponse(
        document_type="supplier_payment_voucher",
        station_id=station.id,
        title="Supplier Payment Voucher",
        document_number=document_number,
        recipient_name=supplier.name if supplier else f"Supplier {payment.supplier_id}",
        recipient_contact=supplier.phone if supplier else None,
        total_amount=round(payment.amount, 2),
        balance=round(supplier.payable_balance if supplier else 0, 2),
        generated_at=utc_now(),
        rendered_html=rendered_html,
    )


def render_customer_ledger_statement(db: Session, customer: Customer, current_user: User | None = None) -> FinancialDocumentResponse:
    station = customer.station
    if current_user is not None:
        _ensure_station_access(current_user, station)
    profile = _get_profile(db, station)
    template = get_document_template(db, station, "customer_ledger_statement")
    items = []
    sales = db.query(FuelSale).filter(FuelSale.customer_id == customer.id, FuelSale.sale_type == "credit", FuelSale.is_reversed.is_(False)).all()
    payments = db.query(CustomerPayment).filter(CustomerPayment.customer_id == customer.id, CustomerPayment.is_reversed.is_(False)).all()
    for sale in sales:
        items.append((sale.created_at, "Credit Sale", sale.total_amount))
    for payment in payments:
        items.append((payment.created_at, "Payment", -payment.amount))
    items.sort(key=lambda item: item[0])
    running = 0.0
    rows = []
    for when, label, amount in items:
        running += amount
        rows.append(f"<tr><td>{when.isoformat()}</td><td>{label}</td><td>{amount:.2f}</td><td>{running:.2f}</td></tr>")
    document_number = build_document_number(profile, build_numbered_suffix(profile, "CL", customer.id))
    context = {
        "business_name": profile.business_name if profile else station.name,
        "legal_name": get_business_display_name(profile, station),
        "document_title": "Customer Ledger Statement",
        "document_number": document_number,
        "customer_name": customer.name,
        "recipient_name": customer.name,
        "recipient_contact": customer.phone or "-",
        "rows_html": "".join(rows),
        "final_balance": f"{running:.2f}",
        "footer_text": profile.footer_text if profile and profile.footer_text else "",
    }
    default_body_html = f"""
    <h3>Customer Ledger Statement</h3>
    <div>Statement No: {document_number}</div>
    <div>Customer: {context['customer_name']}</div>
    <table border='1' cellpadding='4' cellspacing='0'>
      <tr><th>Date</th><th>Entry</th><th>Amount</th><th>Balance</th></tr>
      {context['rows_html']}
    </table>
    <div>Final Balance: {context['final_balance']}</div>
    """
    rendered_html = compose_document_html(
        template=template,
        default_header_html=build_profile_header(profile, station),
        default_body_html=default_body_html,
        default_footer_html=f"<div>{context['footer_text']}</div>",
        context=context,
    )
    return FinancialDocumentResponse(
        document_type="customer_ledger_statement",
        station_id=station.id,
        title="Customer Ledger Statement",
        document_number=document_number,
        recipient_name=customer.name,
        recipient_contact=customer.phone,
        total_amount=None,
        balance=round(running, 2),
        generated_at=utc_now(),
        rendered_html=rendered_html,
    )


def render_supplier_ledger_statement(db: Session, supplier: Supplier, station: Station, current_user: User | None = None) -> FinancialDocumentResponse:
    if current_user is not None:
        _ensure_station_access(current_user, station)
    profile = _get_profile(db, station)
    template = get_document_template(db, station, "supplier_ledger_statement")
    items = []
    purchases = (
        db.query(Purchase)
        .filter(Purchase.supplier_id == supplier.id, Purchase.status == "approved", Purchase.is_reversed.is_(False))
        .all()
    )
    payments = (
        db.query(SupplierPayment)
        .filter(SupplierPayment.supplier_id == supplier.id, SupplierPayment.station_id == station.id, SupplierPayment.is_reversed.is_(False))
        .all()
    )
    for purchase in purchases:
        if purchase.tank and purchase.tank.station_id == station.id:
            items.append((purchase.created_at, "Purchase", purchase.total_amount))
    for payment in payments:
        items.append((payment.created_at, "Payment", -payment.amount))
    items.sort(key=lambda item: item[0])
    running = 0.0
    rows = []
    for when, label, amount in items:
        running += amount
        rows.append(f"<tr><td>{when.isoformat()}</td><td>{label}</td><td>{amount:.2f}</td><td>{running:.2f}</td></tr>")
    document_number = build_document_number(profile, build_numbered_suffix(profile, "SL", supplier.id))
    context = {
        "business_name": profile.business_name if profile else station.name,
        "legal_name": get_business_display_name(profile, station),
        "document_title": "Supplier Ledger Statement",
        "document_number": document_number,
        "supplier_name": supplier.name,
        "recipient_name": supplier.name,
        "recipient_contact": supplier.phone or "-",
        "rows_html": "".join(rows),
        "final_balance": f"{running:.2f}",
        "footer_text": profile.footer_text if profile and profile.footer_text else "",
    }
    default_body_html = f"""
    <h3>Supplier Ledger Statement</h3>
    <div>Statement No: {document_number}</div>
    <div>Supplier: {context['supplier_name']}</div>
    <table border='1' cellpadding='4' cellspacing='0'>
      <tr><th>Date</th><th>Entry</th><th>Amount</th><th>Balance</th></tr>
      {context['rows_html']}
    </table>
    <div>Final Balance: {context['final_balance']}</div>
    """
    rendered_html = compose_document_html(
        template=template,
        default_header_html=build_profile_header(profile, station),
        default_body_html=default_body_html,
        default_footer_html=f"<div>{context['footer_text']}</div>",
        context=context,
    )
    return FinancialDocumentResponse(
        document_type="supplier_ledger_statement",
        station_id=station.id,
        title="Supplier Ledger Statement",
        document_number=document_number,
        recipient_name=supplier.name,
        recipient_contact=supplier.phone,
        total_amount=None,
        balance=round(running, 2),
        generated_at=utc_now(),
        rendered_html=rendered_html,
    )


def render_fuel_sale_invoice(db: Session, sale: FuelSale, current_user: User | None = None) -> FinancialDocumentResponse:
    station = sale.station
    if current_user is not None:
        _ensure_station_access(current_user, station)
    profile = _get_profile(db, station)
    template = get_document_template(db, station, "fuel_sale_invoice")
    subtotal, tax_amount, grand_total = calculate_tax_breakdown(profile, sale.total_amount)
    customer_name = sale.customer.name if sale.customer else "Walk-in Customer"
    customer_contact = sale.customer.phone if sale.customer else None
    tax_label = get_tax_label(profile)
    payment_terms = profile.payment_terms if profile and profile.payment_terms else "Payment due as per station policy."
    notes = profile.sale_invoice_notes if profile and profile.sale_invoice_notes else ""
    document_number = build_document_number(profile, build_numbered_suffix(profile, "FS", sale.id))
    context = {
        "business_name": profile.business_name if profile else station.name,
        "legal_name": get_business_display_name(profile, station),
        "document_title": "Fuel Sale Invoice",
        "document_number": document_number,
        "created_at": sale.created_at.isoformat(),
        "customer_name": customer_name,
        "recipient_name": customer_name,
        "recipient_contact": customer_contact or "-",
        "sale_type": sale.sale_type.title(),
        "fuel_type_name": sale.fuel_type.name,
        "quantity": f"{sale.quantity:.2f}",
        "rate_per_liter": f"{sale.rate_per_liter:.2f}",
        "subtotal": f"{subtotal:.2f}",
        "tax_label": tax_label,
        "tax_amount": f"{tax_amount:.2f}",
        "total": f"{grand_total:.2f}",
        "payment_terms": payment_terms,
        "notes": notes or "-",
        "footer_text": profile.footer_text if profile and profile.footer_text else "",
        "customer_balance": f"{(sale.customer.outstanding_balance if sale.customer else 0):.2f}",
    }
    default_body_html = f"""
    <h3>Fuel Sale Invoice</h3>
    <div>Invoice No: {document_number}</div>
    <div>Date: {context['created_at']}</div>
    <div>Customer: {context['customer_name']}</div>
    <div>Sale Type: {context['sale_type']}</div>
    <table border='1' cellpadding='4' cellspacing='0'>
      <tr><th>Fuel Type</th><th>Quantity (L)</th><th>Rate / Liter</th><th>Subtotal</th></tr>
      <tr><td>{context['fuel_type_name']}</td><td>{context['quantity']}</td><td>{context['rate_per_liter']}</td><td>{context['subtotal']}</td></tr>
    </table>
    <div>Subtotal: {context['subtotal']}</div>
    <div>{context['tax_label']}: {context['tax_amount']}</div>
    <div>Total: {context['total']}</div>
    <div>Payment Terms: {context['payment_terms']}</div>
    <div>Notes: {context['notes']}</div>
    """
    rendered_html = compose_document_html(
        template=template,
        default_header_html=build_profile_header(profile, station),
        default_body_html=default_body_html,
        default_footer_html=f"<div>{context['footer_text']}</div>",
        context=context,
    )
    return FinancialDocumentResponse(
        document_type="fuel_sale_invoice",
        station_id=station.id,
        title="Fuel Sale Invoice",
        document_number=document_number,
        recipient_name=customer_name,
        recipient_contact=customer_contact,
        total_amount=grand_total,
        balance=round(sale.customer.outstanding_balance, 2) if sale.customer else None,
        generated_at=utc_now(),
        rendered_html=rendered_html,
    )


def dispatch_document(
    db: Session,
    *,
    current_user: User,
    document: FinancialDocumentResponse,
    entity_type: str,
    entity_id: int,
    channel: str,
    output_format: str,
    recipient_name: str | None,
    recipient_contact: str | None,
) -> FinancialDocumentDispatch:
    station_id = document.station_id
    document_type = document.document_type
    station = db.query(Station).filter(Station.id == station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    _ensure_station_access(current_user, station)
    dispatch = FinancialDocumentDispatch(
        station_id=station_id,
        requested_by_user_id=current_user.id,
        document_type=document_type,
        entity_type=entity_type,
        entity_id=entity_id,
        channel=channel,
        output_format=output_format,
        recipient_name=recipient_name,
        recipient_contact=recipient_contact,
        status="queued",
        detail="Queued for delivery",
    )
    db.add(dispatch)
    db.flush()
    process_financial_document_dispatch(db, dispatch=dispatch)
    log_audit_event(
        db,
        current_user=current_user,
        module="financial_documents",
        action="financial_documents.dispatch",
        entity_type=entity_type,
        entity_id=entity_id,
        station_id=station_id,
        details={"document_type": document_type, "channel": channel, "recipient_contact": recipient_contact, "status": dispatch.status},
    )
    notify_actor(
        db,
        actor_user=current_user,
        station_id=station_id,
        entity_type=entity_type,
        entity_id=entity_id,
        title="Financial document dispatched",
        message=f"{document_type} was processed for {channel} delivery with status {dispatch.status}.",
        event_type="financial_document.dispatched",
    )
    db.commit()
    db.refresh(dispatch)
    return dispatch


def _dispatch_via_channel(
    *,
    channel: str,
    output_format: str,
    recipient_contact: str | None,
    recipient_name: str | None,
    document_type: str,
    entity_type: str,
    entity_id: int,
    document: FinancialDocumentResponse | None,
) -> tuple[str, str | None]:
    message_text = (
        f"{document_type.replace('_', ' ').title()} is ready."
        f" Reference: {entity_type} #{entity_id}."
        f" Recipient: {recipient_name or '-'}."
    )
    message_html = f"<h3>{document_type.replace('_', ' ').title()}</h3><p>{message_text}</p>"
    if channel == "print":
        return "sent", "Print-ready document generated"
    if channel == "email":
        attachment_bytes = None
        attachment_filename = None
        if output_format == "pdf" and document is not None:
            attachment_bytes = render_financial_document_pdf(document)
            attachment_filename = f"{document.document_number}.pdf"
        return deliver_email(
            to_email=recipient_contact,
            subject=document_type.replace("_", " ").title(),
            body_text=message_text,
            body_html=message_html,
            attachment_bytes=attachment_bytes,
            attachment_filename=attachment_filename,
            attachment_content_type="application/pdf" if attachment_bytes is not None else "application/octet-stream",
        )
    if channel == "sms":
        return deliver_sms(to_number=recipient_contact, body_text=message_text)
    if channel == "whatsapp":
        return deliver_whatsapp(to_number=recipient_contact, body_text=message_text)
    return "skipped", f"Unsupported channel {channel}"


def render_document_pdf_bytes(document: FinancialDocumentResponse) -> bytes:
    return render_financial_document_pdf(document)


def _resolve_document_for_dispatch(db: Session, dispatch: FinancialDocumentDispatch) -> FinancialDocumentResponse:
    if dispatch.entity_type == "customer_payment":
        payment = db.query(CustomerPayment).filter(CustomerPayment.id == dispatch.entity_id).first()
        if not payment:
            raise HTTPException(status_code=404, detail="Customer payment not found")
        return render_customer_payment_receipt(db, payment)
    if dispatch.entity_type == "supplier_payment":
        payment = db.query(SupplierPayment).filter(SupplierPayment.id == dispatch.entity_id).first()
        if not payment:
            raise HTTPException(status_code=404, detail="Supplier payment not found")
        return render_supplier_payment_voucher(db, payment)
    if dispatch.entity_type == "customer":
        customer = db.query(Customer).filter(Customer.id == dispatch.entity_id).first()
        if not customer:
            raise HTTPException(status_code=404, detail="Customer not found")
        return render_customer_ledger_statement(db, customer)
    if dispatch.entity_type == "supplier":
        supplier = db.query(Supplier).filter(Supplier.id == dispatch.entity_id).first()
        station = db.query(Station).filter(Station.id == dispatch.station_id).first()
        if not supplier:
            raise HTTPException(status_code=404, detail="Supplier not found")
        if not station:
            raise HTTPException(status_code=404, detail="Station not found")
        return render_supplier_ledger_statement(db, supplier, station)
    if dispatch.entity_type == "fuel_sale":
        sale = db.query(FuelSale).filter(FuelSale.id == dispatch.entity_id).first()
        if not sale:
            raise HTTPException(status_code=404, detail="Fuel sale not found")
        return render_fuel_sale_invoice(db, sale)
    raise HTTPException(status_code=400, detail="Unsupported financial document entity type")


def process_financial_document_dispatch(db: Session, *, dispatch: FinancialDocumentDispatch) -> FinancialDocumentDispatch:
    document = _resolve_document_for_dispatch(db, dispatch)
    dispatch.attempts_count += 1
    dispatch.last_attempt_at = utc_now()
    status, detail = _dispatch_via_channel(
        channel=dispatch.channel,
        output_format=dispatch.output_format,
        recipient_contact=dispatch.recipient_contact,
        recipient_name=dispatch.recipient_name,
        document_type=dispatch.document_type,
        entity_type=dispatch.entity_type,
        entity_id=dispatch.entity_id,
        document=document,
    )
    if status in {"sent", "skipped"}:
        dispatch.status = status
        dispatch.detail = detail
        dispatch.next_retry_at = None
        dispatch.processed_at = utc_now()
    elif should_retry(status, dispatch.attempts_count):
        dispatch.status = "retrying"
        dispatch.detail = detail
        dispatch.next_retry_at = next_retry_time(dispatch.attempts_count)
        dispatch.processed_at = None
    else:
        dispatch.status = "failed"
        dispatch.detail = detail
        dispatch.next_retry_at = None
        dispatch.processed_at = utc_now()
    db.flush()
    return dispatch


def retry_document_dispatch(db: Session, *, dispatch: FinancialDocumentDispatch, current_user: User) -> FinancialDocumentDispatch:
    station = db.query(Station).filter(Station.id == dispatch.station_id).first()
    if not station:
        raise HTTPException(status_code=404, detail="Station not found")
    _ensure_station_access(current_user, station)
    if dispatch.status not in {"failed", "retrying"}:
        raise HTTPException(status_code=400, detail="Dispatch is not eligible for retry")
    dispatch.next_retry_at = None
    process_financial_document_dispatch(db, dispatch=dispatch)
    db.commit()
    db.refresh(dispatch)
    return dispatch


def process_due_financial_document_dispatches(db: Session, *, limit: int = 100) -> dict:
    now = utc_now()
    dispatches = (
        db.query(FinancialDocumentDispatch)
        .filter(
            FinancialDocumentDispatch.status.in_(["queued", "retrying"]),
            or_(FinancialDocumentDispatch.next_retry_at.is_(None), FinancialDocumentDispatch.next_retry_at <= now),
        )
        .order_by(FinancialDocumentDispatch.id.asc())
        .limit(limit)
        .all()
    )
    processed = 0
    for dispatch in dispatches:
        process_financial_document_dispatch(db, dispatch=dispatch)
        processed += 1
    db.commit()
    return {"processed": processed}
