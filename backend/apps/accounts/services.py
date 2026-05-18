from .models import Account
from apps.common.permissions import get_owned_or_404


def list_accounts(user):
    return list(Account.objects.filter(user=user))


def create_account(user, payload) -> Account:
    return Account.objects.create(user=user, name=payload.name, balance=payload.balance)


def get_account(user, account_id) -> Account:
    return get_owned_or_404(Account, account_id, user)


def update_account(user, account_id, payload) -> Account:
    acc = get_owned_or_404(Account, account_id, user)
    if payload.name is not None:
        acc.name = payload.name
    if payload.balance is not None:
        acc.balance = payload.balance
    acc.save()
    return acc


def delete_account(user, account_id) -> None:
    acc = get_owned_or_404(Account, account_id, user)
    acc.delete()
