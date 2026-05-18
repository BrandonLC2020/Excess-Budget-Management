from django.apps import AppConfig


class ExpensesConfig(AppConfig):
    name = "apps.expenses"
    label = "expenses"
    default_auto_field = "django.db.models.BigAutoField"

    def ready(self):
        from . import signals  # noqa
