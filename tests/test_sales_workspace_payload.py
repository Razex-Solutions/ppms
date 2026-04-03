from desktop_app.views.sales_view import SalesView


class _DummyMaster:
    tk = None


def test_sales_view_reference_helpers_are_consistent():
    view = object.__new__(SalesView)

    station = {"id": 1, "name": "Main Station", "code": "MAIN"}
    nozzle = {"id": 2, "code": "N1", "name": "Petrol Bay"}
    customer = {"id": 3, "code": "CUST-1", "name": "Fleet One"}

    assert view._station_label(station) == "Main Station (MAIN)"
    assert view._nozzle_label(nozzle) == "N1 - Petrol Bay"
    assert view._customer_label(customer) == "CUST-1 - Fleet One"
