import pytest


@pytest.mark.django_db
def test_create_expense_category(auth_client):
    client, _ = auth_client
    r = client.post(
        "/api/v1/budget/categories",
        data={
            "name": "Groceries",
            "limit_amount": "400.00",
            "category_type": "expense",
            "icon_code": 58820,
            "color_hex": "#9E9E9E",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    body = r.json()
    assert body["spent_amount"] == "0.00"
    assert body["category_type"] == "expense"


@pytest.mark.django_db
def test_create_income_category_defaults_color(auth_client):
    client, _ = auth_client
    r = client.post(
        "/api/v1/budget/categories",
        data={"name": "Bonus", "limit_amount": "1000.00", "category_type": "income"},
        content_type="application/json",
    )
    assert r.status_code == 201


@pytest.mark.django_db
def test_invalid_category_type_rejected(auth_client):
    client, _ = auth_client
    r = client.post(
        "/api/v1/budget/categories",
        data={"name": "x", "limit_amount": "1.00", "category_type": "wat"},
        content_type="application/json",
    )
    assert r.status_code == 422


@pytest.mark.django_db
def test_isolation(auth_client, other_auth_client):
    a, _ = auth_client
    b, _ = other_auth_client
    created = a.post(
        "/api/v1/budget/categories",
        data={"name": "A", "limit_amount": "1.00", "category_type": "expense"},
        content_type="application/json",
    ).json()
    assert b.get(f"/api/v1/budget/categories/{created['id']}").status_code == 404
