import pytest
from decimal import Decimal
from datetime import date


@pytest.mark.django_db
def test_create_expense_happy_path(auth_client):
    client, user = auth_client
    # Create prerequisite budget category
    cat = client.post(
        "/api/v1/budget/categories",
        data={"name": "Food", "limit_amount": "200.00", "category_type": "expense"},
        content_type="application/json",
    ).json()

    r = client.post(
        "/api/v1/expenses",
        data={
            "budget_category_id": cat["id"],
            "amount": "45.00",
            "description": "Groceries",
            "date": str(date.today()),
        },
        content_type="application/json",
    )
    assert r.status_code == 201, r.content
    body = r.json()
    assert body["amount"] == "45.00"
    assert body["description"] == "Groceries"
    assert body["budget_category_id"] == cat["id"]
    assert body["account_id"] is None


@pytest.mark.django_db
def test_list_expenses_returns_only_own(auth_client, other_auth_client):
    a_client, _ = auth_client
    b_client, _ = other_auth_client

    a_cat = a_client.post(
        "/api/v1/budget/categories",
        data={"name": "Food", "limit_amount": "100.00", "category_type": "expense"},
        content_type="application/json",
    ).json()
    b_cat = b_client.post(
        "/api/v1/budget/categories",
        data={"name": "Transport", "limit_amount": "50.00", "category_type": "expense"},
        content_type="application/json",
    ).json()

    a_client.post("/api/v1/expenses",
                  data={"budget_category_id": a_cat["id"], "amount": "10.00", "date": str(date.today())},
                  content_type="application/json")
    b_client.post("/api/v1/expenses",
                  data={"budget_category_id": b_cat["id"], "amount": "20.00", "date": str(date.today())},
                  content_type="application/json")

    r = a_client.get("/api/v1/expenses")
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert r.json()[0]["amount"] == "10.00"


@pytest.mark.django_db
def test_cross_user_expense_returns_404(auth_client, other_auth_client):
    a_client, _ = auth_client
    b_client, _ = other_auth_client

    cat = a_client.post(
        "/api/v1/budget/categories",
        data={"name": "Food", "limit_amount": "100.00", "category_type": "expense"},
        content_type="application/json",
    ).json()
    expense = a_client.post(
        "/api/v1/expenses",
        data={"budget_category_id": cat["id"], "amount": "10.00", "date": str(date.today())},
        content_type="application/json",
    ).json()

    r = b_client.get(f"/api/v1/expenses/{expense['id']}")
    assert r.status_code == 404


@pytest.mark.django_db
def test_list_filter_by_account_id(auth_client):
    client, user = auth_client

    acc = client.post("/api/v1/accounts",
                      data={"name": "Checking", "balance": "500.00"},
                      content_type="application/json").json()
    cat = client.post(
        "/api/v1/budget/categories",
        data={"name": "Food", "limit_amount": "200.00", "category_type": "expense"},
        content_type="application/json",
    ).json()

    # Expense linked to account
    client.post("/api/v1/expenses",
                data={"budget_category_id": cat["id"], "account_id": acc["id"],
                      "amount": "30.00", "date": str(date.today())},
                content_type="application/json")
    # Expense NOT linked to account
    client.post("/api/v1/expenses",
                data={"budget_category_id": cat["id"], "amount": "15.00", "date": str(date.today())},
                content_type="application/json")

    r = client.get(f"/api/v1/expenses?account_id={acc['id']}")
    assert r.status_code == 200
    results = r.json()
    assert len(results) == 1
    assert results[0]["amount"] == "30.00"


@pytest.mark.django_db
def test_delete_expense(auth_client):
    client, _ = auth_client
    cat = client.post(
        "/api/v1/budget/categories",
        data={"name": "Food", "limit_amount": "100.00", "category_type": "expense"},
        content_type="application/json",
    ).json()
    expense = client.post(
        "/api/v1/expenses",
        data={"budget_category_id": cat["id"], "amount": "10.00", "date": str(date.today())},
        content_type="application/json",
    ).json()

    r = client.delete(f"/api/v1/expenses/{expense['id']}")
    assert r.status_code == 204

    r = client.get(f"/api/v1/expenses/{expense['id']}")
    assert r.status_code == 404


@pytest.mark.django_db
def test_requires_auth():
    from django.test import Client
    assert Client().get("/api/v1/expenses").status_code == 401
