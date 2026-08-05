import pytest
from unittest.mock import patch
from decimal import Decimal
from apps.users.models import Profile
from apps.goals.services import create_goal
from apps.goals.schemas import GoalIn


@pytest.mark.django_db
def test_generate_requires_auth():
    from django.test import Client

    assert (
        Client()
        .post(
            "/api/v1/suggestions/generate",
            data={"excess_funds": "100.00"},
            content_type="application/json",
        )
        .status_code
        == 401
    )


@pytest.mark.django_db
def test_generate_returns_suggestion_and_persists_audit(auth_client):
    client, user = auth_client
    Profile.objects.update_or_create(
        user=user, defaults={"default_savings_ratio": Decimal("0.5")}
    )
    create_goal(
        user,
        GoalIn(
            name="Vacation",
            target_amount=Decimal("1000"),
            type="short_term",
            category="purchase",
        ),
    )

    fake_response = {
        "suggestions": [{"goalName": "Vacation", "amount": 100}],
        "reasoning": "Vacation funds short-term gratification.",
    }
    with patch("apps.suggestions.services.call_gemini", return_value=fake_response):
        r = client.post(
            "/api/v1/suggestions/generate",
            data={"excess_funds": "100.00"},
            content_type="application/json",
        )
    assert r.status_code == 200
    assert r.json()["reasoning"].startswith("Vacation funds")
    from apps.common.firestore import get_client
    from apps.suggestions.services import COLLECTION

    docs = list(
        get_client().collection(COLLECTION).where("user_id", "==", str(user.id)).stream()
    )
    assert len(docs) == 1


@pytest.mark.django_db
def test_generate_maps_gemini_failure_to_502(auth_client):
    client, _ = auth_client
    from apps.common.exceptions import UpstreamError

    def boom(*_a, **_kw):
        raise UpstreamError("Gemini unavailable")

    with patch("apps.suggestions.services.call_gemini", side_effect=boom):
        r = client.post(
            "/api/v1/suggestions/generate",
            data={"excess_funds": "100.00"},
            content_type="application/json",
        )
    assert r.status_code == 502
    assert r.json()["error"]["code"] == "upstream_error"
