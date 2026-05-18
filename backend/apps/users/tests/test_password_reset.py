import re
import pytest
from django.core import mail
from django.test import Client
from apps.users.models import User

@pytest.mark.django_db
def test_password_reset_round_trip(settings):
    settings.EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
    User.objects.create_user(email="a@b.co", password="originalpass!")
    client = Client()

    r = client.post("/api/v1/auth/password-reset/request",
        data={"email": "a@b.co"}, content_type="application/json")
    assert r.status_code == 204
    assert len(mail.outbox) == 1
    m = re.search(r"token=([\w\-\.:]+)", mail.outbox[0].body)
    token = m.group(1)

    r2 = client.post("/api/v1/auth/password-reset/confirm",
        data={"token": token, "new_password": "shinynewpassword"},
        content_type="application/json")
    assert r2.status_code == 204

    login = client.post("/api/v1/auth/login",
        data={"email": "a@b.co", "password": "shinynewpassword"},
        content_type="application/json")
    assert login.status_code == 200

@pytest.mark.django_db
def test_password_reset_unknown_email_still_returns_204(settings):
    """Don't leak account existence."""
    settings.EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
    r = Client().post("/api/v1/auth/password-reset/request",
        data={"email": "ghost@nowhere.io"}, content_type="application/json")
    assert r.status_code == 204
    assert len(mail.outbox) == 0

@pytest.mark.django_db
def test_password_reset_invalid_token_returns_401():
    User.objects.create_user(email="a@b.co", password="x" * 12)
    r = Client().post("/api/v1/auth/password-reset/confirm",
        data={"token": "garbage", "new_password": "shinynewpassword"},
        content_type="application/json")
    assert r.status_code == 401
