import pytest


@pytest.mark.django_db
def test_create_account(auth_client):
    client, user = auth_client
    r = client.post("/api/v1/accounts", data={"name": "Checking", "balance": "100.00"},
                    content_type="application/json")
    assert r.status_code == 201, r.content
    body = r.json()
    assert body["name"] == "Checking" and body["balance"] == "100.00"


@pytest.mark.django_db
def test_list_returns_only_own_accounts(auth_client, other_auth_client):
    a_client, _ = auth_client
    b_client, _ = other_auth_client
    a_client.post("/api/v1/accounts", data={"name": "A", "balance": "1.00"}, content_type="application/json")
    b_client.post("/api/v1/accounts", data={"name": "B", "balance": "2.00"}, content_type="application/json")
    r = a_client.get("/api/v1/accounts")
    assert r.status_code == 200
    names = [a["name"] for a in r.json()]
    assert names == ["A"]


@pytest.mark.django_db
def test_cross_user_get_returns_404(auth_client, other_auth_client):
    a_client, _ = auth_client
    b_client, _ = other_auth_client
    created = a_client.post("/api/v1/accounts", data={"name": "A", "balance": "1.00"},
                            content_type="application/json").json()
    r = b_client.get(f"/api/v1/accounts/{created['id']}")
    assert r.status_code == 404


@pytest.mark.django_db
def test_negative_balance_rejected(auth_client):
    client, _ = auth_client
    r = client.post("/api/v1/accounts", data={"name": "Bad", "balance": "-1.00"},
                    content_type="application/json")
    assert r.status_code == 422


@pytest.mark.django_db
def test_requires_auth():
    from django.test import Client
    assert Client().get("/api/v1/accounts").status_code == 401
