import pytest
from decimal import Decimal
from apps.users.models import User
from apps.accounts.models import Account
from apps.goals.models import Goal, Subgoal
from apps.allocations.models import GoalAllocation


@pytest.fixture
def u(db):
    return User.objects.create_user(email="a@b.co", password="x" * 12)


@pytest.mark.django_db
def test_allocation_debits_account_credits_goal(u):
    acc = Account.objects.create(user=u, name="Chk", balance=Decimal("500"))
    g = Goal.objects.create(
        user=u,
        name="g",
        target_amount=Decimal("1000"),
        current_amount=0,
        type="long_term",
        category="savings",
    )
    GoalAllocation.objects.create(user=u, goal=g, account=acc, amount=Decimal("200"))
    acc.refresh_from_db()
    g.refresh_from_db()
    assert acc.balance == Decimal("300.00")
    assert g.current_amount == Decimal("200.00")


@pytest.mark.django_db
def test_allocation_credits_subgoal_when_present(u):
    g = Goal.objects.create(
        user=u, name="g", target_amount=0, type="short_term", category="purchase"
    )
    s = Subgoal.objects.create(
        user=u, goal=g, name="Flights", target_amount=Decimal("500")
    )
    GoalAllocation.objects.create(user=u, goal=g, sub_goal=s, amount=Decimal("100"))
    s.refresh_from_db()
    assert s.current_amount == Decimal("100.00")
    # parent rolls up via the Subgoal post_save signal (Task 12)
    g.refresh_from_db()
    assert g.current_amount == Decimal("100.00")


@pytest.mark.django_db
def test_allocation_delete_reverses(u):
    acc = Account.objects.create(user=u, name="Chk", balance=Decimal("500"))
    g = Goal.objects.create(
        user=u,
        name="g",
        target_amount=Decimal("1000"),
        current_amount=0,
        type="long_term",
        category="savings",
    )
    a = GoalAllocation.objects.create(
        user=u, goal=g, account=acc, amount=Decimal("200")
    )
    a.delete()
    acc.refresh_from_db()
    g.refresh_from_db()
    assert acc.balance == Decimal("500.00")
    assert g.current_amount == Decimal("0.00")
