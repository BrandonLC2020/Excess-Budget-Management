import os
from functools import lru_cache
from google.cloud import firestore


@lru_cache(maxsize=1)
def get_client() -> firestore.Client:
    project = os.environ.get("GOOGLE_CLOUD_PROJECT", "excess-budget-dev")
    return firestore.Client(project=project)
