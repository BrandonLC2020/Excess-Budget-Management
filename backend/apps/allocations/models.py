import uuid
from django.conf import settings
from django.db import models


class GoalAllocation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    goal = models.ForeignKey(
        "goals.Goal", on_delete=models.CASCADE, related_name="allocations"
    )
    sub_goal = models.ForeignKey(
        "goals.Subgoal",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="allocations",
    )
    account = models.ForeignKey(
        "accounts.Account",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="allocations",
    )
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["account"]),
            models.Index(fields=["sub_goal"]),
            models.Index(fields=["user", "created_at"]),
        ]
