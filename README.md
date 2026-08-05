# Excess-Budget-Management

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://choosealicense.com/licenses/mit/)
[![Flutter](https://img.shields.io/badge/Flutter-v3.11.0-blue.svg)](https://flutter.dev/)
[![Django](https://img.shields.io/badge/Django-5.x-092e20.svg)](https://www.djangoproject.com/)
[![Django Ninja](https://img.shields.io/badge/Django%20Ninja-1.6-12a594.svg)](https://django-ninja.dev/)

**Excess-Budget-Management** is a full-stack personal finance application designed to help users track their income, manage accounts, set budget categories, and achieve financial goals through intelligent, AI-driven allocation.

---

## 🚀 Key Features

### 🧠 Balanced Allocation Intelligence (Phase 2)
The core engine of the app uses the **Gemini API** to suggest how to distribute "excess" funds. It intelligently balances between **"Savings"** (long-term, responsible goals) and **"Purchases"** (immediate treats) based on your 30-day historical data to prevent financial burnout.

### 📊 Subgoal Tracking & Aggregation (Phase 3)
Break down large, categorical goals (e.g., "Vacation" or "Tech Upgrade") into specific, actionable line items (subgoals).
- **Automatic Rollups:** Parent goals automatically aggregate the `target_amount` and `current_amount` of all nested subgoals via Django signals.
- **Granular Progress:** Track individual items (like "Flights" or "New Keyboard") within a unified master progress bar.

### 🛡️ Secure & Private
Authentication is handled via JWT (access + refresh) issued by `django-ninja-jwt`. Per-resource ownership is enforced at the application layer through a `get_owned_or_404` helper — every authenticated endpoint resolves resources scoped to the current user.

### 📱 Modern, Responsive UI
A beautiful Material 3 interface built with Flutter, featuring:
- **Outfit Typography:** Clean, premium font scales from Google Fonts.
- **Feature-First Architecture:** Organized for scalability and maintainability.
- **BLoC State Management:** Predictable, reactive UI updates.

---

## 🛠️ Tech Stack

### Frontend
- **Framework:** [Flutter](https://flutter.dev/) (Dart)
- **State Management:** [flutter_bloc](https://pub.dev/packages/flutter_bloc)
- **Navigation:** [go_router](https://pub.dev/packages/go_router)
- **Theming:** Material 3 with [Google Fonts (Outfit)](https://fonts.google.com/specimen/Outfit)

### Backend (Django + Django Ninja)
- **Framework:** [Django 5.x](https://www.djangoproject.com/) with [Django Ninja](https://django-ninja.dev/) for typed, OpenAPI-documented endpoints.
- **Database:** PostgreSQL 16 (Dockerized for local dev).
- **Auth:** JWT access + refresh via [`django-ninja-jwt`](https://pypi.org/project/django-ninja-jwt/).
- **AI:** Gemini API consumed server-side from `apps/suggestions` (key never leaves the backend).
- **Tooling:** `uv`, `pytest-django`, `factory-boy`, `ruff`.

### Infrastructure
- **Cloud Provider:** AWS
- **IaC:** [Terraform](https://www.terraform.io/)
- **Services:** S3 (Static Website Hosting), CloudFront (CDN)

---

## 📁 Project Structure

```text
/
├── frontend/               # Flutter application code
│   ├── lib/features/       # Feature-based organization (auth, accounts, budget, goals)
│   └── lib/core/           # Routing, ApiClient infrastructure, shared utilities
├── backend/                # Django project (NinjaAPI mounted at /api/v1)
│   ├── apps/               # users, accounts, income, budget, goals, expenses,
│   │                       #   allocations, suggestions, dashboard, common
│   ├── config/             # Django settings, urls, NinjaAPI, JWTAuth
│   ├── docker-compose.yml  # Postgres + web service for local dev
│   └── Dockerfile
├── infra/                  # Terraform configuration for AWS (S3, CloudFront)
└── docs/                   # Phase specifications and implementation plans
```

---

## 🚦 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (^3.11.0)
- [Docker](https://www.docker.com/) + Docker Compose (for the local Postgres + Django stack)
- [`uv`](https://docs.astral.sh/uv/) (for running Django commands outside Docker, if preferred)
- [Terraform](https://www.terraform.io/downloads) (for infrastructure deployment)

### 1. Backend Setup
```bash
cd backend
cp .env.example .env
# Set DJANGO_SECRET_KEY, JWT_SIGNING_KEY (random strings), and GEMINI_API_KEY in .env.
docker compose up -d --build           # starts Postgres + Django at http://localhost:8000
curl http://localhost:8000/api/v1/health
```

### 2. Frontend Setup
```bash
cd frontend
flutter pub get
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

### 3. Infrastructure Setup
```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Firestore (local dev)

Business data (`accounts`, `budget`, `income`, `goals`, `expenses`, `allocations`,
`suggestions`) is stored in Google Cloud Firestore. Locally this runs against the
Firestore Emulator, started automatically by `make up` alongside Postgres (which
still backs auth only). No GCP project or credentials are needed for local dev —
the emulator runs fully offline against the dummy project ID in `.env.example`.

Run `make logs-firestore` to tail the emulator's logs.

---

## 🗺️ Roadmap

- [x] **Phase 1: Foundation** - Basic account management, goal setting, and income tracking.
- [ ] **Phase 2: Balanced Allocation Intelligence** - Implementation of the Gemini-powered suggestion engine with historical balance tracking.
- [ ] **Phase 3: Subgoal Tracking & Aggregation** - Introduction of nested subgoals and automatic database-level aggregation.

---

## 📜 License
Distributed under the **MIT License**. See `LICENSE` for more information.

---

*Built with ❤️ by Brandon Lamer-Connolly (2026)*
