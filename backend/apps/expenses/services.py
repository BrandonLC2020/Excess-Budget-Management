import uuid
from datetime import date, datetime, timezone
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import apply_expense_effects
from .models import Expense

COLLECTION = "expenses"


def _from_doc(snapshot) -> Expense:
    data = snapshot.to_dict()
    return Expense(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        budget_category_id=uuid.UUID(data["budget_category_id"]),
        account_id=uuid.UUID(data["account_id"]) if data.get("account_id") else None,
        amount=from_cents(data["amount"]),
        description=data["description"],
        date=date.fromisoformat(data["date"]),
        created_at=data["created_at"],
    )


def list_expenses(user, account_id=None, budget_category_id=None):
    query = get_client().collection(COLLECTION).where("user_id", "==", str(user.id))
    if account_id:
        query = query.where("account_id", "==", str(account_id))
    if budget_category_id:
        query = query.where("budget_category_id", "==", str(budget_category_id))
    return [_from_doc(d) for d in query.stream()]


def create_expense(user, payload) -> Expense:
    get_owned_or_404_fs("budget_categories", payload.budget_category_id, user)
    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)

    expense_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    amount_cents = to_cents(payload.amount)
    account_id = str(payload.account_id) if payload.account_id else None
    get_client().collection(COLLECTION).document(str(expense_id)).set({
        "user_id": str(user.id),
        "budget_category_id": str(payload.budget_category_id),
        "account_id": account_id,
        "amount": amount_cents,
        "description": payload.description,
        "date": payload.date.isoformat(),
        "created_at": now,
    })

    apply_expense_effects(
        old=None,
        new={"account_id": account_id, "budget_category_id": str(payload.budget_category_id),
             "amount_cents": amount_cents},
    )

    return Expense(id=expense_id, user_id=str(user.id), budget_category_id=payload.budget_category_id,
                   account_id=payload.account_id, amount=payload.amount,
                   description=payload.description, date=payload.date, created_at=now)


def get_expense(user, expense_id) -> Expense:
    return _from_doc(get_owned_or_404_fs(COLLECTION, expense_id, user))


def update_expense(user, expense_id, payload) -> Expense:
    snapshot = get_owned_or_404_fs(COLLECTION, expense_id, user)
    old_data = snapshot.to_dict()
    old_effect = {
        "account_id": old_data.get("account_id"),
        "budget_category_id": old_data["budget_category_id"],
        "amount_cents": old_data["amount"],
    }

    updates = {}
    if payload.budget_category_id is not None:
        get_owned_or_404_fs("budget_categories", payload.budget_category_id, user)
        updates["budget_category_id"] = str(payload.budget_category_id)
    if payload.amount is not None:
        updates["amount"] = to_cents(payload.amount)
    if payload.description is not None:
        updates["description"] = payload.description
    if payload.date is not None:
        updates["date"] = payload.date.isoformat()

    fields_set = payload.model_fields_set
    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)
        updates["account_id"] = str(payload.account_id)
    elif "account_id" in fields_set and payload.account_id is None:
        updates["account_id"] = None

    doc_ref = get_client().collection(COLLECTION).document(str(expense_id))
    if updates:
        doc_ref.update(updates)

    new_data = doc_ref.get().to_dict()
    apply_expense_effects(
        old=old_effect,
        new={"account_id": new_data.get("account_id"), "budget_category_id": new_data["budget_category_id"],
             "amount_cents": new_data["amount"]},
    )

    return _from_doc(doc_ref.get())


def delete_expense(user, expense_id) -> None:
    snapshot = get_owned_or_404_fs(COLLECTION, expense_id, user)
    data = snapshot.to_dict()
    get_client().collection(COLLECTION).document(str(expense_id)).delete()
    apply_expense_effects(
        old={"account_id": data.get("account_id"), "budget_category_id": data["budget_category_id"],
             "amount_cents": data["amount"]},
        new=None,
    )
