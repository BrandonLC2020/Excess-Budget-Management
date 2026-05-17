from django.db import IntegrityError, transaction
from ninja_jwt.tokens import RefreshToken
from .models import User, Profile
from apps.common.exceptions import ConflictError


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
