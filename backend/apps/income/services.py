import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from google.cloud import firestore
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import apply_extra_income_effects
from apps.goals.services import get_goal, get_subgoal
from .models import IncomeSource, ExtraIncome, OvertimeSettings

SOURCES_COLLECTION = "income_sources"
EXTRA_COLLECTION = "extra_income"
OVERTIME_COLLECTION = "overtime_settings"


# ── IncomeSource ──────────────────────────────────────────────────────────────

def _source_from_doc(snapshot) -> IncomeSource:
    data = snapshot.to_dict()
    return IncomeSource(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        name=data["name"],
        expected_amount=from_cents(data["expected_amount"]),
        frequency=data["frequency"],
        created_at=data["created_at"],
    )


def list_sources(user):
    docs = get_client().collection(SOURCES_COLLECTION).where(
        "user_id", "==", str(user.id)
    ).order_by("created_at").stream()
    return [_source_from_doc(d) for d in docs]


def create_source(user, payload) -> IncomeSource:
    source_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    get_client().collection(SOURCES_COLLECTION).document(str(source_id)).set({
        "user_id": str(user.id),
        "name": payload.name,
        "expected_amount": to_cents(payload.expected_amount),
        "frequency": payload.frequency,
        "created_at": now,
    })
    return IncomeSource(id=source_id, user_id=str(user.id), name=payload.name,
                        expected_amount=payload.expected_amount, frequency=payload.frequency,
                        created_at=now)


def get_source(user, source_id) -> IncomeSource:
    return _source_from_doc(get_owned_or_404_fs(SOURCES_COLLECTION, source_id, user))


def update_source(user, source_id, payload) -> IncomeSource:
    get_owned_or_404_fs(SOURCES_COLLECTION, source_id, user)
    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.expected_amount is not None:
        updates["expected_amount"] = to_cents(payload.expected_amount)
    if payload.frequency is not None:
        updates["frequency"] = payload.frequency

    doc_ref = get_client().collection(SOURCES_COLLECTION).document(str(source_id))
    if updates:
        doc_ref.update(updates)
    return _source_from_doc(doc_ref.get())


def delete_source(user, source_id) -> None:
    get_owned_or_404_fs(SOURCES_COLLECTION, source_id, user)
    get_client().collection(SOURCES_COLLECTION).document(str(source_id)).delete()


# ── ExtraIncome ───────────────────────────────────────────────────────────────

def _extra_from_doc(snapshot) -> ExtraIncome:
    data = snapshot.to_dict()
    return ExtraIncome(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        amount=from_cents(data["amount"]),
        description=data["description"],
        date_received=date.fromisoformat(data["date_received"]),
        account_id=uuid.UUID(data["account_id"]) if data.get("account_id") else None,
        budget_category_id=uuid.UUID(data["budget_category_id"]) if data.get("budget_category_id") else None,
        created_at=data["created_at"],
    )


def list_extra(user, account_id=None, budget_category_id=None):
    query = get_client().collection(EXTRA_COLLECTION).where("user_id", "==", str(user.id))
    if account_id:
        query = query.where("account_id", "==", str(account_id))
    if budget_category_id:
        query = query.where("budget_category_id", "==", str(budget_category_id))
    query = query.order_by(
        "date_received", direction=firestore.Query.DESCENDING
    ).order_by("created_at", direction=firestore.Query.DESCENDING)
    return [_extra_from_doc(d) for d in query.stream()]


def create_extra(user, payload) -> ExtraIncome:
    account_id = None
    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)
        account_id = str(payload.account_id)

    budget_category_id = None
    if payload.budget_category_id is not None:
        get_owned_or_404_fs("budget_categories", payload.budget_category_id, user)
        budget_category_id = str(payload.budget_category_id)

    extra_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    amount_cents = to_cents(payload.amount)
    get_client().collection(EXTRA_COLLECTION).document(str(extra_id)).set({
        "user_id": str(user.id),
        "amount": amount_cents,
        "description": payload.description,
        "date_received": payload.date_received.isoformat(),
        "account_id": account_id,
        "budget_category_id": budget_category_id,
        "created_at": now,
    })

    apply_extra_income_effects(
        old=None,
        new={"account_id": account_id, "budget_category_id": budget_category_id, "amount_cents": amount_cents},
    )

    return ExtraIncome(
        id=extra_id, user_id=str(user.id), amount=payload.amount, description=payload.description,
        date_received=payload.date_received,
        account_id=payload.account_id, budget_category_id=payload.budget_category_id, created_at=now,
    )


def get_extra(user, extra_id) -> ExtraIncome:
    return _extra_from_doc(get_owned_or_404_fs(EXTRA_COLLECTION, extra_id, user))


def update_extra(user, extra_id, payload) -> ExtraIncome:
    snapshot = get_owned_or_404_fs(EXTRA_COLLECTION, extra_id, user)
    old_data = snapshot.to_dict()
    old_effect = {
        "account_id": old_data.get("account_id"),
        "budget_category_id": old_data.get("budget_category_id"),
        "amount_cents": old_data["amount"],
    }

    updates = {}
    if payload.amount is not None:
        updates["amount"] = to_cents(payload.amount)
    if payload.description is not None:
        updates["description"] = payload.description
    if payload.date_received is not None:
        updates["date_received"] = payload.date_received.isoformat()

    fields_set = payload.model_fields_set
    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)
        updates["account_id"] = str(payload.account_id)
    elif "account_id" in fields_set and payload.account_id is None:
        updates["account_id"] = None

    if payload.budget_category_id is not None:
        get_owned_or_404_fs("budget_categories", payload.budget_category_id, user)
        updates["budget_category_id"] = str(payload.budget_category_id)
    elif "budget_category_id" in fields_set and payload.budget_category_id is None:
        updates["budget_category_id"] = None

    doc_ref = get_client().collection(EXTRA_COLLECTION).document(str(extra_id))
    if updates:
        doc_ref.update(updates)

    new_data = doc_ref.get().to_dict()
    apply_extra_income_effects(
        old=old_effect,
        new={
            "account_id": new_data.get("account_id"),
            "budget_category_id": new_data.get("budget_category_id"),
            "amount_cents": new_data["amount"],
        },
    )

    return _extra_from_doc(doc_ref.get())


def delete_extra(user, extra_id) -> None:
    snapshot = get_owned_or_404_fs(EXTRA_COLLECTION, extra_id, user)
    data = snapshot.to_dict()
    get_client().collection(EXTRA_COLLECTION).document(str(extra_id)).delete()
    apply_extra_income_effects(
        old={
            "account_id": data.get("account_id"),
            "budget_category_id": data.get("budget_category_id"),
            "amount_cents": data["amount"],
        },
        new=None,
    )


# ── Overtime Settings & Calculations ──────────────────────────────────────────

def _overtime_from_doc(snapshot, user_id: str) -> OvertimeSettings:
    data = snapshot.to_dict()
    return OvertimeSettings(
        user_id=user_id,
        hourly_base_rate=from_cents(data["hourly_base_rate"]),
        overtime_multiplier=from_cents(data["overtime_multiplier"]),
        estimated_tax_rate=from_cents(data["estimated_tax_rate"]),
        created_at=data["created_at"],
        updated_at=data["updated_at"],
    )


def get_overtime_settings(user) -> OvertimeSettings:
    doc_ref = get_client().collection(OVERTIME_COLLECTION).document(str(user.id))
    snapshot = doc_ref.get()
    if not snapshot.exists:
        now = datetime.now(timezone.utc)
        doc_ref.set({
            "hourly_base_rate": to_cents(Decimal("0.00")),
            "overtime_multiplier": to_cents(Decimal("1.50")),
            "estimated_tax_rate": to_cents(Decimal("0.25")),
            "created_at": now,
            "updated_at": now,
        })
        snapshot = doc_ref.get()
    return _overtime_from_doc(snapshot, str(user.id))


def update_overtime_settings(user, payload) -> OvertimeSettings:
    get_overtime_settings(user)  # ensures the doc exists
    updates = {"updated_at": datetime.now(timezone.utc)}
    if payload.hourly_base_rate is not None:
        updates["hourly_base_rate"] = to_cents(payload.hourly_base_rate)
    if payload.overtime_multiplier is not None:
        updates["overtime_multiplier"] = to_cents(payload.overtime_multiplier)
    if payload.estimated_tax_rate is not None:
        updates["estimated_tax_rate"] = to_cents(payload.estimated_tax_rate)

    doc_ref = get_client().collection(OVERTIME_COLLECTION).document(str(user.id))
    doc_ref.update(updates)
    return _overtime_from_doc(doc_ref.get(), str(user.id))


def calculate_overtime_projections(user, payload) -> dict:
    settings_obj = get_overtime_settings(user)

    base = settings_obj.hourly_base_rate
    mult = settings_obj.overtime_multiplier
    tax = settings_obj.estimated_tax_rate

    net_hourly_rate = base * mult * (Decimal("1.00") - tax)
    weekly_overtime_net_income = net_hourly_rate * payload.overtime_hours_per_week
    monthly_overtime_net_income = weekly_overtime_net_income * Decimal("52") / Decimal("12")

    result = {
        "net_hourly_rate": round(net_hourly_rate, 2),
        "weekly_overtime_net_income": round(weekly_overtime_net_income, 2),
        "monthly_overtime_net_income": round(monthly_overtime_net_income, 2),
        "total_hours_needed": None,
        "months_to_complete_standard": None,
        "months_to_complete_with_overtime": None,
        "months_saved": None,
    }

    remaining_amount = Decimal("0.00")
    has_target = False

    if payload.subgoal_id:
        subgoal = get_subgoal(user, payload.goal_id, payload.subgoal_id) if payload.goal_id else None
        # subgoal_id can be supplied without goal_id in the request schema; resolve via a
        # direct ownership check when goal_id isn't given.
        if subgoal is None:
            from apps.goals.services import get_subgoal_by_id
            sg = get_subgoal_by_id(user, payload.subgoal_id)
            remaining_amount = sg.target_amount - sg.current_amount
        else:
            remaining_amount = subgoal.target_amount - subgoal.current_amount
        has_target = True
    elif payload.goal_id:
        goal = get_goal(user, payload.goal_id)
        remaining_amount = goal.target_amount - goal.current_amount
        has_target = True

    if has_target:
        remaining_amount = max(Decimal("0.00"), remaining_amount)

        if net_hourly_rate > 0:
            result["total_hours_needed"] = round(remaining_amount / net_hourly_rate, 2)

        std_contrib = payload.standard_contribution

        if std_contrib > 0:
            result["months_to_complete_standard"] = round(remaining_amount / std_contrib, 2)
            total_monthly = std_contrib + monthly_overtime_net_income
            result["months_to_complete_with_overtime"] = round(remaining_amount / total_monthly, 2)
            result["months_saved"] = round(
                result["months_to_complete_standard"] - result["months_to_complete_with_overtime"], 2
            )
        elif monthly_overtime_net_income > 0:
            result["months_to_complete_with_overtime"] = round(remaining_amount / monthly_overtime_net_income, 2)

    return result
