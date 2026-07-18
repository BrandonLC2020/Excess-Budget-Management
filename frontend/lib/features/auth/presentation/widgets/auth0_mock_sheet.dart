import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/constants.dart';

class Auth0MockSheet extends StatefulWidget {
  final Function(String token) onLogin;

  const Auth0MockSheet({super.key, required this.onLogin});

  @override
  State<Auth0MockSheet> createState() => _Auth0MockSheetState();
}

class _Auth0MockSheetState extends State<Auth0MockSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isEmailFlow = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _createMockJwt(String email, String name, String picture) {
    final headerJson = jsonEncode({'alg': 'none', 'typ': 'JWT'});
    final payloadJson = jsonEncode({
      'email': email,
      'name': name,
      'picture': picture,
      'iss': 'https://${Constants.auth0Domain}/',
      'aud': Constants.auth0Audience,
      'sub': 'auth0|mock_user_${DateTime.now().millisecondsSinceEpoch}',
    });

    String base64UrlEncode(String str) {
      return base64Url.encode(utf8.encode(str)).replaceAll('=', '');
    }

    final headerBase64 = base64UrlEncode(headerJson);
    final payloadBase64 = base64UrlEncode(payloadJson);

    return '$headerBase64.$payloadBase64.';
  }

  void _handleSocialLogin(String provider) {
    final email = '${provider.toLowerCase()}-user@example.com';
    final name = '${provider[0].toUpperCase()}${provider.substring(1)} User';
    final token = _createMockJwt(
      email,
      name,
      'https://api.dicebear.com/7.x/bottts/png?seed=$email',
    );
    Navigator.pop(context);
    widget.onLogin(token);
  }

  void _handleEmailSubmit() {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }
    final email = _emailController.text;
    final name = email.split('@').first;
    final token = _createMockJwt(
      email,
      name,
      'https://api.dicebear.com/7.x/bottts/png?seed=$email',
    );
    Navigator.pop(context);
    widget.onLogin(token);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: _isEmailFlow ? 0.65 : 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Auth0 Logo / Shield Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEB5424).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFEB5424),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'auth0',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEB5424),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'SECURE SIGN IN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                _isEmailFlow
                    ? (_isSignUp ? 'Create your Account' : 'Welcome back')
                    : 'Sign in to Excess Budget',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A single secure login for all your financial apps.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (!_isEmailFlow) ...[
                // Google Sign In
                _SocialButton(
                  icon: Icons.g_mobiledata_outlined,
                  logoColor: Colors.blue,
                  label: 'Continue with Google',
                  onPressed: () => _handleSocialLogin('Google'),
                ),
                const SizedBox(height: 12),

                // Apple Sign In
                _SocialButton(
                  icon: Icons.apple,
                  logoColor: theme.colorScheme.onSurface,
                  label: 'Continue with Apple',
                  onPressed: () => _handleSocialLogin('Apple'),
                ),
                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.dividerColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'OR',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: theme.dividerColor)),
                  ],
                ),
                const SizedBox(height: 16),

                // Email button
                FilledButton.icon(
                  onPressed: () => setState(() => _isEmailFlow = true),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Continue with Email'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                // Email input form
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: _handleEmailSubmit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFEB5424),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isSignUp ? 'Sign Up' : 'Log In',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isEmailFlow = false),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back, size: 16),
                          SizedBox(width: 4),
                          Text('Other login options'),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? 'Already have an account?'
                            : 'Need an account?',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final Color logoColor;
  final String label;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.logoColor,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: theme.dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: logoColor, size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
