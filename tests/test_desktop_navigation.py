from desktop_app.navigation import build_navigation


def test_navigation_respects_enabled_modules_and_permissions():
    items = build_navigation(
        enabled_modules=["dashboard", "reports", "attendance", "payroll", "notifications"],
        permissions={
            "reports": ["read"],
            "attendance": ["read"],
            "payroll": ["read"],
            "notifications": ["read"],
        },
    )

    keys = [item.key for item in items]
    assert "dashboard" in keys
    assert "reports" in keys
    assert "attendance" in keys
    assert "payroll" in keys
    assert "notifications" in keys
    assert "sales" not in keys
