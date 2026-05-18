"""
Test-only Django settings.

Imported by pytest via DJANGO_SETTINGS_MODULE=config.settings_test.
Provides all required defaults so tests run without a .env file, and keeps
INSTALLED_APPS to the apps that actually exist so far.  As later tasks land
and add more app packages, this file stays in sync automatically via the
dynamic import below.
"""

import os

# Provide defaults for any required env-vars before the real settings module loads
os.environ.setdefault("DJANGO_SECRET_KEY", "test-only-secret-key-not-for-production")

# Import everything from the main settings module
from config.settings import *  # noqa: F401, F403, E402

# Override only the parts that differ for the test environment
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Local apps — add here as each task lands:
    "apps.common",
    "apps.users",
    "apps.accounts",
    "apps.income",
    "apps.budget",
    "apps.goals",
    "apps.expenses",
    "apps.allocations",
    "apps.suggestions",
]

AUTH_USER_MODEL = "users.User"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": ":memory:",
    }
}
