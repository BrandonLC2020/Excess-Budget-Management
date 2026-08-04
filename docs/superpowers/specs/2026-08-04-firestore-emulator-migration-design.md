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
│   ├── suggestions/               # same shape
│   └── dashboard/                # UNCHANGED — no models of its own, only composes other services
```

### Data flow (representative example: `budget` app)

- **Create:** `create_category(user, payload)` builds `{"user_id": str(user.id), "name": ..., "limit_amount": ..., ...}`, generates `id = uuid4()`, writes via `db.collection("budget_categories").document(str(id)).set(data)`.
- **List:** `list_categories(user)` → `db.collection("budget_categories").where("user_id", "==", str(user.id)).order_by("created_at").stream()`, mapped into `BudgetCategory` dataclasses.
- **Get/Update/Delete:** route through `get_owned_or_404_fs("budget_categories", category_id, user)`, which checks `snapshot.exists` and `snapshot.get("user_id") == str(user.id)`, raising the existing `NotFoundError` on failure — the exact contract `get_owned_or_404` provides today.
- **Cascades (goals app):** `delete_goal(user, goal_id)` fetches the goal via the helper, then queries `sub_goals` and `goal_accounts` for `goal_id == goal.id`, and removes all three (goal + children) in one `WriteBatch.commit()`.
- **Singleton (income app):** `get_or_create_overtime_settings(user)` reads `db.collection("overtime_settings").document(str(user.id))` directly — no query needed since the doc ID *is* the user ID.

### Composite indexes — known parity gap

`gcloud emulators firestore start` does **not** enforce composite-index requirements as strictly as production Firestore does. `firestore.indexes.json` will document the indexes each app's compound queries need (e.g. `user_id` + `created_at` ordering) for when prod Firestore is eventually provisioned, but a missing-index bug that would fail in prod may pass silently against the local emulator. This is a real, accepted gap — not something local-only tooling can fully close.

## Error handling

Firestore's `.get()` returns a snapshot with `.exists == False` rather than raising on a missing document, so `get_owned_or_404_fs` checks `exists` + ownership and raises the same `NotFoundError` already used everywhere in `apps/common/exceptions.py` — no changes needed in `api.py`'s exception handling for any of the 7 apps. There are no DB-level unique constraints on business fields today (only `User.email`, which stays in Postgres), so no constraint behavior is lost in the move.

## Testing

- Root `conftest.py` gains a session-scoped fixture asserting `FIRESTORE_EMULATOR_HOST` is set (fails loudly if not — tests run against the real emulator, no in-memory fake).
- A function-scoped **autouse** fixture wipes all emulator collections before each test, via the emulator's REST wipe endpoint (`DELETE /emulator/v1/projects/{project}/databases/(default)/documents`), giving the same clean-slate-per-test guarantee SQLite in-memory gives `apps.users` today.
- `apps.users`' existing fixtures (`db`, `user`, `other_user`, `auth_client`, `other_auth_client`) are untouched.
- Per-app test files (`test_api.py`, `test_services.py`) keep the same coverage shape as today: list scoped to `request.auth`, cross-user GET → 404, CRUD round-trip, validation → 422; goals/income get extra coverage for cascade deletes and the singleton-doc path.

## Tooling changes

- `docker-compose.yml`: new `firestore` service running `google/cloud-sdk` with `gcloud emulators firestore start --host-port=0.0.0.0:8080`; `web` gets `FIRESTORE_EMULATOR_HOST=firestore:8080` and `GOOGLE_CLOUD_PROJECT=excess-budget-dev` added to its environment.
- `Makefile`: new `logs-firestore` target (mirrors existing `logs-db`); `test` target needs no change since it already execs into `web`, which will have the emulator env vars set.
- `.env.example` / `.env`: add `GOOGLE_CLOUD_PROJECT` and `FIRESTORE_EMULATOR_HOST`.
- `pyproject.toml`: add `google-cloud-firestore` to `dependencies`.

## Rollout sequence

The implementation plan will sequence work as:

1. Tooling: `docker-compose.yml` Firestore emulator service, `.env.example`, `pyproject.toml` dependency, `Makefile` target, health-check that the emulator is reachable.
2. `apps/common/firestore.py` (client factory) + `apps/common/firestore_helpers.py` (`get_owned_or_404_fs`).
3. Root `conftest.py`: emulator-required fixture + autouse per-test wipe fixture.
4. Domain apps in dependency order (mirrors their FK dependency graph today): `accounts` → `income` (incl. `OvertimeSettings` singleton) → `budget` → `goals` (incl. subgoal/goal_account cascade) → `expenses` → `allocations` → `suggestions`. Each app: convert `models.py` to dataclasses, rewrite `services.py` against Firestore, delete `migrations/`, re-run that app's existing tests against the emulator.
5. `firestore.indexes.json` authored from the compound queries actually written in step 4.
6. Manual verification: fresh `docker compose up`, full CRUD flow through the Flutter app end-to-end, `make test` green.
7. Final commit: wipe the local Postgres dev volume (`make clean`) so no orphaned tables or stale `django_migrations` rows remain for the 7 apps whose migration files were just deleted, then `make up` to confirm `apps.users`' migrations still apply cleanly on a fresh volume. Update `README.md`.

## Risks

- **Composite-index parity gap** (see above) — a query that needs an index may pass locally and fail in prod. Mitigated by authoring `firestore.indexes.json` deliberately from every compound query, not just reactively.
- **Cascade-delete correctness.** Postgres enforced this implicitly; Firestore requires it to be hand-written per app. The `goals` app (subgoals + goal_accounts) is the highest-risk case — gets explicit test coverage for partial-failure scenarios (e.g. batch commit failure leaving orphans).
- **No referential integrity.** A bug that writes a `budget_category_id` pointing at a deleted or another user's category would previously be impossible (FK constraint); now it's only caught if `get_owned_or_404_fs` is used consistently. Same mitigation pattern as the existing `get_owned_or_404` convention — it's the only path to a resource — carried over.
- **Emulator/prod behavioral drift beyond indexes** (e.g. transaction semantics, quota simulation) is possible but unknown until real GCP Firestore is provisioned in the future task; not fully de-riskable from local dev alone.
