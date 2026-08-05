import pytest
from decimal import Decimal
from apps.accounts.services import create_account
from apps.accounts.schemas import AccountIn
from apps.goals.services import create_goal, GOALS_COLLECTION
from apps.goals.schemas import GoalIn
from apps.budget.services import create_category, COLLECTION as BUDGET_COLLECTION
from apps.budget.schemas import BudgetCategoryIn
from apps.common.firestore import get_client
from apps.common.money import to_cents


@pytest.mark.django_db
def test_dashboard_summary_returns_aggregates(auth_client):
    client, user = auth_client
    create_account(user, AccountIn(name="Chk", balance=Decimal("100")))
    create_account(user, AccountIn(name="Sav", balance=Decimal("400")))

    goal = create_goal(user, GoalIn(name="g", target_amount=Decimal("1000"),
                                    type="long_term", category="savings"))
    # current_amount isn't settable via GoalIn/GoalPatch (it's derived from linked
    # accounts via recompute_goal_from_accounts), so write it directly, matching
    # the direct-Firestore-write pattern already used in
    # apps/suggestions/tests/test_api.py for fields with no service-layer setter.
    get_client().collection(GOALS_COLLECTION).document(str(goal.id)).update(
        {"current_amount": to_cents(Decimal("250"))}
    )

    category = create_category(user, BudgetCategoryIn(name="Food", limit_amount=Decimal("500"),
                                                       category_type="expense"))
    # spent_amount is likewise not settable via BudgetCategoryIn/Patch (create_category
    # always initializes it to 0), so write it directly for the same reason as above.
    get_client().collection(BUDGET_COLLECTION).document(str(category.id)).update(
        {"spent_amount": to_cents(Decimal("125"))}
    )

    r = client.get("/api/v1/dashboard/summary")
    assert r.status_code == 200
    body = r.json()
    assert body["total_balance"] == "500.00"
    assert body["goals_total_target"] == "1000.00"
    assert body["goals_total_current"] == "250.00"
    assert body["budgets_total_limit"] == "500.00"
    assert body["budgets_total_spent"] == "125.00"


@pytest.mark.django_db
def test_dashboard_requires_auth():
    from django.test import Client
    assert Client().get("/api/v1/dashboard/summary").status_code == 401
