from .models import IncomeSource, ExtraIncome
from apps.common.permissions import get_owned_or_404
from apps.accounts.models import Account
from apps.budget.models import BudgetCategory


# ── IncomeSource ──────────────────────────────────────────────────────────────

def list_sources(user):
    return list(IncomeSource.objects.filter(user=user))


def create_source(user, payload) -> IncomeSource:
    return IncomeSource.objects.create(
        user=user,
        name=payload.name,
        expected_amount=payload.expected_amount,
        frequency=payload.frequency,
    )


def get_source(user, source_id) -> IncomeSource:
    return get_owned_or_404(IncomeSource, source_id, user)


def update_source(user, source_id, payload) -> IncomeSource:
    src = get_owned_or_404(IncomeSource, source_id, user)
    if payload.name is not None:
        src.name = payload.name
    if payload.expected_amount is not None:
        src.expected_amount = payload.expected_amount
    if payload.frequency is not None:
        src.frequency = payload.frequency
    src.save()
    return src


def delete_source(user, source_id) -> None:
    src = get_owned_or_404(IncomeSource, source_id, user)
    src.delete()


# ── ExtraIncome ───────────────────────────────────────────────────────────────

def list_extra(user, account_id=None, budget_category_id=None):
    qs = ExtraIncome.objects.filter(user=user)
    if account_id:
        qs = qs.filter(account_id=account_id)
    if budget_category_id:
        qs = qs.filter(budget_category_id=budget_category_id)
    return list(qs)


def create_extra(user, payload) -> ExtraIncome:
    account = None
    if payload.account_id is not None:
        account = get_owned_or_404(Account, payload.account_id, user)

    budget_category = None
    if payload.budget_category_id is not None:
        budget_category = get_owned_or_404(BudgetCategory, payload.budget_category_id, user)

    return ExtraIncome.objects.create(
        user=user,
        amount=payload.amount,
        description=payload.description,
        date_received=payload.date_received,
        account=account,
        budget_category=budget_category,
    )


def get_extra(user, extra_id) -> ExtraIncome:
    return get_owned_or_404(ExtraIncome, extra_id, user)


def update_extra(user, extra_id, payload) -> ExtraIncome:
    ei = get_owned_or_404(ExtraIncome, extra_id, user)
    if payload.amount is not None:
        ei.amount = payload.amount
    if payload.description is not None:
        ei.description = payload.description
    if payload.date_received is not None:
        ei.date_received = payload.date_received
    if payload.account_id is not None:
        ei.account = get_owned_or_404(Account, payload.account_id, user)
    elif "account_id" in payload.model_fields_set and payload.account_id is None:
        # Explicit null clears the link
        ei.account = None

    if payload.budget_category_id is not None:
        ei.budget_category = get_owned_or_404(BudgetCategory, payload.budget_category_id, user)
    elif "budget_category_id" in payload.model_fields_set and payload.budget_category_id is None:
        # Explicit null clears the link
        ei.budget_category = None

    ei.save()
    return ei


def delete_extra(user, extra_id) -> None:
    ei = get_owned_or_404(ExtraIncome, extra_id, user)
    ei.delete()
