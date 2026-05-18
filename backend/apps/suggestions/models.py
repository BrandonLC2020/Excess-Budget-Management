import uuid
from django.conf import settings
from django.db import models


class AllocationSuggestion(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="allocation_suggestions",
    )
    excess_funds = models.DecimalField(max_digits=12, decimal_places=2)
    response_json = models.JSONField()
    created_at = models.DateTimeField(auto_now_add=True)
