from .firestore import get_client
from .exceptions import NotFoundError


def get_owned_or_404_fs(collection: str, doc_id, user):
    """Fetch a Firestore document snapshot owned by `user`, or raise NotFoundError.
    Firestore-backed counterpart to apps/common/permissions.py::get_owned_or_404."""
    snapshot = get_client().collection(collection).document(str(doc_id)).get()
    if not snapshot.exists or snapshot.to_dict().get("user_id") != str(user.id):
        raise NotFoundError(f"{collection} not found.")
    return snapshot
