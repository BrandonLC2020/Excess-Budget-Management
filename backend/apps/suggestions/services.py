import uuid
from datetime import datetime, timezone
from decimal import Decimal
from django.conf import settings
from apps.accounts.services import list_accounts
from apps.goals.services import list_goals, list_subgoals
from apps.allocations.services import recent_allocation_summary
from apps.common.exceptions import UpstreamError
from apps.common.firestore import get_client
from apps.common.money import to_cents

COLLECTION = "allocation_suggestions"


def gather_context(user) -> dict:
    profile = getattr(user, "profile", None)
    ratio = float(profile.default_savings_ratio) if profile else 0.5

    goals = []
    for g in list_goals(user):
        subgoals = list_subgoals(user, g.id)
        goals.append({
            "id": str(g.id),
            "name": g.name,
            "category": g.category,
            "type": g.type,
            "target_amount": float(g.target_amount),
            "current_amount": float(g.current_amount),
            "target_date": g.target_date.isoformat() if g.target_date else None,
            "sub_goals": [
                {"name": s.name, "target": float(s.target_amount), "current": float(s.current_amount)}
                for s in subgoals
            ],
        })

    accounts = [{"id": str(a.id), "name": a.name, "balance": float(a.balance)} for a in list_accounts(user)]

    return {
        "goals": goals,
        "accounts": accounts,
        "recentAllocations": recent_allocation_summary(user),
        "defaultSavingsRatio": ratio,
    }


def _build_prompt(excess: Decimal, ctx: dict) -> str:
    return (
        f"You are a financial advisor. The user has an excess budget of "
        f"${excess} this month. Prioritize short term goals and near target dates. "
        f"Recent 30-day allocations: ${ctx['recentAllocations']['totalSavings']} savings "
        f"and ${ctx['recentAllocations']['totalPurchases']} purchases. "
        f"Default ratio: {int(ctx['defaultSavingsRatio'] * 100)}% savings. "
        f"Goals: {ctx['goals']}. Accounts: {ctx['accounts']}. "
        f"Reply as JSON with keys 'suggestions' (list of {{goalName, amount, subgoalName?}}) "
        f"and 'reasoning' (string)."
    )


def call_gemini(prompt: str) -> dict:
    """Live call to Gemini. Mocked in tests."""
    import json
    from google import genai

    if not settings.GEMINI_API_KEY:
        raise UpstreamError("GEMINI_API_KEY is not configured.")
    try:
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        resp = client.models.generate_content(
            model="gemini-1.5-flash",
            contents=prompt,
            config={"response_mime_type": "application/json"},
        )
        return json.loads(resp.text)
    except Exception as e:
        raise UpstreamError(f"Gemini call failed: {e}") from e


def generate(user, excess: Decimal) -> dict:
    ctx = gather_context(user)
    prompt = _build_prompt(excess, ctx)
    result = call_gemini(prompt)

    suggestion_id = uuid.uuid4()
    get_client().collection(COLLECTION).document(str(suggestion_id)).set({
        "user_id": str(user.id),
        "excess_funds": to_cents(excess),
        "response_json": result,
        "created_at": datetime.now(timezone.utc),
    })

    return result
