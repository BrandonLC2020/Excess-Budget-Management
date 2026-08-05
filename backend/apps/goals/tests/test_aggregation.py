import pytest
from decimal import Decimal
from apps.users.models import User
from apps.accounts.services import create_account
from apps.goals.services import create_goal, create_subgoal, delete_subgoal, link_account, get_goal
from apps.accounts.schemas import AccountIn
from apps.goals.schemas import GoalIn, SubgoalIn


@pytest.fixture
def u(db):
    return User.objects.create_user(email="a@b.co", password="x" * 12)


def _goal_payload(**overrides):
    defaults = dict(name="g", target_amount=Decimal("0"), target_date=None,
                    type="short_term", category="savings")
    defaults.update(overrides)
    return GoalIn(**defaults)


def _subgoal_payload(**overrides):
    defaults = dict(name="s", target_amount=Decimal("10"), current_amount=Decimal("0"))
    defaults.update(overrides)
    return SubgoalIn(**defaults)


def test_subgoals_aggregate_to_parent(u):
    g = create_goal(u, _goal_payload(name="Vacation", type="short_term", category="purchase"))
    create_subgoal(u, g.id, _subgoal_payload(name="Flights", target_amount=Decimal("500"), current_amount=Decimal("100")))
    create_subgoal(u, g.id, _subgoal_payload(name="Hotel", target_amount=Decimal("700"), current_amount=Decimal("0")))

    refreshed = get_goal(u, g.id)
    assert refreshed.target_amount == Decimal("1200.00")
    assert refreshed.current_amount == Decimal("100.00")


def test_subgoal_delete_recomputes_parent(u):
    g = create_goal(u, _goal_payload(type="short_term", category="savings"))
    s1 = create_subgoal(u, g.id, _subgoal_payload(name="a", target_amount=Decimal("10"), current_amount=Decimal("5")))
    create_subgoal(u, g.id, _subgoal_payload(name="b", target_amount=Decimal("20"), current_amount=Decimal("0")))

    delete_subgoal(u, g.id, s1.id)

    refreshed = get_goal(u, g.id)
    assert refreshed.target_amount == Decimal("20.00")
    assert refreshed.current_amount == Decimal("0.00")


def test_linked_accounts_drive_goal_current(u):
    g = create_goal(u, _goal_payload(name="Emergency", target_amount=Decimal("1000"),
                                     type="long_term", category="savings"))
    a1 = create_account(u, AccountIn(name="Sav1", balance=Decimal("300")))
    a2 = create_account(u, AccountIn(name="Sav2", balance=Decimal("400")))

    link_account(u, g.id, a1.id)
    link_account(u, g.id, a2.id)

    refreshed = get_goal(u, g.id)
    assert refreshed.current_amount == Decimal("700.00")


def test_account_balance_change_propagates(u):
    from apps.accounts.services import update_account
    from apps.accounts.schemas import AccountPatch

    g = create_goal(u, _goal_payload(type="long_term", category="savings"))
    a = create_account(u, AccountIn(name="x", balance=Decimal("100")))
    link_account(u, g.id, a.id)

    update_account(u, a.id, AccountPatch(balance=Decimal("250")))

    refreshed = get_goal(u, g.id)
    assert refreshed.current_amount == Decimal("250.00")
