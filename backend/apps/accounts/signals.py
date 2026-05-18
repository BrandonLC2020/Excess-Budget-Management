from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Account


@receiver(post_save, sender=Account)
def _account_saved(sender, instance, created, update_fields=None, **_):
    if update_fields is not None and "balance" not in update_fields and not created:
        return
    from apps.goals.services import recompute_goal_from_accounts
    for goal_id in instance.goal_accounts.values_list("goal_id", flat=True):
        recompute_goal_from_accounts(goal_id)
