from django.apps import AppConfig


class GoalsConfig(AppConfig):
    name = "apps.goals"
    label = "goals"
    default_auto_field = "django.db.models.BigAutoField"

    def ready(self):
        from . import signals  # noqa
