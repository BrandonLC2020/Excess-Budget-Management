from decimal import Decimal
from django.db import models as db_models
from django.db.models.signals import post_save, post_delete, pre_save
from django.dispatch import receiver
from apps.accounts.models import Account
from apps.goals.models import Goal, Subgoal
from .models import GoalAllocation


def _apply_to_balance(account_id, delta: Decimal):
    """Add delta to account.balance. Uses .update() to avoid signal recursion."""
    if not account_id or delta == 0:
        return
    Account.objects.filter(pk=account_id).update(
        balance=db_models.F("balance") + delta
    )


def _apply_to_subgoal(subgoal_id, delta: Decimal):
    """Update subgoal.current_amount using .save() to trigger the Task 12
    post_save signal that recomputes the parent goal's current_amount."""
    if not subgoal_id or delta == 0:
        return
    sg = Subgoal.objects.filter(pk=subgoal_id).first()
    if not sg:
        return
    sg.current_amount = sg.current_amount + delta
    sg.save(update_fields=["current_amount"])


def _apply_to_goal(goal_id, delta: Decimal):
    """Directly update goal.current_amount (no sub-goal involved)."""
    if not goal_id or delta == 0:
        return
    Goal.objects.filter(pk=goal_id).update(
        current_amount=db_models.F("current_amount") + delta
    )


def _apply_progress(sub_goal_id, goal_id, delta: Decimal):
    """Route progress delta to subgoal (which rolls up to parent) or goal directly."""
    if sub_goal_id:
        _apply_to_subgoal(sub_goal_id, delta)
    else:
        _apply_to_goal(goal_id, delta)


@receiver(pre_save, sender=GoalAllocation)
def _alloc_pre_save(sender, instance, **_):
    instance._old = (
        sender.objects.filter(pk=instance.pk)
        .only("amount", "account_id", "sub_goal_id", "goal_id")
        .first()
        if instance.pk
        else None
    )


@receiver(post_save, sender=GoalAllocation)
def _alloc_post_save(sender, instance, created, **_):
    if created:
        _apply_to_balance(instance.account_id, -instance.amount)
        _apply_progress(instance.sub_goal_id, instance.goal_id, instance.amount)
        return
    old = getattr(instance, "_old", None)
    if not old:
        return
    # Reverse old effects, then apply new.
    _apply_to_balance(old.account_id, old.amount)
    _apply_to_balance(instance.account_id, -instance.amount)
    _apply_progress(old.sub_goal_id, old.goal_id, -old.amount)
    _apply_progress(instance.sub_goal_id, instance.goal_id, instance.amount)


@receiver(post_delete, sender=GoalAllocation)
def _alloc_post_delete(sender, instance, **_):
    _apply_to_balance(instance.account_id, instance.amount)
    _apply_progress(instance.sub_goal_id, instance.goal_id, -instance.amount)
