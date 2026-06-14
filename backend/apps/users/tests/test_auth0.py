import pytest
import jwt
from django.conf import settings
from django.test import Client
from apps.users.models import User, Profile

@pytest.mark.django_db
def test_auth0_login_creates_new_user_and_returns_tokens():
    # Generate a mock Auth0 token signed with HS256 using SECRET_KEY
    token_payload = {
        "email": "new-auth0-user@example.com",
        "name": "Auth0 User",
        "picture": "https://example.com/avatar.png",
    }
    mock_token = jwt.encode(token_payload, settings.SECRET_KEY, algorithm="HS256")

    client = Client()
    r = client.post(
        "/api/v1/auth/auth0",
        data={"token": mock_token},
        content_type="application/json"
    )
    assert r.status_code == 200
    body = r.json()
    assert body["access"] and body["refresh"]
    assert body["user"]["email"] == "new-auth0-user@example.com"
    assert body["user"]["full_name"] == "Auth0 User"
    assert body["user"]["avatar_url"] == "https://example.com/avatar.png"
    
    # Check that database user was created
    user = User.objects.get(email="new-auth0-user@example.com")
    assert not user.has_usable_password()
    assert user.profile.full_name == "Auth0 User"
    assert user.profile.avatar_url == "https://example.com/avatar.png"


@pytest.mark.django_db
def test_auth0_login_logs_in_existing_user(user):
    # Set profile fields to empty first
    profile, _ = Profile.objects.get_or_create(user=user)
    profile.full_name = ""
    profile.avatar_url = ""
    profile.save()

    # Generate a mock Auth0 token for the existing user's email
    token_payload = {
        "email": user.email,
        "name": "Existing User Updated Name",
        "picture": "https://example.com/updated-avatar.png",
    }
    mock_token = jwt.encode(token_payload, settings.SECRET_KEY, algorithm="HS256")

    client = Client()
    r = client.post(
        "/api/v1/auth/auth0",
        data={"token": mock_token},
        content_type="application/json"
    )
    assert r.status_code == 200
    body = r.json()
    assert body["access"] and body["refresh"]
    assert body["user"]["email"] == user.email
    assert body["user"]["full_name"] == "Existing User Updated Name"
    assert body["user"]["avatar_url"] == "https://example.com/updated-avatar.png"


@pytest.mark.django_db
def test_auth0_login_fails_with_invalid_token():
    client = Client()
    r = client.post(
        "/api/v1/auth/auth0",
        data={"token": "this-is-not-a-valid-token"},
        content_type="application/json"
    )
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "auth_error"
