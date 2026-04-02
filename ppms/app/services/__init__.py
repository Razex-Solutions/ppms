from app.services.customers import create_customer, update_customer
from app.services.expenses import create_expense, update_expense
from app.services.fuel_sales import create_fuel_sale, ensure_sale_access, reverse_fuel_sale
from app.services.payments import (
    create_customer_payment,
    create_supplier_payment,
    ensure_customer_payment_access,
    ensure_supplier_payment_access,
    reverse_customer_payment,
    reverse_supplier_payment,
)
from app.services.purchases import create_purchase, ensure_purchase_access, reverse_purchase
from app.services.shifts import close_shift, create_shift, ensure_shift_access
from app.services.tank_dips import create_tank_dip, ensure_tank_dip_access
