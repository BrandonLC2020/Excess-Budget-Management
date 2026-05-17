"""
Root conftest.py.

Sets required env-vars and trims INSTALLED_APPS so the test suite can run
while later app packages are still being built in subsequent tasks.
"""

import os

# Must be set before Django loads settings (settings.py does os.environ["DJANGO_SECRET_KEY"])
os.environ.setdefault("DJANGO_SECRET_KEY", "test-only-secret-key-not-for-production")
