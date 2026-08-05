import pytest
from decimal import Decimal
from apps.users.models import User
from apps.accounts.services import create_account, get_account
from apps.accounts.schemas import AccountIn
from apps.goals.services import create_goal, create_subgoal, get_goal
from apps.goals.schemas import GoalIn, SubgoalIn
from apps.allocations.services import create_allocation, delete_allocation, recent_allocation_summary
from apps.allocations.schemas import AllocationIn


@pytest.fixture
def u(db):
    return User.objects.create_user(email="a@b.co", password="x" * 12)


def test_allocation_debits_account_credits_goal(u):
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("500")))
    g = create_goal(u, GoalIn(name="g", target_amount=Decimal("1000"), target_date=None,
                              type="long_term", category="savings"))

    create_allocation(u, AllocationIn(goal_id=g.id, account_id=acc.id, amount=Decimal("200")))

    assert get_account(u, acc.id).balance == Decimal("300.00")
    assert get_goal(u, g.id).current_amount == Decimal("200.00")


def test_allocation_credits_subgoal_when_present(u):
    g = create_goal(u, GoalIn(name="g", target_amount=Decimal("0"), target_date=None,
                              type="short_term", category="purchase"))
    s = create_subgoal(u, g.id, SubgoalIn(name="Flights", target_amount=Decimal("500"),
                                          current_amount=Decimal("0")))

    create_allocation(u, AllocationIn(goal_id=g.id, sub_goal_id=s.id, amount=Decimal("100")))

    from apps.goals.services import get_subgoal
    refreshed_subgoal = get_subgoal(u, g.id, s.id)
    assert refreshed_subgoal.current_amount == Decimal("100.00")
    # parent rolls up via recompute_subgoal_parent, called from apply_allocation_effects
    assert get_goal(u, g.id).current_amount == Decimal("100.00")


def test_allocation_delete_reverses(u):
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("500")))
    g = create_goal(u, GoalIn(name="g", target_amount=Decimal("1000"), target_date=None,
                              type="long_term", category="savings"))

    allocation = create_allocation(u, AllocationIn(goal_id=g.id, account_id=acc.id, amount=Decimal("200")))
    delete_allocation(u, allocation.id)

    assert get_account(u, acc.id).balance == Decimal("500.00")
    assert get_goal(u, g.id).current_amount == Decimal("0.00")


def test_recent_summary_buckets_by_goal_category(u):
    g_sav = create_goal(u, GoalIn(name="s", target_amount=Decimal("0"), target_date=None,
                                  type="long_term", category="savings"))
    g_pur = create_goal(u, GoalIn(name="p", target_amount=Decimal("0"), target_date=None,
                                  type="short_term", category="purchase"))

    create_allocation(u, AllocationIn(goal_id=g_sav.id, amount=Decimal("100")))
    create_allocation(u, AllocationIn(goal_id=g_pur.id, amount=Decimal("40")))

    summary = recent_allocation_summary(u, days=30)
    assert summary == {"totalSavings": 100.0, "totalPurchases": 40.0}
