"""
Root conftest.py.

Sets required env-vars and trims INSTALLED_APPS so the test suite can run
while later app packages are still being built in subsequent tasks.
"""

import os

# Must be set before Django loads settings (settings.py does os.environ["DJANGO_SECRET_KEY"])
os.environ.setdefault("DJANGO_SECRET_KEY", "test-only-secret-key-not-for-production")

import pytest
from django.test import Client
from apps.users.models import User
from apps.users.services import issue_tokens

import urllib.request


@pytest.fixture(scope="session", autouse=True)
def _require_firestore_emulator():
    if not os.environ.get("FIRESTORE_EMULATOR_HOST"):
        pytest.exit(
            "FIRESTORE_EMULATOR_HOST is not set. Start the emulator "
            "(`make up`, or `docker compose -f backend/docker-compose.yml up firestore`) "
            "before running tests.",
            returncode=1,
        )


@pytest.fixture(autouse=True)
def _wipe_firestore():
    from apps.common.firestore import get_client

    host = os.environ["FIRESTORE_EMULATOR_HOST"]
    project = get_client().project
    url = f"http://{host}/emulator/v1/projects/{project}/databases/(default)/documents"
    urllib.request.urlopen(urllib.request.Request(url, method="DELETE"))
    yield


@pytest.fixture
def user(db):
    return User.objects.create_user(email="alice@example.com", password="alicepass!")

@pytest.fixture
def other_user(db):
    return User.objects.create_user(email="bob@example.com", password="bobpass!!")

@pytest.fixture
def auth_client(user):
    tokens = issue_tokens(user)
    client = Client(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    return client, user

@pytest.fixture
def other_auth_client(other_user):
    tokens = issue_tokens(other_user)
    client = Client(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    return client, other_user
