from decimal import Decimal, ROUND_HALF_UP
from django.db.models import Sum
from apps.accounts.models import Account
from apps.goals.models import Goal
from apps.budget.models import BudgetCategory

_TWO_PLACES = Decimal("0.01")


def dashboard_summary(user) -> dict:
    def s(qs, field):
        val = qs.aggregate(t=Sum(field))["t"] or Decimal("0")
        return val.quantize(_TWO_PLACES, rounding=ROUND_HALF_UP)

    return {
        "total_balance":        s(Account.objects.filter(user=user), "balance"),
        "goals_total_target":   s(Goal.objects.filter(user=user), "target_amount"),
        "goals_total_current":  s(Goal.objects.filter(user=user), "current_amount"),
        "budgets_total_limit":  s(BudgetCategory.objects.filter(user=user), "limit_amount"),
        "budgets_total_spent":  s(BudgetCategory.objects.filter(user=user), "spent_amount"),
    }
