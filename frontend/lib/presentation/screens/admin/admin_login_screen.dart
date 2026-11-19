import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/admin_auth_provider.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(adminAuthProvider.notifier).login(
          username: _usernameController.text,
          password: _passwordController.text,
        );

    if (success && mounted) {
      context.go('/admin/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Portal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Visitor Portal',
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Lock & Security Header
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 36,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Moderator Sign In',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Access photo moderation queue and configure slideshow display settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Error message if login failed
                      if (authState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.errorColor.withAlpha(80)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authState.errorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Username or Email
                      TextFormField(
                        key: const Key('admin_username_field'),
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username or Email',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your admin username or email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Password
                      TextFormField(
                        key: const Key('admin_password_field'),
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Submit button
                      ElevatedButton(
                        key: const Key('admin_login_button'),
                        onPressed: authState.isLoading ? null : _handleLogin,
                        child: authState.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign In to Dashboard'),
                      ),
                      const SizedBox(height: 16),

                      // Return to Visitor App
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Switch to Visitor Portal'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
