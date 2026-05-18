import uuid
from django.conf import settings
from django.db import models


class BudgetCategory(models.Model):
    EXPENSE = "expense"
    INCOME = "income"
    TYPE_CHOICES = [(EXPENSE, "expense"), (INCOME, "income")]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="budget_categories",
    )
    name = models.CharField(max_length=200)
    limit_amount = models.DecimalField(max_digits=12, decimal_places=2)
    spent_amount = models.DecimalField(max_digits=12, decimal_places=2, default="0.00")
    icon_code = models.IntegerField(null=True, blank=True)
    color_hex = models.CharField(max_length=9, null=True, blank=True)
    category_type = models.CharField(max_length=10, choices=TYPE_CHOICES, default=EXPENSE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
