from ninja import Router
from config.auth import JWTAuth
from .schemas import AccountIn, AccountPatch, AccountOut
from .services import list_accounts, create_account, get_account, update_account, delete_account

router = Router(tags=["accounts"], auth=JWTAuth())


@router.get("", response=list[AccountOut], summary="List accounts")
def list_(request):
    return list_accounts(request.auth)


@router.post("", response={201: AccountOut}, summary="Create account")
def create(request, payload: AccountIn):
    return 201, create_account(request.auth, payload)


@router.get("/{account_id}", response=AccountOut, summary="Get account")
def get(request, account_id: str):
    return get_account(request.auth, account_id)


@router.patch("/{account_id}", response=AccountOut, summary="Update account")
def patch(request, account_id: str, payload: AccountPatch):
    return update_account(request.auth, account_id, payload)


@router.delete("/{account_id}", response={204: None}, summary="Delete account")
def delete(request, account_id: str):
    delete_account(request.auth, account_id)
    return 204, None
