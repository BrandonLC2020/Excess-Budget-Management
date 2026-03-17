import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/constants.dart';
import 'core/router.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/accounts/bloc/account_bloc.dart';
import 'features/accounts/repositories/account_repository.dart';
import 'features/budget/bloc/budget_bloc.dart';
import 'features/budget/repositories/budget_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnonKey,
  );

  runApp(const BudgetApp());
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseClient = Supabase.instance.client;

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(supabase: supabaseClient)..add(AuthCheckRequested()),
        ),
        BlocProvider<AccountBloc>(
          create: (context) => AccountBloc(repository: AccountRepository(supabase: supabaseClient)),
        ),
        BlocProvider<BudgetBloc>(
          create: (context) => BudgetBloc(repository: BudgetRepository(supabase: supabaseClient)),
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
          textTheme: GoogleFonts.outfitTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
          useMaterial3: true,
        ),
        routerConfig: goRouter,
      ),
    );
  }
}
