import pytest
from datetime import date
from decimal import Decimal
from apps.users.models import User
from apps.accounts.services import create_account, delete_account, get_account
from apps.allocations.services import create_allocation, get_allocation
from apps.allocations.schemas import AllocationIn
from apps.budget.services import create_category
from apps.budget.schemas import BudgetCategoryIn
from apps.common.exceptions import NotFoundError
from apps.expenses.services import create_expense, get_expense
from apps.expenses.schemas import ExpenseIn
from apps.goals.services import (
    create_goal, create_subgoal, delete_goal, delete_subgoal, link_account, get_goal,
)
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


# --- on_delete parity (ported from Postgres CASCADE / SET_NULL) --------------

def test_goal_delete_cascades_allocations_and_reverses_balance(u):
    """Django: GoalAllocation.goal is on_delete=CASCADE, and the cascaded delete
    fires post_delete, which restores the debited account balance."""
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("500")))
    g = create_goal(u, _goal_payload(name="Car", type="short_term", category="purchase"))
    alloc = create_allocation(u, AllocationIn(goal_id=g.id, account_id=acc.id, amount=Decimal("200")))

    assert get_account(u, acc.id).balance == Decimal("300.00")

    delete_goal(u, g.id)

    with pytest.raises(NotFoundError):
        get_allocation(u, alloc.id)
    assert get_account(u, acc.id).balance == Decimal("500.00")


def test_subgoal_delete_set_nulls_allocations_without_deleting_them(u):
    """Django: GoalAllocation.sub_goal is on_delete=SET_NULL — the allocation
    survives (keeping its goal_id) and fires no post_delete signal."""
    g = create_goal(u, _goal_payload(type="short_term", category="savings"))
    s = create_subgoal(u, g.id, _subgoal_payload(name="Deposit", target_amount=Decimal("100")))
    alloc = create_allocation(u, AllocationIn(goal_id=g.id, sub_goal_id=s.id, amount=Decimal("40")))

    delete_subgoal(u, g.id, s.id)

    refreshed = get_allocation(u, alloc.id)
    assert refreshed.sub_goal_id is None
    assert refreshed.goal_id == g.id
    assert refreshed.amount == Decimal("40.00")


def test_account_delete_cascades_links_and_set_nulls_expenses(u):
    """Django: GoalAccount.account is on_delete=CASCADE (so the goal recomputes
    without it), while Expense.account is on_delete=SET_NULL."""
    acc = create_account(u, AccountIn(name="Sav", balance=Decimal("300")))
    g = create_goal(u, _goal_payload(name="Emergency", type="long_term", category="savings"))
    link_account(u, g.id, acc.id)

    assert get_goal(u, g.id).current_amount == Decimal("300.00")

    cat = create_category(u, BudgetCategoryIn(name="Food", limit_amount=Decimal("100"),
                                              category_type="expense"))
    expense = create_expense(u, ExpenseIn(budget_category_id=cat.id, account_id=acc.id,
                                          amount=Decimal("25"), date=date.today()))

    delete_account(u, acc.id)

    assert get_goal(u, g.id).current_amount == Decimal("0.00")
    surviving = get_expense(u, expense.id)
    assert surviving.account_id is None
    assert surviving.amount == Decimal("25.00")
