DEFAULT_TEMPLATES: dict[str, dict[str, str]] = {
    "customer_payment_receipt": {
        "name": "Default Customer Payment Receipt",
        "body_html": """
<h3>{document_title}</h3>
<div>Receipt No: {document_number}</div>
<div>Date: {created_at}</div>
<div>Customer: {customer_name}</div>
<div>Amount Received: {amount_received}</div>
<div>Method: {payment_method}</div>
<div>Reference: {reference_no}</div>
<div>Notes: {notes}</div>
<div>Current Outstanding Balance: {outstanding_balance}</div>
""".strip(),
    },
    "supplier_payment_voucher": {
        "name": "Default Supplier Payment Voucher",
        "body_html": """
<h3>{document_title}</h3>
<div>Voucher No: {document_number}</div>
<div>Date: {created_at}</div>
<div>Supplier: {supplier_name}</div>
<div>Amount Paid: {amount_paid}</div>
<div>Method: {payment_method}</div>
<div>Reference: {reference_no}</div>
<div>Notes: {notes}</div>
<div>Current Payable Balance: {payable_balance}</div>
""".strip(),
    },
    "customer_ledger_statement": {
        "name": "Default Customer Ledger Statement",
        "body_html": """
<h3>{document_title}</h3>
<div>Statement No: {document_number}</div>
<div>Customer: {customer_name}</div>
<table border='1' cellpadding='4' cellspacing='0'>
  <tr><th>Date</th><th>Entry</th><th>Amount</th><th>Balance</th></tr>
  {rows_html}
</table>
<div>Final Balance: {final_balance}</div>
""".strip(),
    },
    "supplier_ledger_statement": {
        "name": "Default Supplier Ledger Statement",
        "body_html": """
<h3>{document_title}</h3>
<div>Statement No: {document_number}</div>
<div>Supplier: {supplier_name}</div>
<table border='1' cellpadding='4' cellspacing='0'>
  <tr><th>Date</th><th>Entry</th><th>Amount</th><th>Balance</th></tr>
  {rows_html}
</table>
<div>Final Balance: {final_balance}</div>
""".strip(),
    },
    "fuel_sale_invoice": {
        "name": "Default Fuel Sale Invoice",
        "body_html": """
<h3>{document_title}</h3>
<div>Invoice No: {document_number}</div>
<div>Date: {created_at}</div>
<div>Customer: {customer_name}</div>
<div>Sale Type: {sale_type}</div>
<table border='1' cellpadding='4' cellspacing='0'>
  <tr><th>Fuel Type</th><th>Quantity (L)</th><th>Rate / Liter</th><th>Subtotal</th></tr>
  <tr><td>{fuel_type_name}</td><td>{quantity}</td><td>{rate_per_liter}</td><td>{subtotal}</td></tr>
</table>
<div>Subtotal: {subtotal}</div>
<div>{tax_label}: {tax_amount}</div>
<div>Total: {total}</div>
<div>Payment Terms: {payment_terms}</div>
<div>Notes: {notes}</div>
""".strip(),
    },
}


PLACEHOLDER_CATALOG: dict[str, list[str]] = {
    "customer_payment_receipt": [
        "document_title", "document_number", "created_at", "customer_name",
        "recipient_name", "recipient_contact", "amount_received", "payment_method",
        "reference_no", "notes", "outstanding_balance", "footer_text",
    ],
    "supplier_payment_voucher": [
        "document_title", "document_number", "created_at", "supplier_name",
        "recipient_name", "recipient_contact", "amount_paid", "payment_method",
        "reference_no", "notes", "payable_balance", "footer_text",
    ],
    "customer_ledger_statement": [
        "document_title", "document_number", "customer_name", "recipient_name",
        "recipient_contact", "rows_html", "final_balance", "footer_text",
    ],
    "supplier_ledger_statement": [
        "document_title", "document_number", "supplier_name", "recipient_name",
        "recipient_contact", "rows_html", "final_balance", "footer_text",
    ],
    "fuel_sale_invoice": [
        "document_title", "document_number", "created_at", "customer_name",
        "recipient_name", "recipient_contact", "sale_type", "fuel_type_name",
        "quantity", "rate_per_liter", "subtotal", "tax_label", "tax_amount",
        "total", "payment_terms", "notes", "footer_text", "customer_balance",
    ],
}
