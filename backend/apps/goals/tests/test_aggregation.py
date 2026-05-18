import pytest
from decimal import Decimal
from apps.users.models import User
from apps.accounts.models import Account
from apps.goals.models import Goal, Subgoal, GoalAccount


@pytest.fixture
def u(db):
    return User.objects.create_user(email="a@b.co", password="x" * 12)


@pytest.mark.django_db
def test_subgoals_aggregate_to_parent(u):
    g = Goal.objects.create(user=u, name="Vacation", target_amount=0, type="short_term", category="purchase")
    Subgoal.objects.create(user=u, goal=g, name="Flights", target_amount=Decimal("500"), current_amount=Decimal("100"))
    Subgoal.objects.create(user=u, goal=g, name="Hotel",   target_amount=Decimal("700"), current_amount=Decimal("0"))
    g.refresh_from_db()
    assert g.target_amount == Decimal("1200.00")
    assert g.current_amount == Decimal("100.00")


@pytest.mark.django_db
def test_subgoal_delete_recomputes_parent(u):
    g = Goal.objects.create(user=u, name="g", target_amount=0, type="short_term", category="savings")
    s1 = Subgoal.objects.create(user=u, goal=g, name="a", target_amount=Decimal("10"), current_amount=Decimal("5"))
    Subgoal.objects.create(user=u, goal=g, name="b", target_amount=Decimal("20"), current_amount=Decimal("0"))
    s1.delete()
    g.refresh_from_db()
    assert g.target_amount == Decimal("20.00")
    assert g.current_amount == Decimal("0.00")


@pytest.mark.django_db
def test_linked_accounts_drive_goal_current(u):
    g = Goal.objects.create(user=u, name="Emergency", target_amount=Decimal("1000"),
                            type="long_term", category="savings")
    a1 = Account.objects.create(user=u, name="Sav1", balance=Decimal("300"))
    a2 = Account.objects.create(user=u, name="Sav2", balance=Decimal("400"))
    GoalAccount.objects.create(user=u, goal=g, account=a1)
    GoalAccount.objects.create(user=u, goal=g, account=a2)
    g.refresh_from_db()
    assert g.current_amount == Decimal("700.00")


@pytest.mark.django_db
def test_account_balance_change_propagates(u):
    g = Goal.objects.create(user=u, name="g", target_amount=0, type="long_term", category="savings")
    a = Account.objects.create(user=u, name="x", balance=Decimal("100"))
    GoalAccount.objects.create(user=u, goal=g, account=a)
    a.balance = Decimal("250")
    a.save()
    g.refresh_from_db()
    assert g.current_amount == Decimal("250.00")
