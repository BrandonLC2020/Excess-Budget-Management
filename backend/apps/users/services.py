from django.conf import settings
from django.core.mail import send_mail
from django.db import IntegrityError, transaction
from django.contrib.auth import authenticate as django_authenticate
from ninja_jwt.tokens import RefreshToken
from ninja_jwt.exceptions import TokenError
from .models import User, Profile
from apps.common.exceptions import AuthError, ConflictError
from .tokens import make_reset_token, parse_reset_token


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


def request_password_reset(email: str) -> None:
    user = User.objects.filter(email__iexact=email).first()
    if user is None:
        return  # silent success — don't leak account existence
    token = make_reset_token(user.id)
    link = settings.PASSWORD_RESET_URL_TEMPLATE.format(token=token)
    send_mail(
        subject="Reset your Excess Budget password",
        message=f"Open this link to set a new password:\n\n{link}\n\nLink expires in 1 hour.",
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
    )


def confirm_password_reset(token: str, new_password: str) -> None:
    try:
        user_id = parse_reset_token(token)
    except ValueError as e:
        raise AuthError("Invalid or expired reset token.") from e
    user = User.objects.filter(id=user_id).first()
    if user is None:
        raise AuthError("Invalid or expired reset token.")
    user.set_password(new_password)
    user.save(update_fields=["password"])
