from ninja import Router
from config.auth import JWTAuth
from .schemas import SignupIn, LoginIn, Auth0LoginIn, RefreshIn, AuthResultOut, TokenPairOut, UserOut, MePatchIn, PasswordResetRequestIn, PasswordResetConfirmIn
from .services import (
    create_user, issue_tokens, to_user_out,
    authenticate_user, refresh_tokens,
    request_password_reset, confirm_password_reset,
    authenticate_auth0_token,
)

router = Router(tags=["auth"])


@router.post("/signup", response={201: AuthResultOut}, auth=None,
             summary="Create a new user")
def signup(request, payload: SignupIn):
    user = create_user(payload.email, payload.password)
    tokens = issue_tokens(user)
    return 201, {"user": to_user_out(user), **tokens}


@router.post("/login", response={200: AuthResultOut}, auth=None,
             summary="Email/password login")
def login(request, payload: LoginIn):
    user = authenticate_user(payload.email, payload.password)
    tokens = issue_tokens(user)
    return 200, {"user": to_user_out(user), **tokens}


@router.post("/auth0", response={200: AuthResultOut}, auth=None,
             summary="Login/signup with Auth0 token")
def auth0_login(request, payload: Auth0LoginIn):
    user = authenticate_auth0_token(payload.token)
    tokens = issue_tokens(user)
    return 200, {"user": to_user_out(user), **tokens}



@router.post("/refresh", response={200: TokenPairOut}, auth=None,
             summary="Exchange refresh for new access+refresh")
def refresh(request, payload: RefreshIn):
    return 200, refresh_tokens(payload.refresh)


@router.get("/me", response=UserOut, auth=JWTAuth(),
            summary="Current authenticated user")
def me(request):
    return to_user_out(request.auth)


@router.patch("/me", response=UserOut, auth=JWTAuth(),
              summary="Update current user's profile")
def patch_me(request, payload: MePatchIn):
    from .models import Profile
    user = request.auth
    profile, _ = Profile.objects.get_or_create(user=user)
    if payload.full_name is not None:
        profile.full_name = payload.full_name
    if payload.avatar_url is not None:
        profile.avatar_url = payload.avatar_url
    if payload.default_savings_ratio is not None:
        profile.default_savings_ratio = payload.default_savings_ratio
    profile.save()
    return to_user_out(user)


@router.post("/password-reset/request", response={204: None}, auth=None,
             summary="Start password reset flow")
def password_reset_request(request, payload: PasswordResetRequestIn):
    request_password_reset(payload.email)
    return 204, None


@router.post("/password-reset/confirm", response={204: None}, auth=None,
             summary="Confirm password reset with token")
def password_reset_confirm(request, payload: PasswordResetConfirmIn):
    confirm_password_reset(payload.token, payload.new_password)
    return 204, None
