from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Subgoal, GoalAccount
from .services import recompute_parent_totals, recompute_goal_from_accounts


@receiver(post_save, sender=Subgoal)
def _subgoal_saved(sender, instance, **_):
    recompute_parent_totals(instance.goal_id)


@receiver(post_delete, sender=Subgoal)
def _subgoal_deleted(sender, instance, **_):
    recompute_parent_totals(instance.goal_id)


@receiver(post_save, sender=GoalAccount)
def _goal_account_added(sender, instance, **_):
    recompute_goal_from_accounts(instance.goal_id)


@receiver(post_delete, sender=GoalAccount)
def _goal_account_removed(sender, instance, **_):
    recompute_goal_from_accounts(instance.goal_id)
