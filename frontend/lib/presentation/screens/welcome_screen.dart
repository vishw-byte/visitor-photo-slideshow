import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryDark,
              AppTheme.primaryColor,
              AppTheme.primaryLight.withAlpha(200),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Hero Header & App Branding
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(60), width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Visitor Photo Slideshow',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Be part of the celebration! Share your favorite event moments to appear on the big screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Feature Highlights Cards
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withAlpha(40)),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow(
                        Icons.photo_library_outlined,
                        'Upload Event Photos',
                        'Pick from your phone gallery with full preview control.',
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      _buildFeatureRow(
                        Icons.verified_user_outlined,
                        'Secure & Consent-Driven',
                        'You control public display consent and can remove photos anytime.',
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      _buildFeatureRow(
                        Icons.tv,
                        'Live on the Big Screen',
                        'Once approved by our host, your photo streams live to the TV!',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Area
                if (authState.isAuthenticated) ...[
                  Text(
                    'Welcome back, ${authState.visitor?.name}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryDark,
                      ),
                      onPressed: () => context.go('/upload'),
                      child: const Text('Continue to Photo Upload'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text(
                      'Register as a new visitor',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryDark,
                      ),
                      onPressed: () => context.go('/register'),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Get Started'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('open_tv_display_button'),
                  icon: const Icon(Icons.tv_rounded, size: 18),
                  label: const Text('Launch Big Screen Slideshow'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withAlpha(120)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go('/display'),
                ),

                const SizedBox(height: 16),
                TextButton.icon(
                  key: const Key('admin_portal_link'),
                  icon: Icon(Icons.admin_panel_settings_outlined, size: 16, color: Colors.white.withAlpha(180)),
                  label: Text('Admin Moderation Portal', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
                  onPressed: () => context.go('/admin/login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.accentColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
