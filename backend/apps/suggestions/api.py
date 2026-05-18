from ninja import Router
from config.auth import JWTAuth
from .schemas import SuggestIn, SuggestOut
from .services import generate

router = Router(tags=["suggestions"], auth=JWTAuth())


@router.post("/generate", response=SuggestOut, summary="Generate allocation suggestion")
def generate_endpoint(request, payload: SuggestIn):
    return generate(request.auth, payload.excess_funds)
