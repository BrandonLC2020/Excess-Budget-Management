import uuid
from django.conf import settings
from django.db import models


class GoalAllocation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    goal_id = models.UUIDField()
    sub_goal_id = models.UUIDField(null=True, blank=True)
    account_id = models.UUIDField(null=True, blank=True)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["account_id"]),
            models.Index(fields=["sub_goal_id"]),
            models.Index(fields=["user", "created_at"]),
        ]
