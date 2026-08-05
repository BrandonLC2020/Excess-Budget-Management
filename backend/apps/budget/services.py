import uuid
from datetime import datetime, timezone
from decimal import Decimal
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import apply_expense_effects
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
    docs = get_client().collection(COLLECTION).where(
        "user_id", "==", str(user.id)
    ).order_by("created_at").stream()
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
    client = get_client()

    # Reverse the account-balance effect of every expense tied to this category
    # before deleting it — mirrors Django's CASCADE + post_delete-signal
    # behavior: deleting a BudgetCategory cascades to its Expenses, restoring
    # any debited account balance. (Updating this category's own spent_amount
    # along the way is wasted work since the category doc is deleted right
    # after, but harmless.)
    for expense in client.collection("expenses").where("budget_category_id", "==", str(category_id)).stream():
        data = expense.to_dict()
        apply_expense_effects(
            old={
                "account_id": data.get("account_id"),
                "budget_category_id": data["budget_category_id"],
                "amount_cents": data["amount"],
            },
            new=None,
        )

    batch = client.batch()
    batch.delete(client.collection(COLLECTION).document(str(category_id)))
    for expense in client.collection("expenses").where("budget_category_id", "==", str(category_id)).stream():
        batch.delete(expense.reference)
    # Mirrors on_delete=SET_NULL for ExtraIncome.budget_category: keeps existing,
    # just loses the category link.
    for extra in client.collection("extra_income").where("budget_category_id", "==", str(category_id)).stream():
        batch.update(extra.reference, {"budget_category_id": None})
    batch.commit()
