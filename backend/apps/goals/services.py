import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import recompute_subgoal_parent, recompute_goal_from_accounts
from apps.common.exceptions import NotFoundError
from .models import Goal, Subgoal, GoalAccount

GOALS_COLLECTION = "goals"
SUBGOALS_COLLECTION = "sub_goals"
GOAL_ACCOUNTS_COLLECTION = "goal_accounts"


def _goal_from_doc(snapshot) -> Goal:
    data = snapshot.to_dict()
    return Goal(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        name=data["name"],
        target_amount=from_cents(data["target_amount"]),
        current_amount=from_cents(data["current_amount"]),
        target_date=date.fromisoformat(data["target_date"]) if data.get("target_date") else None,
        type=data["type"],
        category=data["category"],
        created_at=data["created_at"],
    )


def _subgoal_from_doc(snapshot) -> Subgoal:
    data = snapshot.to_dict()
    return Subgoal(
        id=uuid.UUID(snapshot.id),
        goal_id=uuid.UUID(data["goal_id"]),
        user_id=data["user_id"],
        name=data["name"],
        target_amount=from_cents(data["target_amount"]),
        current_amount=from_cents(data["current_amount"]),
        created_at=data["created_at"],
    )


# --- Goal CRUD ---

def list_goals(user):
    docs = get_client().collection(GOALS_COLLECTION).where("user_id", "==", str(user.id)).stream()
    return [_goal_from_doc(d) for d in docs]


def create_goal(user, payload) -> Goal:
    goal_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    get_client().collection(GOALS_COLLECTION).document(str(goal_id)).set({
        "user_id": str(user.id),
        "name": payload.name,
        "target_amount": to_cents(payload.target_amount),
        "current_amount": to_cents(Decimal("0.00")),
        "target_date": payload.target_date.isoformat() if payload.target_date else None,
        "type": payload.type,
        "category": payload.category,
        "created_at": now,
    })
    return Goal(id=goal_id, user_id=str(user.id), name=payload.name,
               target_amount=payload.target_amount, current_amount=Decimal("0.00"),
               target_date=payload.target_date, type=payload.type, category=payload.category,
               created_at=now)


def get_goal(user, goal_id) -> Goal:
    return _goal_from_doc(get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user))


def update_goal(user, goal_id, payload) -> Goal:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.target_amount is not None:
        updates["target_amount"] = to_cents(payload.target_amount)
    if payload.target_date is not None:
        updates["target_date"] = payload.target_date.isoformat()
    if payload.type is not None:
        updates["type"] = payload.type
    if payload.category is not None:
        updates["category"] = payload.category

    doc_ref = get_client().collection(GOALS_COLLECTION).document(str(goal_id))
    if updates:
        doc_ref.update(updates)
    return _goal_from_doc(doc_ref.get())


def delete_goal(user, goal_id) -> None:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    client = get_client()
    batch = client.batch()

    for sub in client.collection(SUBGOALS_COLLECTION).where("goal_id", "==", str(goal_id)).stream():
        batch.delete(sub.reference)
    for link in client.collection(GOAL_ACCOUNTS_COLLECTION).where("goal_id", "==", str(goal_id)).stream():
        batch.delete(link.reference)
    batch.delete(client.collection(GOALS_COLLECTION).document(str(goal_id)))

    batch.commit()


# --- Subgoal CRUD ---

def list_subgoals(user, goal_id):
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    docs = get_client().collection(SUBGOALS_COLLECTION).where("goal_id", "==", str(goal_id)).stream()
    return [_subgoal_from_doc(d) for d in docs]


def create_subgoal(user, goal_id, payload) -> Subgoal:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    subgoal_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    get_client().collection(SUBGOALS_COLLECTION).document(str(subgoal_id)).set({
        "user_id": str(user.id),
        "goal_id": str(goal_id),
        "name": payload.name,
        "target_amount": to_cents(payload.target_amount),
        "current_amount": to_cents(payload.current_amount),
        "created_at": now,
    })
    recompute_subgoal_parent(str(goal_id))
    return Subgoal(id=subgoal_id, goal_id=uuid.UUID(str(goal_id)), user_id=str(user.id),
                   name=payload.name, target_amount=payload.target_amount,
                   current_amount=payload.current_amount, created_at=now)


def get_subgoal(user, goal_id, subgoal_id) -> Subgoal:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    snapshot = get_owned_or_404_fs(SUBGOALS_COLLECTION, subgoal_id, user)
    if snapshot.get("goal_id") != str(goal_id):
        raise NotFoundError("Subgoal not found.")
    return _subgoal_from_doc(snapshot)


def get_subgoal_by_id(user, subgoal_id) -> Subgoal:
    """Like get_subgoal, but without requiring the parent goal_id — used by
    apps/income/services.py::calculate_overtime_projections, whose request
    schema allows subgoal_id without goal_id."""
    return _subgoal_from_doc(get_owned_or_404_fs(SUBGOALS_COLLECTION, subgoal_id, user))


def update_subgoal(user, goal_id, subgoal_id, payload) -> Subgoal:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    snapshot = get_owned_or_404_fs(SUBGOALS_COLLECTION, subgoal_id, user)
    if snapshot.get("goal_id") != str(goal_id):
        raise NotFoundError("Subgoal not found.")

    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.target_amount is not None:
        updates["target_amount"] = to_cents(payload.target_amount)
    if payload.current_amount is not None:
        updates["current_amount"] = to_cents(payload.current_amount)

    doc_ref = get_client().collection(SUBGOALS_COLLECTION).document(str(subgoal_id))
    if updates:
        doc_ref.update(updates)
    recompute_subgoal_parent(str(goal_id))
    return _subgoal_from_doc(doc_ref.get())


def delete_subgoal(user, goal_id, subgoal_id) -> None:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    snapshot = get_owned_or_404_fs(SUBGOALS_COLLECTION, subgoal_id, user)
    if snapshot.get("goal_id") != str(goal_id):
        raise NotFoundError("Subgoal not found.")
    get_client().collection(SUBGOALS_COLLECTION).document(str(subgoal_id)).delete()
    recompute_subgoal_parent(str(goal_id))


# --- GoalAccount (link/unlink) ---

def link_account(user, goal_id, account_id) -> GoalAccount:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    get_owned_or_404_fs("accounts", account_id, user)

    now = datetime.now(timezone.utc)
    link_doc_id = f"{goal_id}_{account_id}"
    get_client().collection(GOAL_ACCOUNTS_COLLECTION).document(link_doc_id).set({
        "user_id": str(user.id),
        "goal_id": str(goal_id),
        "account_id": str(account_id),
        "created_at": now,
    })
    recompute_goal_from_accounts(str(goal_id))
    return GoalAccount(goal_id=uuid.UUID(str(goal_id)), account_id=uuid.UUID(str(account_id)),
                       user_id=str(user.id), created_at=now)


def unlink_account(user, goal_id, account_id) -> None:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    get_owned_or_404_fs("accounts", account_id, user)

    link_doc_id = f"{goal_id}_{account_id}"
    get_client().collection(GOAL_ACCOUNTS_COLLECTION).document(link_doc_id).delete()
    recompute_goal_from_accounts(str(goal_id))
