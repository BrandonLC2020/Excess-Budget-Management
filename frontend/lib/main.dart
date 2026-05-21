import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/api/api_client.dart';
import 'core/router.dart';
import 'features/accounts/bloc/account_bloc.dart';
import 'features/accounts/repositories/account_repository.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/repositories/profile_repository.dart';
import 'features/auth/services/auth_service.dart';
import 'features/budget/bloc/budget_bloc.dart';
import 'features/budget/repositories/budget_repository.dart';
import 'features/dashboard/bloc/dashboard_bloc.dart';
import 'features/dashboard/repositories/suggestion_repository.dart';
import 'features/goals/repositories/goal_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient(
    onUnauthenticated: () async {
      // AuthBloc listens to auth_state changes; the router handles redirecting to /login.
      // No-op here; AuthCheckRequested will surface AuthUnauthenticated on next check.
    },
  );
  final authService = AuthService(apiClient);
  runApp(BudgetApp(apiClient: apiClient, authService: authService));
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  final ApiClient apiClient;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: apiClient),
        RepositoryProvider(create: (_) => AccountRepository(client: apiClient)),
        RepositoryProvider(create: (_) => BudgetRepository(client: apiClient)),
        RepositoryProvider(create: (_) => GoalRepository(client: apiClient)),
        RepositoryProvider(create: (_) => ProfileRepository(client: apiClient)),
        RepositoryProvider(create: (_) => SuggestionRepository(client: apiClient)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (_) =>
                AuthBloc(authService: authService)..add(AuthCheckRequested()),
          ),
          BlocProvider<AccountBloc>(
            create: (context) => AccountBloc(
              repository: context.read<AccountRepository>(),
            ),
          ),
          BlocProvider<BudgetBloc>(
            create: (context) => BudgetBloc(
              repository: context.read<BudgetRepository>(),
            ),
          ),
          BlocProvider<DashboardBloc>(
            create: (context) => DashboardBloc(
              suggestionRepository: context.read<SuggestionRepository>(),
              accountRepository: context.read<AccountRepository>(),
              goalRepository: context.read<GoalRepository>(),
              profileRepository: context.read<ProfileRepository>(),
              budgetRepository: context.read<BudgetRepository>(),
            ),
          ),
        ],
        child: MaterialApp.router(
          title: 'Excess Budget Management',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2C5E4B),
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.outfitTextTheme(),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2C5E4B),
              brightness: Brightness.dark,
            ),
            textTheme: GoogleFonts.outfitTextTheme(
              ThemeData(brightness: Brightness.dark).textTheme,
            ),
            useMaterial3: true,
          ),
          routerConfig: goRouter,
        ),
      ),
    );
  }
}
