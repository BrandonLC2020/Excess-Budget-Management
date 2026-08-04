import uuid
from django.conf import settings
from django.db import models


class IncomeSource(models.Model):
    FREQUENCY_CHOICES = [
        ("weekly", "weekly"),
        ("bi-weekly", "bi-weekly"),
        ("monthly", "monthly"),
        ("yearly", "yearly"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="income_sources",
    )
    name = models.CharField(max_length=200)
    expected_amount = models.DecimalField(max_digits=12, decimal_places=2)
    frequency = models.CharField(max_length=20, choices=FREQUENCY_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]


class ExtraIncome(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="extra_income",
    )
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    description = models.CharField(max_length=500, blank=True, default="")
    date_received = models.DateField()
    account_id = models.UUIDField(null=True, blank=True)
    budget_category = models.ForeignKey(
        "budget.BudgetCategory",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="extra_income",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date_received", "-created_at"]


class OvertimeSettings(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="overtime_settings",
    )
    hourly_base_rate = models.DecimalField(max_digits=12, decimal_places=2, default="0.00")
    overtime_multiplier = models.DecimalField(max_digits=4, decimal_places=2, default="1.50")
    estimated_tax_rate = models.DecimalField(max_digits=4, decimal_places=2, default="0.25")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name_plural = "Overtime Settings"

    def __str__(self) -> str:
        return f"Overtime settings for {self.user.email}"
