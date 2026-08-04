import uuid
from datetime import datetime, timezone
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import recompute_goal_from_accounts
from .models import Account

COLLECTION = "accounts"


def _from_doc(snapshot) -> Account:
    data = snapshot.to_dict()
    return Account(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        name=data["name"],
        balance=from_cents(data["balance"]),
        created_at=data["created_at"],
    )


def list_accounts(user):
    docs = get_client().collection(COLLECTION).where("user_id", "==", str(user.id)).stream()
    return [_from_doc(d) for d in docs]


def create_account(user, payload) -> Account:
    account_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    get_client().collection(COLLECTION).document(str(account_id)).set({
        "user_id": str(user.id),
        "name": payload.name,
        "balance": to_cents(payload.balance),
        "created_at": now,
    })
    return Account(id=account_id, user_id=str(user.id), name=payload.name,
                   balance=payload.balance, created_at=now)


def get_account(user, account_id) -> Account:
    return _from_doc(get_owned_or_404_fs(COLLECTION, account_id, user))


def update_account(user, account_id, payload) -> Account:
    get_owned_or_404_fs(COLLECTION, account_id, user)
    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.balance is not None:
        updates["balance"] = to_cents(payload.balance)

    doc_ref = get_client().collection(COLLECTION).document(str(account_id))
    if updates:
        doc_ref.update(updates)

    # Mirrors accounts/signals.py::_account_saved, which fires on every save()
    # (not just balance changes) since update_account never passes update_fields.
    for link in get_client().collection("goal_accounts").where(
        "account_id", "==", str(account_id)
    ).stream():
        recompute_goal_from_accounts(link.get("goal_id"))

    return _from_doc(doc_ref.get())


def delete_account(user, account_id) -> None:
    get_owned_or_404_fs(COLLECTION, account_id, user)
    get_client().collection(COLLECTION).document(str(account_id)).delete()
