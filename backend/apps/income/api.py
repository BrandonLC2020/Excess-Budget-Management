from ninja import Router
from config.auth import JWTAuth
from .schemas import (
    IncomeSourceIn, IncomeSourcePatch, IncomeSourceOut,
    ExtraIncomeIn, ExtraIncomePatch, ExtraIncomeOut,
)
from .services import (
    list_sources, create_source, get_source, update_source, delete_source,
    list_extra, create_extra, get_extra, update_extra, delete_extra,
)

sources_router = Router(tags=["income"], auth=JWTAuth())
extra_router = Router(tags=["income"], auth=JWTAuth())


# ── IncomeSource endpoints ────────────────────────────────────────────────────

@sources_router.get("", response=list[IncomeSourceOut], summary="List income sources")
def list_sources_(request):
    return list_sources(request.auth)


@sources_router.post("", response={201: IncomeSourceOut}, summary="Create income source")
def create_source_(request, payload: IncomeSourceIn):
    return 201, create_source(request.auth, payload)


@sources_router.get("/{source_id}", response=IncomeSourceOut, summary="Get income source")
def get_source_(request, source_id: str):
    return get_source(request.auth, source_id)


@sources_router.patch("/{source_id}", response=IncomeSourceOut, summary="Update income source")
def patch_source_(request, source_id: str, payload: IncomeSourcePatch):
    return update_source(request.auth, source_id, payload)


@sources_router.delete("/{source_id}", response={204: None}, summary="Delete income source")
def delete_source_(request, source_id: str):
    delete_source(request.auth, source_id)
    return 204, None


# ── ExtraIncome endpoints ─────────────────────────────────────────────────────

@extra_router.get("", response=list[ExtraIncomeOut], summary="List extra income")
def list_extra_(request, account_id: str | None = None):
    return list_extra(request.auth, account_id=account_id)


@extra_router.post("", response={201: ExtraIncomeOut}, summary="Create extra income")
def create_extra_(request, payload: ExtraIncomeIn):
    return 201, create_extra(request.auth, payload)


@extra_router.get("/{extra_id}", response=ExtraIncomeOut, summary="Get extra income")
def get_extra_(request, extra_id: str):
    return get_extra(request.auth, extra_id)


@extra_router.patch("/{extra_id}", response=ExtraIncomeOut, summary="Update extra income")
def patch_extra_(request, extra_id: str, payload: ExtraIncomePatch):
    return update_extra(request.auth, extra_id, payload)


@extra_router.delete("/{extra_id}", response={204: None}, summary="Delete extra income")
def delete_extra_(request, extra_id: str):
    delete_extra(request.auth, extra_id)
    return 204, None


# ── Mount sub-routers ─────────────────────────────────────────────────────────

router = Router(auth=JWTAuth())
router.add_router("/sources", sources_router)
router.add_router("/extra", extra_router)
