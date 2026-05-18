from .models import IncomeSource, ExtraIncome
from apps.common.permissions import get_owned_or_404
from apps.accounts.models import Account


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

def list_extra(user):
    return list(ExtraIncome.objects.filter(user=user))


def create_extra(user, payload) -> ExtraIncome:
    account = None
    if payload.account_id is not None:
        account = get_owned_or_404(Account, payload.account_id, user)

    # TODO(Task 11): resolve budget_category_id once budget.BudgetCategory exists.
    # For now, budget_category_id is accepted in the schema but not persisted.

    return ExtraIncome.objects.create(
        user=user,
        amount=payload.amount,
        description=payload.description,
        date_received=payload.date_received,
        account=account,
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

    # TODO(Task 11): handle budget_category_id once budget.BudgetCategory exists.

    ei.save()
    return ei


def delete_extra(user, extra_id) -> None:
    ei = get_owned_or_404(ExtraIncome, extra_id, user)
    ei.delete()
