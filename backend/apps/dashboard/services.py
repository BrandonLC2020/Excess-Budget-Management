from decimal import Decimal, ROUND_HALF_UP
from apps.accounts.services import list_accounts
from apps.goals.services import list_goals
from apps.budget.services import list_categories

_TWO_PLACES = Decimal("0.01")


def _sum(items, attr) -> Decimal:
    total = sum((getattr(item, attr) for item in items), Decimal("0"))
    return total.quantize(_TWO_PLACES, rounding=ROUND_HALF_UP)


def dashboard_summary(user) -> dict:
    accounts = list_accounts(user)
    goals = list_goals(user)
    categories = list_categories(user)

    return {
        "total_balance":        _sum(accounts, "balance"),
        "goals_total_target":   _sum(goals, "target_amount"),
        "goals_total_current":  _sum(goals, "current_amount"),
        "budgets_total_limit":  _sum(categories, "limit_amount"),
        "budgets_total_spent":  _sum(categories, "spent_amount"),
    }
