import pytest


@pytest.mark.django_db
def test_create_and_list_income_source(auth_client):
    client, _ = auth_client
    r = client.post(
        "/api/v1/income/sources",
        data={"name": "Salary", "expected_amount": "5000.00", "frequency": "monthly"},
        content_type="application/json",
    )
    assert r.status_code == 201
    r2 = client.get("/api/v1/income/sources")
    assert [s["name"] for s in r2.json()] == ["Salary"]


@pytest.mark.django_db
def test_extra_income_with_account_link(auth_client):
    client, _ = auth_client
    acc = client.post(
        "/api/v1/accounts",
        data={"name": "Chk", "balance": "0.00"},
        content_type="application/json",
    ).json()
    r = client.post(
        "/api/v1/income/extra",
        data={
            "amount": "200.00",
            "description": "Refund",
            "date_received": "2026-05-17",
            "account_id": acc["id"],
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    assert r.json()["account_id"] == acc["id"]


@pytest.mark.django_db
def test_extra_income_with_budget_category(auth_client):
    client, _ = auth_client
    cat = client.post(
        "/api/v1/budget/categories",
        data={"name": "Side hustle", "limit_amount": "0.00", "category_type": "income"},
        content_type="application/json",
    ).json()
    r = client.post(
        "/api/v1/income/extra",
        data={
            "amount": "75.00",
            "description": "Freelance",
            "date_received": "2026-05-17",
            "budget_category_id": cat["id"],
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    assert r.json()["budget_category_id"] == cat["id"]


@pytest.mark.django_db
def test_cross_user_isolation(auth_client, other_auth_client):
    a, _ = auth_client
    b, _ = other_auth_client
    created = a.post(
        "/api/v1/income/sources",
        data={"name": "x", "expected_amount": "1.00", "frequency": "monthly"},
        content_type="application/json",
    ).json()
    assert b.get(f"/api/v1/income/sources/{created['id']}").status_code == 404
