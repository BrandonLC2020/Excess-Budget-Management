import uuid
from datetime import datetime, timezone
from decimal import Decimal
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from .models import BudgetCategory

COLLECTION = "budget_categories"


def _from_doc(snapshot) -> BudgetCategory:
    data = snapshot.to_dict()
    return BudgetCategory(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        name=data["name"],
        limit_amount=from_cents(data["limit_amount"]),
        spent_amount=from_cents(data["spent_amount"]),
        icon_code=data.get("icon_code"),
        color_hex=data.get("color_hex"),
        category_type=data["category_type"],
        created_at=data["created_at"],
    )


def list_categories(user):
    docs = get_client().collection(COLLECTION).where("user_id", "==", str(user.id)).stream()
    return [_from_doc(d) for d in docs]


def create_category(user, payload) -> BudgetCategory:
    category_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    get_client().collection(COLLECTION).document(str(category_id)).set({
        "user_id": str(user.id),
        "name": payload.name,
        "limit_amount": to_cents(payload.limit_amount),
        "spent_amount": 0,
        "icon_code": payload.icon_code,
        "color_hex": payload.color_hex,
        "category_type": payload.category_type,
        "created_at": now,
    })
    return BudgetCategory(
        id=category_id, user_id=str(user.id), name=payload.name,
        limit_amount=payload.limit_amount, spent_amount=Decimal("0.00"),
        icon_code=payload.icon_code, color_hex=payload.color_hex,
        category_type=payload.category_type, created_at=now,
    )


def get_category(user, category_id) -> BudgetCategory:
    return _from_doc(get_owned_or_404_fs(COLLECTION, category_id, user))


def update_category(user, category_id, payload) -> BudgetCategory:
    get_owned_or_404_fs(COLLECTION, category_id, user)
    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.limit_amount is not None:
        updates["limit_amount"] = to_cents(payload.limit_amount)
    if payload.category_type is not None:
        updates["category_type"] = payload.category_type
    if payload.icon_code is not None:
        updates["icon_code"] = payload.icon_code
    if payload.color_hex is not None:
        updates["color_hex"] = payload.color_hex

    doc_ref = get_client().collection(COLLECTION).document(str(category_id))
    if updates:
        doc_ref.update(updates)
    return _from_doc(doc_ref.get())


def delete_category(user, category_id) -> None:
    get_owned_or_404_fs(COLLECTION, category_id, user)
    get_client().collection(COLLECTION).document(str(category_id)).delete()
