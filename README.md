# Excess-Budget-Management

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://choosealicense.com/licenses/mit/)
[![Flutter](https://img.shields.io/badge/Flutter-v3.11.0-blue.svg)](https://flutter.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-Database%20%26%20Auth-green.svg)](https://supabase.com/)

**Excess-Budget-Management** is a full-stack personal finance application designed to help users track their income, manage accounts, set budget categories, and achieve financial goals through intelligent, AI-driven allocation.

---

## 🚀 Key Features

### 🧠 Balanced Allocation Intelligence (Phase 2)
The core engine of the app uses the **Gemini API** to suggest how to distribute "excess" funds. It intelligently balances between **"Savings"** (long-term, responsible goals) and **"Purchases"** (immediate treats) based on your 30-day historical data to prevent financial burnout.

### 📊 Subgoal Tracking & Aggregation (Phase 3)
Break down large, categorical goals (e.g., "Vacation" or "Tech Upgrade") into specific, actionable line items (subgoals).
- **Automatic Rollups:** Parent goals automatically aggregate the `target_amount` and `current_amount` of all nested subgoals using database triggers.
- **Granular Progress:** Track individual items (like "Flights" or "New Keyboard") within a unified master progress bar.

### 🛡️ Secure & Private
Built on **Supabase**, the application enforces **Row Level Security (RLS)** to ensure that your financial data is strictly yours. Authentication is handled via Supabase Auth (Email/Password).

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

### Backend (Supabase)
- **Database:** PostgreSQL (managed via migrations)
- **Auth:** Supabase Auth (Email/Password)
- **Edge Functions:** [Deno v2](https://deno.com/) for business logic and Gemini API integration.

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
│   └── lib/core/           # Routing, shared utilities, and constants
├── backend/supabase/       # Supabase configuration and database scripts
│   ├── migrations/         # SQL schema and trigger logic
│   └── functions/          # Deno Edge Functions (AI Suggestion Engine)
├── infra/                  # Terraform configuration for AWS (S3, CloudFront)
└── docs/                   # Phase specifications and implementation plans
```

---

## 🚦 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (^3.11.0)
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- [Docker](https://www.docker.com/) (for local Supabase environment)
- [Terraform](https://www.terraform.io/downloads) (for infrastructure deployment)

### 1. Frontend Setup
```bash
cd frontend
flutter pub get
flutter run -d chrome  # Run locally for web
```

### 2. Backend Setup
```bash
# Requires Docker to be running
cd backend
supabase start
supabase db reset      # Apply migrations and seed data
supabase functions serve generate-suggestions
```

### 3. Infrastructure Setup
```bash
cd infra
terraform init
terraform plan
terraform apply
```

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
