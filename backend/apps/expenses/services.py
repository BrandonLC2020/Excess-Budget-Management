from .models import Expense
from apps.common.permissions import get_owned_or_404
from apps.accounts.models import Account
from apps.budget.models import BudgetCategory


def list_expenses(user, account_id=None):
    qs = Expense.objects.filter(user=user)
    if account_id:
        qs = qs.filter(account_id=account_id)
    return list(qs)


def create_expense(user, payload) -> Expense:
    category = get_owned_or_404(BudgetCategory, payload.budget_category_id, user)

    account = None
    if payload.account_id is not None:
        account = get_owned_or_404(Account, payload.account_id, user)

    return Expense.objects.create(
        user=user,
        budget_category=category,
        account=account,
        amount=payload.amount,
        description=payload.description,
        date=payload.date,
    )


def get_expense(user, expense_id) -> Expense:
    return get_owned_or_404(Expense, expense_id, user)


def update_expense(user, expense_id, payload) -> Expense:
    expense = get_owned_or_404(Expense, expense_id, user)

    if payload.budget_category_id is not None:
        expense.budget_category = get_owned_or_404(BudgetCategory, payload.budget_category_id, user)
    if payload.amount is not None:
        expense.amount = payload.amount
    if payload.description is not None:
        expense.description = payload.description
    if payload.date is not None:
        expense.date = payload.date

    if payload.account_id is not None:
        expense.account = get_owned_or_404(Account, payload.account_id, user)
    elif "account_id" in payload.model_fields_set and payload.account_id is None:
        expense.account = None

    expense.save()
    return expense


def delete_expense(user, expense_id) -> None:
    expense = get_owned_or_404(Expense, expense_id, user)
    expense.delete()
