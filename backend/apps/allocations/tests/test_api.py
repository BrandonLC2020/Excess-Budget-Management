import pytest
from decimal import Decimal


@pytest.mark.django_db
def test_create_allocation_goal_only(auth_client):
    client, _ = auth_client
    goal = client.post(
        "/api/v1/goals",
        data={"name": "Emergency Fund", "target_amount": "1000.00",
              "type": "long_term", "category": "savings"},
        content_type="application/json",
    ).json()

    r = client.post(
        "/api/v1/allocations",
        data={"goal_id": goal["id"], "amount": "250.00"},
        content_type="application/json",
    )
    assert r.status_code == 201, r.content
    body = r.json()
    assert body["goal_id"] == goal["id"]
    assert body["amount"] == "250.00"
    assert body["account_id"] is None
    assert body["sub_goal_id"] is None


@pytest.mark.django_db
def test_create_allocation_debits_account(auth_client):
    client, _ = auth_client
    acc = client.post(
        "/api/v1/accounts",
        data={"name": "Checking", "balance": "800.00"},
        content_type="application/json",
    ).json()
    goal = client.post(
        "/api/v1/goals",
        data={"name": "Vacation", "target_amount": "2000.00",
              "type": "short_term", "category": "purchase"},
        content_type="application/json",
    ).json()

    r = client.post(
        "/api/v1/allocations",
        data={"goal_id": goal["id"], "account_id": acc["id"], "amount": "300.00"},
        content_type="application/json",
    )
    assert r.status_code == 201, r.content

    # Account balance should be debited
    updated_acc = client.get(f"/api/v1/accounts/{acc['id']}").json()
    assert Decimal(updated_acc["balance"]) == Decimal("500.00")


@pytest.mark.django_db
def test_list_allocations(auth_client):
    client, _ = auth_client
    goal = client.post(
        "/api/v1/goals",
        data={"name": "Savings", "target_amount": "500.00",
              "type": "long_term", "category": "savings"},
        content_type="application/json",
    ).json()

    client.post("/api/v1/allocations",
                data={"goal_id": goal["id"], "amount": "50.00"},
                content_type="application/json")
    client.post("/api/v1/allocations",
                data={"goal_id": goal["id"], "amount": "75.00"},
                content_type="application/json")

    r = client.get("/api/v1/allocations")
    assert r.status_code == 200
    assert len(r.json()) == 2


@pytest.mark.django_db
def test_list_filter_by_goal(auth_client):
    client, _ = auth_client
    g1 = client.post(
        "/api/v1/goals",
        data={"name": "G1", "target_amount": "100.00",
              "type": "long_term", "category": "savings"},
        content_type="application/json",
    ).json()
    g2 = client.post(
        "/api/v1/goals",
        data={"name": "G2", "target_amount": "200.00",
              "type": "long_term", "category": "savings"},
        content_type="application/json",
    ).json()

    client.post("/api/v1/allocations",
                data={"goal_id": g1["id"], "amount": "10.00"},
                content_type="application/json")
    client.post("/api/v1/allocations",
                data={"goal_id": g2["id"], "amount": "20.00"},
                content_type="application/json")

    r = client.get(f"/api/v1/allocations?goal_id={g1['id']}")
    assert r.status_code == 200
    results = r.json()
    assert len(results) == 1
    assert results[0]["goal_id"] == g1["id"]


@pytest.mark.django_db
def test_delete_allocation(auth_client):
    client, _ = auth_client
    goal = client.post(
        "/api/v1/goals",
        data={"name": "Fund", "target_amount": "1000.00",
              "type": "long_term", "category": "savings"},
        content_type="application/json",
    ).json()
    allocation = client.post(
        "/api/v1/allocations",
        data={"goal_id": goal["id"], "amount": "100.00"},
        content_type="application/json",
    ).json()

    r = client.delete(f"/api/v1/allocations/{allocation['id']}")
    assert r.status_code == 204

    r = client.get(f"/api/v1/allocations/{allocation['id']}")
    assert r.status_code == 404


@pytest.mark.django_db
def test_cross_user_allocation_returns_404(auth_client, other_auth_client):
    a_client, _ = auth_client
    b_client, _ = other_auth_client

    goal = a_client.post(
        "/api/v1/goals",
        data={"name": "Secret", "target_amount": "999.00",
              "type": "long_term", "category": "savings"},
        content_type="application/json",
    ).json()
    allocation = a_client.post(
        "/api/v1/allocations",
        data={"goal_id": goal["id"], "amount": "50.00"},
        content_type="application/json",
    ).json()

    r = b_client.get(f"/api/v1/allocations/{allocation['id']}")
    assert r.status_code == 404


@pytest.mark.django_db
def test_requires_auth():
    from django.test import Client
    assert Client().get("/api/v1/allocations").status_code == 401
