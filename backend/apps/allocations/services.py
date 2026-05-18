from datetime import timedelta
from decimal import Decimal
from django.db.models import Sum
from django.utils import timezone
from .models import GoalAllocation
from apps.common.permissions import get_owned_or_404
from apps.common.exceptions import AppError
from apps.goals.models import Goal, Subgoal
from apps.accounts.models import Account


def list_allocations(user, goal_id=None):
    qs = GoalAllocation.objects.filter(user=user)
    if goal_id:
        qs = qs.filter(goal_id=goal_id)
    return list(qs)


def create_allocation(user, payload) -> GoalAllocation:
    goal = get_owned_or_404(Goal, payload.goal_id, user)

    sub_goal = None
    if payload.sub_goal_id is not None:
        sub_goal = get_owned_or_404(Subgoal, payload.sub_goal_id, user)
        if sub_goal.goal_id != goal.id:
            raise AppError(
                code="subgoal_goal_mismatch",
                message="The sub_goal does not belong to the specified goal.",
                status_code=400,
            )

    account = None
    if payload.account_id is not None:
        account = get_owned_or_404(Account, payload.account_id, user)

    return GoalAllocation.objects.create(
        user=user,
        goal=goal,
        sub_goal=sub_goal,
        account=account,
        amount=payload.amount,
    )


def get_allocation(user, allocation_id) -> GoalAllocation:
    return get_owned_or_404(GoalAllocation, allocation_id, user)


def update_allocation(user, allocation_id, payload) -> GoalAllocation:
    allocation = get_owned_or_404(GoalAllocation, allocation_id, user)

    if payload.goal_id is not None:
        allocation.goal = get_owned_or_404(Goal, payload.goal_id, user)

    if payload.sub_goal_id is not None:
        sub_goal = get_owned_or_404(Subgoal, payload.sub_goal_id, user)
        if sub_goal.goal_id != allocation.goal_id:
            raise AppError(
                code="subgoal_goal_mismatch",
                message="The sub_goal does not belong to the specified goal.",
                status_code=400,
            )
        allocation.sub_goal = sub_goal
    elif "sub_goal_id" in payload.model_fields_set and payload.sub_goal_id is None:
        allocation.sub_goal = None

    if payload.account_id is not None:
        allocation.account = get_owned_or_404(Account, payload.account_id, user)
    elif "account_id" in payload.model_fields_set and payload.account_id is None:
        allocation.account = None

    if payload.amount is not None:
        allocation.amount = payload.amount

    allocation.save()
    return allocation


def delete_allocation(user, allocation_id) -> None:
    allocation = get_owned_or_404(GoalAllocation, allocation_id, user)
    allocation.delete()


def recent_allocation_summary(user, days: int = 30) -> dict:
    since = timezone.now() - timedelta(days=days)
    qs = GoalAllocation.objects.filter(user=user, created_at__gt=since)
    by_category = qs.values("goal__category").annotate(total=Sum("amount"))
    totals = {row["goal__category"]: row["total"] or Decimal("0") for row in by_category}
    return {
        "totalSavings": float(totals.get("savings", Decimal("0"))),
        "totalPurchases": float(totals.get("purchase", Decimal("0"))),
    }
