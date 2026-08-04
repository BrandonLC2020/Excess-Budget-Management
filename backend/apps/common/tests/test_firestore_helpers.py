import pytest
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.exceptions import NotFoundError


def test_get_client_returns_same_instance_on_repeat_calls():
    assert get_client() is get_client()


def test_get_owned_or_404_fs_returns_snapshot_when_owner_matches():
    get_client().collection("smoke").document("doc1").set({"user_id": "u1", "name": "x"})

    class U:
        id = "u1"

    snapshot = get_owned_or_404_fs("smoke", "doc1", U())
    assert snapshot.get("name") == "x"


def test_get_owned_or_404_fs_raises_when_owner_differs():
    get_client().collection("smoke").document("doc2").set({"user_id": "u1"})

    class U:
        id = "u2"

    with pytest.raises(NotFoundError):
        get_owned_or_404_fs("smoke", "doc2", U())


def test_get_owned_or_404_fs_raises_when_doc_missing():
    class U:
        id = "u1"

    with pytest.raises(NotFoundError):
        get_owned_or_404_fs("smoke", "does-not-exist", U())
