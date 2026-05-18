import pytest
from decimal import Decimal
from apps.users.models import User
from apps.accounts.models import Account
from apps.budget.models import BudgetCategory
from apps.expenses.models import Expense
from apps.income.models import ExtraIncome
from datetime import date


@pytest.fixture
def u(db):
    return User.objects.create_user(email="a@b.co", password="x" * 12)


@pytest.mark.django_db
def test_expense_increments_expense_category_spent(u):
    cat = BudgetCategory.objects.create(user=u, name="Food", limit_amount=Decimal("100"),
                                        category_type="expense")
    Expense.objects.create(user=u, budget_category=cat, amount=Decimal("30"), date=date.today())
    cat.refresh_from_db()
    assert cat.spent_amount == Decimal("30.00")


@pytest.mark.django_db
def test_expense_against_income_category_decrements_spent(u):
    cat = BudgetCategory.objects.create(user=u, name="Bonus pool", limit_amount=Decimal("0"),
                                        category_type="income")
    Expense.objects.create(user=u, budget_category=cat, amount=Decimal("50"), date=date.today())
    cat.refresh_from_db()
    assert cat.spent_amount == Decimal("-50.00")


@pytest.mark.django_db
def test_expense_decrements_account_balance(u):
    acc = Account.objects.create(user=u, name="Chk", balance=Decimal("100"))
    cat = BudgetCategory.objects.create(user=u, name="Food", limit_amount=Decimal("100"),
                                        category_type="expense")
    Expense.objects.create(user=u, account=acc, budget_category=cat, amount=Decimal("30"), date=date.today())
    acc.refresh_from_db()
    assert acc.balance == Decimal("70.00")


@pytest.mark.django_db
def test_expense_delete_reverses_both(u):
    acc = Account.objects.create(user=u, name="Chk", balance=Decimal("100"))
    cat = BudgetCategory.objects.create(user=u, name="Food", limit_amount=Decimal("100"),
                                        category_type="expense")
    e = Expense.objects.create(user=u, account=acc, budget_category=cat, amount=Decimal("30"), date=date.today())
    e.delete()
    acc.refresh_from_db()
    cat.refresh_from_db()
    assert acc.balance == Decimal("100.00")
    assert cat.spent_amount == Decimal("0.00")


@pytest.mark.django_db
def test_extra_income_credits_account_and_budget(u):
    acc = Account.objects.create(user=u, name="Chk", balance=Decimal("100"))
    cat = BudgetCategory.objects.create(user=u, name="Side gig", limit_amount=Decimal("0"),
                                        category_type="income")
    ExtraIncome.objects.create(user=u, amount=Decimal("50"), date_received=date.today(),
                               account=acc, budget_category=cat)
    acc.refresh_from_db()
    cat.refresh_from_db()
    assert acc.balance == Decimal("150.00")
    assert cat.spent_amount == Decimal("50.00")
