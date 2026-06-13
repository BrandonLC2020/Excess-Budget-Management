import pytest


@pytest.mark.django_db
def test_create_and_list_income_source(auth_client):
    client, _ = auth_client
    r = client.post(
        "/api/v1/income/sources",
        data={"name": "Salary", "expected_amount": "5000.00", "frequency": "monthly"},
        content_type="application/json",
    )
    assert r.status_code == 201
    r2 = client.get("/api/v1/income/sources")
    assert [s["name"] for s in r2.json()] == ["Salary"]


@pytest.mark.django_db
def test_extra_income_with_account_link(auth_client):
    client, _ = auth_client
    acc = client.post(
        "/api/v1/accounts",
        data={"name": "Chk", "balance": "0.00"},
        content_type="application/json",
    ).json()
    r = client.post(
        "/api/v1/income/extra",
        data={
            "amount": "200.00",
            "description": "Refund",
            "date_received": "2026-05-17",
            "account_id": acc["id"],
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    assert r.json()["account_id"] == acc["id"]


@pytest.mark.django_db
def test_extra_income_with_budget_category(auth_client):
    client, _ = auth_client
    cat = client.post(
        "/api/v1/budget/categories",
        data={"name": "Side hustle", "limit_amount": "0.00", "category_type": "income"},
        content_type="application/json",
    ).json()
    r = client.post(
        "/api/v1/income/extra",
        data={
            "amount": "75.00",
            "description": "Freelance",
            "date_received": "2026-05-17",
            "budget_category_id": cat["id"],
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    assert r.json()["budget_category_id"] == cat["id"]


@pytest.mark.django_db
def test_cross_user_isolation(auth_client, other_auth_client):
    a, _ = auth_client
    b, _ = other_auth_client
    created = a.post(
        "/api/v1/income/sources",
        data={"name": "x", "expected_amount": "1.00", "frequency": "monthly"},
        content_type="application/json",
    ).json()
    assert b.get(f"/api/v1/income/sources/{created['id']}").status_code == 404


@pytest.mark.django_db
def test_get_and_update_overtime_settings(auth_client):
    client, _ = auth_client
    
    # Get defaults
    r = client.get("/api/v1/income/overtime/settings")
    assert r.status_code == 200
    res = r.json()
    assert res["hourly_base_rate"] == "0.00"
    assert res["overtime_multiplier"] == "1.50"
    assert res["estimated_tax_rate"] == "0.25"
    
    # Update settings
    r2 = client.patch(
        "/api/v1/income/overtime/settings",
        data={
            "hourly_base_rate": "40.00",
            "overtime_multiplier": "1.50",
            "estimated_tax_rate": "0.20",
        },
        content_type="application/json",
    )
    assert r2.status_code == 200
    res2 = r2.json()
    assert res2["hourly_base_rate"] == "40.00"
    assert res2["overtime_multiplier"] == "1.50"
    assert res2["estimated_tax_rate"] == "0.20"
    
    # Verify via get
    r3 = client.get("/api/v1/income/overtime/settings")
    assert r3.json()["hourly_base_rate"] == "40.00"


@pytest.mark.django_db
def test_overtime_projections_goal(auth_client):
    client, _ = auth_client
    
    # Configure settings
    client.patch(
        "/api/v1/income/overtime/settings",
        data={
            "hourly_base_rate": "50.00",
            "overtime_multiplier": "1.50",
            "estimated_tax_rate": "0.20",
        },
        content_type="application/json",
    )
    
    # Create goal (1200 target, 0 current)
    g = client.post(
        "/api/v1/goals",
        data={
            "name": "Europe Trip",
            "target_amount": "1200.00",
            "current_amount": "0.00",
            "type": "short_term",
            "category": "purchase",
        },
        content_type="application/json",
    ).json()
    
    # Get projections
    r = client.post(
        "/api/v1/income/overtime/projections",
        data={
            "overtime_hours_per_week": "10.00",
            "goal_id": g["id"],
            "standard_contribution": "200.00",
        },
        content_type="application/json",
    )
    assert r.status_code == 200
    res = r.json()
    
    # Math check:
    # net_hourly = 50 * 1.5 * 0.8 = 60.00
    # weekly = 60 * 10 = 600.00
    # monthly = 600 * 52 / 12 = 2600.00
    # remaining = 1200.00
    # total hours needed = 1200 / 60 = 20.00
    # standard months = 1200 / 200 = 6.00
    # overtime months = 1200 / (200 + 2600) = 1200 / 2800 = 0.43
    # months saved = 6.00 - 0.43 = 5.57
    assert res["net_hourly_rate"] == "60.00"
    assert res["weekly_overtime_net_income"] == "600.00"
    assert res["monthly_overtime_net_income"] == "2600.00"
    assert res["total_hours_needed"] == "20.00"
    assert res["months_to_complete_standard"] == "6.00"
    assert res["months_to_complete_with_overtime"] == "0.43"
    assert res["months_saved"] == "5.57"


@pytest.mark.django_db
def test_overtime_projections_subgoal(auth_client):
    client, _ = auth_client
    
    # Configure settings
    client.patch(
        "/api/v1/income/overtime/settings",
        data={
            "hourly_base_rate": "50.00",
            "overtime_multiplier": "1.50",
            "estimated_tax_rate": "0.20",
        },
        content_type="application/json",
    )
    
    # Create goal (1000 target, 0 current)
    g = client.post(
        "/api/v1/goals",
        data={
            "name": "Europe Trip",
            "target_amount": "1000.00",
            "current_amount": "0.00",
            "type": "short_term",
            "category": "purchase",
        },
        content_type="application/json",
    ).json()
    
    # Create subgoal (remaining is 500)
    subg = client.post(
        f"/api/v1/goals/{g['id']}/subgoals",
        data={
            "name": "Flights",
            "target_amount": "600.00",
            "current_amount": "100.00",
        },
        content_type="application/json",
    ).json()
    
    r = client.post(
        "/api/v1/income/overtime/projections",
        data={
            "overtime_hours_per_week": "10.00",
            "subgoal_id": subg["id"],
            "standard_contribution": "100.00",
        },
        content_type="application/json",
    )
    assert r.status_code == 200
    res = r.json()
    
    # remaining = 600 - 100 = 500
    # hours needed = 500 / 60 = 8.33
    # standard months = 500 / 100 = 5.00
    # overtime months = 500 / (100 + 2600) = 500 / 2700 = 0.19
    # saved = 5.00 - 0.19 = 4.81
    assert res["total_hours_needed"] == "8.33"
    assert res["months_to_complete_standard"] == "5.00"
    assert res["months_to_complete_with_overtime"] == "0.19"
    assert res["months_saved"] == "4.81"


@pytest.mark.django_db
def test_overtime_cross_user_isolation_security(auth_client, other_auth_client):
    a, _ = auth_client
    b, _ = other_auth_client
    
    # Create goal under user A
    g = a.post(
        "/api/v1/goals",
        data={
            "name": "Europe Trip",
            "target_amount": "1200.00",
            "current_amount": "0.00",
            "type": "short_term",
            "category": "purchase",
        },
        content_type="application/json",
    ).json()
    
    # A's settings update
    a.patch(
        "/api/v1/income/overtime/settings",
        data={"hourly_base_rate": "50.00"},
        content_type="application/json",
    )
    
    # User B tries to fetch projections on User A's goal
    r = b.post(
        "/api/v1/income/overtime/projections",
        data={
            "overtime_hours_per_week": "10.00",
            "goal_id": g["id"],
        },
        content_type="application/json",
    )
    assert r.status_code == 404
