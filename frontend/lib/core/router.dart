import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/budget/presentation/screens/add_budget_category_screen.dart';
import '../features/budget/presentation/screens/edit_budget_category_screen.dart';
import '../features/budget/models/budget_category.dart';

final supabase = Supabase.instance.client;

final goRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = supabase.auth.currentSession;
    final isLoggingIn = state.uri.toString() == '/login' || state.uri.toString() == '/signup';

    if (session == null && !isLoggingIn) {
      return '/login';
    }
    
    if (session != null && isLoggingIn) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/budget/add',
      builder: (context, state) => const AddBudgetCategoryScreen(),
    ),
    GoRoute(
      path: '/budget/edit',
      builder: (context, state) => EditBudgetCategoryScreen(
        category: state.extra as BudgetCategory,
      ),
    ),
  ],
);
