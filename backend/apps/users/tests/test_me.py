import pytest
from django.test import Client
from apps.users.models import User

@pytest.mark.django_db
def test_me_requires_auth():
    r = Client().get("/api/v1/auth/me")
    assert r.status_code == 401

@pytest.mark.django_db
def test_me_returns_current_user():
    User.objects.create_user(email="a@b.co", password="correct horse battery")
    client = Client()
    login = client.post("/api/v1/auth/login",
        data={"email": "a@b.co", "password": "correct horse battery"},
        content_type="application/json").json()
    r = client.get("/api/v1/auth/me",
        HTTP_AUTHORIZATION=f"Bearer {login['access']}")
    assert r.status_code == 200
    assert r.json()["email"] == "a@b.co"


@pytest.mark.django_db
def test_patch_me_updates_profile(auth_client):
    client, user = auth_client
    r = client.patch(
        "/api/v1/auth/me",
        data={"full_name": "Alice Wonderland", "default_savings_ratio": 0.7},
        content_type="application/json",
    )
    assert r.status_code == 200, r.content
    body = r.json()
    assert body["full_name"] == "Alice Wonderland"
    assert body["default_savings_ratio"] == 0.7


@pytest.mark.django_db
def test_patch_me_requires_auth():
    from django.test import Client
    r = Client().patch("/api/v1/auth/me",
                       data={"full_name": "x"}, content_type="application/json")
    assert r.status_code == 401


@pytest.mark.django_db
def test_patch_me_rejects_invalid_ratio(auth_client):
    client, _ = auth_client
    r = client.patch("/api/v1/auth/me",
                     data={"default_savings_ratio": 1.5},
                     content_type="application/json")
    assert r.status_code == 422
