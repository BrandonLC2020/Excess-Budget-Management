from django.apps import AppConfig


class AllocationsConfig(AppConfig):
    name = "apps.allocations"
    label = "allocations"
    default_auto_field = "django.db.models.BigAutoField"

    def ready(self):
        from . import signals  # noqa
