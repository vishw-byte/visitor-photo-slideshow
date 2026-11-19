import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/admin_auth_provider.dart';
import '../../providers/moderation_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(moderationProvider.notifier).loadDashboardStats();
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to end your administrator session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(adminAuthProvider.notifier).logout();
      if (mounted) {
        context.go('/admin/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider);
    final modState = ref.watch(moderationProvider);
    final stats = modState.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: () => ref.read(moderationProvider.notifier).loadDashboardStats(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: modState.isLoadingStats && stats == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(moderationProvider.notifier).loadDashboardStats(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Welcome Banner with Admin Info
                        Card(
                          elevation: 0,
                          color: AppTheme.primaryColor.withAlpha(15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppTheme.primaryColor.withAlpha(40)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppTheme.primaryColor,
                                  child: const Icon(
                                    Icons.shield_outlined,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome, ${authState.username ?? 'Administrator'}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Live overview of photo submissions, visitor engagement, and moderation status.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error Banner if stats failed
                        if (modState.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              modState.errorMessage!,
                              style: const TextStyle(color: AppTheme.errorColor),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Metrics Overview Grid
                        const Text(
                          'Moderation & System Metrics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 650;
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _StatCard(
                                  width: isWide ? (constraints.maxWidth - 48) / 3 : double.infinity,
                                  label: 'Pending Moderation',
                                  value: stats?.pendingPhotos.toString() ?? '0',
                                  icon: Icons.hourglass_top_rounded,
                                  color: AppTheme.warningColor,
                                  badgeText: (stats?.pendingPhotos ?? 0) > 0 ? 'Requires Action' : 'All Clear',
                                  onTap: () => context.go('/admin/moderation'),
                                ),
                                _StatCard(
                                  width: isWide ? (constraints.maxWidth - 48) / 3 : double.infinity,
                                  label: 'Approved Photos',
                                  value: stats?.approvedPhotos.toString() ?? '0',
                                  icon: Icons.check_circle_outline_rounded,
                                  color: AppTheme.successColor,
                                  badgeText: 'Active in Queue',
                                  onTap: () => context.go('/admin/moderation'),
                                ),
                                _StatCard(
                                  width: isWide ? (constraints.maxWidth - 48) / 3 : double.infinity,
                                  label: 'Rejected Photos',
                                  value: stats?.rejectedPhotos.toString() ?? '0',
                                  icon: Icons.cancel_outlined,
                                  color: AppTheme.errorColor,
                                  badgeText: 'Declined',
                                  onTap: () => context.go('/admin/moderation'),
                                ),
                                _StatCard(
                                  width: isWide ? (constraints.maxWidth - 32) / 2 : double.infinity,
                                  label: 'Total Uploaded Photos',
                                  value: stats?.totalPhotos.toString() ?? '0',
                                  icon: Icons.photo_library_outlined,
                                  color: AppTheme.primaryColor,
                                  onTap: () => context.go('/admin/moderation'),
                                ),
                                _StatCard(
                                  width: isWide ? (constraints.maxWidth - 32) / 2 : double.infinity,
                                  label: 'Registered Visitors',
                                  value: stats?.totalVisitors.toString() ?? '0',
                                  icon: Icons.people_outline_rounded,
                                  color: const Color(0xFF8B5CF6), // Purple
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // Quick Navigation Actions
                        const Text(
                          'Administrative Control',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _ActionTile(
                                title: 'Photo Moderation Queue',
                                subtitle: 'Review pending uploads, verify visitor consent, and approve or reject.',
                                icon: Icons.rate_review_outlined,
                                color: AppTheme.primaryColor,
                                onTap: () => context.go('/admin/moderation'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ActionTile(
                                title: 'Slideshow Settings',
                                subtitle: 'Configure slide duration, animation transitions, and display toggles.',
                                icon: Icons.tune_rounded,
                                color: AppTheme.accentColor,
                                onTap: () => context.go('/admin/settings'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Launch Live Smart TV Slideshow
                        ElevatedButton.icon(
                          key: const Key('admin_launch_tv_button'),
                          icon: const Icon(Icons.tv_rounded),
                          label: const Text('Launch Live Smart TV Slideshow'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => context.go('/display'),
                        ),
                        const SizedBox(height: 12),

                        // Switch to Visitor View
                        OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Open Visitor Upload Experience'),
                          onPressed: () => context.go('/'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? badgeText;
  final VoidCallback? onTap;

  const _StatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.badgeText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText!,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
