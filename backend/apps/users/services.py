from django.db import IntegrityError, transaction
from django.contrib.auth import authenticate as django_authenticate
from ninja_jwt.tokens import RefreshToken
from ninja_jwt.exceptions import TokenError
from .models import User, Profile
from apps.common.exceptions import AuthError, ConflictError


@transaction.atomic
def create_user(email: str, password: str) -> User:
    try:
        user = User.objects.create_user(email=email, password=password)
    except IntegrityError as e:
        raise ConflictError("A user with this email already exists.") from e
    Profile.objects.create(user=user)
    return user


def issue_tokens(user: User) -> dict:
    refresh = RefreshToken.for_user(user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}


def to_user_out(user: User) -> dict:
    profile = getattr(user, "profile", None)
    return {
        "id": str(user.id),
        "email": user.email,
        "full_name": profile.full_name if profile else "",
        "default_savings_ratio": float(profile.default_savings_ratio) if profile else 0.5,
        "date_joined": user.date_joined,
    }


def authenticate_user(email: str, password: str) -> User:
    user = django_authenticate(username=email, password=password)
    if user is None:
        raise AuthError("Invalid email or password.")
    return user


def refresh_tokens(refresh_token_str: str) -> dict:
    try:
        token = RefreshToken(refresh_token_str)
    except TokenError as e:
        raise AuthError("Invalid or expired refresh token.") from e
    user = User.objects.filter(id=token["user_id"], is_active=True).first()
    if user is None:
        raise AuthError("Invalid or expired refresh token.")
    new_token = RefreshToken.for_user(user)
    return {"access": str(new_token.access_token), "refresh": str(new_token)}
