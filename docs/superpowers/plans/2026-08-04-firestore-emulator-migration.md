# Firestore + Emulator Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `accounts`, `budget`, `income`, `goals`, `expenses`, `allocations`, `suggestions`, and `dashboard` off Postgres/Django ORM onto Firestore (Native mode), developed locally against the Firestore Emulator, while `apps.users` (auth) stays untouched on Postgres.

**Architecture:** Each app's `models.py` becomes a plain `@dataclass`; `services.py` is rewritten to call the official `google-cloud-firestore` SDK directly against flat top-level collections (`user_id` string field for ownership) instead of the Django ORM. `api.py` and `schemas.py` are untouched everywhere. Cross-app rollup logic that used to live in Django signal receivers (`expenses/signals.py`, `allocations/signals.py`, `goals/signals.py`, `accounts/signals.py`) becomes explicit function calls into a new `apps/common/rollups.py`, invoked directly from each `services.py` at the point where the equivalent write happens.

**Tech Stack:** Django 5, Django Ninja, `google-cloud-firestore`, Firestore Emulator (`gcloud emulators firestore`), pytest-django, Docker Compose.

## Global Constraints

- **Auth is out of scope.** `apps/users/*` (models, services, api, migrations) must not change. `AUTH_USER_MODEL` stays `users.User` on Postgres.
- **No `infra/*.tf` changes, no real GCP project.** Everything here targets the local emulator only.
- **`api.py` and `schemas.py` are frozen** for all 8 converted apps — every schema still types `id: uuid.UUID`, so every app-generated ID must be `uuid.uuid4()` used as the Firestore document ID (`.document(str(id))`), never Firestore's own auto-ID.
- **Every persisted decimal field is stored as an integer scaled ×100** (`apps/common/money.py::to_cents`/`from_cents`) — never store money/rate fields as Firestore `double`.
- **Ownership check is always `get_owned_or_404_fs(collection, doc_id, user)`** (`apps/common/firestore_helpers.py`) — no service function reads a document without it, mirroring the existing `get_owned_or_404` convention.
- **Firestore collection names** (fixed, referenced by every task below): `accounts`, `budget_categories`, `income_sources`, `extra_income`, `overtime_settings`, `goals`, `sub_goals`, `goal_accounts`, `expenses`, `allocations`, `allocation_suggestions`.
- **`date`-only fields** (not full timestamps — `Expense.date`, `ExtraIncome.date_received`, `Goal.target_date`) are stored as ISO strings (`date.isoformat()`) and parsed back with `date.fromisoformat()`; Firestore has no bare-date type.
- **`created_at`/`updated_at`** are computed client-side as `datetime.now(timezone.utc)` and written as a literal value (not the `SERVER_TIMESTAMP` sentinel) so the value is immediately available for the function's return value without a second round-trip read — this matches the *existing* behavior anyway, since Django's `auto_now_add=True` also uses `timezone.now()` client-side, not a database server clock.
- Run all commands from `backend/` unless stated otherwise. Every commit in this plan runs `uv run ruff check .` first and fixes any lint failures before committing.

---

### Task 1: Firestore emulator tooling

**Files:**
- Modify: `backend/docker-compose.yml`
- Modify: `backend/pyproject.toml`
- Modify: `backend/.env.example`, `backend/.env`
- Modify: `Makefile`

**Interfaces:**
- Produces: a running `firestore` container reachable at `firestore:8080` from inside the `web` container, and `localhost:8080` from the host. `web`'s environment gets `FIRESTORE_EMULATOR_HOST=firestore:8080` and `GOOGLE_CLOUD_PROJECT=excess-budget-dev`.

- [ ] **Step 1: Add the Firestore emulator service to `docker-compose.yml`**

Edit `backend/docker-compose.yml` — add a `firestore` service and wire its env vars into `web`:

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: excess
    ports:
      - "5432:5432"
    volumes:
      - excess_pg:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 10

  firestore:
    image: google/cloud-sdk:emulators
    command: >
      gcloud emulators firestore start
        --host-port=0.0.0.0:8080
        --project=excess-budget-dev
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://localhost:8080 || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 10

  web:
    build: .
    env_file: .env
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/excess
      FIRESTORE_EMULATOR_HOST: firestore:8080
      GOOGLE_CLOUD_PROJECT: excess-budget-dev
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
      firestore:
        condition: service_healthy
    command: >
      bash -c "uv run python manage.py migrate &&
               uv run python manage.py runserver 0.0.0.0:8000"
    volumes:
      - .:/app

volumes:
  excess_pg:
```

- [ ] **Step 2: Add the Firestore client dependency**

Edit `backend/pyproject.toml`, add to `dependencies`:

```toml
  "google-cloud-firestore>=2.16,<3.0",
```

- [ ] **Step 3: Update env files**

Append to both `backend/.env.example` and `backend/.env`:

```
# Firestore (emulator locally; unset FIRESTORE_EMULATOR_HOST to hit real GCP Firestore)
GOOGLE_CLOUD_PROJECT=excess-budget-dev
FIRESTORE_EMULATOR_HOST=firestore:8080
```

- [ ] **Step 4: Add a `logs-firestore` Makefile target**

Edit `Makefile`, add next to the existing `logs-db` target:

```makefile
FIRESTORE     ?= firestore

.PHONY: logs-firestore
logs-firestore:  ## Tail Firestore emulator logs.
	$(COMPOSE) logs -f $(FIRESTORE)
```

- [ ] **Step 5: Sync dependencies and bring the stack up**

Run: `cd backend && uv sync`
Expected: `google-cloud-firestore` and its transitive deps (`google-cloud-firestore` pulls in `grpcio`, `proto-plus`, etc.) resolve and lock into `uv.lock` without conflicts.

Run: `make up`
Expected: `db`, `firestore`, and `web` all report healthy; `docker compose ps` shows all three `Up`.

- [ ] **Step 6: Verify the emulator is reachable from inside the `web` container**

Run: `make shell` then, inside the container shell:

```python
import os
from google.cloud import firestore
assert os.environ["FIRESTORE_EMULATOR_HOST"] == "firestore:8080"
client = firestore.Client(project=os.environ["GOOGLE_CLOUD_PROJECT"])
client.collection("smoke_test").document("1").set({"ok": True})
assert client.collection("smoke_test").document("1").get().get("ok") is True
print("Firestore emulator reachable.")
```

Expected: prints `Firestore emulator reachable.` with no exceptions.

- [ ] **Step 7: Commit**

```bash
git add backend/docker-compose.yml backend/pyproject.toml backend/uv.lock backend/.env.example Makefile
git commit -m "chore: add Firestore emulator to local dev stack"
```

(`.env` is not committed — it's already gitignored; edit it locally to match `.env.example`.)

---

### Task 2: Common Firestore infrastructure — client, money encoding, ownership helper

**Files:**
- Create: `backend/apps/common/firestore.py`
- Create: `backend/apps/common/money.py`
- Create: `backend/apps/common/firestore_helpers.py`
- Test: `backend/apps/common/tests/test_money.py`
- Test: `backend/apps/common/tests/test_firestore_helpers.py`

**Interfaces:**
- Produces: `get_client() -> google.cloud.firestore.Client` (cached singleton); `to_cents(Decimal) -> int`; `from_cents(int) -> Decimal`; `get_owned_or_404_fs(collection: str, doc_id, user) -> DocumentSnapshot` (raises `apps.common.exceptions.NotFoundError`).

- [ ] **Step 1: Write the failing tests for `money.py`**

Create `backend/apps/common/tests/test_money.py`:

```python
from decimal import Decimal
from apps.common.money import to_cents, from_cents


def test_to_cents_converts_whole_dollars():
    assert to_cents(Decimal("45.00")) == 4500


def test_to_cents_converts_fractional_cents_with_rounding():
    assert to_cents(Decimal("10.005")) == 1001  # ROUND_HALF_UP


def test_from_cents_converts_back_to_two_decimal_places():
    assert from_cents(4500) == Decimal("45.00")


def test_from_cents_handles_negative_values():
    assert from_cents(-500) == Decimal("-5.00")


def test_round_trip_is_exact_for_typical_amounts():
    for dollars in ["0.00", "0.01", "12.34", "1000000.99"]:
        assert from_cents(to_cents(Decimal(dollars))) == Decimal(dollars)
```

- [ ] **Step 2: Run and confirm failure**

Run: `uv run pytest apps/common/tests/test_money.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.common.money'`

- [ ] **Step 3: Implement `apps/common/money.py`**

```python
"""Firestore has no Decimal type. Every persisted 2-decimal-place field in
this schema — money amounts and OvertimeSettings' two rate fields — is
stored as an integer scaled by 100, converted at the service-layer boundary.
"""
from decimal import Decimal, ROUND_HALF_UP

_SCALE = Decimal("100")
_TWO_PLACES = Decimal("0.01")


def to_cents(amount: Decimal) -> int:
    return int((Decimal(amount) * _SCALE).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def from_cents(cents: int) -> Decimal:
    return (Decimal(cents) / _SCALE).quantize(_TWO_PLACES, rounding=ROUND_HALF_UP)
```

- [ ] **Step 4: Run and confirm pass**

Run: `uv run pytest apps/common/tests/test_money.py -v`
Expected: PASS (5 passed)

- [ ] **Step 5: Write the failing tests for `firestore.py` + `firestore_helpers.py`**

Create `backend/apps/common/tests/test_firestore_helpers.py`:

```python
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
```

- [ ] **Step 6: Run and confirm failure**

Run: `uv run pytest apps/common/tests/test_firestore_helpers.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.common.firestore'`

- [ ] **Step 7: Implement `apps/common/firestore.py`**

```python
import os
from functools import lru_cache
from google.cloud import firestore


@lru_cache(maxsize=1)
def get_client() -> firestore.Client:
    project = os.environ.get("GOOGLE_CLOUD_PROJECT", "excess-budget-dev")
    return firestore.Client(project=project)
```

- [ ] **Step 8: Implement `apps/common/firestore_helpers.py`**

```python
from .firestore import get_client
from .exceptions import NotFoundError


def get_owned_or_404_fs(collection: str, doc_id, user):
    """Fetch a Firestore document snapshot owned by `user`, or raise NotFoundError.
    Firestore-backed counterpart to apps/common/permissions.py::get_owned_or_404."""
    snapshot = get_client().collection(collection).document(str(doc_id)).get()
    if not snapshot.exists or snapshot.to_dict().get("user_id") != str(user.id):
        raise NotFoundError(f"{collection} not found.")
    return snapshot
```

- [ ] **Step 9: Run and confirm pass**

Run: `uv run pytest apps/common/tests/test_firestore_helpers.py apps/common/tests/test_money.py -v`
Expected: PASS (9 passed). Note: this requires the Firestore emulator to be reachable — run via `make test` (execs inside the `web` container, which has `FIRESTORE_EMULATOR_HOST` set) rather than bare `pytest` on the host, unless `FIRESTORE_EMULATOR_HOST=localhost:8080` is exported in your host shell.

- [ ] **Step 10: Commit**

```bash
git add apps/common/firestore.py apps/common/money.py apps/common/firestore_helpers.py apps/common/tests/test_money.py apps/common/tests/test_firestore_helpers.py
git commit -m "feat(common): add Firestore client, money encoding, and ownership helper"
```

---

### Task 3: Rollup module — explicit replacements for the 4 signal files

**Files:**
- Create: `backend/apps/common/rollups.py`
- Test: `backend/apps/common/tests/test_rollups.py`

**Interfaces:**
- Consumes: `apps.common.firestore.get_client`.
- Produces: `apply_expense_effects(old: dict | None, new: dict | None) -> None`; `apply_extra_income_effects(old: dict | None, new: dict | None) -> None`; `recompute_subgoal_parent(goal_id: str) -> None`; `recompute_goal_from_accounts(goal_id: str) -> None`; `apply_allocation_effects(old: dict | None, new: dict | None) -> None`. All operate on raw collection names; no dependency on any other app's code.
  - `apply_expense_effects`/`apply_extra_income_effects` dict shape: `{"account_id": str | None, "budget_category_id": str | None, "amount_cents": int}`.
  - `apply_allocation_effects` dict shape: `{"account_id": str | None, "goal_id": str, "sub_goal_id": str | None, "amount_cents": int}`.

- [ ] **Step 1: Write the failing tests**

Create `backend/apps/common/tests/test_rollups.py`:

```python
from apps.common.firestore import get_client
from apps.common.rollups import (
    apply_expense_effects,
    apply_extra_income_effects,
    recompute_subgoal_parent,
    recompute_goal_from_accounts,
    apply_allocation_effects,
)


def _seed_account(account_id, balance_cents):
    get_client().collection("accounts").document(account_id).set({"balance": balance_cents})


def _seed_category(category_id, category_type, spent_cents=0):
    get_client().collection("budget_categories").document(category_id).set(
        {"category_type": category_type, "spent_amount": spent_cents}
    )


def test_apply_expense_effects_on_create_debits_balance_and_credits_spent():
    _seed_account("acc1", 10000)
    _seed_category("cat1", "expense", 0)

    apply_expense_effects(
        old=None, new={"account_id": "acc1", "budget_category_id": "cat1", "amount_cents": 3000}
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 7000
    assert get_client().collection("budget_categories").document("cat1").get().get("spent_amount") == 3000


def test_apply_expense_effects_against_income_category_flips_sign():
    _seed_category("cat1", "income", 0)

    apply_expense_effects(
        old=None, new={"account_id": None, "budget_category_id": "cat1", "amount_cents": 5000}
    )

    assert get_client().collection("budget_categories").document("cat1").get().get("spent_amount") == -5000


def test_apply_expense_effects_on_delete_reverses():
    _seed_account("acc1", 7000)
    _seed_category("cat1", "expense", 3000)

    apply_expense_effects(
        old={"account_id": "acc1", "budget_category_id": "cat1", "amount_cents": 3000}, new=None
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 10000
    assert get_client().collection("budget_categories").document("cat1").get().get("spent_amount") == 0


def test_apply_expense_effects_on_update_reverses_old_and_applies_new():
    _seed_account("acc1", 7000)
    _seed_category("cat1", "expense", 3000)

    apply_expense_effects(
        old={"account_id": "acc1", "budget_category_id": "cat1", "amount_cents": 3000},
        new={"account_id": "acc1", "budget_category_id": "cat1", "amount_cents": 5000},
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 5000
    assert get_client().collection("budget_categories").document("cat1").get().get("spent_amount") == 5000


def test_apply_extra_income_effects_credits_balance_and_budget():
    _seed_account("acc1", 10000)
    _seed_category("cat1", "income", 0)

    apply_extra_income_effects(
        old=None, new={"account_id": "acc1", "budget_category_id": "cat1", "amount_cents": 5000}
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 15000
    assert get_client().collection("budget_categories").document("cat1").get().get("spent_amount") == 5000


def test_recompute_subgoal_parent_sums_siblings():
    get_client().collection("goals").document("g1").set({"target_amount": 0, "current_amount": 0})
    get_client().collection("sub_goals").document("s1").set(
        {"goal_id": "g1", "target_amount": 50000, "current_amount": 10000}
    )
    get_client().collection("sub_goals").document("s2").set(
        {"goal_id": "g1", "target_amount": 70000, "current_amount": 0}
    )

    recompute_subgoal_parent("g1")

    goal = get_client().collection("goals").document("g1").get()
    assert goal.get("target_amount") == 120000
    assert goal.get("current_amount") == 10000


def test_recompute_subgoal_parent_noop_when_no_subgoals():
    get_client().collection("goals").document("g2").set({"target_amount": 999, "current_amount": 999})

    recompute_subgoal_parent("g2")

    goal = get_client().collection("goals").document("g2").get()
    assert goal.get("target_amount") == 999


def test_recompute_goal_from_accounts_sums_linked_balances():
    get_client().collection("goals").document("g1").set({"current_amount": 0})
    _seed_account("a1", 30000)
    _seed_account("a2", 40000)
    get_client().collection("goal_accounts").document("g1_a1").set({"goal_id": "g1", "account_id": "a1"})
    get_client().collection("goal_accounts").document("g1_a2").set({"goal_id": "g1", "account_id": "a2"})

    recompute_goal_from_accounts("g1")

    assert get_client().collection("goals").document("g1").get().get("current_amount") == 70000


def test_apply_allocation_effects_debits_account_credits_goal():
    _seed_account("acc1", 50000)
    get_client().collection("goals").document("g1").set({"current_amount": 0})

    apply_allocation_effects(
        old=None, new={"account_id": "acc1", "goal_id": "g1", "sub_goal_id": None, "amount_cents": 20000}
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 30000
    assert get_client().collection("goals").document("g1").get().get("current_amount") == 20000


def test_apply_allocation_effects_credits_subgoal_and_rolls_up_to_parent():
    get_client().collection("goals").document("g1").set({"target_amount": 50000, "current_amount": 0})
    get_client().collection("sub_goals").document("s1").set(
        {"goal_id": "g1", "target_amount": 50000, "current_amount": 0}
    )

    apply_allocation_effects(
        old=None, new={"account_id": None, "goal_id": "g1", "sub_goal_id": "s1", "amount_cents": 10000}
    )

    assert get_client().collection("sub_goals").document("s1").get().get("current_amount") == 10000
    assert get_client().collection("goals").document("g1").get().get("current_amount") == 10000


def test_apply_allocation_effects_on_delete_reverses():
    _seed_account("acc1", 30000)
    get_client().collection("goals").document("g1").set({"current_amount": 20000})

    apply_allocation_effects(
        old={"account_id": "acc1", "goal_id": "g1", "sub_goal_id": None, "amount_cents": 20000}, new=None
    )

    assert get_client().collection("accounts").document("acc1").get().get("balance") == 50000
    assert get_client().collection("goals").document("g1").get().get("current_amount") == 0
```

- [ ] **Step 2: Run and confirm failure**

Run: `uv run pytest apps/common/tests/test_rollups.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.common.rollups'`

- [ ] **Step 3: Implement `apps/common/rollups.py`**

```python
"""Explicit-call replacements for the Django signal receivers in
expenses/signals.py, allocations/signals.py, goals/signals.py, and
accounts/signals.py. Firestore has no signal dispatcher, so each app's
services.py calls these directly at the point its ORM .save()/.delete()
used to trigger a signal. Operates on raw collection names — no dependency
on any specific app's models.py or services.py, so this module can be
built and tested before any of the 8 apps are converted.
"""
from google.cloud import firestore
from .firestore import get_client


def _apply_to_balance(account_id: str | None, delta_cents: int) -> None:
    """Add delta_cents to accounts/{account_id}.balance. No-op if account_id is None
    or the account doesn't exist (mirrors _apply_to_budget's existence check below)."""
    if not account_id or delta_cents == 0:
        return
    doc_ref = get_client().collection("accounts").document(account_id)
    if not doc_ref.get().exists:
        return
    doc_ref.update({"balance": firestore.Increment(delta_cents)})


def _apply_to_budget(category_id: str | None, raw_delta_cents: int) -> None:
    """Apply raw_delta_cents to budget_categories/{category_id}.spent_amount.

    raw_delta_cents is treated as "expense semantics":
    - expense category: spent_amount += raw_delta_cents
    - income category:  spent_amount -= raw_delta_cents (sign flipped)
    """
    if not category_id or raw_delta_cents == 0:
        return
    doc_ref = get_client().collection("budget_categories").document(category_id)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        return
    category_type = snapshot.get("category_type")
    delta = raw_delta_cents if category_type == "expense" else -raw_delta_cents
    doc_ref.update({"spent_amount": firestore.Increment(delta)})


def apply_expense_effects(old: dict | None, new: dict | None) -> None:
    """Port of expenses/signals.py's Expense post_save/post_delete receivers.
    Pass old=None on create, new=None on delete, both on update."""
    if old is not None:
        _apply_to_balance(old["account_id"], old["amount_cents"])
        _apply_to_budget(old["budget_category_id"], -old["amount_cents"])
    if new is not None:
        _apply_to_balance(new["account_id"], -new["amount_cents"])
        _apply_to_budget(new["budget_category_id"], new["amount_cents"])


def apply_extra_income_effects(old: dict | None, new: dict | None) -> None:
    """Port of expenses/signals.py's ExtraIncome post_save/post_delete receivers
    (income credits balance/budget with signs mirrored from an expense)."""
    if old is not None:
        _apply_to_balance(old["account_id"], -old["amount_cents"])
        _apply_to_budget(old["budget_category_id"], old["amount_cents"])
    if new is not None:
        _apply_to_balance(new["account_id"], new["amount_cents"])
        _apply_to_budget(new["budget_category_id"], -new["amount_cents"])


def recompute_subgoal_parent(goal_id: str) -> None:
    """Port of goals/signals.py's Subgoal post_save/post_delete receivers:
    re-sum all sibling subgoals' target/current amounts onto the parent Goal.
    No-op if the goal itself doesn't exist (e.g. orphaned/racing delete)."""
    client = get_client()
    goal_ref = client.collection("goals").document(goal_id)
    if not goal_ref.get().exists:
        return
    subgoals = list(client.collection("sub_goals").where("goal_id", "==", goal_id).stream())
    if not subgoals:
        return
    target_total = sum(s.get("target_amount") for s in subgoals)
    current_total = sum(s.get("current_amount") for s in subgoals)
    goal_ref.update({"target_amount": target_total, "current_amount": current_total})


def recompute_goal_from_accounts(goal_id: str) -> None:
    """Port of goals/signals.py's GoalAccount post_save/post_delete receivers
    (and reused by accounts/services.py's balance-change path): re-sum linked
    accounts' balances onto the Goal's current_amount.
    No-op if the goal itself doesn't exist (e.g. orphaned/racing delete)."""
    client = get_client()
    goal_ref = client.collection("goals").document(goal_id)
    if not goal_ref.get().exists:
        return
    links = list(client.collection("goal_accounts").where("goal_id", "==", goal_id).stream())
    total = 0
    for link in links:
        account = client.collection("accounts").document(link.get("account_id")).get()
        if account.exists:
            total += account.get("balance")
    goal_ref.update({"current_amount": total})


def _apply_progress(sub_goal_id: str | None, goal_id: str, delta_cents: int) -> None:
    client = get_client()
    if sub_goal_id:
        client.collection("sub_goals").document(sub_goal_id).update(
            {"current_amount": firestore.Increment(delta_cents)}
        )
        recompute_subgoal_parent(goal_id)
    else:
        client.collection("goals").document(goal_id).update(
            {"current_amount": firestore.Increment(delta_cents)}
        )


def apply_allocation_effects(old: dict | None, new: dict | None) -> None:
    """Port of allocations/signals.py's GoalAllocation post_save/post_delete receivers."""
    if old is not None:
        _apply_to_balance(old["account_id"], old["amount_cents"])
        _apply_progress(old["sub_goal_id"], old["goal_id"], -old["amount_cents"])
    if new is not None:
        _apply_to_balance(new["account_id"], -new["amount_cents"])
        _apply_progress(new["sub_goal_id"], new["goal_id"], new["amount_cents"])
```

- [ ] **Step 4: Run and confirm pass**

Run: `uv run pytest apps/common/tests/test_rollups.py -v`
Expected: PASS (11 passed)

- [ ] **Step 5: Commit**

```bash
git add apps/common/rollups.py apps/common/tests/test_rollups.py
git commit -m "feat(common): add rollups module replacing the 4 Django signal files"
```

---

### Task 4: Test infrastructure — emulator-required fixture + per-test wipe

**Files:**
- Modify: `backend/conftest.py`

**Interfaces:**
- Consumes: `apps.common.firestore.get_client`.
- Produces: an autouse session fixture that fails the whole run loudly if `FIRESTORE_EMULATOR_HOST` isn't set, and an autouse per-test fixture that wipes all emulator collections before each test runs.

- [ ] **Step 1: Add the fixtures**

Edit `backend/conftest.py`, add after the existing imports and before the `user` fixture:

```python
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
```

- [ ] **Step 2: Verify the emulator-required guard actually blocks a run without it**

Run (from the host, without the emulator env var set): `cd backend && FIRESTORE_EMULATOR_HOST= uv run pytest apps/common/tests/test_money.py -v`
Expected: pytest exits immediately with the `"FIRESTORE_EMULATOR_HOST is not set"` message, before any test collection output.

- [ ] **Step 3: Verify the wipe fixture actually clears state between tests**

Run: `make test ARGS="apps/common/tests/test_rollups.py -v"`
Expected: all 11 tests from Task 3 still PASS — each test seeds its own fixture data assuming an empty collection (e.g. `_seed_account("acc1", 10000)` then asserting balance is exactly `7000` after a `-3000` delta); if the wipe fixture weren't working, leftover docs from a previous test with the same ID would make these assertions fail intermittently depending on run order.

- [ ] **Step 4: Commit**

```bash
git add conftest.py
git commit -m "test: require Firestore emulator and wipe collections between tests"
```

---

### Task 5: `accounts` app → Firestore

**Files:**
- Modify: `backend/apps/accounts/models.py`
- Modify: `backend/apps/accounts/services.py`
- Delete: `backend/apps/accounts/signals.py`
- Modify: `backend/apps/accounts/apps.py`
- Delete: `backend/apps/accounts/migrations/` (all files except keep the directory removed entirely)
- No changes: `backend/apps/accounts/api.py`, `backend/apps/accounts/schemas.py`, `backend/apps/accounts/tests/test_api.py`

**Interfaces:**
- Consumes: `apps.common.firestore.get_client`, `apps.common.firestore_helpers.get_owned_or_404_fs`, `apps.common.money.{to_cents,from_cents}`, `apps.common.rollups.recompute_goal_from_accounts`.
- Produces: `Account` dataclass (`id: uuid.UUID`, `user_id: str`, `name: str`, `balance: Decimal`, `created_at: datetime`); `list_accounts(user) -> list[Account]`; `create_account(user, payload) -> Account`; `get_account(user, account_id) -> Account`; `update_account(user, account_id, payload) -> Account`; `delete_account(user, account_id) -> None`. This is the interface every later task (`income`, `expenses`, `goals`, `allocations`, `suggestions`, `dashboard`) relies on when it says "call `accounts.services`".

- [ ] **Step 1: Confirm the current baseline passes**

Run: `uv run pytest apps/accounts/tests/test_api.py -v`
Expected: PASS (this is the Postgres/ORM baseline, before any change).

- [ ] **Step 2: Replace `apps/accounts/models.py` with a dataclass**

```python
import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass
class Account:
    id: uuid.UUID
    user_id: str
    name: str
    balance: Decimal
    created_at: datetime
```

- [ ] **Step 3: Run and confirm the existing tests now fail**

Run: `uv run pytest apps/accounts/tests/test_api.py -v`
Expected: FAIL — `services.py` still does `Account.objects.filter(...)`, and `Account` (now a dataclass) has no `.objects` manager: `AttributeError: type object 'Account' has no attribute 'objects'`.

- [ ] **Step 4: Rewrite `apps/accounts/services.py`**

```python
import uuid
from datetime import datetime, timezone
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import recompute_goal_from_accounts
from .models import Account

COLLECTION = "accounts"


def _from_doc(snapshot) -> Account:
    data = snapshot.to_dict()
    return Account(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        name=data["name"],
        balance=from_cents(data["balance"]),
        created_at=data["created_at"],
    )


def list_accounts(user):
    docs = get_client().collection(COLLECTION).where("user_id", "==", str(user.id)).stream()
    return [_from_doc(d) for d in docs]


def create_account(user, payload) -> Account:
    account_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    get_client().collection(COLLECTION).document(str(account_id)).set({
        "user_id": str(user.id),
        "name": payload.name,
        "balance": to_cents(payload.balance),
        "created_at": now,
    })
    return Account(id=account_id, user_id=str(user.id), name=payload.name,
                   balance=payload.balance, created_at=now)


def get_account(user, account_id) -> Account:
    return _from_doc(get_owned_or_404_fs(COLLECTION, account_id, user))


def update_account(user, account_id, payload) -> Account:
    get_owned_or_404_fs(COLLECTION, account_id, user)
    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.balance is not None:
        updates["balance"] = to_cents(payload.balance)

    doc_ref = get_client().collection(COLLECTION).document(str(account_id))
    if updates:
        doc_ref.update(updates)

    # Mirrors accounts/signals.py::_account_saved, which fires on every save()
    # (not just balance changes) since update_account never passes update_fields.
    for link in get_client().collection("goal_accounts").where(
        "account_id", "==", str(account_id)
    ).stream():
        recompute_goal_from_accounts(link.get("goal_id"))

    return _from_doc(doc_ref.get())


def delete_account(user, account_id) -> None:
    get_owned_or_404_fs(COLLECTION, account_id, user)
    get_client().collection(COLLECTION).document(str(account_id)).delete()
```

- [ ] **Step 5: Remove the now-dead signal wiring**

Delete `backend/apps/accounts/signals.py` (its logic now lives in `apps/common/rollups.py`, called explicitly from `update_account` above).

Edit `backend/apps/accounts/apps.py` to remove the `ready()` hook:

```python
from django.apps import AppConfig


class AccountsConfig(AppConfig):
    name = "apps.accounts"
    label = "accounts"
    default_auto_field = "django.db.models.BigAutoField"
```

- [ ] **Step 6: Delete the app's migrations**

Run: `rm -rf apps/accounts/migrations`
(Firestore is schemaless — this app no longer has any ORM tables to migrate. The `migrations/__init__.py` and any numbered migration files are all removed.)

- [ ] **Step 7: Run and confirm the existing tests pass again**

Run: `uv run pytest apps/accounts/tests/test_api.py -v`
Expected: PASS — same test file, unchanged, now running against Firestore instead of Postgres.

- [ ] **Step 8: Commit**

```bash
git add apps/accounts/models.py apps/accounts/services.py apps/accounts/apps.py
git rm apps/accounts/signals.py
git add -A apps/accounts/migrations
git commit -m "feat(accounts): migrate to Firestore"
```

---

### Task 6: `budget` app → Firestore

**Files:**
- Modify: `backend/apps/budget/models.py`
- Modify: `backend/apps/budget/services.py`
- Delete: `backend/apps/budget/migrations/`
- No changes: `backend/apps/budget/api.py`, `backend/apps/budget/schemas.py`, `backend/apps/budget/tests/test_api.py`

**Interfaces:**
- Consumes: `apps.common.firestore.get_client`, `apps.common.firestore_helpers.get_owned_or_404_fs`, `apps.common.money.{to_cents,from_cents}`.
- Produces: `BudgetCategory` dataclass (`id`, `user_id`, `name`, `limit_amount: Decimal`, `spent_amount: Decimal`, `icon_code: int | None`, `color_hex: str | None`, `category_type: str`, `created_at`); `list_categories`, `create_category`, `get_category`, `update_category`, `delete_category` — same signatures as today. **`spent_amount` is written and mutated exclusively by `apps/common/rollups.py`** (via `expenses`/`income`'s calls) — `create_category`/`update_category` here never touch it directly except initializing to `0` on create, matching the original `spent_amount = models.DecimalField(..., default="0.00")`.

- [ ] **Step 1: Confirm baseline passes**

Run: `uv run pytest apps/budget/tests/test_api.py -v`
Expected: PASS.

- [ ] **Step 2: Replace `apps/budget/models.py`**

```python
import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass
class BudgetCategory:
    id: uuid.UUID
    user_id: str
    name: str
    limit_amount: Decimal
    spent_amount: Decimal
    icon_code: int | None
    color_hex: str | None
    category_type: str
    created_at: datetime
```

- [ ] **Step 3: Run and confirm failure**

Run: `uv run pytest apps/budget/tests/test_api.py -v`
Expected: FAIL — `AttributeError: type object 'BudgetCategory' has no attribute 'objects'`.

- [ ] **Step 4: Rewrite `apps/budget/services.py`**

```python
import uuid
from datetime import datetime, timezone
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from .models import BudgetCategory

COLLECTION = "budget_categories"


def _from_doc(snapshot) -> BudgetCategory:
    data = snapshot.to_dict()
    return BudgetCategory(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        name=data["name"],
        limit_amount=from_cents(data["limit_amount"]),
        spent_amount=from_cents(data["spent_amount"]),
        icon_code=data.get("icon_code"),
        color_hex=data.get("color_hex"),
        category_type=data["category_type"],
        created_at=data["created_at"],
    )


def list_categories(user):
    docs = get_client().collection(COLLECTION).where("user_id", "==", str(user.id)).stream()
    return [_from_doc(d) for d in docs]


def create_category(user, payload) -> BudgetCategory:
    category_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    get_client().collection(COLLECTION).document(str(category_id)).set({
        "user_id": str(user.id),
        "name": payload.name,
        "limit_amount": to_cents(payload.limit_amount),
        "spent_amount": 0,
        "icon_code": payload.icon_code,
        "color_hex": payload.color_hex,
        "category_type": payload.category_type,
        "created_at": now,
    })
    return BudgetCategory(
        id=category_id, user_id=str(user.id), name=payload.name,
        limit_amount=payload.limit_amount, spent_amount=Decimal("0.00"),
        icon_code=payload.icon_code, color_hex=payload.color_hex,
        category_type=payload.category_type, created_at=now,
    )


def get_category(user, category_id) -> BudgetCategory:
    return _from_doc(get_owned_or_404_fs(COLLECTION, category_id, user))


def update_category(user, category_id, payload) -> BudgetCategory:
    get_owned_or_404_fs(COLLECTION, category_id, user)
    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.limit_amount is not None:
        updates["limit_amount"] = to_cents(payload.limit_amount)
    if payload.category_type is not None:
        updates["category_type"] = payload.category_type
    if payload.icon_code is not None:
        updates["icon_code"] = payload.icon_code
    if payload.color_hex is not None:
        updates["color_hex"] = payload.color_hex

    doc_ref = get_client().collection(COLLECTION).document(str(category_id))
    if updates:
        doc_ref.update(updates)
    return _from_doc(doc_ref.get())


def delete_category(user, category_id) -> None:
    get_owned_or_404_fs(COLLECTION, category_id, user)
    get_client().collection(COLLECTION).document(str(category_id)).delete()
```

Add `from decimal import Decimal` to the imports at the top of the file (used in `create_category`'s return value).

- [ ] **Step 5: Delete migrations**

Run: `rm -rf apps/budget/migrations`

- [ ] **Step 6: Run and confirm pass**

Run: `uv run pytest apps/budget/tests/test_api.py -v`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/budget/models.py apps/budget/services.py
git add -A apps/budget/migrations
git commit -m "feat(budget): migrate to Firestore"
```

---

### Task 7: `income` app → Firestore (sources, extra income, overtime settings singleton)

**Files:**
- Modify: `backend/apps/income/models.py`
- Modify: `backend/apps/income/services.py`
- Delete: `backend/apps/income/migrations/`
- No changes: `backend/apps/income/api.py`, `backend/apps/income/schemas.py`, `backend/apps/income/tests/test_api.py`

**Interfaces:**
- Consumes: `apps.common.firestore.get_client`, `apps.common.firestore_helpers.get_owned_or_404_fs`, `apps.common.money.{to_cents,from_cents}`, `apps.common.rollups.apply_extra_income_effects`, `apps.accounts.services` (via `firestore_helpers` for ownership, not direct import), `apps.budget.services` (same), `apps.goals.services.get_subgoal`/`get_goal` for overtime projections.
- Produces: `IncomeSource`, `ExtraIncome`, `OvertimeSettings` dataclasses; `list_sources`, `create_source`, `get_source`, `update_source`, `delete_source`; `list_extra`, `create_extra`, `get_extra`, `update_extra`, `delete_extra`; `get_overtime_settings`, `update_overtime_settings`, `calculate_overtime_projections` — same signatures as today.

- [ ] **Step 1: Confirm baseline passes**

Run: `uv run pytest apps/income/tests/test_api.py -v`
Expected: PASS.

- [ ] **Step 2: Replace `apps/income/models.py`**

```python
import uuid
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass
class IncomeSource:
    id: uuid.UUID
    user_id: str
    name: str
    expected_amount: Decimal
    frequency: str
    created_at: datetime


@dataclass
class ExtraIncome:
    id: uuid.UUID
    user_id: str
    amount: Decimal
    description: str
    date_received: date
    account_id: uuid.UUID | None
    budget_category_id: uuid.UUID | None
    created_at: datetime


@dataclass
class OvertimeSettings:
    user_id: str
    hourly_base_rate: Decimal
    overtime_multiplier: Decimal
    estimated_tax_rate: Decimal
    created_at: datetime
    updated_at: datetime
```

- [ ] **Step 3: Run and confirm failure**

Run: `uv run pytest apps/income/tests/test_api.py -v`
Expected: FAIL — `AttributeError: type object 'IncomeSource' has no attribute 'objects'`.

- [ ] **Step 4: Rewrite `apps/income/services.py`**

```python
import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import apply_extra_income_effects
from apps.goals.services import get_goal, get_subgoal
from .models import IncomeSource, ExtraIncome, OvertimeSettings

SOURCES_COLLECTION = "income_sources"
EXTRA_COLLECTION = "extra_income"
OVERTIME_COLLECTION = "overtime_settings"


# ── IncomeSource ──────────────────────────────────────────────────────────────

def _source_from_doc(snapshot) -> IncomeSource:
    data = snapshot.to_dict()
    return IncomeSource(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        name=data["name"],
        expected_amount=from_cents(data["expected_amount"]),
        frequency=data["frequency"],
        created_at=data["created_at"],
    )


def list_sources(user):
    docs = get_client().collection(SOURCES_COLLECTION).where("user_id", "==", str(user.id)).stream()
    return [_source_from_doc(d) for d in docs]


def create_source(user, payload) -> IncomeSource:
    source_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    get_client().collection(SOURCES_COLLECTION).document(str(source_id)).set({
        "user_id": str(user.id),
        "name": payload.name,
        "expected_amount": to_cents(payload.expected_amount),
        "frequency": payload.frequency,
        "created_at": now,
    })
    return IncomeSource(id=source_id, user_id=str(user.id), name=payload.name,
                        expected_amount=payload.expected_amount, frequency=payload.frequency,
                        created_at=now)


def get_source(user, source_id) -> IncomeSource:
    return _source_from_doc(get_owned_or_404_fs(SOURCES_COLLECTION, source_id, user))


def update_source(user, source_id, payload) -> IncomeSource:
    get_owned_or_404_fs(SOURCES_COLLECTION, source_id, user)
    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.expected_amount is not None:
        updates["expected_amount"] = to_cents(payload.expected_amount)
    if payload.frequency is not None:
        updates["frequency"] = payload.frequency

    doc_ref = get_client().collection(SOURCES_COLLECTION).document(str(source_id))
    if updates:
        doc_ref.update(updates)
    return _source_from_doc(doc_ref.get())


def delete_source(user, source_id) -> None:
    get_owned_or_404_fs(SOURCES_COLLECTION, source_id, user)
    get_client().collection(SOURCES_COLLECTION).document(str(source_id)).delete()


# ── ExtraIncome ───────────────────────────────────────────────────────────────

def _extra_from_doc(snapshot) -> ExtraIncome:
    data = snapshot.to_dict()
    return ExtraIncome(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        amount=from_cents(data["amount"]),
        description=data["description"],
        date_received=date.fromisoformat(data["date_received"]),
        account_id=uuid.UUID(data["account_id"]) if data.get("account_id") else None,
        budget_category_id=uuid.UUID(data["budget_category_id"]) if data.get("budget_category_id") else None,
        created_at=data["created_at"],
    )


def list_extra(user, account_id=None, budget_category_id=None):
    query = get_client().collection(EXTRA_COLLECTION).where("user_id", "==", str(user.id))
    if account_id:
        query = query.where("account_id", "==", str(account_id))
    if budget_category_id:
        query = query.where("budget_category_id", "==", str(budget_category_id))
    return [_extra_from_doc(d) for d in query.stream()]


def create_extra(user, payload) -> ExtraIncome:
    account_id = None
    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)
        account_id = str(payload.account_id)

    budget_category_id = None
    if payload.budget_category_id is not None:
        get_owned_or_404_fs("budget_categories", payload.budget_category_id, user)
        budget_category_id = str(payload.budget_category_id)

    extra_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    amount_cents = to_cents(payload.amount)
    get_client().collection(EXTRA_COLLECTION).document(str(extra_id)).set({
        "user_id": str(user.id),
        "amount": amount_cents,
        "description": payload.description,
        "date_received": payload.date_received.isoformat(),
        "account_id": account_id,
        "budget_category_id": budget_category_id,
        "created_at": now,
    })

    apply_extra_income_effects(
        old=None,
        new={"account_id": account_id, "budget_category_id": budget_category_id, "amount_cents": amount_cents},
    )

    return ExtraIncome(
        id=extra_id, user_id=str(user.id), amount=payload.amount, description=payload.description,
        date_received=payload.date_received,
        account_id=payload.account_id, budget_category_id=payload.budget_category_id, created_at=now,
    )


def get_extra(user, extra_id) -> ExtraIncome:
    return _extra_from_doc(get_owned_or_404_fs(EXTRA_COLLECTION, extra_id, user))


def update_extra(user, extra_id, payload) -> ExtraIncome:
    snapshot = get_owned_or_404_fs(EXTRA_COLLECTION, extra_id, user)
    old_data = snapshot.to_dict()
    old_effect = {
        "account_id": old_data.get("account_id"),
        "budget_category_id": old_data.get("budget_category_id"),
        "amount_cents": old_data["amount"],
    }

    updates = {}
    if payload.amount is not None:
        updates["amount"] = to_cents(payload.amount)
    if payload.description is not None:
        updates["description"] = payload.description
    if payload.date_received is not None:
        updates["date_received"] = payload.date_received.isoformat()

    fields_set = payload.model_fields_set
    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)
        updates["account_id"] = str(payload.account_id)
    elif "account_id" in fields_set and payload.account_id is None:
        updates["account_id"] = None

    if payload.budget_category_id is not None:
        get_owned_or_404_fs("budget_categories", payload.budget_category_id, user)
        updates["budget_category_id"] = str(payload.budget_category_id)
    elif "budget_category_id" in fields_set and payload.budget_category_id is None:
        updates["budget_category_id"] = None

    doc_ref = get_client().collection(EXTRA_COLLECTION).document(str(extra_id))
    if updates:
        doc_ref.update(updates)

    new_data = doc_ref.get().to_dict()
    apply_extra_income_effects(
        old=old_effect,
        new={
            "account_id": new_data.get("account_id"),
            "budget_category_id": new_data.get("budget_category_id"),
            "amount_cents": new_data["amount"],
        },
    )

    return _extra_from_doc(doc_ref.get())


def delete_extra(user, extra_id) -> None:
    snapshot = get_owned_or_404_fs(EXTRA_COLLECTION, extra_id, user)
    data = snapshot.to_dict()
    get_client().collection(EXTRA_COLLECTION).document(str(extra_id)).delete()
    apply_extra_income_effects(
        old={
            "account_id": data.get("account_id"),
            "budget_category_id": data.get("budget_category_id"),
            "amount_cents": data["amount"],
        },
        new=None,
    )


# ── Overtime Settings & Calculations ──────────────────────────────────────────

def _overtime_from_doc(snapshot, user_id: str) -> OvertimeSettings:
    data = snapshot.to_dict()
    return OvertimeSettings(
        user_id=user_id,
        hourly_base_rate=from_cents(data["hourly_base_rate"]),
        overtime_multiplier=from_cents(data["overtime_multiplier"]),
        estimated_tax_rate=from_cents(data["estimated_tax_rate"]),
        created_at=data["created_at"],
        updated_at=data["updated_at"],
    )


def get_overtime_settings(user) -> OvertimeSettings:
    doc_ref = get_client().collection(OVERTIME_COLLECTION).document(str(user.id))
    snapshot = doc_ref.get()
    if not snapshot.exists:
        now = datetime.now(timezone.utc)
        doc_ref.set({
            "hourly_base_rate": to_cents(Decimal("0.00")),
            "overtime_multiplier": to_cents(Decimal("1.50")),
            "estimated_tax_rate": to_cents(Decimal("0.25")),
            "created_at": now,
            "updated_at": now,
        })
        snapshot = doc_ref.get()
    return _overtime_from_doc(snapshot, str(user.id))


def update_overtime_settings(user, payload) -> OvertimeSettings:
    get_overtime_settings(user)  # ensures the doc exists
    updates = {"updated_at": datetime.now(timezone.utc)}
    if payload.hourly_base_rate is not None:
        updates["hourly_base_rate"] = to_cents(payload.hourly_base_rate)
    if payload.overtime_multiplier is not None:
        updates["overtime_multiplier"] = to_cents(payload.overtime_multiplier)
    if payload.estimated_tax_rate is not None:
        updates["estimated_tax_rate"] = to_cents(payload.estimated_tax_rate)

    doc_ref = get_client().collection(OVERTIME_COLLECTION).document(str(user.id))
    doc_ref.update(updates)
    return _overtime_from_doc(doc_ref.get(), str(user.id))


def calculate_overtime_projections(user, payload) -> dict:
    settings_obj = get_overtime_settings(user)

    base = settings_obj.hourly_base_rate
    mult = settings_obj.overtime_multiplier
    tax = settings_obj.estimated_tax_rate

    net_hourly_rate = base * mult * (Decimal("1.00") - tax)
    weekly_overtime_net_income = net_hourly_rate * payload.overtime_hours_per_week
    monthly_overtime_net_income = weekly_overtime_net_income * Decimal("52") / Decimal("12")

    result = {
        "net_hourly_rate": round(net_hourly_rate, 2),
        "weekly_overtime_net_income": round(weekly_overtime_net_income, 2),
        "monthly_overtime_net_income": round(monthly_overtime_net_income, 2),
        "total_hours_needed": None,
        "months_to_complete_standard": None,
        "months_to_complete_with_overtime": None,
        "months_saved": None,
    }

    remaining_amount = Decimal("0.00")
    has_target = False

    if payload.subgoal_id:
        subgoal = get_subgoal(user, payload.goal_id, payload.subgoal_id) if payload.goal_id else None
        # subgoal_id can be supplied without goal_id in the request schema; resolve via a
        # direct ownership check when goal_id isn't given.
        if subgoal is None:
            snap = get_owned_or_404_fs("sub_goals", payload.subgoal_id, user)
            remaining_amount = from_cents(snap.get("target_amount")) - from_cents(snap.get("current_amount"))
        else:
            remaining_amount = subgoal.target_amount - subgoal.current_amount
        has_target = True
    elif payload.goal_id:
        goal = get_goal(user, payload.goal_id)
        remaining_amount = goal.target_amount - goal.current_amount
        has_target = True

    if has_target:
        remaining_amount = max(Decimal("0.00"), remaining_amount)

        if net_hourly_rate > 0:
            result["total_hours_needed"] = round(remaining_amount / net_hourly_rate, 2)

        std_contrib = payload.standard_contribution

        if std_contrib > 0:
            result["months_to_complete_standard"] = round(remaining_amount / std_contrib, 2)
            total_monthly = std_contrib + monthly_overtime_net_income
            result["months_to_complete_with_overtime"] = round(remaining_amount / total_monthly, 2)
            result["months_saved"] = round(
                result["months_to_complete_standard"] - result["months_to_complete_with_overtime"], 2
            )
        elif monthly_overtime_net_income > 0:
            result["months_to_complete_with_overtime"] = round(remaining_amount / monthly_overtime_net_income, 2)

    return result
```

Note: `calculate_overtime_projections`'s subgoal-without-goal_id branch is a direct port of the original's `get_owned_or_404(Subgoal, payload.subgoal_id, user)` call, which never required a `goal_id` either — `goals.services.get_subgoal(user, goal_id, subgoal_id)` (Task 8) requires both, so this function falls back to `get_owned_or_404_fs("sub_goals", ...)` directly when only `subgoal_id` is given, exactly matching the original's lack of a goal/subgoal cross-check in this one call site.

- [ ] **Step 5: Delete migrations**

Run: `rm -rf apps/income/migrations`

- [ ] **Step 6: Run and confirm pass**

Run: `uv run pytest apps/income/tests/test_api.py -v`
Expected: PASS. (This task depends on `apps/goals/services.py::get_goal`/`get_subgoal` existing — see Task 8's ordering note below.)

**Ordering note:** `income/services.py` imports `apps.goals.services.get_goal`/`get_subgoal`, but Task 8 (`goals`) is sequenced *after* this task per the spec's dependency order (accounts → budget → income → goals). Since `goals/services.py` hasn't been converted yet at this point, `get_goal`/`get_subgoal` still exist as ORM-based functions from the pre-migration code — which still work correctly here because `income`'s calls into them are read-only ownership/value lookups unrelated to Firestore. Once Task 8 converts `goals/services.py` to Firestore, its `get_goal`/`get_subgoal` signatures stay identical, so no further change is needed in `income/services.py`. Re-run `uv run pytest apps/income/tests/test_api.py -v` again after Task 8 completes as a regression check.

- [ ] **Step 7: Commit**

```bash
git add apps/income/models.py apps/income/services.py
git add -A apps/income/migrations
git commit -m "feat(income): migrate to Firestore"
```

---

### Task 8: `goals` app → Firestore (goals, subgoals, goal-account links, cascade delete)

**Files:**
- Modify: `backend/apps/goals/models.py`
- Modify: `backend/apps/goals/services.py`
- Delete: `backend/apps/goals/signals.py`
- Modify: `backend/apps/goals/apps.py`
- Delete: `backend/apps/goals/migrations/`
- Rewrite: `backend/apps/goals/tests/test_aggregation.py`
- No changes: `backend/apps/goals/api.py`, `backend/apps/goals/schemas.py`, `backend/apps/goals/tests/test_api.py`

**Interfaces:**
- Consumes: `apps.common.firestore.get_client`, `apps.common.firestore_helpers.get_owned_or_404_fs`, `apps.common.money.{to_cents,from_cents}`, `apps.common.rollups.{recompute_subgoal_parent,recompute_goal_from_accounts}`.
- Produces: `Goal`, `Subgoal`, `GoalAccount` dataclasses; `list_goals`, `create_goal`, `get_goal`, `update_goal`, `delete_goal`; `list_subgoals`, `create_subgoal`, `get_subgoal`, `update_subgoal`, `delete_subgoal`; `link_account`, `unlink_account` — same signatures as today. `get_goal`/`get_subgoal` are consumed directly by `income/services.py` (Task 7) and `suggestions/services.py` (Task 11).
- `goal_accounts` documents use a **deterministic composite ID** `f"{goal_id}_{account_id}"` instead of a random UUID — this replaces Postgres's `UniqueConstraint(fields=["goal", "account"])`: writing the same link twice just overwrites the same document instead of creating a duplicate.

- [ ] **Step 1: Confirm baseline passes**

Run: `uv run pytest apps/goals/tests/test_api.py apps/goals/tests/test_aggregation.py -v`
Expected: PASS.

- [ ] **Step 2: Replace `apps/goals/models.py`**

```python
import uuid
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass
class Goal:
    id: uuid.UUID
    user_id: str
    name: str
    target_amount: Decimal
    current_amount: Decimal
    target_date: date | None
    type: str
    category: str
    created_at: datetime


@dataclass
class Subgoal:
    id: uuid.UUID
    goal_id: uuid.UUID
    user_id: str
    name: str
    target_amount: Decimal
    current_amount: Decimal
    created_at: datetime


@dataclass
class GoalAccount:
    goal_id: uuid.UUID
    account_id: uuid.UUID
    user_id: str
    created_at: datetime
```

- [ ] **Step 3: Run and confirm failure**

Run: `uv run pytest apps/goals/tests/test_api.py -v`
Expected: FAIL — `AttributeError: type object 'Goal' has no attribute 'objects'`.

- [ ] **Step 4: Rewrite `apps/goals/services.py`**

```python
import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import recompute_subgoal_parent, recompute_goal_from_accounts
from apps.common.exceptions import NotFoundError
from .models import Goal, Subgoal, GoalAccount

GOALS_COLLECTION = "goals"
SUBGOALS_COLLECTION = "sub_goals"
GOAL_ACCOUNTS_COLLECTION = "goal_accounts"


def _goal_from_doc(snapshot) -> Goal:
    data = snapshot.to_dict()
    return Goal(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        name=data["name"],
        target_amount=from_cents(data["target_amount"]),
        current_amount=from_cents(data["current_amount"]),
        target_date=date.fromisoformat(data["target_date"]) if data.get("target_date") else None,
        type=data["type"],
        category=data["category"],
        created_at=data["created_at"],
    )


def _subgoal_from_doc(snapshot) -> Subgoal:
    data = snapshot.to_dict()
    return Subgoal(
        id=uuid.UUID(snapshot.id),
        goal_id=uuid.UUID(data["goal_id"]),
        user_id=data["user_id"],
        name=data["name"],
        target_amount=from_cents(data["target_amount"]),
        current_amount=from_cents(data["current_amount"]),
        created_at=data["created_at"],
    )


# --- Goal CRUD ---

def list_goals(user):
    docs = get_client().collection(GOALS_COLLECTION).where("user_id", "==", str(user.id)).stream()
    return [_goal_from_doc(d) for d in docs]


def create_goal(user, payload) -> Goal:
    goal_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    get_client().collection(GOALS_COLLECTION).document(str(goal_id)).set({
        "user_id": str(user.id),
        "name": payload.name,
        "target_amount": to_cents(payload.target_amount),
        "current_amount": to_cents(Decimal("0.00")),
        "target_date": payload.target_date.isoformat() if payload.target_date else None,
        "type": payload.type,
        "category": payload.category,
        "created_at": now,
    })
    return Goal(id=goal_id, user_id=str(user.id), name=payload.name,
               target_amount=payload.target_amount, current_amount=Decimal("0.00"),
               target_date=payload.target_date, type=payload.type, category=payload.category,
               created_at=now)


def get_goal(user, goal_id) -> Goal:
    return _goal_from_doc(get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user))


def update_goal(user, goal_id, payload) -> Goal:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.target_amount is not None:
        updates["target_amount"] = to_cents(payload.target_amount)
    if payload.target_date is not None:
        updates["target_date"] = payload.target_date.isoformat()
    if payload.type is not None:
        updates["type"] = payload.type
    if payload.category is not None:
        updates["category"] = payload.category

    doc_ref = get_client().collection(GOALS_COLLECTION).document(str(goal_id))
    if updates:
        doc_ref.update(updates)
    return _goal_from_doc(doc_ref.get())


def delete_goal(user, goal_id) -> None:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    client = get_client()
    batch = client.batch()

    for sub in client.collection(SUBGOALS_COLLECTION).where("goal_id", "==", str(goal_id)).stream():
        batch.delete(sub.reference)
    for link in client.collection(GOAL_ACCOUNTS_COLLECTION).where("goal_id", "==", str(goal_id)).stream():
        batch.delete(link.reference)
    batch.delete(client.collection(GOALS_COLLECTION).document(str(goal_id)))

    batch.commit()


# --- Subgoal CRUD ---

def list_subgoals(user, goal_id):
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    docs = get_client().collection(SUBGOALS_COLLECTION).where("goal_id", "==", str(goal_id)).stream()
    return [_subgoal_from_doc(d) for d in docs]


def create_subgoal(user, goal_id, payload) -> Subgoal:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    subgoal_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    get_client().collection(SUBGOALS_COLLECTION).document(str(subgoal_id)).set({
        "user_id": str(user.id),
        "goal_id": str(goal_id),
        "name": payload.name,
        "target_amount": to_cents(payload.target_amount),
        "current_amount": to_cents(payload.current_amount),
        "created_at": now,
    })
    recompute_subgoal_parent(str(goal_id))
    return Subgoal(id=subgoal_id, goal_id=uuid.UUID(str(goal_id)), user_id=str(user.id),
                   name=payload.name, target_amount=payload.target_amount,
                   current_amount=payload.current_amount, created_at=now)


def get_subgoal(user, goal_id, subgoal_id) -> Subgoal:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    snapshot = get_owned_or_404_fs(SUBGOALS_COLLECTION, subgoal_id, user)
    if snapshot.get("goal_id") != str(goal_id):
        raise NotFoundError("Subgoal not found.")
    return _subgoal_from_doc(snapshot)


def update_subgoal(user, goal_id, subgoal_id, payload) -> Subgoal:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    snapshot = get_owned_or_404_fs(SUBGOALS_COLLECTION, subgoal_id, user)
    if snapshot.get("goal_id") != str(goal_id):
        raise NotFoundError("Subgoal not found.")

    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.target_amount is not None:
        updates["target_amount"] = to_cents(payload.target_amount)
    if payload.current_amount is not None:
        updates["current_amount"] = to_cents(payload.current_amount)

    doc_ref = get_client().collection(SUBGOALS_COLLECTION).document(str(subgoal_id))
    if updates:
        doc_ref.update(updates)
    recompute_subgoal_parent(str(goal_id))
    return _subgoal_from_doc(doc_ref.get())


def delete_subgoal(user, goal_id, subgoal_id) -> None:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    snapshot = get_owned_or_404_fs(SUBGOALS_COLLECTION, subgoal_id, user)
    if snapshot.get("goal_id") != str(goal_id):
        raise NotFoundError("Subgoal not found.")
    get_client().collection(SUBGOALS_COLLECTION).document(str(subgoal_id)).delete()
    recompute_subgoal_parent(str(goal_id))


# --- GoalAccount (link/unlink) ---

def link_account(user, goal_id, account_id) -> GoalAccount:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    get_owned_or_404_fs("accounts", account_id, user)

    now = datetime.now(timezone.utc)
    link_doc_id = f"{goal_id}_{account_id}"
    get_client().collection(GOAL_ACCOUNTS_COLLECTION).document(link_doc_id).set({
        "user_id": str(user.id),
        "goal_id": str(goal_id),
        "account_id": str(account_id),
        "created_at": now,
    })
    recompute_goal_from_accounts(str(goal_id))
    return GoalAccount(goal_id=uuid.UUID(str(goal_id)), account_id=uuid.UUID(str(account_id)),
                       user_id=str(user.id), created_at=now)


def unlink_account(user, goal_id, account_id) -> None:
    get_owned_or_404_fs(GOALS_COLLECTION, goal_id, user)
    get_owned_or_404_fs("accounts", account_id, user)

    link_doc_id = f"{goal_id}_{account_id}"
    get_client().collection(GOAL_ACCOUNTS_COLLECTION).document(link_doc_id).delete()
    recompute_goal_from_accounts(str(goal_id))
```

- [ ] **Step 5: Remove the now-dead signal wiring**

Delete `backend/apps/goals/signals.py`.

Edit `backend/apps/goals/apps.py`:

```python
from django.apps import AppConfig


class GoalsConfig(AppConfig):
    name = "apps.goals"
    label = "goals"
    default_auto_field = "django.db.models.BigAutoField"
```

- [ ] **Step 6: Delete migrations**

Run: `rm -rf apps/goals/migrations`

- [ ] **Step 7: Run and confirm `test_api.py` passes**

Run: `uv run pytest apps/goals/tests/test_api.py -v`
Expected: PASS.

- [ ] **Step 8: Rewrite `apps/goals/tests/test_aggregation.py`**

The original constructs fixtures via `Goal.objects.create(...)`/`Subgoal.objects.create(...)`/`GoalAccount.objects.create(...)`, which no longer exist. Rewrite it to build fixtures through the now-Firestore-backed `services.py`:

```python
import pytest
from decimal import Decimal
from types import SimpleNamespace
from apps.users.models import User
from apps.accounts.services import create_account
from apps.goals.services import create_goal, create_subgoal, delete_subgoal, link_account, get_goal
from apps.accounts.schemas import AccountIn
from apps.goals.schemas import GoalIn, SubgoalIn


@pytest.fixture
def u(db):
    return User.objects.create_user(email="a@b.co", password="x" * 12)


def _goal_payload(**overrides):
    defaults = dict(name="g", target_amount=Decimal("0"), target_date=None,
                    type="short_term", category="savings")
    defaults.update(overrides)
    return GoalIn(**defaults)


def _subgoal_payload(**overrides):
    defaults = dict(name="s", target_amount=Decimal("10"), current_amount=Decimal("0"))
    defaults.update(overrides)
    return SubgoalIn(**defaults)


def test_subgoals_aggregate_to_parent(u):
    g = create_goal(u, _goal_payload(name="Vacation", type="short_term", category="purchase"))
    create_subgoal(u, g.id, _subgoal_payload(name="Flights", target_amount=Decimal("500"), current_amount=Decimal("100")))
    create_subgoal(u, g.id, _subgoal_payload(name="Hotel", target_amount=Decimal("700"), current_amount=Decimal("0")))

    refreshed = get_goal(u, g.id)
    assert refreshed.target_amount == Decimal("1200.00")
    assert refreshed.current_amount == Decimal("100.00")


def test_subgoal_delete_recomputes_parent(u):
    g = create_goal(u, _goal_payload(type="short_term", category="savings"))
    s1 = create_subgoal(u, g.id, _subgoal_payload(name="a", target_amount=Decimal("10"), current_amount=Decimal("5")))
    create_subgoal(u, g.id, _subgoal_payload(name="b", target_amount=Decimal("20"), current_amount=Decimal("0")))

    delete_subgoal(u, g.id, s1.id)

    refreshed = get_goal(u, g.id)
    assert refreshed.target_amount == Decimal("20.00")
    assert refreshed.current_amount == Decimal("0.00")


def test_linked_accounts_drive_goal_current(u):
    g = create_goal(u, _goal_payload(name="Emergency", target_amount=Decimal("1000"),
                                     type="long_term", category="savings"))
    a1 = create_account(u, AccountIn(name="Sav1", balance=Decimal("300")))
    a2 = create_account(u, AccountIn(name="Sav2", balance=Decimal("400")))

    link_account(u, g.id, a1.id)
    link_account(u, g.id, a2.id)

    refreshed = get_goal(u, g.id)
    assert refreshed.current_amount == Decimal("700.00")


def test_account_balance_change_propagates(u):
    from apps.accounts.services import update_account
    from apps.accounts.schemas import AccountPatch

    g = create_goal(u, _goal_payload(type="long_term", category="savings"))
    a = create_account(u, AccountIn(name="x", balance=Decimal("100")))
    link_account(u, g.id, a.id)

    update_account(u, a.id, AccountPatch(balance=Decimal("250")))

    refreshed = get_goal(u, g.id)
    assert refreshed.current_amount == Decimal("250.00")
```

- [ ] **Step 9: Run and confirm the rewritten aggregation tests pass**

Run: `uv run pytest apps/goals/tests/test_aggregation.py -v`
Expected: PASS (4 passed).

- [ ] **Step 10: Commit**

```bash
git add apps/goals/models.py apps/goals/services.py apps/goals/apps.py apps/goals/tests/test_aggregation.py
git rm apps/goals/signals.py
git add -A apps/goals/migrations
git commit -m "feat(goals): migrate to Firestore, port cascade delete and aggregation rollups"
```

---

### Task 9: `expenses` app → Firestore

**Files:**
- Modify: `backend/apps/expenses/models.py`
- Modify: `backend/apps/expenses/services.py`
- Delete: `backend/apps/expenses/signals.py`
- Modify: `backend/apps/expenses/apps.py`
- Delete: `backend/apps/expenses/migrations/`
- Rewrite: `backend/apps/expenses/tests/test_rollups.py`
- No changes: `backend/apps/expenses/api.py`, `backend/apps/expenses/schemas.py`, `backend/apps/expenses/tests/test_api.py`

**Interfaces:**
- Consumes: `apps.common.firestore.get_client`, `apps.common.firestore_helpers.get_owned_or_404_fs`, `apps.common.money.{to_cents,from_cents}`, `apps.common.rollups.apply_expense_effects`.
- Produces: `Expense` dataclass; `list_expenses`, `create_expense`, `get_expense`, `update_expense`, `delete_expense` — same signatures as today.

- [ ] **Step 1: Confirm baseline passes**

Run: `uv run pytest apps/expenses/tests/test_api.py apps/expenses/tests/test_rollups.py -v`
Expected: PASS.

- [ ] **Step 2: Replace `apps/expenses/models.py`**

```python
import uuid
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal


@dataclass
class Expense:
    id: uuid.UUID
    user_id: str
    budget_category_id: uuid.UUID
    account_id: uuid.UUID | None
    amount: Decimal
    description: str
    date: date
    created_at: datetime
```

- [ ] **Step 3: Run and confirm failure**

Run: `uv run pytest apps/expenses/tests/test_api.py -v`
Expected: FAIL — `AttributeError: type object 'Expense' has no attribute 'objects'`.

- [ ] **Step 4: Rewrite `apps/expenses/services.py`**

```python
import uuid
from datetime import date, datetime, timezone
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import apply_expense_effects
from .models import Expense

COLLECTION = "expenses"


def _from_doc(snapshot) -> Expense:
    data = snapshot.to_dict()
    return Expense(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        budget_category_id=uuid.UUID(data["budget_category_id"]),
        account_id=uuid.UUID(data["account_id"]) if data.get("account_id") else None,
        amount=from_cents(data["amount"]),
        description=data["description"],
        date=date.fromisoformat(data["date"]),
        created_at=data["created_at"],
    )


def list_expenses(user, account_id=None, budget_category_id=None):
    query = get_client().collection(COLLECTION).where("user_id", "==", str(user.id))
    if account_id:
        query = query.where("account_id", "==", str(account_id))
    if budget_category_id:
        query = query.where("budget_category_id", "==", str(budget_category_id))
    return [_from_doc(d) for d in query.stream()]


def create_expense(user, payload) -> Expense:
    get_owned_or_404_fs("budget_categories", payload.budget_category_id, user)
    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)

    expense_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    amount_cents = to_cents(payload.amount)
    account_id = str(payload.account_id) if payload.account_id else None
    get_client().collection(COLLECTION).document(str(expense_id)).set({
        "user_id": str(user.id),
        "budget_category_id": str(payload.budget_category_id),
        "account_id": account_id,
        "amount": amount_cents,
        "description": payload.description,
        "date": payload.date.isoformat(),
        "created_at": now,
    })

    apply_expense_effects(
        old=None,
        new={"account_id": account_id, "budget_category_id": str(payload.budget_category_id),
             "amount_cents": amount_cents},
    )

    return Expense(id=expense_id, user_id=str(user.id), budget_category_id=payload.budget_category_id,
                   account_id=payload.account_id, amount=payload.amount,
                   description=payload.description, date=payload.date, created_at=now)


def get_expense(user, expense_id) -> Expense:
    return _from_doc(get_owned_or_404_fs(COLLECTION, expense_id, user))


def update_expense(user, expense_id, payload) -> Expense:
    snapshot = get_owned_or_404_fs(COLLECTION, expense_id, user)
    old_data = snapshot.to_dict()
    old_effect = {
        "account_id": old_data.get("account_id"),
        "budget_category_id": old_data["budget_category_id"],
        "amount_cents": old_data["amount"],
    }

    updates = {}
    if payload.budget_category_id is not None:
        get_owned_or_404_fs("budget_categories", payload.budget_category_id, user)
        updates["budget_category_id"] = str(payload.budget_category_id)
    if payload.amount is not None:
        updates["amount"] = to_cents(payload.amount)
    if payload.description is not None:
        updates["description"] = payload.description
    if payload.date is not None:
        updates["date"] = payload.date.isoformat()

    fields_set = payload.model_fields_set
    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)
        updates["account_id"] = str(payload.account_id)
    elif "account_id" in fields_set and payload.account_id is None:
        updates["account_id"] = None

    doc_ref = get_client().collection(COLLECTION).document(str(expense_id))
    if updates:
        doc_ref.update(updates)

    new_data = doc_ref.get().to_dict()
    apply_expense_effects(
        old=old_effect,
        new={"account_id": new_data.get("account_id"), "budget_category_id": new_data["budget_category_id"],
             "amount_cents": new_data["amount"]},
    )

    return _from_doc(doc_ref.get())


def delete_expense(user, expense_id) -> None:
    snapshot = get_owned_or_404_fs(COLLECTION, expense_id, user)
    data = snapshot.to_dict()
    get_client().collection(COLLECTION).document(str(expense_id)).delete()
    apply_expense_effects(
        old={"account_id": data.get("account_id"), "budget_category_id": data["budget_category_id"],
             "amount_cents": data["amount"]},
        new=None,
    )
```

- [ ] **Step 5: Remove the now-dead signal wiring**

Delete `backend/apps/expenses/signals.py` (both its `Expense` *and* `ExtraIncome` receivers — the latter's replacement, `apply_extra_income_effects`, is already wired into `income/services.py` from Task 7).

Edit `backend/apps/expenses/apps.py`:

```python
from django.apps import AppConfig


class ExpensesConfig(AppConfig):
    name = "apps.expenses"
    label = "expenses"
    default_auto_field = "django.db.models.BigAutoField"
```

- [ ] **Step 6: Delete migrations**

Run: `rm -rf apps/expenses/migrations`

- [ ] **Step 7: Run and confirm `test_api.py` passes**

Run: `uv run pytest apps/expenses/tests/test_api.py -v`
Expected: PASS.

- [ ] **Step 8: Rewrite `apps/expenses/tests/test_rollups.py`**

The original constructs fixtures via `Account.objects.create`/`BudgetCategory.objects.create`/`Expense.objects.create`/`ExtraIncome.objects.create`. Rewrite using the Firestore-backed services from Tasks 5, 6, 7, and this task:

```python
import pytest
from decimal import Decimal
from datetime import date
from apps.users.models import User
from apps.accounts.services import create_account, get_account
from apps.accounts.schemas import AccountIn
from apps.budget.services import create_category, get_category
from apps.budget.schemas import BudgetCategoryIn
from apps.expenses.services import create_expense, delete_expense
from apps.expenses.schemas import ExpenseIn
from apps.income.services import create_extra
from apps.income.schemas import ExtraIncomeIn


@pytest.fixture
def u(db):
    return User.objects.create_user(email="a@b.co", password="x" * 12)


def test_expense_increments_expense_category_spent(u):
    cat = create_category(u, BudgetCategoryIn(name="Food", limit_amount=Decimal("100"), category_type="expense"))
    create_expense(u, ExpenseIn(budget_category_id=cat.id, amount=Decimal("30"), date=date.today()))

    refreshed = get_category(u, cat.id)
    assert refreshed.spent_amount == Decimal("30.00")


def test_expense_against_income_category_decrements_spent(u):
    cat = create_category(u, BudgetCategoryIn(name="Bonus pool", limit_amount=Decimal("0"), category_type="income"))
    create_expense(u, ExpenseIn(budget_category_id=cat.id, amount=Decimal("50"), date=date.today()))

    refreshed = get_category(u, cat.id)
    assert refreshed.spent_amount == Decimal("-50.00")


def test_expense_decrements_account_balance(u):
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("100")))
    cat = create_category(u, BudgetCategoryIn(name="Food", limit_amount=Decimal("100"), category_type="expense"))
    create_expense(u, ExpenseIn(account_id=acc.id, budget_category_id=cat.id, amount=Decimal("30"), date=date.today()))

    refreshed = get_account(u, acc.id)
    assert refreshed.balance == Decimal("70.00")


def test_expense_delete_reverses_both(u):
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("100")))
    cat = create_category(u, BudgetCategoryIn(name="Food", limit_amount=Decimal("100"), category_type="expense"))
    expense = create_expense(u, ExpenseIn(account_id=acc.id, budget_category_id=cat.id,
                                          amount=Decimal("30"), date=date.today()))

    delete_expense(u, expense.id)

    assert get_account(u, acc.id).balance == Decimal("100.00")
    assert get_category(u, cat.id).spent_amount == Decimal("0.00")


def test_extra_income_credits_account_and_budget(u):
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("100")))
    cat = create_category(u, BudgetCategoryIn(name="Side gig", limit_amount=Decimal("0"), category_type="income"))
    create_extra(u, ExtraIncomeIn(amount=Decimal("50"), date_received=date.today(),
                                  account_id=acc.id, budget_category_id=cat.id))

    assert get_account(u, acc.id).balance == Decimal("150.00")
    assert get_category(u, cat.id).spent_amount == Decimal("50.00")
```

- [ ] **Step 9: Run and confirm the rewritten rollup tests pass**

Run: `uv run pytest apps/expenses/tests/test_rollups.py -v`
Expected: PASS (5 passed).

- [ ] **Step 10: Commit**

```bash
git add apps/expenses/models.py apps/expenses/services.py apps/expenses/apps.py apps/expenses/tests/test_rollups.py
git rm apps/expenses/signals.py
git add -A apps/expenses/migrations
git commit -m "feat(expenses): migrate to Firestore, port balance/budget rollups"
```

---

### Task 10: `allocations` app → Firestore

**Files:**
- Modify: `backend/apps/allocations/models.py`
- Modify: `backend/apps/allocations/services.py`
- Delete: `backend/apps/allocations/signals.py`
- Modify: `backend/apps/allocations/apps.py`
- Delete: `backend/apps/allocations/migrations/`
- Rewrite: `backend/apps/allocations/tests/test_sync.py`
- No changes: `backend/apps/allocations/api.py`, `backend/apps/allocations/schemas.py`, `backend/apps/allocations/tests/test_api.py`

**Interfaces:**
- Consumes: `apps.common.firestore.get_client`, `apps.common.firestore_helpers.get_owned_or_404_fs`, `apps.common.money.{to_cents,from_cents}`, `apps.common.rollups.apply_allocation_effects`.
- Produces: `GoalAllocation` dataclass; `list_allocations`, `create_allocation`, `get_allocation`, `update_allocation`, `delete_allocation`, `recent_allocation_summary` — same signatures as today.

- [ ] **Step 1: Confirm baseline passes**

Run: `uv run pytest apps/allocations/tests/test_api.py apps/allocations/tests/test_sync.py -v`
Expected: PASS.

- [ ] **Step 2: Replace `apps/allocations/models.py`**

```python
import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass
class GoalAllocation:
    id: uuid.UUID
    user_id: str
    goal_id: uuid.UUID
    sub_goal_id: uuid.UUID | None
    account_id: uuid.UUID | None
    amount: Decimal
    created_at: datetime
```

- [ ] **Step 3: Run and confirm failure**

Run: `uv run pytest apps/allocations/tests/test_api.py -v`
Expected: FAIL — `AttributeError: type object 'GoalAllocation' has no attribute 'objects'`.

- [ ] **Step 4: Rewrite `apps/allocations/services.py`**

```python
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from apps.common.firestore import get_client
from apps.common.firestore_helpers import get_owned_or_404_fs
from apps.common.money import to_cents, from_cents
from apps.common.rollups import apply_allocation_effects
from apps.common.exceptions import AppError
from .models import GoalAllocation

COLLECTION = "allocations"


def _from_doc(snapshot) -> GoalAllocation:
    data = snapshot.to_dict()
    return GoalAllocation(
        id=uuid.UUID(snapshot.id),
        user_id=data["user_id"],
        goal_id=uuid.UUID(data["goal_id"]),
        sub_goal_id=uuid.UUID(data["sub_goal_id"]) if data.get("sub_goal_id") else None,
        account_id=uuid.UUID(data["account_id"]) if data.get("account_id") else None,
        amount=from_cents(data["amount"]),
        created_at=data["created_at"],
    )


def list_allocations(user, goal_id=None):
    query = get_client().collection(COLLECTION).where("user_id", "==", str(user.id))
    if goal_id:
        query = query.where("goal_id", "==", str(goal_id))
    return [_from_doc(d) for d in query.stream()]


def create_allocation(user, payload) -> GoalAllocation:
    get_owned_or_404_fs("goals", payload.goal_id, user)

    sub_goal_id = None
    if payload.sub_goal_id is not None:
        sub_goal_snapshot = get_owned_or_404_fs("sub_goals", payload.sub_goal_id, user)
        if sub_goal_snapshot.get("goal_id") != str(payload.goal_id):
            raise AppError(
                code="subgoal_goal_mismatch",
                message="The sub_goal does not belong to the specified goal.",
                status_code=400,
            )
        sub_goal_id = str(payload.sub_goal_id)

    account_id = None
    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)
        account_id = str(payload.account_id)

    allocation_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    amount_cents = to_cents(payload.amount)
    get_client().collection(COLLECTION).document(str(allocation_id)).set({
        "user_id": str(user.id),
        "goal_id": str(payload.goal_id),
        "sub_goal_id": sub_goal_id,
        "account_id": account_id,
        "amount": amount_cents,
        "created_at": now,
    })

    apply_allocation_effects(
        old=None,
        new={"account_id": account_id, "goal_id": str(payload.goal_id),
             "sub_goal_id": sub_goal_id, "amount_cents": amount_cents},
    )

    return GoalAllocation(id=allocation_id, user_id=str(user.id), goal_id=payload.goal_id,
                          sub_goal_id=payload.sub_goal_id, account_id=payload.account_id,
                          amount=payload.amount, created_at=now)


def get_allocation(user, allocation_id) -> GoalAllocation:
    return _from_doc(get_owned_or_404_fs(COLLECTION, allocation_id, user))


def update_allocation(user, allocation_id, payload) -> GoalAllocation:
    snapshot = get_owned_or_404_fs(COLLECTION, allocation_id, user)
    old_data = snapshot.to_dict()
    old_effect = {
        "account_id": old_data.get("account_id"),
        "goal_id": old_data["goal_id"],
        "sub_goal_id": old_data.get("sub_goal_id"),
        "amount_cents": old_data["amount"],
    }

    updates = {}
    effective_goal_id = old_data["goal_id"]
    if payload.goal_id is not None:
        get_owned_or_404_fs("goals", payload.goal_id, user)
        updates["goal_id"] = str(payload.goal_id)
        effective_goal_id = str(payload.goal_id)

    fields_set = payload.model_fields_set
    if payload.sub_goal_id is not None:
        sub_goal_snapshot = get_owned_or_404_fs("sub_goals", payload.sub_goal_id, user)
        if sub_goal_snapshot.get("goal_id") != effective_goal_id:
            raise AppError(
                code="subgoal_goal_mismatch",
                message="The sub_goal does not belong to the specified goal.",
                status_code=400,
            )
        updates["sub_goal_id"] = str(payload.sub_goal_id)
    elif "sub_goal_id" in fields_set and payload.sub_goal_id is None:
        updates["sub_goal_id"] = None

    if payload.account_id is not None:
        get_owned_or_404_fs("accounts", payload.account_id, user)
        updates["account_id"] = str(payload.account_id)
    elif "account_id" in fields_set and payload.account_id is None:
        updates["account_id"] = None

    if payload.amount is not None:
        updates["amount"] = to_cents(payload.amount)

    doc_ref = get_client().collection(COLLECTION).document(str(allocation_id))
    if updates:
        doc_ref.update(updates)

    new_data = doc_ref.get().to_dict()
    apply_allocation_effects(
        old=old_effect,
        new={"account_id": new_data.get("account_id"), "goal_id": new_data["goal_id"],
             "sub_goal_id": new_data.get("sub_goal_id"), "amount_cents": new_data["amount"]},
    )

    return _from_doc(doc_ref.get())


def delete_allocation(user, allocation_id) -> None:
    snapshot = get_owned_or_404_fs(COLLECTION, allocation_id, user)
    data = snapshot.to_dict()
    get_client().collection(COLLECTION).document(str(allocation_id)).delete()
    apply_allocation_effects(
        old={"account_id": data.get("account_id"), "goal_id": data["goal_id"],
             "sub_goal_id": data.get("sub_goal_id"), "amount_cents": data["amount"]},
        new=None,
    )


def recent_allocation_summary(user, days: int = 30) -> dict:
    since = datetime.now(timezone.utc) - timedelta(days=days)
    client = get_client()
    docs = client.collection(COLLECTION).where("user_id", "==", str(user.id)).where(
        "created_at", ">", since
    ).stream()

    totals = {"savings": 0, "purchase": 0}
    for doc in docs:
        data = doc.to_dict()
        goal_snapshot = client.collection("goals").document(data["goal_id"]).get()
        if not goal_snapshot.exists:
            continue
        category = goal_snapshot.get("category")
        if category in totals:
            totals[category] += data["amount"]

    return {
        "totalSavings": float(from_cents(totals["savings"])),
        "totalPurchases": float(from_cents(totals["purchase"])),
    }
```

Note: `recent_allocation_summary`'s Firestore query filters on both `user_id` (equality) and `created_at` (range) — this is exactly the kind of compound query that needs a composite index; it's captured in Task 13's `firestore.indexes.json`.

- [ ] **Step 5: Remove the now-dead signal wiring**

Delete `backend/apps/allocations/signals.py`.

Edit `backend/apps/allocations/apps.py`:

```python
from django.apps import AppConfig


class AllocationsConfig(AppConfig):
    name = "apps.allocations"
    label = "allocations"
    default_auto_field = "django.db.models.BigAutoField"
```

- [ ] **Step 6: Delete migrations**

Run: `rm -rf apps/allocations/migrations`

- [ ] **Step 7: Run and confirm `test_api.py` passes**

Run: `uv run pytest apps/allocations/tests/test_api.py -v`
Expected: PASS.

- [ ] **Step 8: Rewrite `apps/allocations/tests/test_sync.py`**

```python
import pytest
from decimal import Decimal
from apps.users.models import User
from apps.accounts.services import create_account, get_account
from apps.accounts.schemas import AccountIn
from apps.goals.services import create_goal, create_subgoal, get_goal
from apps.goals.schemas import GoalIn, SubgoalIn
from apps.allocations.services import create_allocation, delete_allocation, recent_allocation_summary
from apps.allocations.schemas import AllocationIn


@pytest.fixture
def u(db):
    return User.objects.create_user(email="a@b.co", password="x" * 12)


def test_allocation_debits_account_credits_goal(u):
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("500")))
    g = create_goal(u, GoalIn(name="g", target_amount=Decimal("1000"), target_date=None,
                              type="long_term", category="savings"))

    create_allocation(u, AllocationIn(goal_id=g.id, account_id=acc.id, amount=Decimal("200")))

    assert get_account(u, acc.id).balance == Decimal("300.00")
    assert get_goal(u, g.id).current_amount == Decimal("200.00")


def test_allocation_credits_subgoal_when_present(u):
    g = create_goal(u, GoalIn(name="g", target_amount=Decimal("0"), target_date=None,
                              type="short_term", category="purchase"))
    s = create_subgoal(u, g.id, SubgoalIn(name="Flights", target_amount=Decimal("500"),
                                          current_amount=Decimal("0")))

    create_allocation(u, AllocationIn(goal_id=g.id, sub_goal_id=s.id, amount=Decimal("100")))

    from apps.goals.services import get_subgoal
    refreshed_subgoal = get_subgoal(u, g.id, s.id)
    assert refreshed_subgoal.current_amount == Decimal("100.00")
    # parent rolls up via recompute_subgoal_parent, called from apply_allocation_effects
    assert get_goal(u, g.id).current_amount == Decimal("100.00")


def test_allocation_delete_reverses(u):
    acc = create_account(u, AccountIn(name="Chk", balance=Decimal("500")))
    g = create_goal(u, GoalIn(name="g", target_amount=Decimal("1000"), target_date=None,
                              type="long_term", category="savings"))

    allocation = create_allocation(u, AllocationIn(goal_id=g.id, account_id=acc.id, amount=Decimal("200")))
    delete_allocation(u, allocation.id)

    assert get_account(u, acc.id).balance == Decimal("500.00")
    assert get_goal(u, g.id).current_amount == Decimal("0.00")


def test_recent_summary_buckets_by_goal_category(u):
    g_sav = create_goal(u, GoalIn(name="s", target_amount=Decimal("0"), target_date=None,
                                  type="long_term", category="savings"))
    g_pur = create_goal(u, GoalIn(name="p", target_amount=Decimal("0"), target_date=None,
                                  type="short_term", category="purchase"))

    create_allocation(u, AllocationIn(goal_id=g_sav.id, amount=Decimal("100")))
    create_allocation(u, AllocationIn(goal_id=g_pur.id, amount=Decimal("40")))

    summary = recent_allocation_summary(u, days=30)
    assert summary == {"totalSavings": 100.0, "totalPurchases": 40.0}
```

- [ ] **Step 9: Run and confirm the rewritten sync tests pass**

Run: `uv run pytest apps/allocations/tests/test_sync.py -v`
Expected: PASS (4 passed).

- [ ] **Step 10: Commit**

```bash
git add apps/allocations/models.py apps/allocations/services.py apps/allocations/apps.py apps/allocations/tests/test_sync.py
git rm apps/allocations/signals.py
git add -A apps/allocations/migrations
git commit -m "feat(allocations): migrate to Firestore, port balance/goal-progress rollups"
```

---

### Task 11: `suggestions` app → Firestore, rewired off direct ORM access

**Files:**
- Modify: `backend/apps/suggestions/models.py`
- Modify: `backend/apps/suggestions/services.py`
- Delete: `backend/apps/suggestions/migrations/`
- No changes: `backend/apps/suggestions/api.py`, `backend/apps/suggestions/schemas.py`, `backend/apps/suggestions/tests/test_api.py`

**Interfaces:**
- Consumes: `apps.common.firestore.get_client`, `apps.common.money.to_cents`, `apps.goals.services.{list_goals,list_subgoals}`, `apps.accounts.services.list_accounts`, `apps.allocations.services.recent_allocation_summary`.
- Produces: `AllocationSuggestion` dataclass; `gather_context(user) -> dict`, `_build_prompt`, `call_gemini`, `generate(user, excess) -> dict` — same signatures as today.

- [ ] **Step 1: Confirm baseline passes**

Run: `uv run pytest apps/suggestions/tests/test_api.py -v`
Expected: PASS.

- [ ] **Step 2: Replace `apps/suggestions/models.py`**

```python
import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass
class AllocationSuggestion:
    id: uuid.UUID
    user_id: str
    excess_funds: Decimal
    response_json: dict
    created_at: datetime
```

- [ ] **Step 3: Run and confirm failure**

Run: `uv run pytest apps/suggestions/tests/test_api.py -v`
Expected: FAIL — `AttributeError: type object 'AllocationSuggestion' has no attribute 'objects'` (raised from `generate`'s call to `.objects.create`).

- [ ] **Step 4: Rewrite `apps/suggestions/services.py`**

```python
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
from .models import AllocationSuggestion

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
```

- [ ] **Step 5: Delete migrations**

Run: `rm -rf apps/suggestions/migrations`

- [ ] **Step 6: Run and confirm pass**

Run: `uv run pytest apps/suggestions/tests/test_api.py -v`
Expected: PASS. (`test_api.py` mocks `services.call_gemini`, so no real Gemini call happens — only `gather_context` and the Firestore write in `generate` are exercised for real against the emulator.)

- [ ] **Step 7: Commit**

```bash
git add apps/suggestions/models.py apps/suggestions/services.py
git add -A apps/suggestions/migrations
git commit -m "feat(suggestions): migrate to Firestore, consume sibling apps' services instead of their ORM models"
```

---

### Task 12: `dashboard` app → Firestore, rewired off direct ORM access

**Files:**
- Modify: `backend/apps/dashboard/services.py`
- No changes: `backend/apps/dashboard/api.py`, `backend/apps/dashboard/schemas.py`, `backend/apps/dashboard/tests/test_api.py` (no `models.py` exists for this app, and none is created — it has no data of its own)

**Interfaces:**
- Consumes: `apps.accounts.services.list_accounts`, `apps.goals.services.list_goals`, `apps.budget.services.list_categories`.
- Produces: `dashboard_summary(user) -> dict` — same signature and same five keys as today.

- [ ] **Step 1: Confirm baseline passes**

Run: `uv run pytest apps/dashboard/tests/test_api.py -v`
Expected: PASS.

- [ ] **Step 2: Rewrite `apps/dashboard/services.py`**

```python
from decimal import Decimal, ROUND_HALF_UP
from apps.accounts.services import list_accounts
from apps.goals.services import list_goals
from apps.budget.services import list_categories

_TWO_PLACES = Decimal("0.01")


def _sum(items, attr) -> Decimal:
    total = sum((getattr(item, attr) for item in items), Decimal("0"))
    return total.quantize(_TWO_PLACES, rounding=ROUND_HALF_UP)


def dashboard_summary(user) -> dict:
    accounts = list_accounts(user)
    goals = list_goals(user)
    categories = list_categories(user)

    return {
        "total_balance":        _sum(accounts, "balance"),
        "goals_total_target":   _sum(goals, "target_amount"),
        "goals_total_current":  _sum(goals, "current_amount"),
        "budgets_total_limit":  _sum(categories, "limit_amount"),
        "budgets_total_spent":  _sum(categories, "spent_amount"),
    }
```

This is a direct behavioral port: the original did `qs.aggregate(t=Sum(field))["t"] or Decimal("0")` then quantized; `_sum` does the equivalent by summing the already-materialized dataclass list in Python (each app's `list_*` function already returns `Decimal`-typed fields via `from_cents`), since a Firestore dataclass has no server-side `.aggregate()`.

- [ ] **Step 3: Run and confirm pass**

Run: `uv run pytest apps/dashboard/tests/test_api.py -v`
Expected: PASS — unchanged test file, now exercising the rewired services function.

- [ ] **Step 4: Commit**

```bash
git add apps/dashboard/services.py
git commit -m "feat(dashboard): consume sibling apps' services instead of their ORM models directly"
```

---

### Task 13: Author `firestore.indexes.json`

**Files:**
- Create: `backend/firestore.indexes.json`

**Interfaces:**
- None (static config file, not imported by any Python code).

- [ ] **Step 1: Enumerate every compound query written across Tasks 5–12**

Grep for `.where(` chains with more than one call in the same query, or a `.where(...).order_by(...)`:

Run: `grep -rn "\.where(" apps/*/services.py`

Expected matches (from the code above): `expenses/services.py::list_expenses` (up to 3 `.where()` calls chained: `user_id` + optional `account_id` + optional `budget_category_id`), `income/services.py::list_extra` (same 3-field shape), `allocations/services.py::list_allocations` (`user_id` + optional `goal_id`), `allocations/services.py::recent_allocation_summary` (`user_id` + `created_at` range).

- [ ] **Step 2: Write `backend/firestore.indexes.json`**

```json
{
  "indexes": [
    {
      "collectionGroup": "expenses",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "user_id", "order": "ASCENDING" },
        { "fieldPath": "account_id", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "expenses",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "user_id", "order": "ASCENDING" },
        { "fieldPath": "budget_category_id", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "extra_income",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "user_id", "order": "ASCENDING" },
        { "fieldPath": "account_id", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "extra_income",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "user_id", "order": "ASCENDING" },
        { "fieldPath": "budget_category_id", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "allocations",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "user_id", "order": "ASCENDING" },
        { "fieldPath": "goal_id", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "allocations",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "user_id", "order": "ASCENDING" },
        { "fieldPath": "created_at", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

This is the same file format `firebase deploy --only firestore:indexes` and `gcloud firestore indexes composite create --database=...` both consume — ready to apply once a real GCP project exists (a future task).

- [ ] **Step 3: Commit**

```bash
git add firestore.indexes.json
git commit -m "docs(firestore): document composite indexes needed by compound queries"
```

---

### Task 14: Final verification and cleanup

**Files:**
- Modify: `README.md`

**Interfaces:**
- None — this task is verification and documentation only.

- [ ] **Step 1: Full test suite, fresh containers**

Run:
```bash
make down
make clean   # type "yes" when prompted — wipes the Postgres dev volume
make up
```
Expected: `db`, `firestore`, `web` all become healthy; `web`'s startup log shows `python manage.py migrate` applying only `apps.users`' migrations cleanly (no errors about missing migration files for the 7 converted apps, since their `django_migrations` history rows were wiped along with the volume).

- [ ] **Step 2: Run the entire backend test suite**

Run: `make test`
Expected: all tests pass — `apps.users`' existing suite (unaffected, SQLite in-memory) plus every converted app's `test_api.py` and rewritten rollup/aggregation/sync test file.

- [ ] **Step 3: Manual end-to-end verification through the API**

Run: `make health` — expect `{"status": "ok"}`.

With `make up` running, exercise the full flow via `curl` (or the Flutter app pointed at `localhost:8000`):
1. Sign up / log in via `apps.users` (unchanged) to get a JWT.
2. `POST /api/v1/accounts` → create an account.
3. `POST /api/v1/budget/categories` → create a category.
4. `POST /api/v1/expenses` referencing both → confirm the account balance and category `spent_amount` update via `GET /api/v1/accounts/{id}` and `GET /api/v1/budget/categories/{id}`.
5. `POST /api/v1/goals` → create a goal, `POST /api/v1/goals/{id}/accounts` to link the account → confirm `GET /api/v1/goals/{id}` shows `current_amount` matching the linked account's balance.
6. `DELETE /api/v1/goals/{id}` → confirm subgoals/links are gone too (cascade).
7. `GET /api/v1/dashboard/summary` → confirm the aggregate totals match what was created above.

- [ ] **Step 4: Update `README.md`**

Add a short section (find the existing "Getting started" or equivalent section and add beneath it):

```markdown
## Firestore (local dev)

Business data (`accounts`, `budget`, `income`, `goals`, `expenses`, `allocations`,
`suggestions`) is stored in Google Cloud Firestore. Locally this runs against the
Firestore Emulator, started automatically by `make up` alongside Postgres (which
still backs auth only). No GCP project or credentials are needed for local dev —
the emulator runs fully offline against the dummy project ID in `.env.example`.

Run `make logs-firestore` to tail the emulator's logs.
```

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: document local Firestore emulator setup"
```

---

## Self-Review Notes

**Spec coverage:** every Decisions-table row in `docs/superpowers/specs/2026-08-04-firestore-emulator-migration-design.md` has a corresponding task — tooling (Task 1), client/money/ownership (Task 2), rollups (Task 3), testing infra (Task 4), the 7 business apps in the spec's dependency order plus the `dashboard`/`suggestions` bypass fix (Tasks 5–12), composite indexes (Task 13), and final Postgres-volume cleanup + docs (Task 14).

**Type consistency:** `get_owned_or_404_fs` is used with the exact signature defined in Task 2 throughout every later task. `apply_expense_effects`/`apply_extra_income_effects`/`apply_allocation_effects`'s `old`/`new` dict shapes, defined in Task 3, match exactly what Tasks 7, 9, and 10 construct and pass in. `to_cents`/`from_cents` are used consistently for every persisted decimal field across every app — no field anywhere stores a raw `Decimal` or `float`.
