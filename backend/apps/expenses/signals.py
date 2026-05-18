from decimal import Decimal
from django.db import models as db_models
from django.db.models.signals import post_save, post_delete, pre_save
from django.dispatch import receiver
from apps.accounts.models import Account
from apps.budget.models import BudgetCategory
from apps.income.models import ExtraIncome
from .models import Expense


def _apply_to_balance(account_id, delta: Decimal):
    """Add delta to account.balance. Uses .update() to avoid signal recursion."""
    if not account_id or delta == 0:
        return
    Account.objects.filter(pk=account_id).update(
        balance=db_models.F("balance") + delta
    )


def _apply_to_budget(category_id, raw_delta: Decimal):
    """Apply raw_delta to BudgetCategory.spent_amount.

    raw_delta is treated as "expense semantics":
    - expense category: spent_amount += raw_delta
    - income category:  spent_amount -= raw_delta (sign flipped)
    """
    if not category_id or raw_delta == 0:
        return
    cat = BudgetCategory.objects.filter(pk=category_id).only("id", "category_type").first()
    if not cat:
        return
    delta = raw_delta if cat.category_type == "expense" else -raw_delta
    BudgetCategory.objects.filter(pk=category_id).update(
        spent_amount=db_models.F("spent_amount") + delta
    )


# ── Expense signals ───────────────────────────────────────────────────────────

@receiver(pre_save, sender=Expense)
def _expense_pre_save(sender, instance, **_):
    if instance.pk:
        instance._old = (
            sender.objects.filter(pk=instance.pk)
            .only("amount", "account_id", "budget_category_id")
            .first()
        )
    else:
        instance._old = None


@receiver(post_save, sender=Expense)
def _expense_post_save(sender, instance, created, **_):
    if created:
        _apply_to_balance(instance.account_id, -instance.amount)
        _apply_to_budget(instance.budget_category_id, instance.amount)
        return
    old = getattr(instance, "_old", None)
    if not old:
        return
    # Reverse old effects, then apply new.
    _apply_to_balance(old.account_id, old.amount)
    _apply_to_balance(instance.account_id, -instance.amount)
    _apply_to_budget(old.budget_category_id, -old.amount)
    _apply_to_budget(instance.budget_category_id, instance.amount)


@receiver(post_delete, sender=Expense)
def _expense_post_delete(sender, instance, **_):
    _apply_to_balance(instance.account_id, instance.amount)
    _apply_to_budget(instance.budget_category_id, -instance.amount)


# ── ExtraIncome signals ───────────────────────────────────────────────────────
# ExtraIncome is defined in apps.income but its rollup logic lives here.
# Signs are mirrored vs. Expense:
#   - balance: income ADDS (not subtracts)
#   - budget: we pass -amount as raw_delta so that:
#       income category: raw_delta=-amount → flipped to +amount (deposit into bucket)
#       expense category: raw_delta=-amount → stays -amount (reimbursement)

@receiver(pre_save, sender=ExtraIncome)
def _income_pre_save(sender, instance, **_):
    instance._old = (
        sender.objects.filter(pk=instance.pk)
        .only("amount", "account_id", "budget_category_id")
        .first()
        if instance.pk
        else None
    )


@receiver(post_save, sender=ExtraIncome)
def _income_post_save(sender, instance, created, **_):
    if created:
        _apply_to_balance(instance.account_id, instance.amount)
        _apply_to_budget(instance.budget_category_id, -instance.amount)
        return
    old = getattr(instance, "_old", None)
    if not old:
        return
    # Reverse old effects, then apply new.
    _apply_to_balance(old.account_id, -old.amount)
    _apply_to_balance(instance.account_id, instance.amount)
    _apply_to_budget(old.budget_category_id, old.amount)
    _apply_to_budget(instance.budget_category_id, -instance.amount)


@receiver(post_delete, sender=ExtraIncome)
def _income_post_delete(sender, instance, **_):
    _apply_to_balance(instance.account_id, -instance.amount)
    _apply_to_budget(instance.budget_category_id, instance.amount)
