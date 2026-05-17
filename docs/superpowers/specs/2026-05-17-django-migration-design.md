# Django Backend Migration — Design

**Date:** 2026-05-17
**ClickUp:** [86b9zmqvh](https://app.clickup.com/t/86b9zmqvh) — "Migrate development backend from Supabase backend and auth to a local Django backend (dockerized)"
**Status:** Design approved, pending spec review before plan-writing

## Goal

Replace the current Supabase backend (managed Postgres + Auth + Deno Edge Functions) with a self-hosted **Django + Django Ninja** backend running locally in Docker. Supabase is being abandoned, so this migration aims for **full feature parity in one shot** and ends with the `backend/supabase/` directory and `supabase_flutter` dependency deleted.

## Non-Goals

- AWS / production deployment of the Django backend. The existing `infra/` (S3 + CloudFront for the Flutter web build) is untouched. A future task will handle production hosting.
- Real SMTP delivery in dev. Password-reset emails go to the console (`EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend`); SMTP is a one-line env swap when production lands.
- Social login (Google/Apple). Email/password only.
- Email verification on signup. Accounts are active immediately.
- Real-time subscriptions / WebSockets. The current Flutter code does not use Supabase Realtime; we are not adding equivalent functionality.
- Widget tests, golden tests, or end-to-end tests for Flutter. The migration's test suite covers repositories, the auth bloc, and the API client — UI testing is independently scoped.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| End-state | Supabase removed, Django replaces it | User stance: "Supabase is leaving." |
| Scope | Full parity in one migration | User choice; manageable because the surface area is fully known (11 SQL migrations, 7 Flutter repos, 2 edge functions). |
| API framework | Django Ninja | Modern FastAPI-style API with auto OpenAPI, async support, and Pydantic schemas. Matches project conventions in `.claude/context/django-ninja/`. |
| Auth | JWT (access + refresh) via `django-ninja-jwt` | Stateless, mobile-friendly, matches Supabase Auth's behavior most closely. |
| Auth flows in scope | Email/password signup + login, password reset | Mirrors current Supabase Auth usage. Social login and email verification are out of scope. |
| Dev data | Discard, start fresh | Dev data is throwaway. |
| Aggregation logic | Django service layer + signals | Easier to test/debug than Postgres triggers; perf impact negligible at this app's scale. |
| Email backend (dev) | Console | Zero external dependencies for dev. Reset links print to docker logs. |
| Gemini suggestions endpoint | Port now (in scope) | Required for the dashboard to function; same external contract as the current Deno edge function. |
| Rollout | Big-bang cutover | All Flutter repos swapped in the same branch as the backend. No dual-backend abstraction. |
| Authorization model | Application-layer ownership checks | Replaces Supabase RLS. Every authenticated endpoint resolves the user via `request.auth` and routes per-resource access through a `get_owned_or_404` helper. |
| Repo layout | Django installed directly under `backend/`; `backend/supabase/` deleted at the end | Per user preference. No `backend/django/` subdirectory. |

## Architecture

### High-level

```
Flutter (existing)                            Django + Django Ninja
  feature folders         HTTPS / JSON           apps/{users, accounts, income,
  flutter_bloc      ──────────────────────▶          budget, goals, expenses,
  go_router         ◀──────────────────────          suggestions, dashboard}
  ApiClient (dio) +      Authorization:           config/ (settings, urls, api, auth)
  JWT interceptor          Bearer <jwt>           Gemini call from suggestions
                                                          │
                                                          ▼
                                                 Postgres 16 (Docker volume)
```

Local dev: `docker compose up` brings up Postgres + Django. Flutter runs natively (`flutter run -d chrome`) and points at `http://localhost:8000`.

### Backend layout (`backend/`)

```
backend/
├── pyproject.toml                # uv-managed: django, django-ninja, django-ninja-jwt,
│                                  #             psycopg[binary], pydantic, google-genai,
│                                  #             python-dotenv
│                                  # dev: pytest-django, factory-boy, ruff
├── manage.py
├── Dockerfile                    # Python 3.12-slim, uv install, gunicorn entrypoint
├── docker-compose.yml            # services: db (postgres:16), web (django)
├── .env.example                  # DATABASE_URL, SECRET_KEY, JWT_SIGNING_KEY,
│                                  # GEMINI_API_KEY, EMAIL_BACKEND, etc.
├── config/
│   ├── settings.py               # split: base / dev / prod via env
│   ├── urls.py                   # mounts NinjaAPI at /api/v1
│   ├── api.py                    # central NinjaAPI() + router registration
│   ├── auth.py                   # JWTAuth class, token helpers
│   └── exceptions.py             # AppError hierarchy + exception_handler
├── apps/
│   ├── common/                   # shared helpers: get_owned_or_404, base fixtures
│   ├── users/                    # signup, login, refresh, password reset, /me
│   ├── accounts/                 # accounts CRUD + linked-to-goals
│   ├── income/                   # income_sources + extra_income
│   ├── budget/                   # budget_categories + spent_amount rollups
│   ├── goals/                    # goals + subgoals + aggregation signals
│   ├── expenses/                 # expenses table + budget linkage
│   ├── suggestions/              # Gemini-backed endpoint + allocation audit
│   └── dashboard/                # read-only aggregate endpoints
└── supabase/                     # ← deleted in the final commit of the cutover branch
```

Each app follows the project's Django Ninja conventions in `.claude/context/django-ninja/`:

- `api.py` — `NinjaRouter` definitions, mounted in `config/api.py`.
- `schemas.py` — Pydantic `<Model>In` / `<Model>Out` schemas.
- `services.py` — business logic. Endpoint handlers stay thin.
- `models.py` — Django ORM models.
- Endpoints provide `summary`, `description`, `tags` for OpenAPI. I/O-bound endpoints (Gemini) use `async def`.

### Flutter changes (`frontend/lib/`)

```
frontend/lib/
├── core/
│   ├── api/                                  # NEW
│   │   ├── api_client.dart                   # dio instance, baseUrl from .env
│   │   ├── auth_token_store.dart             # flutter_secure_storage wrapper
│   │   ├── auth_interceptor.dart             # attaches Bearer, refresh-on-401
│   │   └── api_exceptions.dart               # sealed ApiException family
│   └── constants.dart                        # apiBaseUrl replaces supabaseUrl/anonKey
├── features/
│   ├── auth/
│   │   ├── repositories/profile_repository.dart      # rewritten: takes ApiClient
│   │   └── bloc/auth_bloc.dart                       # rewritten: depends on AuthService(apiClient)
│   ├── accounts/repositories/account_repository.dart       # rewritten
│   ├── budget/repositories/budget_repository.dart          # rewritten
│   ├── goals/repositories/goal_repository.dart             # rewritten
│   ├── income/repositories/income_repository.dart          # rewritten
│   └── dashboard/repositories/suggestion_repository.dart   # rewritten → /api/v1/suggestions/generate
└── main.dart                                 # init ApiClient instead of Supabase.initialize
```

**Removed from Flutter:** `supabase_flutter` from `pubspec.yaml`; all `Supabase.instance` references.
**Added to Flutter:** `dio`, `flutter_secure_storage`.

### API surface (`/api/v1/...`)

- `POST /auth/signup` — create user, return `{user, access, refresh}`
- `POST /auth/login` — return `{user, access, refresh}`
- `POST /auth/refresh` — return new `{access, refresh}` from a valid refresh token
- `POST /auth/password-reset/request` — start reset flow (console-emails a tokenized link)
- `POST /auth/password-reset/confirm` — set new password from token
- `GET  /auth/me` — current user
- `GET/POST /accounts`, `GET/PATCH/DELETE /accounts/{id}`
- `GET/POST /income/sources`, `GET/PATCH/DELETE /income/sources/{id}`
- `GET/POST /income/extra`, `GET/PATCH/DELETE /income/extra/{id}`
- `GET/POST /budget/categories`, `GET/PATCH/DELETE /budget/categories/{id}`
- `GET/POST /goals`, `GET/PATCH/DELETE /goals/{id}`
- `GET/POST /goals/{id}/subgoals`, `PATCH/DELETE /subgoals/{id}`
- `GET/POST /expenses`, `GET/PATCH/DELETE /expenses/{id}`
- `POST /suggestions/generate` — Gemini-backed allocation suggestion (auth required, async)
- `GET  /dashboard/summary` — aggregate read for the home screen

Exact request/response schemas are derived from the existing Supabase SQL migrations and the 7 Flutter repository call sites; the implementation plan enumerates them per app.

### Authorization (replacing RLS)

- Every authenticated router uses `auth=JWTAuth()`.
- `request.auth` resolves to a `User`.
- All per-resource fetches go through `apps/common/permissions.py::get_owned_or_404(model, id, user)` — the only path to a single resource. Forgetting a `user_id` filter is impossible because there is no other helper.
- Tests assert, for every owned model, that a User-B request for a User-A resource returns 404 (not 403 — we don't leak existence).

### Aggregation (replacing Postgres triggers)

- `Subgoal` `post_save` / `post_delete` signal → `apps/goals/services.recompute_parent_totals(parent_id)` recomputes `target_amount` and `current_amount` for the parent and writes via `.update()` (not `.save()`) to avoid signal recursion.
- `Expense` `post_save` / `post_delete` signal → recomputes `accounts.balance` and `budget_categories.spent_amount` for the related rows.
- Each rollup is unit-tested for create/update/delete paths.

### Gemini suggestion flow

- `apps/suggestions/services.gather_context(user)` pulls goals, accounts, and recent allocations from the DB.
- `apps/suggestions/services.call_gemini(context)` uses the official `google-genai` Python SDK with `GEMINI_API_KEY` from env. Prompt shape is ported from `backend/supabase/functions/generate-suggestions/index.ts`.
- An `AllocationSuggestion` audit row is written on each successful call (new — Supabase didn't persist this).
- Failures bubble as `UpstreamError` → `502` with an envelope the Flutter dashboard renders as a non-blocking banner.

## Error handling

### Backend

Envelope (the only error shape Flutter parses):

```json
{ "error": { "code": "not_found", "message": "Account not found", "details": null } }
```

Exception hierarchy in `config/exceptions.py`:

| Class | Status | Code |
|---|---|---|
| `AppError` (base) | 400 | `app_error` |
| `AuthError` | 401 | `auth_error` |
| `PermissionError` | 403 | `forbidden` |
| `NotFoundError` | 404 | `not_found` |
| `ConflictError` | 409 | `conflict` |
| `UpstreamError` | 502 | `upstream_error` |

Registered once on the `NinjaAPI` instance via `@api.exception_handler(AppError)`. Pydantic validation errors return `422` in Ninja's default shape (`{detail: [...]}`) — Flutter parses this as the `ApiValidationException` case specifically.

**JWT specifics:**
- Expired/invalid access → 401. Flutter interceptor uses the status (not the body) to trigger refresh.
- Refresh failure → 401 on `/auth/refresh`. Flutter clears tokens and routes to login.

**Gemini failures:** network errors, 5xx from Google, quota errors → `UpstreamError(502)`. Dashboard shows "Suggestion engine is unavailable — try again in a moment." Rest of the UI keeps working.

**Domain rule violations** (e.g., expense exceeds account balance) → `ConflictError(409)` raised in services. Flutter forms render inline.

### Flutter

`api_exceptions.dart`:

```dart
sealed class ApiException implements Exception { ... }
class ApiValidationException extends ApiException { ... }   // 422
class ApiAuthException       extends ApiException { ... }   // 401
class ApiForbiddenException  extends ApiException { ... }   // 403
class ApiNotFoundException   extends ApiException { ... }   // 404
class ApiConflictException   extends ApiException { ... }   // 409
class ApiUpstreamException   extends ApiException { ... }   // 502
class ApiNetworkException    extends ApiException { ... }   // no response
class ApiServerException     extends ApiException { ... }   // 500
```

`ApiClient` parses the envelope once and throws the typed exception. Repositories don't try/catch — exceptions propagate to blocs, which map each type to a UI-friendly state.

**Auth interceptor 401-refresh flow:**

1. Catch 401 on any non-`/auth/*` request.
2. If a refresh is already in-flight, await its future (single-flight: parallel requests don't trigger N refreshes).
3. Otherwise POST `/auth/refresh`. On success, retry the original request once.
4. On failure, clear tokens, emit `AuthUnauthenticated`.

## Testing

### Backend (`pytest-django` + `factory-boy`)

```
backend/apps/<feature>/tests/
├── test_api.py          # endpoint-level: status, schemas, auth gating, ownership
├── test_services.py     # business logic: aggregation, validation, token issuance
└── test_models.py       # rare — only for non-trivial model methods
```

Coverage by feature:

- **users:** signup happy + duplicate email; login happy + bad password; refresh happy + expired refresh; password reset happy + invalid token; `/me`. (~12 cases.)
- **accounts / income / budget / goals / expenses:** for each — list returns only `request.auth`'s rows; cross-user GET returns 404; CRUD round-trip; validation returns 422. (~8 cases × 5 resources = 40.)
- **goals aggregation:** parent totals update on subgoal create/update/delete; signals don't recurse. (~6 cases.)
- **expenses → balance/spent rollups:** create decrements/increments; delete reverses. (~4 cases.)
- **suggestions:** Gemini mocked at `services.call_gemini`. Happy path, `UpstreamError` → 502, auth gating, audit row created. (~5 cases.)

Aggregation paths get 100% branch coverage. Everything else gets happy path + auth/ownership gating at minimum.

### Flutter

- Repository unit tests — one file per repo. Mock `ApiClient`, assert HTTP call shape and response/error mapping.
- `AuthBloc` — signup/login state transitions, token storage, 401-refresh-retry path.
- `ApiClient` interceptor — refresh-on-401 with single-flight semantics, against a mocked dio adapter.

### Manual verification (gate for deleting `backend/supabase/`)

1. `docker compose up` runs cleanly from a fresh clone.
2. Flutter web build runs; signup → login → dashboard works end-to-end.
3. Create account → create goal → create subgoal → see parent totals update.
4. Record an expense → see account balance and budget spent update.
5. Trigger a Gemini suggestion → see realistic output.
6. Password reset link appears in `docker compose logs web`, link works.
7. `uv run pytest` and `flutter test` both pass.

All seven must pass before `backend/supabase/` and `supabase_flutter` are removed.

## Rollout sequence

The implementation plan will sequence work as:

1. Backend scaffolding: `pyproject.toml`, `manage.py`, `config/`, `Dockerfile`, `docker-compose.yml`, base settings, `NinjaAPI` mount, health check.
2. `users` app: User model, JWT auth, signup/login/refresh/me, password reset.
3. Common helpers: `get_owned_or_404`, exception hierarchy, exception handler, base test fixtures.
4. Domain apps in dependency order: `accounts` → `income` → `budget` → `goals` (with subgoals + aggregation) → `expenses` (with rollup signals) → `dashboard`.
5. `suggestions` app + Gemini integration + audit model.
6. Flutter: `core/api/` (client, interceptor, token store, exceptions), then rewrite all 7 repositories, then `main.dart`.
7. Manual verification checklist (above).
8. Final commit: delete `backend/supabase/`, drop `supabase_flutter` from `pubspec.yaml`, update `README.md` and `.env.example`.

## Risks

- **Hidden Supabase coupling in Flutter:** any code outside the 7 repository files that imports `Supabase.instance` directly (currently appears limited to `main.dart` and `auth_bloc.dart`) must be found and migrated. A `grep -r "Supabase\|supabase_flutter"` sweep is a gate before the verification step.
- **Gemini SDK behavior differences:** the Deno function uses `@google/genai`; the Python port uses `google-genai`. Response shape parsing may differ. The audit row makes regressions diagnosable post-cutover.
- **Aggregation correctness:** the trigger-to-signals port is the most error-prone piece. Branch coverage on `recompute_parent_totals` and the expense rollups is the safety net.
- **Big-bang merge risk:** the cutover branch will be long-lived. Daily local verification and a short-lived `main` policy during the migration window keeps drift manageable.
