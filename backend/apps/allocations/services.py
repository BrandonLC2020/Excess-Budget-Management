import uuid
from datetime import datetime, timedelta, timezone
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import apply_allocation_effects
from apps.common.exceptions import AppError
from .models import GoalAllocation

COLLECTION = "allocations"


def _from_doc(snapshot) -> GoalAllocation:
    data = snapshot.to_dict()
    return GoalAllocation(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        goal_id=uuid.UUID(data["goal_id"]),
        sub_goal_id=uuid.UUID(data["sub_goal_id"]) if data.get("sub_goal_id") else None,
        account_id=uuid.UUID(data["account_id"]) if data.get("account_id") else None,
        amount=from_cents(data["amount"]),
        created_at=data["created_at"],
    )


def list_allocations(user, goal_id=None):
    query = get_client().collection(COLLECTION).where("user_id", "==", str(user.id))
    if goal_id:
        query = query.where("goal_id", "==", str(goal_id))
    return [_from_doc(d) for d in query.stream()]


def create_allocation(user, payload) -> GoalAllocation:
    get_owned_or_404_fs("goals", payload.goal_id, user)

    sub_goal_id = None
    if payload.sub_goal_id is not None:
        sub_goal_snapshot = get_owned_or_404_fs("sub_goals", payload.sub_goal_id, user)
        if sub_goal_snapshot.get("goal_id") != str(payload.goal_id):
            raise AppError(
                code="subgoal_goal_mismatch",
                message="The sub_goal does not belong to the specified goal.",
                status_code=400,
            )
        sub_goal_id = str(payload.sub_goal_id)

    account_id = None
    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)
        account_id = str(payload.account_id)

    allocation_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    amount_cents = to_cents(payload.amount)
    get_client().collection(COLLECTION).document(str(allocation_id)).set({
        "user_id": str(user.id),
        "goal_id": str(payload.goal_id),
        "sub_goal_id": sub_goal_id,
        "account_id": account_id,
        "amount": amount_cents,
        "created_at": now,
    })

    apply_allocation_effects(
        old=None,
        new={"account_id": account_id, "goal_id": str(payload.goal_id),
             "sub_goal_id": sub_goal_id, "amount_cents": amount_cents},
    )

    return GoalAllocation(id=allocation_id, user_id=str(user.id), goal_id=payload.goal_id,
                          sub_goal_id=payload.sub_goal_id, account_id=payload.account_id,
                          amount=payload.amount, created_at=now)


def get_allocation(user, allocation_id) -> GoalAllocation:
    return _from_doc(get_owned_or_404_fs(COLLECTION, allocation_id, user))


def update_allocation(user, allocation_id, payload) -> GoalAllocation:
    snapshot = get_owned_or_404_fs(COLLECTION, allocation_id, user)
    old_data = snapshot.to_dict()
    old_effect = {
        "account_id": old_data.get("account_id"),
        "goal_id": old_data["goal_id"],
        "sub_goal_id": old_data.get("sub_goal_id"),
        "amount_cents": old_data["amount"],
    }

    updates = {}
    effective_goal_id = old_data["goal_id"]
    if payload.goal_id is not None:
        get_owned_or_404_fs("goals", payload.goal_id, user)
        updates["goal_id"] = str(payload.goal_id)
        effective_goal_id = str(payload.goal_id)

    fields_set = payload.model_fields_set
    if payload.sub_goal_id is not None:
        sub_goal_snapshot = get_owned_or_404_fs("sub_goals", payload.sub_goal_id, user)
        if sub_goal_snapshot.get("goal_id") != effective_goal_id:
            raise AppError(
                code="subgoal_goal_mismatch",
                message="The sub_goal does not belong to the specified goal.",
                status_code=400,
            )
        updates["sub_goal_id"] = str(payload.sub_goal_id)
    elif "sub_goal_id" in fields_set and payload.sub_goal_id is None:
        updates["sub_goal_id"] = None

    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)
        updates["account_id"] = str(payload.account_id)
    elif "account_id" in fields_set and payload.account_id is None:
        updates["account_id"] = None

    if payload.amount is not None:
        updates["amount"] = to_cents(payload.amount)

    doc_ref = get_client().collection(COLLECTION).document(str(allocation_id))
    if updates:
        doc_ref.update(updates)

    new_data = doc_ref.get().to_dict()
    apply_allocation_effects(
        old=old_effect,
        new={"account_id": new_data.get("account_id"), "goal_id": new_data["goal_id"],
             "sub_goal_id": new_data.get("sub_goal_id"), "amount_cents": new_data["amount"]},
    )

    return _from_doc(doc_ref.get())


def delete_allocation(user, allocation_id) -> None:
    snapshot = get_owned_or_404_fs(COLLECTION, allocation_id, user)
    data = snapshot.to_dict()
    get_client().collection(COLLECTION).document(str(allocation_id)).delete()
    apply_allocation_effects(
        old={"account_id": data.get("account_id"), "goal_id": data["goal_id"],
             "sub_goal_id": data.get("sub_goal_id"), "amount_cents": data["amount"]},
        new=None,
    )


def recent_allocation_summary(user, days: int = 30) -> dict:
    since = datetime.now(timezone.utc) - timedelta(days=days)
    client = get_client()
    docs = client.collection(COLLECTION).where("user_id", "==", str(user.id)).where(
        "created_at", ">", since
    ).stream()

    totals = {"savings": 0, "purchase": 0}
    for doc in docs:
        data = doc.to_dict()
        goal_snapshot = client.collection("goals").document(data["goal_id"]).get()
        if not goal_snapshot.exists:
            continue
        category = goal_snapshot.get("category")
        if category in totals:
            totals[category] += data["amount"]

    return {
        "totalSavings": float(from_cents(totals["savings"])),
        "totalPurchases": float(from_cents(totals["purchase"])),
    }
