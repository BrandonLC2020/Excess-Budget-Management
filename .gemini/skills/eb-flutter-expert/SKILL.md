---
name: eb-flutter-expert
description: Expert in Flutter development for the Excess-Budget-Management project. Use when working on the frontend, including UI components, BLoC state management, go_router navigation, and feature-first architecture.
---

# EB Flutter Expert

This skill provides specialized guidance for developing the Flutter frontend of the Excess-Budget-Management application.

## Core Architecture

The project follows a **Feature-First Architecture** located in `frontend/lib/features/`. Each feature directory typically contains:

- `bloc/`: Business Logic Components for state management.
- `models/`: Data models and JSON serialization.
- `presentation/`: Screens, widgets, and UI-specific logic.
- `repositories/`: Data access layer interfacing with Supabase.

## Technical Stack

- **State Management**: `flutter_bloc` (always use Blocs/Cubit for business logic).
- **Navigation**: `go_router` (configured in `lib/core/router.dart`).
- **Backend Integration**: `supabase_flutter`.
- **Styling**: Material 3 with the "Outfit" font (Google Fonts).

## Workflows

### 1. Creating a New Feature
1. Create a new directory in `frontend/lib/features/`.
2. Define the data `models/`.
3. Implement the `repositories/` to handle Supabase interactions.
4. Create the `bloc/` to manage state.
5. Build the `presentation/` layer (screens and widgets).
6. Register the new route in `lib/core/router.dart`.

### 2. State Management (BLoC)
Always use the `flutter_bloc` library. Prefer `Bloc` for complex state transitions and `Cubit` for simpler state.

### 3. Navigation
Add new routes to the `GoRouter` configuration in `lib/core/router.dart`. Use `context.go()` for direct navigation and `context.push()` for stack-based navigation.

## Reference Materials

- [Conventions](references/conventions.md): Detailed coding standards and patterns.
