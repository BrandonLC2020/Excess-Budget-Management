from ninja import Router
from .schemas import SignupIn, AuthResultOut
from .services import create_user, issue_tokens, to_user_out

router = Router(tags=["auth"])


@router.post(
    "/signup",
    response={201: AuthResultOut},
    auth=None,
    summary="Create a new user",
    description="Email/password signup; returns tokens.",
)
def signup(request, payload: SignupIn):
    user = create_user(payload.email, payload.password)
    tokens = issue_tokens(user)
    return 201, {"user": to_user_out(user), **tokens}
