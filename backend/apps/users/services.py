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
        "avatar_url": profile.avatar_url if profile else "",
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


def authenticate_auth0_token(token: str) -> User:
    import jwt
    try:
        domain = getattr(settings, "AUTH0_DOMAIN", "")
        audience = getattr(settings, "AUTH0_AUDIENCE", "")
        
        if domain and not settings.DEBUG:
            from jwt import PyJWKClient
            jwks_url = f"https://{domain}/.well-known/jwks.json"
            jwks_client = PyJWKClient(jwks_url)
            signing_key = jwks_client.get_signing_key_from_jwt(token)
            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256"],
                audience=audience,
                issuer=f"https://{domain}/"
            )
        else:
            try:
                payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
            except Exception:
                payload = jwt.decode(token, options={"verify_signature": False})
                
    except Exception as e:
        raise AuthError(f"Invalid Auth0 token: {str(e)}")
        
    email = payload.get("email")
    if not email:
        raise AuthError("Auth0 token does not contain an email address.")
        
    name = payload.get("name") or payload.get("nickname") or ""
    picture = payload.get("picture") or ""
    
    with transaction.atomic():
        user, created = User.objects.get_or_create(email=email)
        if created:
            user.set_unusable_password()
            user.save()
            Profile.objects.create(user=user, full_name=name, avatar_url=picture)
        else:
            profile, _ = Profile.objects.get_or_create(user=user)
            updated = False
            if not profile.full_name and name:
                profile.full_name = name
                updated = True
            if not profile.avatar_url and picture:
                profile.avatar_url = picture
                updated = True
            if updated:
                profile.save()
                
    return user

