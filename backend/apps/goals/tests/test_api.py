import pytest


@pytest.mark.django_db
def test_create_goal_happy_path(auth_client):
    client, _ = auth_client
    r = client.post(
        "/api/v1/goals",
        data={"name": "Vacation Fund", "target_amount": "2000.00", "type": "short_term", "category": "savings"},
        content_type="application/json",
    )
    assert r.status_code == 201, r.content
    body = r.json()
    assert body["name"] == "Vacation Fund"
    assert body["target_amount"] == "2000.00"
    assert body["type"] == "short_term"
    assert body["category"] == "savings"
    assert "id" in body


@pytest.mark.django_db
def test_cross_user_goal_returns_404(auth_client, other_auth_client):
    a_client, _ = auth_client
    b_client, _ = other_auth_client
    created = a_client.post(
        "/api/v1/goals",
        data={"name": "Secret Goal", "type": "long_term", "category": "savings"},
        content_type="application/json",
    ).json()
    r = b_client.get(f"/api/v1/goals/{created['id']}")
    assert r.status_code == 404


@pytest.mark.django_db
def test_subgoal_under_wrong_goal_returns_404(auth_client):
    """A subgoal of goal A cannot be accessed via /goals/B/subgoals/{id}."""
    import json
    client, _ = auth_client
    g1 = client.post("/api/v1/goals", data=json.dumps({"name": "G1", "type": "short_term", "category": "savings"}),
                     content_type="application/json").json()
    g2 = client.post("/api/v1/goals", data=json.dumps({"name": "G2", "type": "short_term", "category": "savings"}),
                     content_type="application/json").json()
    s = client.post(f"/api/v1/goals/{g1['id']}/subgoals",
                    data=json.dumps({"name": "A", "target_amount": "10.00"}),
                    content_type="application/json").json()
    # Subgoal s belongs to g1; accessing via g2 must 404
    r = client.patch(f"/api/v1/goals/{g2['id']}/subgoals/{s['id']}",
                     data=json.dumps({"name": "Updated"}),
                     content_type="application/json")
    assert r.status_code == 404, r.content
