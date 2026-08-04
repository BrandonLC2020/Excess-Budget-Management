"""Explicit-call replacements for the Django signal receivers in
expenses/signals.py, allocations/signals.py, goals/signals.py, and
accounts/signals.py. Firestore has no signal dispatcher, so each app's
services.py calls these directly at the point its ORM .save()/.delete()
used to trigger a signal. Operates on raw collection names — no dependency
on any specific app's models.py or services.py, so this module can be
built and tested before any of the 8 apps are converted.
"""
from google.cloud import firestore
from .firestore import get_client


def _apply_to_balance(account_id: str | None, delta_cents: int) -> None:
    """Add delta_cents to accounts/{account_id}.balance. No-op if account_id is None."""
    if not account_id or delta_cents == 0:
        return
    get_client().collection("accounts").document(account_id).update(
        {"balance": firestore.Increment(delta_cents)}
    )


def _apply_to_budget(category_id: str | None, raw_delta_cents: int) -> None:
    """Apply raw_delta_cents to budget_categories/{category_id}.spent_amount.

    raw_delta_cents is treated as "expense semantics":
    - expense category: spent_amount += raw_delta_cents
    - income category:  spent_amount -= raw_delta_cents (sign flipped)
    """
    if not category_id or raw_delta_cents == 0:
        return
    doc_ref = get_client().collection("budget_categories").document(category_id)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        return
    category_type = snapshot.get("category_type")
    delta = raw_delta_cents if category_type == "expense" else -raw_delta_cents
    doc_ref.update({"spent_amount": firestore.Increment(delta)})


def apply_expense_effects(old: dict | None, new: dict | None) -> None:
    """Port of expenses/signals.py's Expense post_save/post_delete receivers.
    Pass old=None on create, new=None on delete, both on update."""
    if old is not None:
        _apply_to_balance(old["account_id"], old["amount_cents"])
        _apply_to_budget(old["budget_category_id"], -old["amount_cents"])
    if new is not None:
        _apply_to_balance(new["account_id"], -new["amount_cents"])
        _apply_to_budget(new["budget_category_id"], new["amount_cents"])


def apply_extra_income_effects(old: dict | None, new: dict | None) -> None:
    """Port of expenses/signals.py's ExtraIncome post_save/post_delete receivers
    (income credits balance/budget with signs mirrored from an expense)."""
    if old is not None:
        _apply_to_balance(old["account_id"], -old["amount_cents"])
        _apply_to_budget(old["budget_category_id"], old["amount_cents"])
    if new is not None:
        _apply_to_balance(new["account_id"], new["amount_cents"])
        _apply_to_budget(new["budget_category_id"], -new["amount_cents"])


def recompute_subgoal_parent(goal_id: str) -> None:
    """Port of goals/signals.py's Subgoal post_save/post_delete receivers:
    re-sum all sibling subgoals' target/current amounts onto the parent Goal."""
    client = get_client()
    subgoals = list(client.collection("sub_goals").where("goal_id", "==", goal_id).stream())
    if not subgoals:
        return
    target_total = sum(s.get("target_amount") for s in subgoals)
    current_total = sum(s.get("current_amount") for s in subgoals)
    client.collection("goals").document(goal_id).update(
        {"target_amount": target_total, "current_amount": current_total}
    )


def recompute_goal_from_accounts(goal_id: str) -> None:
    """Port of goals/signals.py's GoalAccount post_save/post_delete receivers
    (and reused by accounts/services.py's balance-change path): re-sum linked
    accounts' balances onto the Goal's current_amount."""
    client = get_client()
    links = list(client.collection("goal_accounts").where("goal_id", "==", goal_id).stream())
    total = 0
    for link in links:
        account = client.collection("accounts").document(link.get("account_id")).get()
        if account.exists:
            total += account.get("balance")
    client.collection("goals").document(goal_id).update({"current_amount": total})


def _apply_progress(sub_goal_id: str | None, goal_id: str, delta_cents: int) -> None:
    client = get_client()
    if sub_goal_id:
        client.collection("sub_goals").document(sub_goal_id).update(
            {"current_amount": firestore.Increment(delta_cents)}
        )
        recompute_subgoal_parent(goal_id)
    else:
        client.collection("goals").document(goal_id).update(
            {"current_amount": firestore.Increment(delta_cents)}
        )


def apply_allocation_effects(old: dict | None, new: dict | None) -> None:
    """Port of allocations/signals.py's GoalAllocation post_save/post_delete receivers."""
    if old is not None:
        _apply_to_balance(old["account_id"], old["amount_cents"])
        _apply_progress(old["sub_goal_id"], old["goal_id"], -old["amount_cents"])
    if new is not None:
        _apply_to_balance(new["account_id"], -new["amount_cents"])
        _apply_progress(new["sub_goal_id"], new["goal_id"], new["amount_cents"])
