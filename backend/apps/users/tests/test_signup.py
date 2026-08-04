import pytest
from django.test import Client
from apps.users.models import User

@pytest.mark.django_db
def test_signup_creates_user_and_returns_tokens():
    client = Client()
    response = client.post(
        "/api/v1/auth/signup",
        data={"email": "a@b.co", "password": "correct horse battery"},
        content_type="application/json",
    )
    assert response.status_code == 201
    body = response.json()
    assert body["user"]["email"] == "a@b.co"
    assert body["access"]
    assert body["refresh"]
    assert User.objects.filter(email="a@b.co").count() == 1

@pytest.mark.django_db
def test_signup_rejects_duplicate_email():
    User.objects.create_user(email="a@b.co", password="x" * 12)
    client = Client()
    response = client.post(
        "/api/v1/auth/signup",
        data={"email": "a@b.co", "password": "correct horse battery"},
        content_type="application/json",
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "conflict"

@pytest.mark.django_db
def test_signup_rejects_short_password():
    client = Client()
    response = client.post(
        "/api/v1/auth/signup",
        data={"email": "a@b.co", "password": "short"},
        content_type="application/json",
    )
    assert response.status_code == 422

@pytest.mark.django_db
def test_signup_is_atomic_user_not_created_if_profile_fails(monkeypatch):
    """If Profile.create() fails, User should also be rolled back."""
    from apps.users import services

    def boom(*a, **kw):
        raise RuntimeError("simulated Profile failure")

    monkeypatch.setattr(services.Profile.objects, "create", boom)

    client = Client()
    with pytest.raises(RuntimeError):
        client.post(
            "/api/v1/auth/signup",
            data={"email": "atomic@b.co", "password": "correct horse battery"},
            content_type="application/json",
        )

    assert User.objects.filter(email="atomic@b.co").count() == 0
