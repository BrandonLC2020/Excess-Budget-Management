import pytest
from apps.common.permissions import get_owned_or_404
from apps.common.exceptions import NotFoundError
from apps.users.models import User

@pytest.mark.django_db
def test_returns_object_when_owner_matches(django_user_model):
    u = User.objects.create_user(email="a@b.co", password="x" * 12)
    fetched = get_owned_or_404(User, u.id, u)
    assert fetched.id == u.id

@pytest.mark.django_db
def test_raises_not_found_when_owner_differs():
    u1 = User.objects.create_user(email="a@b.co", password="x" * 12)
    u2 = User.objects.create_user(email="c@d.co", password="x" * 12)
    with pytest.raises(NotFoundError):
        get_owned_or_404(User, u1.id, u2)

@pytest.mark.django_db
def test_raises_not_found_when_id_missing():
    u = User.objects.create_user(email="a@b.co", password="x" * 12)
    with pytest.raises(NotFoundError):
        get_owned_or_404(User, "00000000-0000-0000-0000-000000000000", u)
