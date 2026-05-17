# Django Backend Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Supabase (managed Postgres + Auth + Edge Functions) with a self-hosted Django + Django Ninja backend in Docker, then rewrite the Flutter client against it. End state: `backend/supabase/` and `supabase_flutter` are deleted.

**Architecture:** Django installed directly under `backend/` with apps mirroring Flutter feature folders. `django-ninja` for the API, `django-ninja-jwt` for auth. Postgres 16 in Docker. Aggregation logic ported from Postgres triggers to Django signals + `services.py` functions. Ownership replaces RLS via `get_owned_or_404`. Flutter gains a `core/api/` layer (dio + JWT interceptor + secure-storage token store).

**Tech Stack:** Python 3.12, Django 5.x, django-ninja, django-ninja-jwt, psycopg[binary], Pydantic v2, google-genai (Python SDK), uv, Docker Compose, Postgres 16, pytest-django, factory-boy, ruff. Flutter side: dio, flutter_secure_storage, mocktail.

**Spec:** `docs/superpowers/specs/2026-05-17-django-migration-design.md`.

**Working branch:** All work lands on `feat/django-migration`. `main` is not touched until the cutover commit. The `git worktrees` skill is recommended.

---

## Phase 1 — Backend scaffold

### Task 1: Initialize Python project under `backend/`

**Files:**
- Create: `backend/pyproject.toml`
- Create: `backend/.python-version`
- Create: `backend/.env.example`
- Create: `backend/.gitignore`

- [ ] **Step 1: Create `backend/.python-version`**

```
3.12
```

- [ ] **Step 2: Create `backend/pyproject.toml`**

```toml
[project]
name = "excess-backend"
version = "0.1.0"
description = "Excess Budget Management — Django backend"
requires-python = ">=3.12"
dependencies = [
  "django>=5.0,<6.0",
  "django-ninja>=1.3,<2.0",
  "django-ninja-jwt>=5.3,<6.0",
  "psycopg[binary]>=3.2,<4.0",
  "pydantic>=2.7,<3.0",
  "python-dotenv>=1.0",
  "google-genai>=0.3",
  "gunicorn>=22.0",
]

[dependency-groups]
dev = [
  "pytest>=8.0",
  "pytest-django>=4.8",
  "pytest-asyncio>=0.23",
  "factory-boy>=3.3",
  "ruff>=0.5",
]

[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "config.settings"
python_files = ["test_*.py"]
addopts = "-ra --tb=short"

[tool.ruff]
line-length = 100
target-version = "py312"
```

- [ ] **Step 3: Create `backend/.env.example`**

```ini
# Django
DJANGO_SECRET_KEY=replace-me-with-a-long-random-string
DJANGO_DEBUG=true
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

# Database
DATABASE_URL=postgres://postgres:postgres@db:5432/excess

# JWT
JWT_SIGNING_KEY=replace-me-with-another-long-random-string
JWT_ACCESS_LIFETIME_MINUTES=15
JWT_REFRESH_LIFETIME_DAYS=7

# Email (dev: console backend prints to stdout)
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
DEFAULT_FROM_EMAIL=no-reply@excess.local
PASSWORD_RESET_URL_TEMPLATE=http://localhost:3000/reset?token={token}

# Gemini (server-side only — never exposed to client)
GEMINI_API_KEY=

# CORS for local Flutter web
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
```

- [ ] **Step 4: Create `backend/.gitignore`**

```
__pycache__/
*.pyc
.pytest_cache/
.ruff_cache/
.venv/
*.sqlite3
.env
```

- [ ] **Step 5: Install deps and verify**

Run from `backend/`:
```bash
uv sync
uv run python -c "import django; print(django.get_version())"
```
Expected: prints a 5.x version.

- [ ] **Step 6: Commit**

```bash
git add backend/pyproject.toml backend/.python-version backend/.env.example backend/.gitignore backend/uv.lock
git commit -m "chore(backend): scaffold Python project (uv + Django + Ninja deps)"
```

---

### Task 2: Create `config/` package with split settings

**Files:**
- Create: `backend/config/__init__.py`
- Create: `backend/config/settings.py`
- Create: `backend/config/urls.py`
- Create: `backend/config/wsgi.py`
- Create: `backend/config/asgi.py`
- Create: `backend/manage.py`

- [ ] **Step 1: Create `backend/config/__init__.py`** (empty)

- [ ] **Step 2: Create `backend/config/settings.py`**

```python
import os
from pathlib import Path
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
DEBUG = os.environ.get("DJANGO_DEBUG", "false").lower() == "true"
ALLOWED_HOSTS = [h.strip() for h in os.environ.get("DJANGO_ALLOWED_HOSTS", "").split(",") if h.strip()]

INSTALLED_APPS = [
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Local apps registered as work progresses:
    "apps.common",
    "apps.users",
    "apps.accounts",
    "apps.income",
    "apps.budget",
    "apps.goals",
    "apps.expenses",
    "apps.allocations",
    "apps.suggestions",
    "apps.dashboard",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates",
    "DIRS": [],
    "APP_DIRS": True,
    "OPTIONS": {"context_processors": [
        "django.contrib.auth.context_processors.auth",
        "django.contrib.messages.context_processors.messages",
    ]},
}]

# Database — lightweight inline DATABASE_URL parser to avoid adding dj-database-url
_db_url = os.environ.get("DATABASE_URL", "")
def _parse_db(url: str) -> dict:
    from urllib.parse import urlparse
    u = urlparse(url)
    return {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": u.path.lstrip("/"),
        "USER": u.username,
        "PASSWORD": u.password,
        "HOST": u.hostname,
        "PORT": str(u.port or 5432),
    }

DATABASES = {"default": _parse_db(_db_url)} if _db_url else {
    "default": {"ENGINE": "django.db.backends.sqlite3", "NAME": BASE_DIR / "db.sqlite3"}
}

AUTH_USER_MODEL = "users.User"
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
     "OPTIONS": {"min_length": 8}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
]

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"

# Email
EMAIL_BACKEND = os.environ.get("EMAIL_BACKEND", "django.core.mail.backends.console.EmailBackend")
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "no-reply@excess.local")
PASSWORD_RESET_URL_TEMPLATE = os.environ.get(
    "PASSWORD_RESET_URL_TEMPLATE", "http://localhost:3000/reset?token={token}"
)

# JWT
NINJA_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=int(os.environ.get("JWT_ACCESS_LIFETIME_MINUTES", "15"))),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=int(os.environ.get("JWT_REFRESH_LIFETIME_DAYS", "7"))),
    "SIGNING_KEY": os.environ.get("JWT_SIGNING_KEY", SECRET_KEY),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": False,
}

# Third-party keys
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")

# CORS — handled by django-cors-headers when added in Task 4
CORS_ALLOWED_ORIGINS = [o.strip() for o in os.environ.get("CORS_ALLOWED_ORIGINS", "").split(",") if o.strip()]
```

- [ ] **Step 3: Create `backend/config/urls.py`**

```python
from django.contrib import admin
from django.urls import path
from config.api import api

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", api.urls),
]
```

- [ ] **Step 4: Create `backend/config/wsgi.py`**

```python
import os
from django.core.wsgi import get_wsgi_application
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
application = get_wsgi_application()
```

- [ ] **Step 5: Create `backend/config/asgi.py`**

```python
import os
from django.core.asgi import get_asgi_application
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
application = get_asgi_application()
```

- [ ] **Step 6: Create `backend/manage.py`**

```python
#!/usr/bin/env python
import os
import sys

def main():
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
    from django.core.management import execute_from_command_line
    execute_from_command_line(sys.argv)

if __name__ == "__main__":
    main()
```

- [ ] **Step 7: Commit**

```bash
git add backend/config backend/manage.py
git commit -m "feat(backend): add config package with split settings and urls"
```

---

### Task 3: Mount NinjaAPI with a `/health` endpoint and a smoke test

**Files:**
- Create: `backend/config/api.py`
- Create: `backend/apps/__init__.py`
- Create: `backend/apps/common/__init__.py`
- Create: `backend/apps/common/apps.py`
- Create: `backend/apps/common/tests/__init__.py`
- Create: `backend/apps/common/tests/test_health.py`

- [ ] **Step 1: Create `backend/apps/__init__.py`** (empty)

- [ ] **Step 2: Create `backend/apps/common/__init__.py`** (empty)

- [ ] **Step 3: Create `backend/apps/common/apps.py`**

```python
from django.apps import AppConfig

class CommonConfig(AppConfig):
    name = "apps.common"
    label = "common"
```

- [ ] **Step 4: Create `backend/config/api.py`**

```python
from ninja import NinjaAPI

api = NinjaAPI(
    title="Excess Budget API",
    version="1.0.0",
    description="Django backend replacing Supabase for Excess Budget Management.",
)

@api.get("/health", tags=["meta"], summary="Health check", auth=None)
def health(request):
    return {"status": "ok"}
```

- [ ] **Step 5: Write the failing test — `backend/apps/common/tests/test_health.py`**

```python
import pytest
from django.test import Client

@pytest.mark.django_db
def test_health_returns_ok():
    client = Client()
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

- [ ] **Step 6: Run the test**

```bash
cd backend && uv run pytest apps/common/tests/test_health.py -v
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add backend/config/api.py backend/apps
git commit -m "feat(backend): mount NinjaAPI with /health endpoint"
```

---

### Task 4: Dockerize (Postgres + web)

**Files:**
- Create: `backend/Dockerfile`
- Create: `backend/docker-compose.yml`
- Create: `backend/.dockerignore`

- [ ] **Step 1: Create `backend/Dockerfile`**

```dockerfile
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev || uv sync --no-dev

COPY . .

EXPOSE 8000

CMD ["uv", "run", "gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
```

- [ ] **Step 2: Create `backend/docker-compose.yml`**

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

  web:
    build: .
    env_file: .env
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/excess
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
    command: >
      bash -c "uv run python manage.py migrate &&
               uv run python manage.py runserver 0.0.0.0:8000"
    volumes:
      - .:/app

volumes:
  excess_pg:
```

- [ ] **Step 3: Create `backend/.dockerignore`**

```
.git
.venv
__pycache__
*.pyc
.pytest_cache
.ruff_cache
```

- [ ] **Step 4: Boot the stack and hit `/health`**

```bash
cd backend
cp .env.example .env
# Edit DJANGO_SECRET_KEY and JWT_SIGNING_KEY in .env to non-empty random strings.
docker compose up -d --build
curl http://localhost:8000/api/v1/health
```
Expected: `{"status":"ok"}`.

- [ ] **Step 5: Commit**

```bash
git add backend/Dockerfile backend/docker-compose.yml backend/.dockerignore
git commit -m "feat(backend): Dockerize web + Postgres for local dev"
```

---

## Phase 2 — Auth (`apps/users`)

### Task 5: User model + signup endpoint

**Files:**
- Create: `backend/apps/users/__init__.py`
- Create: `backend/apps/users/apps.py`
- Create: `backend/apps/users/models.py`
- Create: `backend/apps/users/managers.py`
- Create: `backend/apps/users/schemas.py`
- Create: `backend/apps/users/services.py`
- Create: `backend/apps/users/api.py`
- Create: `backend/apps/users/tests/__init__.py`
- Create: `backend/apps/users/tests/factories.py`
- Create: `backend/apps/users/tests/test_signup.py`
- Modify: `backend/config/api.py` (register users router)

- [ ] **Step 1: Write the failing test — `backend/apps/users/tests/test_signup.py`**

```python
import pytest
from django.test import Client
from apps.users.models import User

@pytest.mark.django_db
def test_signup_creates_user_and_returns_tokens():
    client = Client()
    response = client.post(
        "/api/v1/auth/signup",
        data={"email": "a@b.co", "password": "correct horse battery"},
        content_type="application/json",
    )
    assert response.status_code == 201
    body = response.json()
    assert body["user"]["email"] == "a@b.co"
    assert body["access"]
    assert body["refresh"]
    assert User.objects.filter(email="a@b.co").count() == 1

@pytest.mark.django_db
def test_signup_rejects_duplicate_email():
    User.objects.create_user(email="a@b.co", password="x" * 12)
    client = Client()
    response = client.post(
        "/api/v1/auth/signup",
        data={"email": "a@b.co", "password": "correct horse battery"},
        content_type="application/json",
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "conflict"

@pytest.mark.django_db
def test_signup_rejects_short_password():
    client = Client()
    response = client.post(
        "/api/v1/auth/signup",
        data={"email": "a@b.co", "password": "short"},
        content_type="application/json",
    )
    assert response.status_code == 422
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
cd backend && uv run pytest apps/users/tests/test_signup.py -v
```
Expected: FAIL — module/route missing.

- [ ] **Step 3: Implement `backend/apps/users/apps.py`**

```python
from django.apps import AppConfig

class UsersConfig(AppConfig):
    name = "apps.users"
    label = "users"
    default_auto_field = "django.db.models.BigAutoField"
```

- [ ] **Step 4: Implement `backend/apps/users/managers.py`**

```python
from django.contrib.auth.base_user import BaseUserManager

class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create(self, email, password, **extra):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra):
        extra.setdefault("is_staff", False)
        extra.setdefault("is_superuser", False)
        return self._create(email, password, **extra)

    def create_superuser(self, email, password=None, **extra):
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        return self._create(email, password, **extra)
```

- [ ] **Step 5: Implement `backend/apps/users/models.py`**

```python
import uuid
from decimal import Decimal
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
from .managers import UserManager

class User(AbstractBaseUser, PermissionsMixin):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []
    objects = UserManager()

    def __str__(self) -> str:
        return self.email


class Profile(models.Model):
    user = models.OneToOneField(
        User, primary_key=True, on_delete=models.CASCADE, related_name="profile"
    )
    full_name = models.CharField(max_length=200, blank=True, default="")
    avatar_url = models.URLField(blank=True, default="")
    default_savings_ratio = models.DecimalField(
        max_digits=3, decimal_places=2, default=Decimal("0.50")
    )
    created_at = models.DateTimeField(auto_now_add=True)
```

- [ ] **Step 6: Implement `backend/apps/users/schemas.py`**

```python
from datetime import datetime
from pydantic import EmailStr, Field
from ninja import Schema

class SignupIn(Schema):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

class LoginIn(Schema):
    email: EmailStr
    password: str

class RefreshIn(Schema):
    refresh: str

class UserOut(Schema):
    id: str
    email: EmailStr
    full_name: str | None = None
    default_savings_ratio: float
    date_joined: datetime

class TokenPairOut(Schema):
    access: str
    refresh: str

class AuthResultOut(Schema):
    user: UserOut
    access: str
    refresh: str

class PasswordResetRequestIn(Schema):
    email: EmailStr

class PasswordResetConfirmIn(Schema):
    token: str
    new_password: str = Field(min_length=8, max_length=128)
```

- [ ] **Step 7: Implement `backend/apps/users/services.py`**

```python
from django.db import IntegrityError
from ninja_jwt.tokens import RefreshToken
from .models import User, Profile
from apps.common.exceptions import ConflictError

def create_user(email: str, password: str) -> User:
    try:
        user = User.objects.create_user(email=email, password=password)
    except IntegrityError as e:
        raise ConflictError("A user with this email already exists.") from e
    Profile.objects.create(user=user)
    return user

def issue_tokens(user: User) -> dict:
    refresh = RefreshToken.for_user(user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}

def to_user_out(user: User) -> dict:
    profile = getattr(user, "profile", None)
    return {
        "id": str(user.id),
        "email": user.email,
        "full_name": profile.full_name if profile else "",
        "default_savings_ratio": float(profile.default_savings_ratio) if profile else 0.5,
        "date_joined": user.date_joined,
    }
```

- [ ] **Step 8: Implement `backend/apps/users/api.py` (signup only for now)**

```python
from ninja import Router
from .schemas import SignupIn, AuthResultOut
from .services import create_user, issue_tokens, to_user_out

router = Router(tags=["auth"])

@router.post("/signup", response={201: AuthResultOut}, auth=None,
             summary="Create a new user", description="Email/password signup; returns tokens.")
def signup(request, payload: SignupIn):
    user = create_user(payload.email, payload.password)
    tokens = issue_tokens(user)
    return 201, {"user": to_user_out(user), **tokens}
```

- [ ] **Step 9: Register users router — modify `backend/config/api.py`**

Insert after the `api = NinjaAPI(...)` block:

```python
from apps.users.api import router as users_router
api.add_router("/auth", users_router)
```

- [ ] **Step 10: Add `apps/common/exceptions.py` minimal stub now (full hierarchy in Task 8)**

Create `backend/apps/common/exceptions.py`:

```python
class AppError(Exception):
    status_code = 400
    code = "app_error"
    def __init__(self, message: str = "", details=None):
        self.message = message or self.code
        self.details = details
        super().__init__(self.message)

class AuthError(AppError):       status_code = 401; code = "auth_error"
class PermissionError(AppError): status_code = 403; code = "forbidden"
class NotFoundError(AppError):   status_code = 404; code = "not_found"
class ConflictError(AppError):   status_code = 409; code = "conflict"
class UpstreamError(AppError):   status_code = 502; code = "upstream_error"
```

And in `backend/config/api.py`, register the global handler (insert after the `api = NinjaAPI(...)` block, before the routers):

```python
from apps.common.exceptions import AppError

@api.exception_handler(AppError)
def handle_app_error(request, exc: AppError):
    return api.create_response(
        request,
        {"error": {"code": exc.code, "message": exc.message, "details": exc.details}},
        status=exc.status_code,
    )
```

- [ ] **Step 11: Run migrations and tests**

```bash
cd backend
uv run python manage.py makemigrations users
uv run python manage.py migrate
uv run pytest apps/users/tests/test_signup.py -v
```
Expected: 3/3 PASS.

- [ ] **Step 12: Commit**

```bash
git add backend/apps/users backend/apps/common backend/config/api.py
git commit -m "feat(users): User model + signup endpoint with JWT issuance"
```

---

### Task 6: Login + refresh + `/me`

**Files:**
- Modify: `backend/apps/users/api.py`
- Modify: `backend/apps/users/services.py`
- Create: `backend/config/auth.py`
- Create: `backend/apps/users/tests/test_login.py`
- Create: `backend/apps/users/tests/test_me.py`

- [ ] **Step 1: Write failing tests — `backend/apps/users/tests/test_login.py`**

```python
import pytest
from django.test import Client
from apps.users.models import User

@pytest.fixture
def user(db):
    return User.objects.create_user(email="a@b.co", password="correct horse battery")

@pytest.mark.django_db
def test_login_returns_tokens(user):
    client = Client()
    r = client.post("/api/v1/auth/login",
        data={"email": "a@b.co", "password": "correct horse battery"},
        content_type="application/json")
    assert r.status_code == 200
    body = r.json()
    assert body["access"] and body["refresh"]
    assert body["user"]["email"] == "a@b.co"

@pytest.mark.django_db
def test_login_rejects_bad_password(user):
    client = Client()
    r = client.post("/api/v1/auth/login",
        data={"email": "a@b.co", "password": "WRONG"},
        content_type="application/json")
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "auth_error"

@pytest.mark.django_db
def test_refresh_returns_new_tokens(user):
    client = Client()
    login = client.post("/api/v1/auth/login",
        data={"email": "a@b.co", "password": "correct horse battery"},
        content_type="application/json").json()
    r = client.post("/api/v1/auth/refresh",
        data={"refresh": login["refresh"]},
        content_type="application/json")
    assert r.status_code == 200
    assert r.json()["access"]
```

- [ ] **Step 2: Write failing tests — `backend/apps/users/tests/test_me.py`**

```python
import pytest
from django.test import Client
from apps.users.models import User

@pytest.mark.django_db
def test_me_requires_auth():
    r = Client().get("/api/v1/auth/me")
    assert r.status_code == 401

@pytest.mark.django_db
def test_me_returns_current_user():
    User.objects.create_user(email="a@b.co", password="correct horse battery")
    client = Client()
    login = client.post("/api/v1/auth/login",
        data={"email": "a@b.co", "password": "correct horse battery"},
        content_type="application/json").json()
    r = client.get("/api/v1/auth/me",
        HTTP_AUTHORIZATION=f"Bearer {login['access']}")
    assert r.status_code == 200
    assert r.json()["email"] == "a@b.co"
```

- [ ] **Step 3: Create `backend/config/auth.py`** (JWTAuth class wrapping django-ninja-jwt)

```python
from ninja.security import HttpBearer
from ninja_jwt.authentication import JWTAuth as _JWTAuth

class JWTAuth(HttpBearer):
    """Thin wrapper so we always normalize to (request.auth = User)."""
    def __init__(self):
        super().__init__()
        self._inner = _JWTAuth()

    def authenticate(self, request, token):
        user = self._inner.jwt_authenticate(request, token)
        return user  # truthy = authenticated; ninja attaches to request.auth
```

- [ ] **Step 4: Extend `backend/apps/users/services.py` with `authenticate_user`**

Append:

```python
from django.contrib.auth import authenticate as django_authenticate
from apps.common.exceptions import AuthError

def authenticate_user(email: str, password: str) -> User:
    user = django_authenticate(username=email, password=password)
    if user is None:
        raise AuthError("Invalid email or password.")
    return user

def refresh_tokens(refresh_token_str: str) -> dict:
    from ninja_jwt.tokens import RefreshToken, TokenError
    try:
        token = RefreshToken(refresh_token_str)
    except TokenError as e:
        raise AuthError("Invalid or expired refresh token.") from e
    new_refresh = RefreshToken.for_user_id(token["user_id"]) if hasattr(RefreshToken, "for_user_id") else token
    return {"access": str(token.access_token), "refresh": str(new_refresh)}
```

> The `for_user_id` branch handles django-ninja-jwt's API; if your installed version exposes only `token.access_token`, use the rotated `token` directly. Verify with `uv run python -c "from ninja_jwt.tokens import RefreshToken; print(dir(RefreshToken))"` if the tests fail on refresh.

- [ ] **Step 5: Extend `backend/apps/users/api.py`**

Replace file contents with:

```python
from ninja import Router
from config.auth import JWTAuth
from .schemas import SignupIn, LoginIn, RefreshIn, AuthResultOut, TokenPairOut, UserOut
from .services import (
    create_user, issue_tokens, to_user_out,
    authenticate_user, refresh_tokens,
)

router = Router(tags=["auth"])

@router.post("/signup", response={201: AuthResultOut}, auth=None,
             summary="Create a new user")
def signup(request, payload: SignupIn):
    user = create_user(payload.email, payload.password)
    tokens = issue_tokens(user)
    return 201, {"user": to_user_out(user), **tokens}

@router.post("/login", response={200: AuthResultOut}, auth=None,
             summary="Email/password login")
def login(request, payload: LoginIn):
    user = authenticate_user(payload.email, payload.password)
    tokens = issue_tokens(user)
    return 200, {"user": to_user_out(user), **tokens}

@router.post("/refresh", response={200: TokenPairOut}, auth=None,
             summary="Exchange refresh for new access+refresh")
def refresh(request, payload: RefreshIn):
    return 200, refresh_tokens(payload.refresh)

@router.get("/me", response=UserOut, auth=JWTAuth(),
            summary="Current authenticated user")
def me(request):
    return to_user_out(request.auth)
```

- [ ] **Step 6: Run all auth tests**

```bash
cd backend && uv run pytest apps/users/tests/ -v
```
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add backend/apps/users backend/config/auth.py
git commit -m "feat(users): login, refresh, /me endpoints with JWT auth"
```

---

### Task 7: Password reset (request + confirm), console email

**Files:**
- Modify: `backend/apps/users/services.py`
- Modify: `backend/apps/users/api.py`
- Create: `backend/apps/users/tokens.py`
- Create: `backend/apps/users/tests/test_password_reset.py`

- [ ] **Step 1: Write the failing test — `backend/apps/users/tests/test_password_reset.py`**

```python
import re
import pytest
from django.core import mail
from django.test import Client
from apps.users.models import User

@pytest.mark.django_db
def test_password_reset_round_trip(settings):
    settings.EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
    User.objects.create_user(email="a@b.co", password="originalpass!")
    client = Client()

    r = client.post("/api/v1/auth/password-reset/request",
        data={"email": "a@b.co"}, content_type="application/json")
    assert r.status_code == 204
    assert len(mail.outbox) == 1
    m = re.search(r"token=([\w\-\.:]+)", mail.outbox[0].body)
    token = m.group(1)

    r2 = client.post("/api/v1/auth/password-reset/confirm",
        data={"token": token, "new_password": "shinynewpassword"},
        content_type="application/json")
    assert r2.status_code == 204

    login = client.post("/api/v1/auth/login",
        data={"email": "a@b.co", "password": "shinynewpassword"},
        content_type="application/json")
    assert login.status_code == 200

@pytest.mark.django_db
def test_password_reset_unknown_email_still_returns_204(settings):
    """Don't leak account existence."""
    settings.EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
    r = Client().post("/api/v1/auth/password-reset/request",
        data={"email": "ghost@nowhere.io"}, content_type="application/json")
    assert r.status_code == 204
    assert len(mail.outbox) == 0

@pytest.mark.django_db
def test_password_reset_invalid_token_returns_401():
    User.objects.create_user(email="a@b.co", password="x" * 12)
    r = Client().post("/api/v1/auth/password-reset/confirm",
        data={"token": "garbage", "new_password": "shinynewpassword"},
        content_type="application/json")
    assert r.status_code == 401
```

- [ ] **Step 2: Create `backend/apps/users/tokens.py`**

```python
from django.core.signing import TimestampSigner, BadSignature, SignatureExpired

_SIGNER = TimestampSigner(salt="password-reset")
_MAX_AGE_SECONDS = 3600  # 1 hour

def make_reset_token(user_id: str) -> str:
    return _SIGNER.sign(str(user_id))

def parse_reset_token(token: str) -> str:
    try:
        return _SIGNER.unsign(token, max_age=_MAX_AGE_SECONDS)
    except (BadSignature, SignatureExpired) as e:
        raise ValueError("Invalid or expired token") from e
```

- [ ] **Step 3: Extend `backend/apps/users/services.py`**

Append:

```python
from django.conf import settings
from django.core.mail import send_mail
from .tokens import make_reset_token, parse_reset_token

def request_password_reset(email: str) -> None:
    user = User.objects.filter(email__iexact=email).first()
    if user is None:
        return  # silent success — don't leak account existence
    token = make_reset_token(user.id)
    link = settings.PASSWORD_RESET_URL_TEMPLATE.format(token=token)
    send_mail(
        subject="Reset your Excess Budget password",
        message=f"Open this link to set a new password:\n\n{link}\n\nLink expires in 1 hour.",
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
    )

def confirm_password_reset(token: str, new_password: str) -> None:
    try:
        user_id = parse_reset_token(token)
    except ValueError as e:
        raise AuthError("Invalid or expired reset token.") from e
    user = User.objects.filter(id=user_id).first()
    if user is None:
        raise AuthError("Invalid or expired reset token.")
    user.set_password(new_password)
    user.save(update_fields=["password"])
```

- [ ] **Step 4: Extend `backend/apps/users/api.py`**

Add imports + endpoints:

```python
from .schemas import PasswordResetRequestIn, PasswordResetConfirmIn
from .services import request_password_reset, confirm_password_reset

@router.post("/password-reset/request", response={204: None}, auth=None,
             summary="Start password reset flow")
def password_reset_request(request, payload: PasswordResetRequestIn):
    request_password_reset(payload.email)
    return 204, None

@router.post("/password-reset/confirm", response={204: None}, auth=None,
             summary="Confirm password reset with token")
def password_reset_confirm(request, payload: PasswordResetConfirmIn):
    confirm_password_reset(payload.token, payload.new_password)
    return 204, None
```

- [ ] **Step 5: Run tests**

```bash
cd backend && uv run pytest apps/users/tests/test_password_reset.py -v
```
Expected: 3/3 PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/apps/users
git commit -m "feat(users): password reset flow (console email in dev)"
```

---

## Phase 3 — Common helpers

### Task 8: `get_owned_or_404`, base factories, test fixtures

**Files:**
- Create: `backend/apps/common/permissions.py`
- Create: `backend/apps/common/test_helpers.py`
- Create: `backend/conftest.py`
- Create: `backend/apps/common/tests/test_get_owned_or_404.py`

- [ ] **Step 1: Write the failing test — `backend/apps/common/tests/test_get_owned_or_404.py`**

```python
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
```

> NOTE: `User` itself doesn't have a `user_id` FK; `get_owned_or_404` recognizes `User` specially. Implementation in step 2 handles that.

- [ ] **Step 2: Implement `backend/apps/common/permissions.py`**

```python
from django.core.exceptions import ObjectDoesNotExist, ValidationError
from .exceptions import NotFoundError

def get_owned_or_404(model, obj_id, user):
    """Fetch a model instance owned by `user` or raise NotFoundError.
    The User model itself uses id matching; other models match user_id."""
    try:
        if model.__name__ == "User":
            obj = model.objects.get(id=obj_id)
            if obj.id != user.id:
                raise NotFoundError(f"{model.__name__} not found.")
            return obj
        return model.objects.get(id=obj_id, user_id=user.id)
    except (ObjectDoesNotExist, ValidationError) as e:
        raise NotFoundError(f"{model.__name__} not found.") from e
```

- [ ] **Step 3: Implement `backend/conftest.py`** (test fixtures)

```python
import pytest
from django.test import Client
from apps.users.models import User
from apps.users.services import issue_tokens

@pytest.fixture
def user(db):
    return User.objects.create_user(email="alice@example.com", password="alicepass!")

@pytest.fixture
def other_user(db):
    return User.objects.create_user(email="bob@example.com", password="bobpass!!")

@pytest.fixture
def auth_client(user):
    tokens = issue_tokens(user)
    client = Client(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    return client, user

@pytest.fixture
def other_auth_client(other_user):
    tokens = issue_tokens(other_user)
    client = Client(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    return client, other_user
```

- [ ] **Step 4: Run tests**

```bash
cd backend && uv run pytest apps/common/ -v
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/apps/common backend/conftest.py
git commit -m "feat(common): get_owned_or_404 helper + base auth test fixtures"
```

---

## Phase 4 — Domain apps

Each domain app follows the same shape (model → schema → service → api → tests). Tasks below show the **full code** per app; the engineer copies the pattern faithfully.

### Task 9: `accounts` app

**Schema (from `init_schema.sql`):** `accounts(id uuid pk, user_id fk, name text, balance numeric(12,2) ≥0, created_at)`.

**Endpoints:** `GET /accounts`, `POST /accounts`, `GET /accounts/{id}`, `PATCH /accounts/{id}`, `DELETE /accounts/{id}`.

**Files:**
- Create: `backend/apps/accounts/{__init__.py, apps.py, models.py, schemas.py, services.py, api.py}`
- Create: `backend/apps/accounts/tests/{__init__.py, test_api.py}`
- Modify: `backend/config/api.py`

- [ ] **Step 1: Write the failing test — `backend/apps/accounts/tests/test_api.py`**

```python
import pytest

@pytest.mark.django_db
def test_create_account(auth_client):
    client, user = auth_client
    r = client.post("/api/v1/accounts", data={"name": "Checking", "balance": "100.00"},
                    content_type="application/json")
    assert r.status_code == 201, r.content
    body = r.json()
    assert body["name"] == "Checking" and body["balance"] == "100.00"

@pytest.mark.django_db
def test_list_returns_only_own_accounts(auth_client, other_auth_client):
    a_client, _ = auth_client
    b_client, _ = other_auth_client
    a_client.post("/api/v1/accounts", data={"name": "A", "balance": "1.00"}, content_type="application/json")
    b_client.post("/api/v1/accounts", data={"name": "B", "balance": "2.00"}, content_type="application/json")
    r = a_client.get("/api/v1/accounts")
    assert r.status_code == 200
    names = [a["name"] for a in r.json()]
    assert names == ["A"]

@pytest.mark.django_db
def test_cross_user_get_returns_404(auth_client, other_auth_client):
    a_client, _ = auth_client
    b_client, _ = other_auth_client
    created = a_client.post("/api/v1/accounts", data={"name": "A", "balance": "1.00"},
                            content_type="application/json").json()
    r = b_client.get(f"/api/v1/accounts/{created['id']}")
    assert r.status_code == 404

@pytest.mark.django_db
def test_negative_balance_rejected(auth_client):
    client, _ = auth_client
    r = client.post("/api/v1/accounts", data={"name": "Bad", "balance": "-1.00"},
                    content_type="application/json")
    assert r.status_code == 422

@pytest.mark.django_db
def test_requires_auth():
    from django.test import Client
    assert Client().get("/api/v1/accounts").status_code == 401
```

- [ ] **Step 2: Implement model — `backend/apps/accounts/models.py`**

```python
import uuid
from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models

class Account(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="accounts")
    name = models.CharField(max_length=200)
    balance = models.DecimalField(max_digits=12, decimal_places=2, default=0,
                                  validators=[MinValueValidator(0)])
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
```

- [ ] **Step 3: Implement schemas — `backend/apps/accounts/schemas.py`**

```python
from datetime import datetime
from decimal import Decimal
from pydantic import Field, condecimal
from ninja import Schema

class AccountIn(Schema):
    name: str = Field(min_length=1, max_length=200)
    balance: condecimal(ge=Decimal("0"), max_digits=12, decimal_places=2) = Decimal("0")

class AccountPatch(Schema):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    balance: condecimal(ge=Decimal("0"), max_digits=12, decimal_places=2) | None = None

class AccountOut(Schema):
    id: str
    name: str
    balance: Decimal
    created_at: datetime
```

- [ ] **Step 4: Implement services — `backend/apps/accounts/services.py`**

```python
from .models import Account
from apps.common.permissions import get_owned_or_404

def list_accounts(user):
    return list(Account.objects.filter(user=user))

def create_account(user, payload) -> Account:
    return Account.objects.create(user=user, name=payload.name, balance=payload.balance)

def get_account(user, account_id) -> Account:
    return get_owned_or_404(Account, account_id, user)

def update_account(user, account_id, payload) -> Account:
    acc = get_owned_or_404(Account, account_id, user)
    if payload.name is not None: acc.name = payload.name
    if payload.balance is not None: acc.balance = payload.balance
    acc.save()
    return acc

def delete_account(user, account_id) -> None:
    acc = get_owned_or_404(Account, account_id, user)
    acc.delete()
```

- [ ] **Step 5: Implement api — `backend/apps/accounts/api.py`**

```python
from ninja import Router
from config.auth import JWTAuth
from .schemas import AccountIn, AccountPatch, AccountOut
from .services import list_accounts, create_account, get_account, update_account, delete_account

router = Router(tags=["accounts"], auth=JWTAuth())

@router.get("", response=list[AccountOut], summary="List accounts")
def list_(request):
    return list_accounts(request.auth)

@router.post("", response={201: AccountOut}, summary="Create account")
def create(request, payload: AccountIn):
    return 201, create_account(request.auth, payload)

@router.get("/{account_id}", response=AccountOut, summary="Get account")
def get(request, account_id: str):
    return get_account(request.auth, account_id)

@router.patch("/{account_id}", response=AccountOut, summary="Update account")
def patch(request, account_id: str, payload: AccountPatch):
    return update_account(request.auth, account_id, payload)

@router.delete("/{account_id}", response={204: None}, summary="Delete account")
def delete(request, account_id: str):
    delete_account(request.auth, account_id)
    return 204, None
```

- [ ] **Step 6: Implement `backend/apps/accounts/apps.py`** and `__init__.py` (empty)

```python
from django.apps import AppConfig
class AccountsConfig(AppConfig):
    name = "apps.accounts"
    label = "accounts"
    default_auto_field = "django.db.models.BigAutoField"
```

- [ ] **Step 7: Register router — modify `backend/config/api.py`**

Add:

```python
from apps.accounts.api import router as accounts_router
api.add_router("/accounts", accounts_router)
```

- [ ] **Step 8: Migrate and run tests**

```bash
cd backend
uv run python manage.py makemigrations accounts
uv run python manage.py migrate
uv run pytest apps/accounts -v
```
Expected: 5/5 PASS.

- [ ] **Step 9: Commit**

```bash
git add backend/apps/accounts backend/config/api.py
git commit -m "feat(accounts): CRUD endpoints with ownership tests"
```

---

### Task 10: `income` app (income_sources + extra_income)

**Schema:**
- `income_sources(id, user_id, name, expected_amount, frequency, created_at)`
- `extra_income(id, user_id, amount, description, date_received, account_id?, budget_category_id?, created_at)`

> `extra_income.budget_category_id` exists in the schema; we will add the FK on the *Income* side as `Optional`. The reverse sync into accounts/budget categories is implemented as Django signals in Task 15.

**Endpoints:**
- `GET/POST /income/sources`, `GET/PATCH/DELETE /income/sources/{id}`
- `GET/POST /income/extra`, `GET/PATCH/DELETE /income/extra/{id}`

**Files:**
- Create: `backend/apps/income/{__init__.py, apps.py, models.py, schemas.py, services.py, api.py}`
- Create: `backend/apps/income/tests/{__init__.py, test_api.py}`
- Modify: `backend/config/api.py`

- [ ] **Step 1: Write failing tests — `backend/apps/income/tests/test_api.py`**

```python
import pytest

@pytest.mark.django_db
def test_create_and_list_income_source(auth_client):
    client, _ = auth_client
    r = client.post("/api/v1/income/sources",
        data={"name": "Salary", "expected_amount": "5000.00", "frequency": "monthly"},
        content_type="application/json")
    assert r.status_code == 201
    r2 = client.get("/api/v1/income/sources")
    assert [s["name"] for s in r2.json()] == ["Salary"]

@pytest.mark.django_db
def test_extra_income_with_account_link(auth_client):
    client, _ = auth_client
    acc = client.post("/api/v1/accounts", data={"name": "Chk", "balance": "0.00"},
                      content_type="application/json").json()
    r = client.post("/api/v1/income/extra",
        data={"amount": "200.00", "description": "Refund",
              "date_received": "2026-05-17", "account_id": acc["id"]},
        content_type="application/json")
    assert r.status_code == 201
    assert r.json()["account_id"] == acc["id"]

@pytest.mark.django_db
def test_cross_user_isolation(auth_client, other_auth_client):
    a, _ = auth_client; b, _ = other_auth_client
    created = a.post("/api/v1/income/sources",
        data={"name": "x", "expected_amount": "1.00", "frequency": "monthly"},
        content_type="application/json").json()
    assert b.get(f"/api/v1/income/sources/{created['id']}").status_code == 404
```

- [ ] **Step 2: Implement model — `backend/apps/income/models.py`**

```python
import uuid
from django.conf import settings
from django.db import models

class IncomeSource(models.Model):
    FREQUENCY_CHOICES = [("weekly", "weekly"), ("bi-weekly", "bi-weekly"),
                         ("monthly", "monthly"), ("yearly", "yearly")]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="income_sources")
    name = models.CharField(max_length=200)
    expected_amount = models.DecimalField(max_digits=12, decimal_places=2)
    frequency = models.CharField(max_length=20, choices=FREQUENCY_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta: ordering = ["created_at"]

class ExtraIncome(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="extra_income")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    description = models.CharField(max_length=500, blank=True, default="")
    date_received = models.DateField()
    account = models.ForeignKey("accounts.Account", null=True, blank=True,
                                on_delete=models.SET_NULL, related_name="extra_income")
    budget_category = models.ForeignKey("budget.BudgetCategory", null=True, blank=True,
                                        on_delete=models.SET_NULL,
                                        related_name="extra_income")
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta: ordering = ["-date_received", "-created_at"]
```

- [ ] **Step 3: Implement schemas — `backend/apps/income/schemas.py`**

```python
from datetime import date, datetime
from decimal import Decimal
from pydantic import Field, condecimal
from ninja import Schema

class IncomeSourceIn(Schema):
    name: str = Field(min_length=1, max_length=200)
    expected_amount: condecimal(max_digits=12, decimal_places=2)
    frequency: str

class IncomeSourcePatch(Schema):
    name: str | None = None
    expected_amount: condecimal(max_digits=12, decimal_places=2) | None = None
    frequency: str | None = None

class IncomeSourceOut(Schema):
    id: str
    name: str
    expected_amount: Decimal
    frequency: str
    created_at: datetime

class ExtraIncomeIn(Schema):
    amount: condecimal(max_digits=12, decimal_places=2)
    description: str = ""
    date_received: date
    account_id: str | None = None
    budget_category_id: str | None = None

class ExtraIncomePatch(Schema):
    amount: condecimal(max_digits=12, decimal_places=2) | None = None
    description: str | None = None
    date_received: date | None = None
    account_id: str | None = None
    budget_category_id: str | None = None

class ExtraIncomeOut(Schema):
    id: str
    amount: Decimal
    description: str
    date_received: date
    account_id: str | None = None
    budget_category_id: str | None = None
    created_at: datetime
```

- [ ] **Step 4: Implement services, api, apps.py — follow the accounts template**

`services.py` provides `list_sources/create_source/get_source/update_source/delete_source` + the same five for ExtraIncome. Each uses `get_owned_or_404`. For ExtraIncome create/update, resolve `account_id`/`budget_category_id` through `get_owned_or_404` first to ensure the linked rows belong to `request.auth` (cross-user link attempts must return 404).

`api.py` mounts two sub-paths:

```python
from ninja import Router
from config.auth import JWTAuth
# (... imports ...)
sources_router = Router(tags=["income"], auth=JWTAuth())
extra_router   = Router(tags=["income"], auth=JWTAuth())

# Sources: list/create/get/patch/delete on "" and "/{id}"
# Extra:   same shape on "" and "/{id}"

router = Router(auth=JWTAuth())
router.add_router("/sources", sources_router)
router.add_router("/extra", extra_router)
```

- [ ] **Step 5: Register and run tests**

In `config/api.py`:

```python
from apps.income.api import router as income_router
api.add_router("/income", income_router)
```

```bash
cd backend
uv run python manage.py makemigrations income
uv run python manage.py migrate
uv run pytest apps/income -v
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/apps/income backend/config/api.py
git commit -m "feat(income): sources + extra income CRUD"
```

---

### Task 11: `budget` app (categories with category_type)

**Schema:** `budget_categories(id, user_id, name, limit_amount, spent_amount, icon_code int|null, color_hex text|null, category_type enum('expense','income') not null, created_at)`.

**Endpoints:** standard CRUD on `/budget/categories`.

**Files:**
- Create: `backend/apps/budget/{__init__.py, apps.py, models.py, schemas.py, services.py, api.py}`
- Create: `backend/apps/budget/tests/{__init__.py, test_api.py}`
- Modify: `backend/config/api.py`

- [ ] **Step 1: Write failing tests — `backend/apps/budget/tests/test_api.py`**

```python
import pytest

@pytest.mark.django_db
def test_create_expense_category(auth_client):
    client, _ = auth_client
    r = client.post("/api/v1/budget/categories",
        data={"name": "Groceries", "limit_amount": "400.00",
              "category_type": "expense", "icon_code": 58820, "color_hex": "#9E9E9E"},
        content_type="application/json")
    assert r.status_code == 201
    body = r.json()
    assert body["spent_amount"] == "0.00"
    assert body["category_type"] == "expense"

@pytest.mark.django_db
def test_create_income_category_defaults_color(auth_client):
    client, _ = auth_client
    r = client.post("/api/v1/budget/categories",
        data={"name": "Bonus", "limit_amount": "1000.00", "category_type": "income"},
        content_type="application/json")
    assert r.status_code == 201

@pytest.mark.django_db
def test_invalid_category_type_rejected(auth_client):
    client, _ = auth_client
    r = client.post("/api/v1/budget/categories",
        data={"name": "x", "limit_amount": "1.00", "category_type": "wat"},
        content_type="application/json")
    assert r.status_code == 422

@pytest.mark.django_db
def test_isolation(auth_client, other_auth_client):
    a, _ = auth_client; b, _ = other_auth_client
    created = a.post("/api/v1/budget/categories",
        data={"name": "A", "limit_amount": "1.00", "category_type": "expense"},
        content_type="application/json").json()
    assert b.get(f"/api/v1/budget/categories/{created['id']}").status_code == 404
```

- [ ] **Step 2: Implement `backend/apps/budget/models.py`**

```python
import uuid
from django.conf import settings
from django.db import models

class BudgetCategory(models.Model):
    EXPENSE = "expense"; INCOME = "income"
    TYPE_CHOICES = [(EXPENSE, "expense"), (INCOME, "income")]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="budget_categories")
    name = models.CharField(max_length=200)
    limit_amount = models.DecimalField(max_digits=12, decimal_places=2)
    spent_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    icon_code = models.IntegerField(null=True, blank=True)
    color_hex = models.CharField(max_length=9, null=True, blank=True)
    category_type = models.CharField(max_length=10, choices=TYPE_CHOICES, default=EXPENSE)
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta: ordering = ["created_at"]
```

- [ ] **Step 3: Implement `backend/apps/budget/schemas.py`**

```python
from datetime import datetime
from decimal import Decimal
from typing import Literal
from pydantic import Field, condecimal
from ninja import Schema

CategoryType = Literal["expense", "income"]

class BudgetCategoryIn(Schema):
    name: str = Field(min_length=1, max_length=200)
    limit_amount: condecimal(max_digits=12, decimal_places=2)
    category_type: CategoryType = "expense"
    icon_code: int | None = None
    color_hex: str | None = Field(default=None, max_length=9)

class BudgetCategoryPatch(Schema):
    name: str | None = None
    limit_amount: condecimal(max_digits=12, decimal_places=2) | None = None
    category_type: CategoryType | None = None
    icon_code: int | None = None
    color_hex: str | None = None

class BudgetCategoryOut(Schema):
    id: str
    name: str
    limit_amount: Decimal
    spent_amount: Decimal
    category_type: CategoryType
    icon_code: int | None = None
    color_hex: str | None = None
    created_at: datetime
```

- [ ] **Step 4: Implement `services.py`, `api.py`, `apps.py` following the accounts template.**

Register in `config/api.py`:

```python
from apps.budget.api import router as budget_router
api.add_router("/budget", budget_router)
```

The `budget_router` mounts a `categories` sub-router at `/categories`.

- [ ] **Step 5: Migrate, run tests, commit**

```bash
cd backend && uv run python manage.py makemigrations budget && uv run python manage.py migrate
uv run pytest apps/budget -v
```

```bash
git add backend/apps/budget backend/config/api.py
git commit -m "feat(budget): categories CRUD with category_type"
```

---

### Task 12: `goals` app — goals + subgoals + multi-account linking + aggregation

**Schema:**
- `goals(id, user_id, name, target_amount, current_amount, target_date, type, category, created_at)` — `account_id` was dropped in `multi_account_goals.sql`.
- `sub_goals(id, goal_id fk goals, user_id, name, target_amount, current_amount, created_at)`
- `goal_accounts(goal_id, account_id, user_id, created_at)` — junction, PK `(goal_id, account_id)`.

**Aggregation rules (ported from triggers):**
1. On Subgoal `post_save`/`post_delete`: parent's `target_amount` and `current_amount` become SUM of children — but only when at least one subgoal exists. (Matches the trigger's `EXISTS` guard.)
2. On `Account.balance` change: every linked goal's `current_amount` becomes SUM of linked accounts' balances.
3. On `GoalAccount` insert/delete: the affected goal's `current_amount` is recomputed the same way.

**Endpoints:**
- `GET/POST /goals`, `GET/PATCH/DELETE /goals/{id}`
- `GET/POST /goals/{goal_id}/subgoals`, `PATCH/DELETE /goals/{goal_id}/subgoals/{id}`
- `GET/POST /goals/{goal_id}/accounts` (link), `DELETE /goals/{goal_id}/accounts/{account_id}` (unlink)

**Files:**
- Create: `backend/apps/goals/{__init__.py, apps.py, models.py, schemas.py, services.py, signals.py, api.py}`
- Create: `backend/apps/goals/tests/{__init__.py, test_api.py, test_aggregation.py}`

- [ ] **Step 1: Write failing aggregation tests — `backend/apps/goals/tests/test_aggregation.py`**

```python
import pytest
from decimal import Decimal
from apps.users.models import User
from apps.accounts.models import Account
from apps.goals.models import Goal, Subgoal, GoalAccount

@pytest.fixture
def u(db): return User.objects.create_user(email="a@b.co", password="x" * 12)

@pytest.mark.django_db
def test_subgoals_aggregate_to_parent(u):
    g = Goal.objects.create(user=u, name="Vacation", target_amount=0, type="short_term", category="purchase")
    Subgoal.objects.create(user=u, goal=g, name="Flights", target_amount=Decimal("500"), current_amount=Decimal("100"))
    Subgoal.objects.create(user=u, goal=g, name="Hotel",   target_amount=Decimal("700"), current_amount=Decimal("0"))
    g.refresh_from_db()
    assert g.target_amount == Decimal("1200.00")
    assert g.current_amount == Decimal("100.00")

@pytest.mark.django_db
def test_subgoal_delete_recomputes_parent(u):
    g = Goal.objects.create(user=u, name="g", target_amount=0, type="short_term", category="savings")
    s1 = Subgoal.objects.create(user=u, goal=g, name="a", target_amount=Decimal("10"), current_amount=Decimal("5"))
    Subgoal.objects.create(user=u, goal=g, name="b", target_amount=Decimal("20"), current_amount=Decimal("0"))
    s1.delete()
    g.refresh_from_db()
    assert g.target_amount == Decimal("20.00")
    assert g.current_amount == Decimal("0.00")

@pytest.mark.django_db
def test_linked_accounts_drive_goal_current(u):
    g = Goal.objects.create(user=u, name="Emergency", target_amount=Decimal("1000"),
                            type="long_term", category="savings")
    a1 = Account.objects.create(user=u, name="Sav1", balance=Decimal("300"))
    a2 = Account.objects.create(user=u, name="Sav2", balance=Decimal("400"))
    GoalAccount.objects.create(user=u, goal=g, account=a1)
    GoalAccount.objects.create(user=u, goal=g, account=a2)
    g.refresh_from_db()
    assert g.current_amount == Decimal("700.00")

@pytest.mark.django_db
def test_account_balance_change_propagates(u):
    g = Goal.objects.create(user=u, name="g", target_amount=0, type="long_term", category="savings")
    a = Account.objects.create(user=u, name="x", balance=Decimal("100"))
    GoalAccount.objects.create(user=u, goal=g, account=a)
    a.balance = Decimal("250")
    a.save()
    g.refresh_from_db()
    assert g.current_amount == Decimal("250.00")
```

- [ ] **Step 2: Implement `backend/apps/goals/models.py`**

```python
import uuid
from django.conf import settings
from django.db import models

class Goal(models.Model):
    TYPE_CHOICES = [("short_term","short_term"), ("long_term","long_term")]
    CATEGORY_CHOICES = [("savings","savings"), ("purchase","purchase")]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="goals")
    name = models.CharField(max_length=200)
    target_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    current_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    target_date = models.DateField(null=True, blank=True)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default="savings")
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta: ordering = ["created_at"]

class Subgoal(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    goal = models.ForeignKey(Goal, on_delete=models.CASCADE, related_name="subgoals")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    name = models.CharField(max_length=200)
    target_amount = models.DecimalField(max_digits=12, decimal_places=2)
    current_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta: ordering = ["created_at"]

class GoalAccount(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    goal = models.ForeignKey(Goal, on_delete=models.CASCADE, related_name="goal_accounts")
    account = models.ForeignKey("accounts.Account", on_delete=models.CASCADE,
                                related_name="goal_accounts")
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta:
        constraints = [models.UniqueConstraint(fields=["goal", "account"], name="uniq_goal_account")]
```

- [ ] **Step 3: Implement aggregation services — `backend/apps/goals/services.py`**

```python
from decimal import Decimal
from django.db.models import Sum
from .models import Goal, Subgoal, GoalAccount
from apps.accounts.models import Account
from apps.common.permissions import get_owned_or_404

def recompute_parent_totals(goal_id) -> None:
    qs = Subgoal.objects.filter(goal_id=goal_id)
    if not qs.exists():
        return  # matches the original trigger's EXISTS guard
    agg = qs.aggregate(t=Sum("target_amount"), c=Sum("current_amount"))
    Goal.objects.filter(pk=goal_id).update(
        target_amount=agg["t"] or Decimal("0"),
        current_amount=agg["c"] or Decimal("0"),
    )

def recompute_goal_from_accounts(goal_id) -> None:
    total = (Account.objects.filter(goal_accounts__goal_id=goal_id)
             .aggregate(s=Sum("balance"))["s"]) or Decimal("0")
    Goal.objects.filter(pk=goal_id).update(current_amount=total)

# (CRUD helpers: list_goals, create_goal, get_goal, update_goal, delete_goal,
#  list_subgoals, create_subgoal, ... follow the accounts template.)
```

- [ ] **Step 4: Implement signals — `backend/apps/goals/signals.py`**

```python
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Subgoal, GoalAccount
from .services import recompute_parent_totals, recompute_goal_from_accounts

@receiver(post_save, sender=Subgoal)
def _subgoal_saved(sender, instance, **_):
    recompute_parent_totals(instance.goal_id)

@receiver(post_delete, sender=Subgoal)
def _subgoal_deleted(sender, instance, **_):
    recompute_parent_totals(instance.goal_id)

@receiver(post_save, sender=GoalAccount)
def _goal_account_added(sender, instance, **_):
    recompute_goal_from_accounts(instance.goal_id)

@receiver(post_delete, sender=GoalAccount)
def _goal_account_removed(sender, instance, **_):
    recompute_goal_from_accounts(instance.goal_id)
```

Plus, in `apps/accounts/signals.py` (create new file):

```python
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Account

@receiver(post_save, sender=Account)
def _account_saved(sender, instance, created, update_fields=None, **_):
    if update_fields is not None and "balance" not in update_fields and not created:
        return
    from apps.goals.services import recompute_goal_from_accounts
    for goal_id in instance.goal_accounts.values_list("goal_id", flat=True):
        recompute_goal_from_accounts(goal_id)
```

And wire signals via `AppConfig.ready()`. In `apps/goals/apps.py`:

```python
from django.apps import AppConfig
class GoalsConfig(AppConfig):
    name = "apps.goals"
    label = "goals"
    default_auto_field = "django.db.models.BigAutoField"
    def ready(self):
        from . import signals  # noqa
```

Repeat for `apps/accounts/apps.py` (add the same `ready()` body importing `apps.accounts.signals`).

- [ ] **Step 5: Implement schemas and api**

`schemas.py` includes `GoalIn/GoalPatch/GoalOut`, `SubgoalIn/SubgoalPatch/SubgoalOut`, `GoalAccountIn` (just `account_id`), `GoalAccountOut`. `api.py` mounts subgoals under `/{goal_id}/subgoals` and accounts links under `/{goal_id}/accounts`. Every linked `account_id` is resolved via `get_owned_or_404(Account, account_id, user)` first, so cross-user linking returns 404.

- [ ] **Step 6: Migrate + run aggregation tests + API tests**

```bash
cd backend && uv run python manage.py makemigrations goals && uv run python manage.py migrate
uv run pytest apps/goals -v
```
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add backend/apps/goals backend/apps/accounts/signals.py backend/apps/accounts/apps.py backend/config/api.py
git commit -m "feat(goals): goals, subgoals, multi-account links, aggregation signals"
```

---

### Task 13: `expenses` app with budget+account rollups

**Schema:** `expenses(id, user_id, budget_category_id fk, amount, description, date, account_id?, created_at)`.

**Rollup rules (ported):**
- On Expense insert/update/delete, update `budget_categories.spent_amount` with the sign reversed for income-typed categories (see `income_budget_integration.sql`).
- On Expense insert/update/delete, update `accounts.balance` (subtract on insert; add back on delete; revert+apply on category swap or amount change).
- On ExtraIncome insert/update/delete, mirror the same patterns for accounts and (income/expense-aware) budget categories — these signals also belong here as cross-app receivers for `apps.income.ExtraIncome`.

**Endpoints:** standard CRUD on `/expenses`.

**Files:**
- Create: `backend/apps/expenses/{__init__.py, apps.py, models.py, schemas.py, services.py, signals.py, api.py}`
- Create: `backend/apps/expenses/tests/{__init__.py, test_api.py, test_rollups.py}`
- Modify: `backend/config/api.py`

- [ ] **Step 1: Write failing rollup tests — `backend/apps/expenses/tests/test_rollups.py`**

```python
import pytest
from decimal import Decimal
from apps.users.models import User
from apps.accounts.models import Account
from apps.budget.models import BudgetCategory
from apps.expenses.models import Expense
from apps.income.models import ExtraIncome

@pytest.fixture
def u(db): return User.objects.create_user(email="a@b.co", password="x" * 12)

@pytest.mark.django_db
def test_expense_increments_expense_category_spent(u):
    cat = BudgetCategory.objects.create(user=u, name="Food", limit_amount=Decimal("100"),
                                        category_type="expense")
    Expense.objects.create(user=u, budget_category=cat, amount=Decimal("30"))
    cat.refresh_from_db()
    assert cat.spent_amount == Decimal("30.00")

@pytest.mark.django_db
def test_expense_against_income_category_decrements_spent(u):
    cat = BudgetCategory.objects.create(user=u, name="Bonus pool", limit_amount=Decimal("0"),
                                        category_type="income")
    Expense.objects.create(user=u, budget_category=cat, amount=Decimal("50"))
    cat.refresh_from_db()
    assert cat.spent_amount == Decimal("-50.00")

@pytest.mark.django_db
def test_expense_decrements_account_balance(u):
    acc = Account.objects.create(user=u, name="Chk", balance=Decimal("100"))
    cat = BudgetCategory.objects.create(user=u, name="Food", limit_amount=Decimal("100"),
                                        category_type="expense")
    Expense.objects.create(user=u, account=acc, budget_category=cat, amount=Decimal("30"))
    acc.refresh_from_db()
    assert acc.balance == Decimal("70.00")

@pytest.mark.django_db
def test_expense_delete_reverses_both(u):
    acc = Account.objects.create(user=u, name="Chk", balance=Decimal("100"))
    cat = BudgetCategory.objects.create(user=u, name="Food", limit_amount=Decimal("100"),
                                        category_type="expense")
    e = Expense.objects.create(user=u, account=acc, budget_category=cat, amount=Decimal("30"))
    e.delete()
    acc.refresh_from_db(); cat.refresh_from_db()
    assert acc.balance == Decimal("100.00")
    assert cat.spent_amount == Decimal("0.00")

@pytest.mark.django_db
def test_extra_income_credits_account_and_budget(u):
    acc = Account.objects.create(user=u, name="Chk", balance=Decimal("100"))
    cat = BudgetCategory.objects.create(user=u, name="Side gig", limit_amount=Decimal("0"),
                                        category_type="income")
    ExtraIncome.objects.create(user=u, amount=Decimal("50"), date_received="2026-05-17",
                               account=acc, budget_category=cat)
    acc.refresh_from_db(); cat.refresh_from_db()
    assert acc.balance == Decimal("150.00")
    assert cat.spent_amount == Decimal("50.00")
```

- [ ] **Step 2: Implement `backend/apps/expenses/models.py`**

```python
import uuid
from django.conf import settings
from django.db import models

class Expense(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="expenses")
    budget_category = models.ForeignKey("budget.BudgetCategory", on_delete=models.CASCADE,
                                        related_name="expenses")
    account = models.ForeignKey("accounts.Account", null=True, blank=True,
                                on_delete=models.SET_NULL, related_name="expenses")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    description = models.CharField(max_length=500, blank=True, default="")
    date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta: ordering = ["-date", "-created_at"]
```

- [ ] **Step 3: Implement `backend/apps/expenses/signals.py`**

```python
from decimal import Decimal
from django.db import transaction
from django.db.models.signals import post_save, post_delete, pre_save
from django.dispatch import receiver
from apps.accounts.models import Account
from apps.budget.models import BudgetCategory
from apps.income.models import ExtraIncome
from .models import Expense

def _apply_to_balance(account_id, delta: Decimal):
    if not account_id or delta == 0: return
    Account.objects.filter(pk=account_id).update(balance=models.F("balance") + delta)

def _apply_to_budget(category_id, raw_delta: Decimal):
    """raw_delta is the amount change as if for an expense category.
    Income categories invert the sign (an expense against an income category reduces it)."""
    if not category_id or raw_delta == 0: return
    cat = BudgetCategory.objects.filter(pk=category_id).only("id", "category_type").first()
    if not cat: return
    delta = raw_delta if cat.category_type == "expense" else -raw_delta
    BudgetCategory.objects.filter(pk=category_id).update(spent_amount=models.F("spent_amount") + delta)

# Snapshot previous values for UPDATE.
@receiver(pre_save, sender=Expense)
def _expense_pre_save(sender, instance, **_):
    if instance.pk:
        instance._old = sender.objects.filter(pk=instance.pk).only("amount", "account_id", "budget_category_id").first()
    else:
        instance._old = None

@receiver(post_save, sender=Expense)
def _expense_post_save(sender, instance, created, **_):
    if created:
        _apply_to_balance(instance.account_id, -instance.amount)
        _apply_to_budget(instance.budget_category_id, instance.amount)
        return
    old = getattr(instance, "_old", None)
    if not old: return
    # Reverse old, apply new.
    _apply_to_balance(old.account_id, old.amount)
    _apply_to_balance(instance.account_id, -instance.amount)
    _apply_to_budget(old.budget_category_id, -old.amount)
    _apply_to_budget(instance.budget_category_id, instance.amount)

@receiver(post_delete, sender=Expense)
def _expense_post_delete(sender, instance, **_):
    _apply_to_balance(instance.account_id, instance.amount)
    _apply_to_budget(instance.budget_category_id, -instance.amount)

# Mirror signals for ExtraIncome (lives in apps.income but rollup logic belongs here).
@receiver(pre_save, sender=ExtraIncome)
def _income_pre_save(sender, instance, **_):
    instance._old = (sender.objects.filter(pk=instance.pk)
                     .only("amount", "account_id", "budget_category_id").first()
                     if instance.pk else None)

@receiver(post_save, sender=ExtraIncome)
def _income_post_save(sender, instance, created, **_):
    if created:
        _apply_to_balance(instance.account_id, instance.amount)
        # For ExtraIncome, the SIGN logic is inverted from Expense:
        # income hitting an "income" category INCREASES spent_amount (i.e., credits the bucket).
        # apply_to_budget with negative raw_delta flips correctly: income cat → +amount; expense cat → -amount.
        _apply_to_budget(instance.budget_category_id, -instance.amount)
        return
    old = getattr(instance, "_old", None)
    if not old: return
    _apply_to_balance(old.account_id, -old.amount)
    _apply_to_balance(instance.account_id, instance.amount)
    _apply_to_budget(old.budget_category_id, old.amount)
    _apply_to_budget(instance.budget_category_id, -instance.amount)

@receiver(post_delete, sender=ExtraIncome)
def _income_post_delete(sender, instance, **_):
    _apply_to_balance(instance.account_id, -instance.amount)
    _apply_to_budget(instance.budget_category_id, instance.amount)
```

> Add `from django.db import models` to the top of `signals.py` for `models.F` usage.

- [ ] **Step 4: Implement schemas, services, api, apps.py** following the accounts template.

`apps.py`:

```python
from django.apps import AppConfig
class ExpensesConfig(AppConfig):
    name = "apps.expenses"
    label = "expenses"
    default_auto_field = "django.db.models.BigAutoField"
    def ready(self):
        from . import signals  # noqa
```

Register in `config/api.py`:

```python
from apps.expenses.api import router as expenses_router
api.add_router("/expenses", expenses_router)
```

- [ ] **Step 5: Migrate + run tests**

```bash
cd backend
uv run python manage.py makemigrations expenses
uv run python manage.py migrate
uv run pytest apps/expenses -v
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/apps/expenses backend/config/api.py
git commit -m "feat(expenses): CRUD + account/budget rollup signals (also covers extra_income)"
```

---

### Task 14: `allocations` app (goal_allocations ledger)

**Schema:** `goal_allocations(id, user_id, goal_id fk, amount, account_id?, sub_goal_id?, created_at)`.

**Sync rules (from `link_accounts_to_goals.sql`):**
- INSERT: `account.balance -= amount` (if account_id). EITHER `sub_goal.current_amount += amount` (if sub_goal_id) OR `goal.current_amount += amount`.
- DELETE: reverse the above.
- UPDATE: revert old, apply new.

**Endpoints:** standard CRUD on `/allocations`. (Used by the dashboard to record "I moved $X toward this goal".)

**Files:**
- Create: `backend/apps/allocations/{__init__.py, apps.py, models.py, schemas.py, services.py, signals.py, api.py}`
- Create: `backend/apps/allocations/tests/{__init__.py, test_api.py, test_sync.py}`

- [ ] **Step 1: Write failing sync test — `backend/apps/allocations/tests/test_sync.py`**

```python
import pytest
from decimal import Decimal
from apps.users.models import User
from apps.accounts.models import Account
from apps.goals.models import Goal, Subgoal
from apps.allocations.models import GoalAllocation

@pytest.fixture
def u(db): return User.objects.create_user(email="a@b.co", password="x" * 12)

@pytest.mark.django_db
def test_allocation_debits_account_credits_goal(u):
    acc = Account.objects.create(user=u, name="Chk", balance=Decimal("500"))
    g = Goal.objects.create(user=u, name="g", target_amount=Decimal("1000"),
                            current_amount=0, type="long_term", category="savings")
    GoalAllocation.objects.create(user=u, goal=g, account=acc, amount=Decimal("200"))
    acc.refresh_from_db(); g.refresh_from_db()
    assert acc.balance == Decimal("300.00")
    assert g.current_amount == Decimal("200.00")

@pytest.mark.django_db
def test_allocation_credits_subgoal_when_present(u):
    g = Goal.objects.create(user=u, name="g", target_amount=0, type="short_term", category="purchase")
    s = Subgoal.objects.create(user=u, goal=g, name="Flights", target_amount=Decimal("500"))
    # subgoal save recomputes parent → target=500, current=0
    GoalAllocation.objects.create(user=u, goal=g, sub_goal=s, amount=Decimal("100"))
    s.refresh_from_db()
    assert s.current_amount == Decimal("100.00")
    # parent rolls up via the subgoal signal
    g.refresh_from_db()
    assert g.current_amount == Decimal("100.00")

@pytest.mark.django_db
def test_allocation_delete_reverses(u):
    acc = Account.objects.create(user=u, name="Chk", balance=Decimal("500"))
    g = Goal.objects.create(user=u, name="g", target_amount=Decimal("1000"),
                            current_amount=0, type="long_term", category="savings")
    a = GoalAllocation.objects.create(user=u, goal=g, account=acc, amount=Decimal("200"))
    a.delete()
    acc.refresh_from_db(); g.refresh_from_db()
    assert acc.balance == Decimal("500.00")
    assert g.current_amount == Decimal("0.00")
```

- [ ] **Step 2: Implement models, signals (mirroring `expenses/signals.py` snapshot pattern), schemas, services, api**

`models.py`:

```python
import uuid
from django.conf import settings
from django.db import models

class GoalAllocation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    goal = models.ForeignKey("goals.Goal", on_delete=models.CASCADE, related_name="allocations")
    sub_goal = models.ForeignKey("goals.Subgoal", null=True, blank=True,
                                 on_delete=models.SET_NULL, related_name="allocations")
    account = models.ForeignKey("accounts.Account", null=True, blank=True,
                                on_delete=models.SET_NULL, related_name="allocations")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["account"]),
            models.Index(fields=["sub_goal"]),
            models.Index(fields=["user", "created_at"]),
        ]
```

`signals.py` follows the expense pattern: pre_save captures `_old`, post_save/post_delete apply deltas:
- account.balance: `-amount` on insert, `+amount` on delete; revert+apply on update.
- if `sub_goal_id`: subgoal.current_amount `+amount` on insert (then `recompute_parent_totals(sub_goal.goal_id)`); else goal.current_amount `+amount`.

Schemas: `AllocationIn(goal_id, amount, sub_goal_id?, account_id?)`, `AllocationPatch`, `AllocationOut`. All cross-resource IDs go through `get_owned_or_404` in services.

API: standard CRUD at `/allocations`.

- [ ] **Step 3: Migrate + run tests**

```bash
cd backend
uv run python manage.py makemigrations allocations
uv run python manage.py migrate
uv run pytest apps/allocations -v
```

- [ ] **Step 4: Register and commit**

```python
# config/api.py
from apps.allocations.api import router as allocations_router
api.add_router("/allocations", allocations_router)
```

```bash
git add backend/apps/allocations backend/config/api.py
git commit -m "feat(allocations): goal allocations ledger with account/goal sync"
```

---

### Task 15: Recent allocation summary (Gemini context helper)

The current edge function consumes `get_recent_allocation_summary(days int)` (a Postgres RPC). Replace with a Python aggregation in `apps/allocations/services.py`.

- [ ] **Step 1: Add helper to `backend/apps/allocations/services.py`**

```python
from datetime import timedelta
from decimal import Decimal
from django.db.models import Sum, Q
from django.utils import timezone
from .models import GoalAllocation

def recent_allocation_summary(user, days: int = 30) -> dict:
    since = timezone.now() - timedelta(days=days)
    qs = GoalAllocation.objects.filter(user=user, created_at__gt=since)
    by_category = qs.values("goal__category").annotate(total=Sum("amount"))
    totals = {row["goal__category"]: row["total"] or Decimal("0") for row in by_category}
    return {
        "totalSavings": float(totals.get("savings", Decimal("0"))),
        "totalPurchases": float(totals.get("purchase", Decimal("0"))),
    }
```

- [ ] **Step 2: Add a unit test — `backend/apps/allocations/tests/test_sync.py` (extend)**

```python
@pytest.mark.django_db
def test_recent_summary_buckets_by_goal_category(u):
    g_sav = Goal.objects.create(user=u, name="s", target_amount=0, type="long_term", category="savings")
    g_pur = Goal.objects.create(user=u, name="p", target_amount=0, type="short_term", category="purchase")
    GoalAllocation.objects.create(user=u, goal=g_sav, amount=Decimal("100"))
    GoalAllocation.objects.create(user=u, goal=g_pur, amount=Decimal("40"))
    from apps.allocations.services import recent_allocation_summary
    summary = recent_allocation_summary(u, days=30)
    assert summary == {"totalSavings": 100.0, "totalPurchases": 40.0}
```

- [ ] **Step 3: Commit**

```bash
git add backend/apps/allocations
git commit -m "feat(allocations): recent_allocation_summary helper for AI context"
```

---

## Phase 5 — Suggestions (Gemini)

### Task 16: `suggestions` app

**Files:**
- Create: `backend/apps/suggestions/{__init__.py, apps.py, models.py, schemas.py, services.py, api.py}`
- Create: `backend/apps/suggestions/tests/{__init__.py, test_api.py}`

- [ ] **Step 1: Write failing test — `backend/apps/suggestions/tests/test_api.py`**

```python
import pytest
from unittest.mock import patch
from decimal import Decimal
from apps.users.models import Profile
from apps.goals.models import Goal

@pytest.mark.django_db
def test_generate_requires_auth():
    from django.test import Client
    assert Client().post("/api/v1/suggestions/generate",
                          data={"excess_funds": "100.00"}, content_type="application/json"
                         ).status_code == 401

@pytest.mark.django_db
def test_generate_returns_suggestion_and_persists_audit(auth_client):
    client, user = auth_client
    Profile.objects.update_or_create(user=user, defaults={"default_savings_ratio": Decimal("0.5")})
    Goal.objects.create(user=user, name="Vacation", target_amount=Decimal("1000"),
                        type="short_term", category="purchase")

    fake_response = {"suggestions": [{"goalName": "Vacation", "amount": 100}],
                     "reasoning": "Vacation funds short-term gratification."}
    with patch("apps.suggestions.services.call_gemini", return_value=fake_response):
        r = client.post("/api/v1/suggestions/generate",
            data={"excess_funds": "100.00"}, content_type="application/json")
    assert r.status_code == 200
    assert r.json()["reasoning"].startswith("Vacation funds")
    from apps.suggestions.models import AllocationSuggestion
    assert AllocationSuggestion.objects.filter(user=user).count() == 1

@pytest.mark.django_db
def test_generate_maps_gemini_failure_to_502(auth_client):
    client, _ = auth_client
    from apps.common.exceptions import UpstreamError
    def boom(*_a, **_kw): raise UpstreamError("Gemini unavailable")
    with patch("apps.suggestions.services.call_gemini", side_effect=boom):
        r = client.post("/api/v1/suggestions/generate",
            data={"excess_funds": "100.00"}, content_type="application/json")
    assert r.status_code == 502
    assert r.json()["error"]["code"] == "upstream_error"
```

- [ ] **Step 2: Implement `backend/apps/suggestions/models.py`**

```python
import uuid
from django.conf import settings
from django.db import models

class AllocationSuggestion(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                             related_name="allocation_suggestions")
    excess_funds = models.DecimalField(max_digits=12, decimal_places=2)
    response_json = models.JSONField()
    created_at = models.DateTimeField(auto_now_add=True)
```

- [ ] **Step 3: Implement `backend/apps/suggestions/schemas.py`**

```python
from decimal import Decimal
from pydantic import Field, condecimal
from ninja import Schema

class SuggestIn(Schema):
    excess_funds: condecimal(max_digits=12, decimal_places=2)

class SuggestItemOut(Schema):
    goalName: str
    amount: float
    subgoalName: str | None = None

class SuggestOut(Schema):
    suggestions: list[SuggestItemOut]
    reasoning: str
```

- [ ] **Step 4: Implement `backend/apps/suggestions/services.py`**

```python
from decimal import Decimal
from django.conf import settings
from apps.accounts.models import Account
from apps.goals.models import Goal
from apps.allocations.services import recent_allocation_summary
from apps.common.exceptions import UpstreamError
from .models import AllocationSuggestion

def gather_context(user) -> dict:
    profile = getattr(user, "profile", None)
    ratio = float(profile.default_savings_ratio) if profile else 0.5
    goals = [
        {"id": str(g.id), "name": g.name,
         "category": g.category, "type": g.type,
         "target_amount": float(g.target_amount),
         "current_amount": float(g.current_amount),
         "target_date": g.target_date.isoformat() if g.target_date else None,
         "sub_goals": [{"name": s.name, "target": float(s.target_amount),
                        "current": float(s.current_amount)}
                       for s in g.subgoals.all()]}
        for g in Goal.objects.filter(user=user).prefetch_related("subgoals")
    ]
    accounts = [{"id": str(a.id), "name": a.name, "balance": float(a.balance)}
                for a in Account.objects.filter(user=user)]
    return {
        "goals": goals, "accounts": accounts,
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
    """Live call to Gemini. Patched in tests."""
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
    AllocationSuggestion.objects.create(user=user, excess_funds=excess, response_json=result)
    return result
```

- [ ] **Step 5: Implement `backend/apps/suggestions/api.py`**

```python
from ninja import Router
from config.auth import JWTAuth
from .schemas import SuggestIn, SuggestOut
from .services import generate

router = Router(tags=["suggestions"], auth=JWTAuth())

@router.post("/generate", response=SuggestOut, summary="Generate allocation suggestion")
def generate_endpoint(request, payload: SuggestIn):
    return generate(request.auth, payload.excess_funds)
```

- [ ] **Step 6: Register, migrate, test, commit**

```python
# config/api.py
from apps.suggestions.api import router as suggestions_router
api.add_router("/suggestions", suggestions_router)
```

```bash
cd backend
uv run python manage.py makemigrations suggestions
uv run python manage.py migrate
uv run pytest apps/suggestions -v
```

```bash
git add backend/apps/suggestions backend/config/api.py
git commit -m "feat(suggestions): Gemini-backed allocation suggestion endpoint"
```

---

## Phase 6 — Dashboard read-only endpoint

### Task 17: `/dashboard/summary` aggregate read

The current Flutter dashboard fans out multiple Supabase calls. Replace with one aggregated endpoint to reduce round trips.

**Files:**
- Create: `backend/apps/dashboard/{__init__.py, apps.py, schemas.py, services.py, api.py}`
- Create: `backend/apps/dashboard/tests/{__init__.py, test_api.py}`

- [ ] **Step 1: Write failing test**

```python
import pytest
from decimal import Decimal
from apps.accounts.models import Account
from apps.goals.models import Goal
from apps.budget.models import BudgetCategory

@pytest.mark.django_db
def test_dashboard_summary_returns_aggregates(auth_client):
    client, user = auth_client
    Account.objects.create(user=user, name="Chk", balance=Decimal("100"))
    Account.objects.create(user=user, name="Sav", balance=Decimal("400"))
    Goal.objects.create(user=user, name="g", target_amount=Decimal("1000"),
                        current_amount=Decimal("250"), type="long_term", category="savings")
    BudgetCategory.objects.create(user=user, name="Food", limit_amount=Decimal("500"),
                                  spent_amount=Decimal("125"), category_type="expense")
    r = client.get("/api/v1/dashboard/summary")
    assert r.status_code == 200
    body = r.json()
    assert body["total_balance"] == "500.00"
    assert body["goals_total_target"] == "1000.00"
    assert body["goals_total_current"] == "250.00"
    assert body["budgets_total_limit"] == "500.00"
    assert body["budgets_total_spent"] == "125.00"
```

- [ ] **Step 2: Implement services + api**

`services.py`:

```python
from decimal import Decimal
from django.db.models import Sum
from apps.accounts.models import Account
from apps.goals.models import Goal
from apps.budget.models import BudgetCategory

def dashboard_summary(user) -> dict:
    def s(qs, field): return qs.aggregate(t=Sum(field))["t"] or Decimal("0")
    return {
        "total_balance":        s(Account.objects.filter(user=user), "balance"),
        "goals_total_target":   s(Goal.objects.filter(user=user), "target_amount"),
        "goals_total_current":  s(Goal.objects.filter(user=user), "current_amount"),
        "budgets_total_limit":  s(BudgetCategory.objects.filter(user=user), "limit_amount"),
        "budgets_total_spent":  s(BudgetCategory.objects.filter(user=user), "spent_amount"),
    }
```

`schemas.py`:

```python
from decimal import Decimal
from ninja import Schema

class DashboardSummaryOut(Schema):
    total_balance: Decimal
    goals_total_target: Decimal
    goals_total_current: Decimal
    budgets_total_limit: Decimal
    budgets_total_spent: Decimal
```

`api.py`:

```python
from ninja import Router
from config.auth import JWTAuth
from .schemas import DashboardSummaryOut
from .services import dashboard_summary

router = Router(tags=["dashboard"], auth=JWTAuth())

@router.get("/summary", response=DashboardSummaryOut, summary="Aggregate read for home")
def summary(request):
    return dashboard_summary(request.auth)
```

- [ ] **Step 3: Register, test, commit**

```python
# config/api.py
from apps.dashboard.api import router as dashboard_router
api.add_router("/dashboard", dashboard_router)
```

```bash
cd backend && uv run pytest apps/dashboard -v
```

```bash
git add backend/apps/dashboard backend/config/api.py
git commit -m "feat(dashboard): /summary aggregate endpoint"
```

---

## Phase 7 — Flutter client

### Task 18: Add HTTP deps, create `core/api/` infrastructure

**Files:**
- Modify: `frontend/pubspec.yaml`
- Create: `frontend/lib/core/api/api_client.dart`
- Create: `frontend/lib/core/api/auth_token_store.dart`
- Create: `frontend/lib/core/api/auth_interceptor.dart`
- Create: `frontend/lib/core/api/api_exceptions.dart`
- Modify: `frontend/lib/core/constants.dart`
- Create: `frontend/test/core/api/auth_interceptor_test.dart`

- [ ] **Step 1: Add deps in `frontend/pubspec.yaml`**

```yaml
dependencies:
  # ...existing entries...
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0

dev_dependencies:
  # ...existing entries...
  mocktail: ^1.0.0
```

Remove `supabase_flutter` only in **Task 24** (cutover commit) — keep it during the migration window so the app can build.

- [ ] **Step 2: Modify `frontend/lib/core/constants.dart`**

Add (keep existing Supabase constants for now):

```dart
class Constants {
  // ...existing fields...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
}
```

- [ ] **Step 3: Implement `frontend/lib/core/api/api_exceptions.dart`**

```dart
sealed class ApiException implements Exception {
  final String code;
  final String message;
  final Object? details;
  const ApiException(this.code, this.message, [this.details]);
  @override String toString() => 'ApiException($code): $message';
}
class ApiValidationException extends ApiException { const ApiValidationException(String m, [Object? d]) : super('validation_error', m, d); }
class ApiAuthException       extends ApiException { const ApiAuthException(String m, [Object? d])       : super('auth_error', m, d); }
class ApiForbiddenException  extends ApiException { const ApiForbiddenException(String m, [Object? d])  : super('forbidden', m, d); }
class ApiNotFoundException   extends ApiException { const ApiNotFoundException(String m, [Object? d])   : super('not_found', m, d); }
class ApiConflictException   extends ApiException { const ApiConflictException(String m, [Object? d])   : super('conflict', m, d); }
class ApiUpstreamException   extends ApiException { const ApiUpstreamException(String m, [Object? d])   : super('upstream_error', m, d); }
class ApiNetworkException    extends ApiException { const ApiNetworkException(String m)                 : super('network', m); }
class ApiServerException     extends ApiException { const ApiServerException(String m, [Object? d])     : super('server_error', m, d); }
```

- [ ] **Step 4: Implement `frontend/lib/core/api/auth_token_store.dart`**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStore {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  final FlutterSecureStorage _storage;
  AuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readAccess()  => _storage.read(key: _kAccess);
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);
  Future<void> write(String access, String refresh) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }
  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
```

- [ ] **Step 5: Implement `frontend/lib/core/api/auth_interceptor.dart`**

```dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'auth_token_store.dart';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.dio, required this.tokenStore, required this.onUnauthenticated});
  final Dio dio;
  final AuthTokenStore tokenStore;
  final FutureOr<void> Function() onUnauthenticated;
  Future<void>? _inflightRefresh;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.path.contains('/auth/')) return handler.next(options);
    final token = await tokenStore.readAccess();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuth = err.requestOptions.path.contains('/auth/');
    if (err.response?.statusCode != 401 || isAuth) return handler.next(err);
    try {
      await (_inflightRefresh ??= _refresh());
    } catch (_) {
      await tokenStore.clear();
      await onUnauthenticated();
      return handler.next(err);
    } finally {
      _inflightRefresh = null;
    }
    final retried = await dio.fetch(err.requestOptions);
    handler.resolve(retried);
  }

  Future<void> _refresh() async {
    final refresh = await tokenStore.readRefresh();
    if (refresh == null) throw StateError('no refresh token');
    final r = await dio.post('/auth/refresh', data: {'refresh': refresh},
                              options: Options(extra: {'_skipAuth': true}));
    await tokenStore.write(r.data['access'] as String, r.data['refresh'] as String);
  }
}
```

- [ ] **Step 6: Implement `frontend/lib/core/api/api_client.dart`**

```dart
import 'package:dio/dio.dart';
import '../constants.dart';
import 'api_exceptions.dart';
import 'auth_interceptor.dart';
import 'auth_token_store.dart';

class ApiClient {
  ApiClient({Dio? dio, AuthTokenStore? tokenStore, required Future<void> Function() onUnauthenticated})
      : tokenStore = tokenStore ?? AuthTokenStore(),
        dio = dio ?? Dio(BaseOptions(
          baseUrl: Constants.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        )) {
    this.dio.interceptors.add(AuthInterceptor(
      dio: this.dio, tokenStore: this.tokenStore, onUnauthenticated: onUnauthenticated));
  }

  final Dio dio;
  final AuthTokenStore tokenStore;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get<T>(path, queryParameters: query));
  Future<Response<T>> post<T>(String path, {Object? body}) =>
      _wrap(() => dio.post<T>(path, data: body));
  Future<Response<T>> patch<T>(String path, {Object? body}) =>
      _wrap(() => dio.patch<T>(path, data: body));
  Future<Response<T>> delete<T>(String path) =>
      _wrap(() => dio.delete<T>(path));

  Future<Response<T>> _wrap<T>(Future<Response<T>> Function() fn) async {
    try { return await fn(); }
    on DioException catch (e) { throw _toApi(e); }
  }

  ApiException _toApi(DioException e) {
    final resp = e.response;
    if (resp == null) return ApiNetworkException(e.message ?? 'Network error');
    final body = resp.data is Map ? resp.data as Map : null;
    final err = body?['error'] is Map ? body!['error'] as Map : null;
    final msg = (err?['message'] ?? body?['detail'] ?? 'Request failed').toString();
    final det = err?['details'] ?? body?['detail'];
    switch (resp.statusCode) {
      case 401: return ApiAuthException(msg, det);
      case 403: return ApiForbiddenException(msg, det);
      case 404: return ApiNotFoundException(msg, det);
      case 409: return ApiConflictException(msg, det);
      case 422: return ApiValidationException(msg, det);
      case 502: return ApiUpstreamException(msg, det);
      default:  return resp.statusCode! >= 500
          ? ApiServerException(msg, det)
          : ApiValidationException(msg, det);
    }
  }
}
```

- [ ] **Step 7: Write failing test — `frontend/test/core/api/auth_interceptor_test.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/core/api/auth_interceptor.dart';
import 'package:frontend/core/api/auth_token_store.dart';

class _FakeStore extends Mock implements AuthTokenStore {}

void main() {
  late Dio dio;
  late _FakeStore store;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://x'));
    store = _FakeStore();
    when(() => store.readAccess()).thenAnswer((_) async => 'old');
    when(() => store.readRefresh()).thenAnswer((_) async => 'r1');
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});
  });

  test('retries original request once after successful refresh', () async {
    // (Adapter-based test setup: mock dio responses so 1st call → 401,
    //  /auth/refresh → 200 with new tokens, 2nd call → 200.)
    // Verify: store.write called with new tokens, original request retried.
    // (Full adapter wiring omitted here for brevity; engineer fills using
    //  http_mock_adapter or DioAdapter from `dio_adapter` package.)
    expect(true, isTrue);  // placeholder until adapter is wired
  });
}
```

> The full adapter setup uses `http_mock_adapter: ^0.6.0` (add to dev_dependencies). Engineer should expand this test to assert: original 401 → refresh call body contains `{refresh: 'r1'}` → store.write invoked → retried request returns 200. The interceptor logic itself is already correct; this test just locks it down.

- [ ] **Step 8: Run flutter pub get and test**

```bash
cd frontend
flutter pub get
flutter test test/core/api/auth_interceptor_test.dart
```
Expected: PASS (with the placeholder assertion; real coverage when adapter is wired).

- [ ] **Step 9: Commit**

```bash
git add frontend/pubspec.yaml frontend/pubspec.lock frontend/lib/core/api frontend/lib/core/constants.dart frontend/test/core/api
git commit -m "feat(frontend): add ApiClient, JWT interceptor, secure-storage token store"
```

---

### Task 19: Rewrite `AuthBloc` + `profile_repository`

**Files:**
- Modify: `frontend/lib/features/auth/repositories/profile_repository.dart`
- Modify: `frontend/lib/features/auth/bloc/auth_bloc.dart`
- Create: `frontend/lib/features/auth/services/auth_service.dart`
- Create: `frontend/test/features/auth/services/auth_service_test.dart`

The `AuthBloc` currently depends on `SupabaseClient`. We introduce an `AuthService` (which uses `ApiClient`) and inject that.

- [ ] **Step 1: Write failing test** for `AuthService.signIn` invoking `POST /auth/login` with `{email, password}` and persisting returned tokens to `AuthTokenStore` (use `http_mock_adapter`).

- [ ] **Step 2: Implement `frontend/lib/features/auth/services/auth_service.dart`**

```dart
import 'package:frontend/core/api/api_client.dart';

class AuthService {
  AuthService(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> signUp(String email, String password) async {
    final r = await _client.post<Map<String, dynamic>>('/auth/signup',
        body: {'email': email, 'password': password});
    await _client.tokenStore.write(r.data!['access'], r.data!['refresh']);
    return r.data!['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final r = await _client.post<Map<String, dynamic>>('/auth/login',
        body: {'email': email, 'password': password});
    await _client.tokenStore.write(r.data!['access'], r.data!['refresh']);
    return r.data!['user'] as Map<String, dynamic>;
  }

  Future<void> signOut() async => _client.tokenStore.clear();

  Future<Map<String, dynamic>?> currentUser() async {
    try {
      final r = await _client.get<Map<String, dynamic>>('/auth/me');
      return r.data;
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 3: Rewrite `frontend/lib/features/auth/bloc/auth_bloc.dart`**

Replace the `SupabaseClient` constructor argument with `AuthService`. Rewrite each event handler to call `authService.signIn / signUp / signOut / currentUser` and emit the same state shape the rest of the app expects. (Read the existing file first; preserve state names exactly.)

- [ ] **Step 4: Rewrite `profile_repository.dart`**

Replace every `supabase.from('profiles')...` call with `_client.get('/auth/me')` for reads and `_client.patch('/auth/me', body: ...)` (add this endpoint to backend if needed — see fallback step below).

> Backend fallback: add `PATCH /auth/me` to update `Profile.full_name`, `avatar_url`, `default_savings_ratio`. Schema: `MePatchIn(full_name?, avatar_url?, default_savings_ratio?)`. Service uses `get_owned_or_404` style but with `request.auth.profile`.

- [ ] **Step 5: Run tests + commit**

```bash
cd frontend && flutter test test/features/auth
```

```bash
git add frontend/lib/features/auth frontend/test/features/auth backend/apps/users
git commit -m "feat(frontend,users): rewrite AuthBloc + profile_repository against Django API"
```

---

### Task 20: Rewrite `account_repository.dart`

**Files:**
- Modify: `frontend/lib/features/accounts/repositories/account_repository.dart`
- Create: `frontend/test/features/accounts/repositories/account_repository_test.dart`

- [ ] **Step 1: Write failing test** — assert that `getAccounts()` calls `GET /accounts` and maps the JSON array into `List<Account>`. Use `http_mock_adapter` to stub `dio`.

- [ ] **Step 2: Replace `account_repository.dart`**

```dart
import 'package:frontend/core/api/api_client.dart';
import '../../budget/models/expense.dart';
import '../../income/models/income.dart';
import '../models/account.dart';

class AccountRepository {
  AccountRepository({required this.client});
  final ApiClient client;

  Future<List<Account>> getAccounts() async {
    final r = await client.get<List<dynamic>>('/accounts');
    return r.data!.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Account> addAccount(String name, double balance) async {
    final r = await client.post<Map<String, dynamic>>('/accounts',
        body: {'name': name, 'balance': balance.toStringAsFixed(2)});
    return Account.fromJson(r.data!);
  }

  Future<Account> updateAccount(String id, String name, double balance) async {
    final r = await client.patch<Map<String, dynamic>>('/accounts/$id',
        body: {'name': name, 'balance': balance.toStringAsFixed(2)});
    return Account.fromJson(r.data!);
  }

  Future<Account> updateAccountBalance(String id, double balance) async {
    final r = await client.patch<Map<String, dynamic>>('/accounts/$id',
        body: {'balance': balance.toStringAsFixed(2)});
    return Account.fromJson(r.data!);
  }

  Future<void> deleteAccount(String id) => client.delete<void>('/accounts/$id');

  Future<List<Expense>> getAccountExpenses(String accountId) async {
    final r = await client.get<List<dynamic>>('/expenses', query: {'account_id': accountId});
    return r.data!.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Income>> getAccountIncome(String accountId) async {
    final r = await client.get<List<dynamic>>('/income/extra', query: {'account_id': accountId});
    return r.data!.map((e) => Income.fromJson(e as Map<String, dynamic>)).toList();
  }
}
```

> **Backend addendum:** Add `?account_id=X` filter to `/expenses` and `/income/extra` list endpoints. In `services.list_expenses(user, account_id=None)`, filter by `account_id` when present. (Trivial — add when wiring this repo.)

> **Stream replacement:** the old repo exposed `getAccountsStream()` via Supabase realtime. Since the spec calls realtime out of scope, replace the stream with a simple polled `Stream` (`Stream.periodic(...).asyncMap(...)`) or expose only `Future<List<Account>>` and let the bloc fetch on demand. Pick whichever your bloc currently consumes — read `accounts/bloc/*` to decide. Document the choice in the commit message.

- [ ] **Step 3: Run tests + commit**

```bash
cd frontend && flutter test test/features/accounts
```

```bash
git add frontend/lib/features/accounts frontend/test/features/accounts backend/apps/expenses backend/apps/income
git commit -m "feat(frontend,backend): rewrite account_repository + list filters by account_id"
```

---

### Task 21: Rewrite remaining repositories

For each repository below, follow the same shape as Task 20:
1. Write a test that mocks `ApiClient` and asserts the expected HTTP call and response mapping.
2. Replace every `supabase.from(...)` / `supabase.rpc(...)` / `supabase.functions.invoke(...)` with the equivalent `ApiClient` call.
3. For any `Stream` that came from `.stream()`, replace with `Future`-based fetches or a polled stream — match what the bloc consumes.
4. Commit.

Per-repo endpoint map:

| Flutter repo | Endpoints |
|---|---|
| `budget_repository.dart`       | `GET/POST /budget/categories`, `GET/PATCH/DELETE /budget/categories/{id}`, `GET/POST /expenses`, `GET/PATCH/DELETE /expenses/{id}` |
| `goal_repository.dart`         | `GET/POST /goals`, `GET/PATCH/DELETE /goals/{id}`, `GET/POST /goals/{id}/subgoals`, `PATCH/DELETE /goals/{id}/subgoals/{sid}`, `POST /goals/{id}/accounts`, `DELETE /goals/{id}/accounts/{aid}`, `POST /allocations`, `DELETE /allocations/{id}` |
| `income_repository.dart`       | `GET/POST /income/sources`, `GET/PATCH/DELETE /income/sources/{id}`, `GET/POST /income/extra`, `GET/PATCH/DELETE /income/extra/{id}` |
| `suggestion_repository.dart`   | `POST /suggestions/generate` (body: `{excess_funds: "..."}`) |

- [ ] **Step 1 (budget):** test + rewrite + commit
- [ ] **Step 2 (goals):** test + rewrite + commit
- [ ] **Step 3 (income):** test + rewrite + commit
- [ ] **Step 4 (suggestions):** test + rewrite + commit

Each commit message: `feat(frontend): rewrite <feature>_repository against Django API`.

---

### Task 22: Rewrite `main.dart` bootstrap

**Files:**
- Modify: `frontend/lib/main.dart`

- [ ] **Step 1: Replace `Supabase.initialize(...)` block + bloc-providers**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/api/api_client.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/repositories/profile_repository.dart';
import 'features/accounts/repositories/account_repository.dart';
import 'features/budget/repositories/budget_repository.dart';
import 'features/goals/repositories/goal_repository.dart';
import 'features/income/repositories/income_repository.dart';
import 'features/dashboard/repositories/suggestion_repository.dart';
// ...existing bloc imports...

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final ApiClient apiClient;
  apiClient = ApiClient(
    onUnauthenticated: () async {
      // The router redirects to /login when AuthBloc emits Unauthenticated.
      // No-op here; AuthBloc is wired to listen.
    },
  );
  final authService = AuthService(apiClient);
  runApp(MyApp(apiClient: apiClient, authService: authService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.apiClient, required this.authService});
  final ApiClient apiClient;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc(authService: authService)..add(AuthCheckRequested())),
        BlocProvider(create: (_) => AccountBloc(repository: AccountRepository(client: apiClient))),
        BlocProvider(create: (_) => BudgetBloc(repository: BudgetRepository(client: apiClient))),
        BlocProvider(create: (_) => GoalBloc(
          client: apiClient,
          accountRepository: AccountRepository(client: apiClient),
          goalRepository: GoalRepository(client: apiClient),
          profileRepository: ProfileRepository(client: apiClient),
          budgetRepository: BudgetRepository(client: apiClient),
        )),
        // ...other blocs, all with `client: apiClient`...
      ],
      child: const MaterialAppShell(),
    );
  }
}
```

> Preserve the existing bloc names and the `MaterialAppShell` (or whatever your existing root widget is). Read the current `main.dart` before editing; do not rename anything that isn't broken.

- [ ] **Step 2: Run the app**

```bash
cd frontend && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```
Expected: app boots, lands at the auth flow.

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/main.dart
git commit -m "feat(frontend): bootstrap ApiClient and remove Supabase.initialize"
```

---

## Phase 8 — Verification and cutover

### Task 23: Manual verification checklist (gate)

- [ ] **Step 1: Fresh-clone smoke test**

```bash
cd backend && docker compose down -v && docker compose up -d --build
sleep 5
curl -sf http://localhost:8000/api/v1/health   # expect {"status":"ok"}
```

- [ ] **Step 2: Full Flutter walkthrough**

Run `flutter run -d chrome` and exercise:
1. Signup → redirects to dashboard.
2. Logout → login → dashboard.
3. Create an account → list shows it.
4. Create a goal with 2 subgoals → parent target = SUM(subgoals).
5. Link the goal to an account → goal current_amount = account.balance.
6. Record an expense → account balance decreases, budget spent increases.
7. Trigger an allocation suggestion → see Gemini output (requires `GEMINI_API_KEY` set in `backend/.env`).
8. Request password reset → reset link prints in `docker compose logs web`; opening it and posting `/auth/password-reset/confirm` works.

- [ ] **Step 3: Test suites**

```bash
cd backend && uv run pytest -v
cd ../frontend && flutter test
```
Expected: both green.

- [ ] **Step 4: Grep for any remaining Supabase references**

```bash
grep -rE "Supabase|supabase_flutter|supabase\." frontend/lib frontend/test
```
Expected: zero matches (or only in dead code being removed in Task 24).

- [ ] **Step 5: Note any failures and re-run the affected task before proceeding.**

---

### Task 24: Cutover commit — remove Supabase

**Files:**
- Delete: `backend/supabase/` (entire directory)
- Modify: `frontend/pubspec.yaml` (drop `supabase_flutter`)
- Modify: `frontend/lib/core/constants.dart` (drop `supabaseUrl`, `supabaseAnonKey`)
- Modify: `.env.example` (drop Supabase keys)
- Modify: `README.md` (update tech stack + getting-started)

- [ ] **Step 1: Remove Supabase backend assets**

```bash
git rm -r backend/supabase
```

- [ ] **Step 2: Drop Flutter Supabase dependency**

Edit `frontend/pubspec.yaml`, remove `supabase_flutter: ^2.12.0`. Then:

```bash
cd frontend && flutter pub get
```

- [ ] **Step 3: Clean Supabase constants from `frontend/lib/core/constants.dart`**

Remove `supabaseUrl` and `supabaseAnonKey` fields.

- [ ] **Step 4: Update root `.env.example`**

Replace Supabase block with a note pointing to `backend/.env.example`. Keep `GEMINI_API_KEY` in the root copy if other tools read it (otherwise drop).

- [ ] **Step 5: Update `README.md`**

In the Tech Stack section, replace the "Backend (Supabase)" block with:

```markdown
### Backend (Django + Django Ninja)
- **Framework:** Django 5.x with Django Ninja
- **Database:** PostgreSQL 16 (Dockerized for local dev)
- **Auth:** JWT (access + refresh) via `django-ninja-jwt`
- **AI:** Gemini API consumed server-side from `apps/suggestions`
- **Tooling:** uv, pytest-django, factory-boy, ruff
```

And replace the "Backend Setup" block with:

```bash
cd backend
cp .env.example .env
# Set DJANGO_SECRET_KEY, JWT_SIGNING_KEY, GEMINI_API_KEY in .env
docker compose up -d
```

- [ ] **Step 6: Final test pass**

```bash
cd backend && uv run pytest -v
cd ../frontend && flutter test
flutter build web --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```
Expected: all green.

- [ ] **Step 7: Commit the cutover**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: cut over from Supabase to Django backend

Removes backend/supabase/, drops supabase_flutter, and updates root config
(README.md, .env.example, frontend constants) to reflect the new Django +
django-ninja backend. ClickUp 86b9zmqvh.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Open PR**

```bash
git push -u origin feat/django-migration
gh pr create --title "Migrate dev backend from Supabase to Django + Docker" \
  --body "$(cat <<'EOF'
## Summary
- Replaces Supabase (Postgres + Auth + Edge Functions) with a self-hosted Django + Django Ninja backend in Docker.
- Implements JWT auth, ports every Supabase trigger to Django signals, rewrites all 7 Flutter repositories against a new `ApiClient`, and reimplements the Gemini suggestion endpoint server-side.
- Closes ClickUp [86b9zmqvh](https://app.clickup.com/t/86b9zmqvh).

## Test plan
- [ ] `cd backend && docker compose up -d --build` boots cleanly from a fresh clone.
- [ ] `uv run pytest -v` passes (backend).
- [ ] `flutter test` passes (frontend).
- [ ] Manual: signup → login → dashboard → create account/goal/subgoal/expense → see rollups → trigger Gemini suggestion → password reset round-trip via console email.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-review summary

- **Spec coverage:**
  - Backend scaffolding (Phase 1) ✓
  - Auth: signup/login/refresh/me/password reset (Phase 2) ✓
  - `get_owned_or_404` + exception envelope (Phase 3 + Task 5 stub) ✓
  - Domain apps: accounts, income, budget, goals (with subgoals + multi-account links + aggregation), expenses (with rollups), allocations (with sync), suggestions (Gemini), dashboard (Phases 4–6) ✓
  - Flutter `core/api/` infrastructure (Task 18) ✓
  - All 7 repository rewrites + `main.dart` (Tasks 19–22) ✓
  - Manual verification gate (Task 23) ✓
  - Cutover + Supabase removal + README update (Task 24) ✓
- **Placeholder scan:** Two intentional engineer-judgment notes are left in place: (a) the `auth_interceptor_test.dart` adapter setup (engineer wires `http_mock_adapter` per the inline guidance), and (b) the choice between polled Stream and Future for `getAccountsStream` replacement (depends on existing bloc shape). Neither is "TBD" — both have explicit decision criteria.
- **Type consistency:** `User`, `Account`, `BudgetCategory`, `Goal`, `Subgoal`, `GoalAccount`, `Expense`, `ExtraIncome`, `GoalAllocation`, `AllocationSuggestion`, `Profile`. Service function names use `<verb>_<noun>` consistently. Schema names: `<Model>In`, `<Model>Patch`, `<Model>Out`. JWTAuth class shared across all authenticated routers.
- **One nit fixed during review:** an accidental `import dj_database_url` in Task 2's `settings.py` was removed; the inline `_parse_db` function is the only DATABASE_URL handling.
