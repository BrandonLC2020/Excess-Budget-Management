# Firestore + Emulator Migration — Design

**Date:** 2026-08-04
**ClickUp:** [86bb077rp](https://app.clickup.com/t/86bb077rp) — "transition local database to Google Cloud Firestore and use the Emulator"
**Status:** Design approved, pending spec review before plan-writing

## Goal

Move the 7 business-data Django apps (`accounts`, `income`, `budget`, `goals`, `expenses`, `allocations`, `suggestions`) off Postgres/Django ORM and onto **Google Cloud Firestore** (Native mode), developed locally against the **Firestore Emulator** with zero-code-change parity to production. This is driven by cost, not convenience: the app has no live userbase yet, and Firestore's pay-per-use pricing (generous free tier, $0 when idle) beats Cloud SQL's fixed always-on instance floor for a project starting at zero traffic. There is no GCP project yet — this task only prepares local dev; provisioning real GCP Firestore is a future task.

## Non-Goals

- **Auth migration.** `apps.users` (User/Profile, Django admin, sessions, `django-ninja-jwt`) stays exactly as-is on Postgres/Django ORM. Switching to Google Cloud Identity Platform (GCIP) is a separate, later task — building throwaway Firestore-backed auth now (to replace with GCIP soon after) is waste.
- **Real GCP provisioning.** No GCP project creation, no prod Firestore instance, no `infra/*.tf` changes. Emulator-only, against a dummy project ID.
- **Data backfill.** No live users exist, so there is no Postgres → Firestore migration script. The old Postgres tables for the 7 apps are simply dropped (migrations deleted), not migrated.
- **Django admin equivalent** for the now-Firestore-backed models. Accepted trade-off — these models drop out of `/admin` since they're no longer ORM-registered.
- **CI changes.** The repo has no CI config yet; wiring a CI Firestore emulator service is left for whenever CI is set up.
- **Dropping Postgres.** The `db` service in `docker-compose.yml` stays, unchanged, for auth.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Scope | Full migration of all 7 business apps now | No live users → no data-migration risk. Deferring piecemeal just delays the same total rewrite. |
| Auth | Stays on Postgres/Django ORM, untouched | `User` is `AbstractBaseUser`+`PermissionsMixin`, deeply load-bearing for `django.contrib.admin`/`auth`/`django-ninja-jwt`. GCIP (a separate task) will replace it soon; not worth building Firestore-backed auth twice. |
| Client library | Official `google-cloud-firestore` SDK | Best-documented, no third-party ODM risk. `FIRESTORE_EMULATOR_HOST` env var gives exact code parity between emulator and prod with zero branching — this *is* the mechanism that makes the cutover seamless. |
| Data shape | Flat top-level collections + `user_id` string field per doc | Mirrors today's `.objects.filter(user=user)` pattern almost line-for-line. Subcollections (`users/{uid}/...`) would only pay off if Flutter talked to Firestore directly and needed security-rule isolation — it doesn't; Django brokers all access. |
| Document IDs | Keep app-generated `uuid.uuid4()` as the doc ID (`.document(str(id))`) | Every `*Out` schema in `schemas.py` types `id: uuid.UUID`. Keeping app-generated UUIDs means **zero changes** to `api.py` or `schemas.py` in any of the 7 apps. |
| Cross-references (e.g. `Expense.budget_category`) | Plain string ID fields, validated in the service layer | Firestore has no FK constraints. `get_owned_or_404_fs` becomes the single enforcement point, same role `get_owned_or_404` plays today. |
| Cascade deletes | Explicit per-app logic using a Firestore `WriteBatch` | Postgres's `on_delete=CASCADE` has no Firestore equivalent; each app's `delete_*` service function does it explicitly. |
| Singleton-per-user models (`OvertimeSettings`) | One doc per user, doc ID = user's UUID | Direct representation of the existing `OneToOneField` — no query needed to find "the" settings doc. |
| Emulator flavor | `gcloud emulators firestore start` (GCP-native, not Firebase CLI) | Consistent with staying off Firebase branding, matching the GCIP (not Firebase Auth) decision made for the future auth task. |
| Testing | Real emulator required, no in-memory fake | Matches the task's own framing ("use the Emulator"). `apps.users` tests keep using SQLite in-memory, unaffected. |
| Cross-app side effects (balance/spent/goal-progress rollups) | Django signals replaced with explicit function calls in `services.py`, atomic increments via `firestore.Increment()` | Django's signal dispatcher only fires on real `models.Model` saves; it cannot fire on Firestore writes. `expenses/signals.py`, `allocations/signals.py`, `goals/signals.py`, and `accounts/signals.py` implement real cross-app business logic (balance/budget/goal-progress consistency) that must be ported deliberately, not dropped. |
| Decimal/money field storage | Every persisted decimal field stored as an **integer in cents** (`$45.00` → `4500`), converted at the service-layer boundary via `apps/common/money.py::to_cents`/`from_cents` | Firestore has no native `Decimal` type, only `double`/`integer`. `double` risks float-rounding drift across repeated `Increment()` calls — unacceptable for a budgeting app. Every persisted decimal field in the current schema already uses `decimal_places=2`, so a uniform ×100 integer scaling has no exceptions and keeps `firestore.Increment()` usable (it only works on numeric fields, not strings). |

## Architecture

### High-level

```
Flutter / Django Ninja API            apps.users (auth)         7 business apps
        (unchanged)          ───────▶  Postgres 16                Firestore (Native mode)
                                        (unchanged)                 via google-cloud-firestore SDK
                                                                     │
                                                        FIRESTORE_EMULATOR_HOST set (dev/test)
                                                                     │            unset (prod)
                                                                     ▼                  ▼
                                                          Firestore Emulator     real GCP Firestore
                                                          (docker-compose)         (future task)
```

Local dev: `docker compose up` brings up `db` (Postgres, for auth) + a new `firestore` service (emulator) + `web` (Django). No GCP project needed locally — the emulator runs fully offline against a dummy project ID (e.g. `excess-budget-dev`).

### New/changed backend layout (`backend/`)

```
backend/
├── docker-compose.yml            # + firestore service (gcloud emulator), db unchanged
├── pyproject.toml                # + google-cloud-firestore
├── .env.example                  # + GOOGLE_CLOUD_PROJECT, FIRESTORE_EMULATOR_HOST
├── firestore.indexes.json        # NEW — composite indexes, for future prod deploy
├── apps/
│   ├── common/
│   │   ├── firestore.py          # NEW — cached client factory: get_client()
│   │   ├── firestore_helpers.py  # NEW — get_owned_or_404_fs(collection, doc_id, user)
│   │   ├── rollups.py            # NEW — explicit-call replacements for the 4 signal files
│   │   ├── money.py              # NEW — to_cents(Decimal) -> int, from_cents(int) -> Decimal
│   │   └── permissions.py        # unchanged — still used by apps.users
│   ├── users/                    # UNCHANGED — Postgres/ORM auth core
│   ├── accounts/
│   │   ├── models.py             # ORM class → @dataclass Account
│   │   ├── services.py           # rewritten: Firestore reads/writes
│   │   ├── migrations/           # DELETED
│   │   └── api.py, schemas.py    # UNCHANGED
│   ├── income/                   # same shape, incl. OvertimeSettings singleton-doc handling
│   ├── budget/                   # same shape
│   ├── goals/                    # same shape + explicit WriteBatch cascade for subgoals/goal_accounts
│   ├── expenses/                 # same shape
│   ├── allocations/              # same shape
│   ├── suggestions/               # services.py rewritten to call sibling services (see below)
│   └── dashboard/                # services.py rewritten to call sibling services (see below)
```

### Data flow (representative example: `budget` app)

- **Create:** `create_category(user, payload)` builds `{"user_id": str(user.id), "name": ..., "limit_amount": ..., ...}`, generates `id = uuid4()`, writes via `db.collection("budget_categories").document(str(id)).set(data)`.
- **List:** `list_categories(user)` → `db.collection("budget_categories").where("user_id", "==", str(user.id)).order_by("created_at").stream()`, mapped into `BudgetCategory` dataclasses.
- **Get/Update/Delete:** route through `get_owned_or_404_fs("budget_categories", category_id, user)`, which checks `snapshot.exists` and `snapshot.get("user_id") == str(user.id)`, raising the existing `NotFoundError` on failure — the exact contract `get_owned_or_404` provides today.
- **Cascades (goals app):** `delete_goal(user, goal_id)` fetches the goal via the helper, then queries `sub_goals` and `goal_accounts` for `goal_id == goal.id`, and removes all three (goal + children) in one `WriteBatch.commit()`.
- **Singleton (income app):** `get_or_create_overtime_settings(user)` reads `db.collection("overtime_settings").document(str(user.id))` directly — no query needed since the doc ID *is* the user ID.

### `dashboard` and `suggestions` — a bypass, corrected

`dashboard/services.py::dashboard_summary` and `suggestions/services.py::gather_context` don't go through `accounts`/`goals`/`budget`'s own service functions today — they import those apps' ORM models directly (`Account.objects.filter(user=user).aggregate(Sum("balance"))`, `Goal.objects.filter(user=user).prefetch_related("subgoals")`) and query them inline. Since a Firestore dataclass has no `.objects` manager or `.aggregate()`/`.prefetch_related()`, this breaks outright rather than needing a mechanical swap — it needs rewriting to call the sibling apps' own (already-converted) service functions instead: `dashboard_summary` calls `accounts.services.list_accounts(user)`, `goals.services.list_goals(user)`, `budget.services.list_categories(user)` and sums the relevant field in Python; `gather_context` calls `goals.services.list_goals(user)` + `goals.services.list_subgoals(user, goal.id)` per goal, and `accounts.services.list_accounts(user)`. This is a net improvement, not just a workaround — it removes the last two places in the codebase that reach into another app's data layer directly instead of through its service boundary, matching the pattern `get_owned_or_404`/`get_owned_or_404_fs` already establishes everywhere else.

### Composite indexes — known parity gap

`gcloud emulators firestore start` does **not** enforce composite-index requirements as strictly as production Firestore does. `firestore.indexes.json` will document the indexes each app's compound queries need (e.g. `user_id` + `created_at` ordering) for when prod Firestore is eventually provisioned, but a missing-index bug that would fail in prod may pass silently against the local emulator. This is a real, accepted gap — not something local-only tooling can fully close.

### Aggregation & side-effects — replacing Django signals

Four apps currently rely on Django's `post_save`/`post_delete`/`pre_save` signal dispatch to keep derived totals consistent across app boundaries. Signals only fire on real `models.Model` instances, so once `models.py` becomes plain dataclasses, none of this logic fires anymore unless it's ported. Each signal receiver becomes an explicit function call at the point in `services.py` where the equivalent write happens — same logic, same ordering (old-value reversal before new-value application on updates), just invoked directly instead of dispatched. Atomic increments (`F("field") + delta` in Django) become `firestore.Increment(delta)` passed to `.update()`, preserving the same race-free guarantee without a read-modify-write round trip.

Mapping of every existing receiver to its explicit-call replacement:

| Today (signal, file) | Fires on | Replacement call site | What it does |
|---|---|---|---|
| `_expense_post_save` / `_expense_post_delete` (`expenses/signals.py`) | `Expense` create/update/delete | `create_expense`, `update_expense`, `delete_expense` in `expenses/services.py` | `Increment` on the linked `Account.balance` (negative) and `BudgetCategory.spent_amount` (sign depends on `category_type`), reversing old values first on update. |
| `_income_post_save` / `_income_post_delete` (`expenses/signals.py`, sender=`ExtraIncome`) | `ExtraIncome` create/update/delete | `create_extra`, `update_extra`, `delete_extra` in `income/services.py` | Mirror of the above with opposite signs (income credits balance/budget instead of debiting). |
| `_subgoal_saved` / `_subgoal_deleted` (`goals/signals.py`) | `Subgoal` create/update/delete | `create_subgoal`, `update_subgoal`, `delete_subgoal` in `goals/services.py` | Re-sums all sibling subgoals' `target_amount`/`current_amount` and writes the parent `Goal`'s totals. |
| `_goal_account_added` / `_goal_account_removed` (`goals/signals.py`) | `GoalAccount` create/delete | `link_account`, `unlink_account` in `goals/services.py` | Re-sums linked accounts' `balance` and writes `Goal.current_amount`. |
| `_account_saved` (`accounts/signals.py`) | `Account.balance` change | `update_account` in `accounts/services.py` (only when `balance` is part of the patch) | Looks up every `GoalAccount` referencing this account (Firestore query on `goal_accounts` where `account_id == account.id`) and re-runs the same goal-account recompute as above for each. |
| `_alloc_post_save` / `_alloc_post_delete` (`allocations/signals.py`) | `GoalAllocation` create/update/delete | `create_allocation`, `update_allocation`, `delete_allocation` in `allocations/services.py` | `Increment` on `Account.balance` (negative); routes progress `Increment` to `Subgoal.current_amount` (which itself then triggers the same parent-recompute call `create_subgoal`'s replacement uses) or directly to `Goal.current_amount`. |

Since there's no signal dispatcher enforcing call order across apps, each of these explicit calls lives in `apps/common/rollups.py` (new) as plain functions (`apply_expense_effects`, `apply_extra_income_effects`, `recompute_subgoal_parent`, `recompute_goal_from_accounts`, `apply_allocation_effects`), imported directly by the service module that needs them. Unlike the signal files they replace — which import each other's Django *models* (`expenses/signals.py` imports `Account`, `BudgetCategory`, `ExtraIncome`) — `rollups.py` operates on raw Firestore collection names and dicts (`db.collection("accounts").document(id).update({"balance": Increment(delta)})`), with no dependency on any other app's `models.py` or `services.py`. That means `rollups.py` can be written in full before any of the 7 apps are converted, and there's no cross-app import-order constraint during rollout.

## Error handling

Firestore's `.get()` returns a snapshot with `.exists == False` rather than raising on a missing document, so `get_owned_or_404_fs` checks `exists` + ownership and raises the same `NotFoundError` already used everywhere in `apps/common/exceptions.py` — no changes needed in `api.py`'s exception handling for any of the 7 apps. There are no DB-level unique constraints on business fields today (only `User.email`, which stays in Postgres), so no constraint behavior is lost in the move.

## Testing

- Root `conftest.py` gains a session-scoped fixture asserting `FIRESTORE_EMULATOR_HOST` is set (fails loudly if not — tests run against the real emulator, no in-memory fake).
- A function-scoped **autouse** fixture wipes all emulator collections before each test, via the emulator's REST wipe endpoint (`DELETE /emulator/v1/projects/{project}/databases/(default)/documents`), giving the same clean-slate-per-test guarantee SQLite in-memory gives `apps.users` today.
- `apps.users`' existing fixtures (`db`, `user`, `other_user`, `auth_client`, `other_auth_client`) are untouched.
- Per-app `test_api.py` files hit the HTTP API only (`client.post("/api/v1/...")`) — they're implementation-agnostic and need **zero changes**; they're the acceptance bar for each app's rewrite.
- Three files are **not** implementation-agnostic and must be rewritten: `expenses/tests/test_rollups.py`, `goals/tests/test_aggregation.py`, and `allocations/tests/test_sync.py` construct fixtures directly via `Model.objects.create(...)` (e.g. `Expense.objects.create(...)`), which won't exist once `models.py` is a dataclass. These get rewritten to build fixtures through the Firestore-backed `services.py` functions instead (e.g. `services.create_expense(user, payload)`), keeping the same assertions — they're the acceptance bar for the signal-replacement logic in `apps/common/rollups.py`.

## Tooling changes

- `docker-compose.yml`: new `firestore` service running `google/cloud-sdk` with `gcloud emulators firestore start --host-port=0.0.0.0:8080`; `web` gets `FIRESTORE_EMULATOR_HOST=firestore:8080` and `GOOGLE_CLOUD_PROJECT=excess-budget-dev` added to its environment.
- `Makefile`: new `logs-firestore` target (mirrors existing `logs-db`); `test` target needs no change since it already execs into `web`, which will have the emulator env vars set.
- `.env.example` / `.env`: add `GOOGLE_CLOUD_PROJECT` and `FIRESTORE_EMULATOR_HOST`.
- `pyproject.toml`: add `google-cloud-firestore` to `dependencies`.

## Rollout sequence

The implementation plan will sequence work as:

1. Tooling: `docker-compose.yml` Firestore emulator service, `.env.example`, `pyproject.toml` dependency, `Makefile` target, health-check that the emulator is reachable.
2. Common Firestore infrastructure: `apps/common/firestore.py` (client factory), `apps/common/firestore_helpers.py` (`get_owned_or_404_fs`), and `apps/common/rollups.py` in full (all 5 functions) — buildable now since it only touches raw Firestore collections, no dependency on any of the 7 apps' own modules.
3. Root `conftest.py`: emulator-required fixture + autouse per-test wipe fixture.
4. Domain apps in dependency order (mirrors their FK dependency graph today): `accounts` → `budget` → `income` (incl. `OvertimeSettings` singleton, and `ExtraIncome`'s rollup call into `apps/common/rollups.py`) → `goals` (incl. subgoal/goal_account cascade + rollup calls) → `expenses` (rollup calls) → `allocations` (rollup calls) → `suggestions` (rewritten to call `goals`/`accounts` services instead of their models directly) → `dashboard` (rewritten to call `accounts`/`goals`/`budget` services instead of their models directly). Each app: convert `models.py` to dataclasses, rewrite `services.py` against Firestore (wiring in the relevant `rollups.py` calls where a signal file existed), delete `migrations/`, re-run that app's `test_api.py` unchanged, and rewrite/re-run its rollup test file where one exists (`test_rollups.py`, `test_aggregation.py`, `test_sync.py`).
5. `firestore.indexes.json` authored from the compound queries actually written in step 4.
6. Manual verification: fresh `docker compose up`, full CRUD flow through the Flutter app end-to-end, `make test` green.
7. Final commit: wipe the local Postgres dev volume (`make clean`) so no orphaned tables or stale `django_migrations` rows remain for the 7 apps whose migration files were just deleted, then `make up` to confirm `apps.users`' migrations still apply cleanly on a fresh volume. Update `README.md`.

## Risks

- **Composite-index parity gap** (see above) — a query that needs an index may pass locally and fail in prod. Mitigated by authoring `firestore.indexes.json` deliberately from every compound query, not just reactively.
- **Cascade-delete correctness.** Postgres enforced this implicitly; Firestore requires it to be hand-written per app. The `goals` app (subgoals + goal_accounts) is the highest-risk case — gets explicit test coverage for partial-failure scenarios (e.g. batch commit failure leaving orphans).
- **No referential integrity.** A bug that writes a `budget_category_id` pointing at a deleted or another user's category would previously be impossible (FK constraint); now it's only caught if `get_owned_or_404_fs` is used consistently. Same mitigation pattern as the existing `get_owned_or_404` convention — it's the only path to a resource — carried over.
- **Emulator/prod behavioral drift beyond indexes** (e.g. transaction semantics, quota simulation) is possible but unknown until real GCP Firestore is provisioned in the future task; not fully de-riskable from local dev alone.
