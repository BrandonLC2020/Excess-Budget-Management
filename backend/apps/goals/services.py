from decimal import Decimal
from django.db.models import Sum
from .models import Goal, Subgoal, GoalAccount
from apps.accounts.models import Account
from apps.common.permissions import get_owned_or_404


# --- Aggregation helpers ---

def recompute_parent_totals(goal_id) -> None:
    qs = Subgoal.objects.filter(goal_id=goal_id)
    if not qs.exists():
        return
    agg = qs.aggregate(t=Sum("target_amount"), c=Sum("current_amount"))
    Goal.objects.filter(pk=goal_id).update(
        target_amount=agg["t"] or Decimal("0"),
        current_amount=agg["c"] or Decimal("0"),
    )


def recompute_goal_from_accounts(goal_id) -> None:
    total = (
        Account.objects.filter(goal_accounts__goal_id=goal_id).aggregate(s=Sum("balance"))["s"]
    ) or Decimal("0")
    Goal.objects.filter(pk=goal_id).update(current_amount=total)


# --- Goal CRUD ---

def list_goals(user):
    return list(Goal.objects.filter(user=user))


def create_goal(user, payload) -> Goal:
    return Goal.objects.create(
        user=user,
        name=payload.name,
        target_amount=payload.target_amount,
        target_date=payload.target_date,
        type=payload.type,
        category=payload.category,
    )


def get_goal(user, goal_id) -> Goal:
    return get_owned_or_404(Goal, goal_id, user)


def update_goal(user, goal_id, payload) -> Goal:
    goal = get_owned_or_404(Goal, goal_id, user)
    if payload.name is not None:
        goal.name = payload.name
    if payload.target_amount is not None:
        goal.target_amount = payload.target_amount
    if payload.target_date is not None:
        goal.target_date = payload.target_date
    if payload.type is not None:
        goal.type = payload.type
    if payload.category is not None:
        goal.category = payload.category
    goal.save()
    return goal


def delete_goal(user, goal_id) -> None:
    goal = get_owned_or_404(Goal, goal_id, user)
    goal.delete()


# --- Subgoal CRUD ---

def list_subgoals(user, goal_id):
    goal = get_owned_or_404(Goal, goal_id, user)
    return list(Subgoal.objects.filter(goal=goal))


def create_subgoal(user, goal_id, payload) -> Subgoal:
    goal = get_owned_or_404(Goal, goal_id, user)
    return Subgoal.objects.create(
        user=user,
        goal=goal,
        name=payload.name,
        target_amount=payload.target_amount,
        current_amount=payload.current_amount,
    )


def get_subgoal(user, goal_id, subgoal_id) -> Subgoal:
    goal = get_owned_or_404(Goal, goal_id, user)
    return get_owned_or_404(Subgoal, subgoal_id, user)


def update_subgoal(user, goal_id, subgoal_id, payload) -> Subgoal:
    get_owned_or_404(Goal, goal_id, user)
    subgoal = get_owned_or_404(Subgoal, subgoal_id, user)
    if payload.name is not None:
        subgoal.name = payload.name
    if payload.target_amount is not None:
        subgoal.target_amount = payload.target_amount
    if payload.current_amount is not None:
        subgoal.current_amount = payload.current_amount
    subgoal.save()
    return subgoal


def delete_subgoal(user, goal_id, subgoal_id) -> None:
    get_owned_or_404(Goal, goal_id, user)
    subgoal = get_owned_or_404(Subgoal, subgoal_id, user)
    subgoal.delete()


# --- GoalAccount (link/unlink) ---

def link_account(user, goal_id, account_id) -> GoalAccount:
    goal = get_owned_or_404(Goal, goal_id, user)
    account = get_owned_or_404(Account, account_id, user)
    ga, _ = GoalAccount.objects.get_or_create(user=user, goal=goal, account=account)
    return ga


def unlink_account(user, goal_id, account_id) -> None:
    goal = get_owned_or_404(Goal, goal_id, user)
    account = get_owned_or_404(Account, account_id, user)
    GoalAccount.objects.filter(goal=goal, account=account).delete()
