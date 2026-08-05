import pytest
from decimal import Decimal
from datetime import date
from apps.users.models import User
from apps.accounts.services import create_account, get_account
from apps.accounts.schemas import AccountIn
from apps.budget.services import create_category, get_category
from apps.budget.schemas import BudgetCategoryIn
from apps.expenses.services import create_expense, delete_expense
from apps.expenses.schemas import ExpenseIn
from apps.income.services import create_extra
from apps.income.schemas import ExtraIncomeIn


@pytest.fixture
def u(db):
    return User.objects.create_user(email="a@b.co", password="x" * 12)


def test_expense_increments_expense_category_spent(u):
    cat = create_category(u, BudgetCategoryIn(name="Food", limit_amount=Decimal("100"), category_type="expense"))
    create_expense(u, ExpenseIn(budget_category_id=cat.id, amount=Decimal("30"), date=date.today()))

    refreshed = get_category(u, cat.id)
    assert refreshed.spent_amount == Decimal("30.00")


def test_expense_against_income_category_decrements_spent(u):
    cat = create_category(u, BudgetCategoryIn(name="Bonus pool", limit_amount=Decimal("0"), category_type="income"))
    create_expense(u, ExpenseIn(budget_category_id=cat.id, amount=Decimal("50"), date=date.today()))

    refreshed = get_category(u, cat.id)
    assert refreshed.spent_amount == Decimal("-50.00")


def test_expense_decrements_account_balance(u):
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("100")))
    cat = create_category(u, BudgetCategoryIn(name="Food", limit_amount=Decimal("100"), category_type="expense"))
    create_expense(u, ExpenseIn(account_id=acc.id, budget_category_id=cat.id, amount=Decimal("30"), date=date.today()))

    refreshed = get_account(u, acc.id)
    assert refreshed.balance == Decimal("70.00")


def test_expense_delete_reverses_both(u):
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("100")))
    cat = create_category(u, BudgetCategoryIn(name="Food", limit_amount=Decimal("100"), category_type="expense"))
    expense = create_expense(u, ExpenseIn(account_id=acc.id, budget_category_id=cat.id,
                                          amount=Decimal("30"), date=date.today()))

    delete_expense(u, expense.id)

    assert get_account(u, acc.id).balance == Decimal("100.00")
    assert get_category(u, cat.id).spent_amount == Decimal("0.00")


def test_extra_income_credits_account_and_budget(u):
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("100")))
    cat = create_category(u, BudgetCategoryIn(name="Side gig", limit_amount=Decimal("0"), category_type="income"))
    create_extra(u, ExtraIncomeIn(amount=Decimal("50"), date_received=date.today(),
                                  account_id=acc.id, budget_category_id=cat.id))

    assert get_account(u, acc.id).balance == Decimal("150.00")
    assert get_category(u, cat.id).spent_amount == Decimal("50.00")
