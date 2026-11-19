import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${_nameController.text.trim()}! You are registered.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      context.go('/upload');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              "Let's get you set up!",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your name so the event host and attendees know who took each amazing shot on the big screen.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),

            if (authState.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.errorColor.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        authState.errorMessage!,
                        style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Your Name *',
                      hintText: 'e.g. Alex Johnson',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      if (val.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address (Optional)',
                      hintText: 'e.g. alex@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                      helperText: 'Used only if the host shares an event photo recap.',
                    ),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(val.trim())) {
                          return 'Please enter a valid email address';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 36),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _submitRegistration,
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continue to Photo Upload'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
