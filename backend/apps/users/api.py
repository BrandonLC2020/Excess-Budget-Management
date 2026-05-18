from ninja import Router
from config.auth import JWTAuth
from .schemas import SignupIn, LoginIn, RefreshIn, AuthResultOut, TokenPairOut, UserOut
from .services import (
    create_user, issue_tokens, to_user_out,
    authenticate_user, refresh_tokens,
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


@router.post("/refresh", response={200: TokenPairOut}, auth=None,
             summary="Exchange refresh for new access+refresh")
def refresh(request, payload: RefreshIn):
    return 200, refresh_tokens(payload.refresh)


@router.get("/me", response=UserOut, auth=JWTAuth(),
            summary="Current authenticated user")
def me(request):
    return to_user_out(request.auth)
