import pytest
from decimal import Decimal
from apps.accounts.models import Account
from apps.goals.models import Goal
from apps.budget.models import BudgetCategory


@pytest.mark.django_db
def test_dashboard_summary_returns_aggregates(auth_client):
    client, user = auth_client
    Account.objects.create(user=user, name="Chk", balance=Decimal("100"))
    Account.objects.create(user=user, name="Sav", balance=Decimal("400"))
    Goal.objects.create(user=user, name="g", target_amount=Decimal("1000"),
                        current_amount=Decimal("250"), type="long_term", category="savings")
    BudgetCategory.objects.create(user=user, name="Food", limit_amount=Decimal("500"),
                                  spent_amount=Decimal("125"), category_type="expense")
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
