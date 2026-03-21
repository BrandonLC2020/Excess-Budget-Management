# Frontend Coding Conventions

## BLoC Pattern
- **Naming**: Follow the `FeatureEvent`, `FeatureState`, and `FeatureBloc` naming convention.
- **State Immutability**: Use `Equatable` for states and `copyWith` for updating them.
- **Provider Scope**: Wrap the relevant feature's screen in `BlocProvider` or use a global `MultiBlocProvider` in `main.dart` if the state is shared.

## GoRouter Navigation
- **Initial Location**: Set to `/` (Home).
- **Redirection**: Handle auth redirection logic within the `redirect` property of the `GoRouter`.
- **Transitions**: Prefer standard Material transitions.

## UI Styling
- **Material 3**: Use `ThemeData(useMaterial3: true)`.
- **Color Scheme**: Seed color `#2C5E4B`.
- **Typography**: `Outfit` from Google Fonts.
- **Responsiveness**: Use `LayoutBuilder` or standard Material widgets for adaptive layouts.

## Supabase Interaction
- **Client**: Access the client via `Supabase.instance.client` (global instance).
- **Error Handling**: Always catch and handle `PostgrestException` or `AuthException`.
- **Typing**: Use the generated types or define clear models for Supabase data.
