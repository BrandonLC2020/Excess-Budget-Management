# GEMINI.md - Instructional Context for Excess-Budget-Management

This project is a full-stack personal finance application designed to help users track their income, manage accounts, set budget categories, and achieve financial goals.

## Project Overview

- **Frontend**: [Flutter](https://flutter.dev/) (Dart)
  - **State Management**: [flutter_bloc](https://pub.dev/packages/flutter_bloc)
  - **Navigation**: [go_router](https://pub.dev/packages/go_router)
  - **Theming**: Material 3 with [Google Fonts (Outfit)](https://fonts.google.com/specimen/Outfit)
- **Backend**: [Supabase](https://supabase.com/)
  - **Database**: PostgreSQL (managed via migrations)
  - **Auth**: Supabase Auth (Email/Password)
  - **Edge Functions**: [Deno](https://deno.land/) (v2) for business logic like suggestion generation
- **Infrastructure**: [Terraform](https://www.terraform.io/)
  - **Cloud Provider**: AWS
  - **Services**: S3 (hosting), CloudFront (CDN)

## Directory Structure

- `frontend/`: The Flutter application code.
  - `lib/core/`: Constants, routing, and shared utilities.
  - `lib/features/`: Feature-based architecture (auth, accounts, budget, dashboard).
    - Each feature typically contains `bloc/`, `models/`, `presentation/`, and `repositories/`.
- `backend/supabase/`: Supabase configuration and database scripts.
  - `migrations/`: SQL files for initializing and updating the schema.
  - `functions/`: Deno Edge Functions (e.g., `generate-suggestions`).
- `infra/`: Terraform configuration for AWS deployment.

## Building and Running

### Frontend (Flutter)

1.  **Install dependencies**:
    ```bash
    cd frontend
    flutter pub get
    ```
2.  **Run locally** (defaults to Chrome for web development):
    ```bash
    flutter run -d chrome
    ```
3.  **Build for production**:
    ```bash
    flutter build web
    ```

### Backend (Supabase)

1.  **Start local environment**:
    ```bash
    # Requires Docker to be running
    cd backend
    supabase start
    ```
2.  **Reset local database** (applies migrations and seed data):
    ```bash
    supabase db reset
    ```
3.  **Serve functions locally**:
    ```bash
    supabase functions serve generate-suggestions
    ```

### Infrastructure (Terraform)

1.  **Initialize**:
    ```bash
    cd infra
    terraform init
    ```
2.  **Deploy**:
    ```bash
    terraform plan
    terraform apply
    ```

## Development Conventions

- **Feature-First Architecture**: Code is organized by feature in the `frontend/lib/features` directory.
- **BLoC Pattern**: Use Bloc for business logic and state management. Avoid state in UI components where possible.
- **Supabase for Data**: All data access should go through Supabase repositories in the `repositories/` subdirectories of each feature.
- **Row Level Security (RLS)**: The database uses RLS to ensure users can only access their own data. Always test with a logged-in user.
- **Styling**: Prefer Material 3 widgets and follow the project's color scheme (Seed: `#2C5E4B`).
