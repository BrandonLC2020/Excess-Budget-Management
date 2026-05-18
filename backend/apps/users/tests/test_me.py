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
