import uuid
from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models


class Account(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="accounts")
    name = models.CharField(max_length=200)
    balance = models.DecimalField(max_digits=12, decimal_places=2, default="0.00",
                                  validators=[MinValueValidator(0)])
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
