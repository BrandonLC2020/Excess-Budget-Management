import pytest
from django.test import Client

@pytest.mark.django_db
def test_login_returns_tokens(user):
    client = Client()
    r = client.post("/api/v1/auth/login",
        data={"email": "alice@example.com", "password": "alicepass!"},
        content_type="application/json")
    assert r.status_code == 200
    body = r.json()
    assert body["access"] and body["refresh"]
    assert body["user"]["email"] == "alice@example.com"

@pytest.mark.django_db
def test_login_rejects_bad_password(user):
    client = Client()
    r = client.post("/api/v1/auth/login",
        data={"email": "alice@example.com", "password": "WRONG"},
        content_type="application/json")
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "auth_error"

@pytest.mark.django_db
def test_refresh_returns_new_tokens(user):
    client = Client()
    login = client.post("/api/v1/auth/login",
        data={"email": "alice@example.com", "password": "alicepass!"},
        content_type="application/json").json()
    r = client.post("/api/v1/auth/refresh",
        data={"refresh": login["refresh"]},
        content_type="application/json")
    assert r.status_code == 200
    assert r.json()["access"]

@pytest.mark.django_db
def test_refresh_rejects_token_for_deleted_user(user):
    client = Client()
    login = client.post("/api/v1/auth/login",
        data={"email": "alice@example.com", "password": "alicepass!"},
        content_type="application/json").json()
    user.delete()
    r = client.post("/api/v1/auth/refresh",
        data={"refresh": login["refresh"]},
        content_type="application/json")
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "auth_error"

@pytest.mark.django_db
def test_refresh_rejects_token_for_inactive_user(user):
    client = Client()
    login = client.post("/api/v1/auth/login",
        data={"email": "alice@example.com", "password": "alicepass!"},
        content_type="application/json").json()
    user.is_active = False
    user.save(update_fields=["is_active"])
    r = client.post("/api/v1/auth/refresh",
        data={"refresh": login["refresh"]},
        content_type="application/json")
    assert r.status_code == 401
