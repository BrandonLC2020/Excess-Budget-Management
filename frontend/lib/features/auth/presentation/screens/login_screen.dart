import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/breakpoints.dart';
import '../../../../core/theme/refractive_glass.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_state.dart';
import '../widgets/branding_panel.dart';
import '../widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < Breakpoints.compact;

            if (isCompact) {
              return SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: RefractiveGlass(
                        child: const LoginForm(),
                      ),
                    ),
                  ),
                ),
              );
            } else {
              return Row(
                children: [
                  const Expanded(flex: 1, child: BrandingPanel()),
                  Expanded(
                    flex: 1,
                    child: SafeArea(
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: const SingleChildScrollView(child: LoginForm()),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
