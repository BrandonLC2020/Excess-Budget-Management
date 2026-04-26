import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/dashboard/presentation/screens/overview_tab.dart';
import '../features/accounts/presentation/screens/accounts_screen.dart';
import '../features/budget/presentation/screens/budget_categories_screen.dart';
import '../features/goals/presentation/screens/goal_list_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/auth/presentation/screens/profile_screen.dart';
import '../features/goals/presentation/screens/allocation_history_screen.dart';
import '../features/dashboard/presentation/screens/bulk_entry_screen.dart';
import '../features/transactions/presentation/screens/transactions_screen.dart';
import '../features/goals/bloc/allocation_history_bloc.dart';
import '../features/goals/bloc/allocation_history_event.dart';
import '../features/goals/repositories/goal_repository.dart';

final supabase = Supabase.instance.client;

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootNavigatorKey,
  redirect: (context, state) {
    final session = supabase.auth.currentSession;
    final isLoggingIn =
        state.uri.toString() == '/login' || state.uri.toString() == '/signup';

    if (session == null && !isLoggingIn) {
      return '/login';
    }

    if (session != null && isLoggingIn) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return DashboardScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const OverviewTab(),
              routes: [
                GoRoute(
                  path: 'history',
                  builder: (context, state) => BlocProvider(
                    create: (context) => AllocationHistoryBloc(
                      goalRepository: GoalRepository(supabase: supabase),
                    )..add(FetchAllocationHistory()),
                    child: const AllocationHistoryScreen(),
                  ),
                ),
                GoRoute(
                  path: 'bulk-entry',
                  builder: (context, state) => const BulkEntryScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) => const TransactionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/accounts',
              builder: (context, state) => const AccountsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/budget',
              builder: (context, state) => const BudgetCategoriesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/goals',
              builder: (context, state) => const GoalListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
