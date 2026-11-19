import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../../data/models/admin_models.dart';

class SlideshowSettingsScreen extends ConsumerStatefulWidget {
  const SlideshowSettingsScreen({super.key});

  @override
  ConsumerState<SlideshowSettingsScreen> createState() => _SlideshowSettingsScreenState();
}

class _SlideshowSettingsScreenState extends ConsumerState<SlideshowSettingsScreen> {
  int _slideDuration = 5;
  String _transitionEffect = 'fade';
  bool _displayVisitorName = true;
  bool _shuffleMode = false;
  bool _slideshowAutoplay = true;
  bool _slideshowEnabled = true;
  bool _showQrCode = true;
  final _portalUrlController = TextEditingController();
  bool _initialized = false;

  final List<String> _transitionOptions = ['fade', 'slide', 'zoom'];

  @override
  void dispose() {
    _portalUrlController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(settingsProvider.notifier).loadSettings();
      _syncFromProvider();
    });
  }

  void _syncFromProvider() {
    final settings = ref.read(settingsProvider).settings;
    if (settings != null) {
      setState(() {
        _slideDuration = settings.slideDurationSeconds;
        _transitionEffect = settings.transitionEffect;
        _displayVisitorName = settings.displayVisitorName;
        _shuffleMode = settings.shuffleMode;
        _slideshowAutoplay = settings.slideshowAutoplay;
        _slideshowEnabled = settings.slideshowEnabled;
        _showQrCode = settings.showQrCode;
        _portalUrlController.text = settings.visitorPortalUrl ?? '';
        _initialized = true;
      });
    }
  }

  Future<void> _handleSave() async {
    final newSettings = SlideshowSettingsModel(
      slideDurationSeconds: _slideDuration,
      transitionEffect: _transitionEffect,
      displayVisitorName: _displayVisitorName,
      shuffleMode: _shuffleMode,
      slideshowAutoplay: _slideshowAutoplay,
      slideshowEnabled: _slideshowEnabled,
      showQrCode: _showQrCode,
      visitorPortalUrl: _portalUrlController.text.trim().isEmpty ? null : _portalUrlController.text.trim(),
    );

    final success = await ref.read(settingsProvider.notifier).updateSettings(newSettings);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slideshow settings updated successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);

    // If state finished loading and local state not yet initialized, sync it
    if (!_initialized && state.settings != null) {
      _slideDuration = state.settings!.slideDurationSeconds;
      _transitionEffect = state.settings!.transitionEffect;
      _displayVisitorName = state.settings!.displayVisitorName;
      _shuffleMode = state.settings!.shuffleMode;
      _slideshowAutoplay = state.settings!.slideshowAutoplay;
      _slideshowEnabled = state.settings!.slideshowEnabled;
      _showQrCode = state.settings!.showQrCode;
      _portalUrlController.text = state.settings!.visitorPortalUrl ?? '';
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slideshow Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Settings',
            onPressed: () async {
              await ref.read(settingsProvider.notifier).loadSettings();
              _syncFromProvider();
            },
          ),
        ],
      ),
      body: state.isLoading && !_initialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header card
                      Card(
                        elevation: 0,
                        color: AppTheme.accentColor.withAlpha(20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppTheme.accentColor.withAlpha(40)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: const [
                              Icon(Icons.tv_rounded, size: 36, color: AppTheme.accentColor),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Smart TV Display Configuration',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Customize how approved visitor photos are rendered on digital displays.',
                                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Error message if any
                      if (state.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(color: AppTheme.errorColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Settings Form Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Slide duration slider
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Slide Duration',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$_slideDuration seconds',
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'How many seconds each photo stays on screen before transitioning.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              Slider(
                                key: const Key('slide_duration_slider'),
                                value: _slideDuration.toDouble(),
                                min: 3,
                                max: 60,
                                divisions: 57,
                                label: '$_slideDuration s',
                                onChanged: (val) {
                                  setState(() {
                                    _slideDuration = val.round();
                                  });
                                },
                              ),
                              const Divider(height: 32),

                              // Transition Effect Dropdown
                              const Text(
                                'Transition Effect',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Visual transition style between consecutive slideshow slides.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: const Key('transition_effect_dropdown'),
                                initialValue: _transitionEffect,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                items: _transitionOptions.map((opt) {
                                  return DropdownMenuItem<String>(
                                    value: opt,
                                    child: Text(
                                      opt.toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _transitionEffect = val;
                                    });
                                  }
                                },
                              ),
                              const Divider(height: 32),

                              // Display Visitor Name Toggle
                              SwitchListTile(
                                key: const Key('display_visitor_name_switch'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Display Visitor Name Overlay',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Show the contributing visitor name on the bottom overlay banner of each slide.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                value: _displayVisitorName,
                                onChanged: (val) => setState(() => _displayVisitorName = val),
                              ),
                              const Divider(height: 24),

                              // Shuffle Mode Toggle
                              SwitchListTile(
                                key: const Key('shuffle_mode_switch'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Shuffle Mode',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Randomize playback order instead of chronological sequence.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                value: _shuffleMode,
                                onChanged: (val) => setState(() => _shuffleMode = val),
                              ),
                              const Divider(height: 24),

                              // Slideshow Autoplay Toggle
                              SwitchListTile(
                                key: const Key('slideshow_autoplay_switch'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Autoplay Slideshow',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Automatically advance through photos without requiring manual remote input.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                value: _slideshowAutoplay,
                                onChanged: (val) => setState(() => _slideshowAutoplay = val),
                              ),
                              const Divider(height: 24),

                              // Master Slideshow Enabled Switch
                              SwitchListTile(
                                key: const Key('slideshow_enabled_switch'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Enable Public Slideshow Display',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'When turned off, the Smart TV screen shows a standby screen and suspends media broadcast.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                value: _slideshowEnabled,
                                onChanged: (val) => setState(() => _slideshowEnabled = val),
                              ),
                              const Divider(height: 24),

                              // Visitor Portal QR Code Toggle & URL Field
                              SwitchListTile(
                                key: const Key('show_qr_code_switch'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Display Visitor Portal QR Code',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Show a scannable QR code on the Smart TV screen for guest photo uploads.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                value: _showQrCode,
                                onChanged: (val) => setState(() => _showQrCode = val),
                              ),
                              if (_showQrCode) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const Key('portal_url_field'),
                                  controller: _portalUrlController,
                                  decoration: const InputDecoration(
                                    labelText: 'Custom Visitor Portal URL (Optional)',
                                    hintText: 'e.g. https://eventphotos.example.com (Leave empty to use server default)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.qr_code_2),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),

                              // Save Button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  key: const Key('save_settings_button'),
                                  icon: state.isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.save_rounded),
                                  label: Text(state.isSaving ? 'Saving Changes...' : 'Save Settings'),
                                  onPressed: state.isSaving ? null : _handleSave,
                                ),
                              ),
                            ],
                          ),
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
