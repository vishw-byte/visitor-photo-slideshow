import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/display_provider.dart';

class SmartTvDisplayScreen extends ConsumerStatefulWidget {
  const SmartTvDisplayScreen({super.key});

  @override
  ConsumerState<SmartTvDisplayScreen> createState() => _SmartTvDisplayScreenState();
}

class _SmartTvDisplayScreenState extends ConsumerState<SmartTvDisplayScreen> {
  final FocusNode _focusNode = FocusNode();
  bool _showControls = false;
  Timer? _hideControlsTimer;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        _toggleFullscreen();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.space) {
        ref.read(displayProvider.notifier).nextPhoto();
        _onUserInteraction();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        ref.read(displayProvider.notifier).previousPhoto();
        _onUserInteraction();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onUserInteraction() {
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  String _resolveVisitorPortalUrl(DisplayState state) {
    final serverUrl = state.settings.portalUrl?.trim();
    if (serverUrl != null && serverUrl.isNotEmpty) {
      return serverUrl;
    }
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('null')) {
        return origin;
      }
    }
    return ApiConstants.defaultPortalUrl;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(displayProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          onHover: (_) => _onUserInteraction(),
          child: GestureDetector(
            onTap: _onUserInteraction,
            child: Stack(
            fit: StackFit.expand,
            children: [
              // Main Content Area depending on state
              _buildContent(state),

              // Subtle Background Refresh & Network Error Indicator (Top Right)
              if (state.errorMessage != null || state.isBackgroundRefreshing)
                Positioned(
                  top: 20,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: state.errorMessage != null
                            ? AppTheme.warningColor.withAlpha(180)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.isBackgroundRefreshing) ...[
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (state.errorMessage != null) ...[
                          const Icon(Icons.wifi_off, size: 14, color: AppTheme.warningColor),
                          const SizedBox(width: 8),
                          Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Auto-hiding Ambient TV Overlay Controls
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _buildControlsOverlay(state),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildContent(DisplayState state) {
    // 1. Initial Loading State
    if (state.isLoading && state.photos.isEmpty) {
      return _buildLoadingState();
    }

    // 2. Master Slideshow Disabled State
    if (!state.isEnabled) {
      return _buildDisabledState();
    }

    // 3. Network Error on Initial Load with 0 photos
    if (state.errorMessage != null && state.photos.isEmpty) {
      return _buildNetworkErrorState(state.errorMessage!);
    }

    // 4. Empty Queue State
    if (state.isEmpty) {
      return _buildEmptyState(state);
    }

    // 5. Active Slideshow Photo State
    return _buildActiveSlideshow(state);
  }

  Widget _buildLoadingState() {
    return Container(
      color: const Color(0xFF0F172A), // Dark slate
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  color: AppTheme.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Connecting to Event Slideshow...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Synchronizing approved guest photos & display configuration',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledState() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tv_off_rounded,
                  size: 64,
                  color: AppTheme.warningColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Event Display Paused',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The slideshow is temporarily suspended by event hosts. It will resume automatically when re-enabled.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(DisplayState state) {
    final portalUrl = _resolveVisitorPortalUrl(state);

    return Container(
      color: const Color(0xFF0B1120),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(35),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryLight.withAlpha(60), width: 2),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  size: 72,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Your event memories will appear here soon!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Capture your favorite moments and upload them via the Visitor Portal. Once approved by event hosts, they will rotate live on this big screen!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              if (state.settings.showQrCode) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    key: const Key('empty_state_qr_code'),
                    data: portalUrl,
                    version: QrVersions.auto,
                    size: 130,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan with smartphone camera to upload photos',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 28),
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                label: const Text('Open Visitor Upload Portal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkErrorState(String message) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 20),
            const Text(
              'Connection Interrupted',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
              onPressed: () => ref.read(displayProvider.notifier).loadInitial(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSlideshow(DisplayState state) {
    final photo = state.currentPhoto!;
    final photoUrl = ApiConstants.displayMediaUrl(photo.id);
    final transition = state.settings.transitionEffect.toUpperCase();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Animated Switcher with Selected Transition
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 900),
          transitionBuilder: (Widget child, Animation<double> animation) {
            if (transition == 'SLIDE') {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic)),
                child: child,
              );
            } else if (transition == 'ZOOM') {
              return ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: FadeTransition(opacity: animation, child: child),
              );
            } else {
              // Default: Cross-Fade
              return FadeTransition(opacity: animation, child: child);
            }
          },
          child: Container(
            key: ValueKey<String>(photo.id),
            color: Colors.black,
            child: Center(
              child: Image.network(
                photoUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white38),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.broken_image_rounded, size: 64, color: Colors.white38),
                        SizedBox(height: 12),
                        Text('Image not accessible', style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Optional Visitor Name Overlay (Bottom Left)
        if (state.settings.showVisitorName && photo.visitorName.isNotEmpty)
          Positioned(
            left: 32,
            bottom: 32,
            child: AnimatedOpacity(
              opacity: _showControls ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withAlpha(180),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Shared by',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          photo.visitorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Optional QR Code Overlay (Bottom Right)
        if (state.settings.showQrCode)
          Positioned(
            right: 32,
            bottom: 32,
            child: AnimatedOpacity(
              opacity: _showControls ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(4),
                        child: QrImageView(
                          key: const Key('display_qr_code_widget'),
                          data: _resolveVisitorPortalUrl(state),
                          version: QrVersions.auto,
                          size: 76,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Scan to Share',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your Photos',
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Point phone camera',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlsOverlay(DisplayState state) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha(160),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withAlpha(180),
          ],
          stops: const [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Navigation Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Return to Visitor Portal',
                    onPressed: () => context.go('/'),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Event Photo Slideshow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
                    tooltip: 'Admin Portal',
                    onPressed: () => context.go('/admin/login'),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white,
                    ),
                    tooltip: 'Toggle Fullscreen',
                    onPressed: _toggleFullscreen,
                  ),
                ],
              ),
            ],
          ),

          // Bottom Playback Control Bar
          if (state.photos.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Photo Counter & Timing
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Photo ${state.currentIndex + 1} of ${state.photos.length}  •  ${state.settings.slideDurationSeconds}s/slide',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),

                // Center Playback Buttons
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
                      tooltip: 'Previous Photo',
                      onPressed: () => ref.read(displayProvider.notifier).previousPhoto(),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      tooltip: state.isPaused ? 'Resume Playback' : 'Pause Playback',
                      onPressed: () => ref.read(displayProvider.notifier).togglePause(),
                      child: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                      tooltip: 'Next Photo',
                      onPressed: () => ref.read(displayProvider.notifier).nextPhoto(),
                    ),
                  ],
                ),

                // Right Status Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: state.isPaused
                        ? AppTheme.warningColor.withAlpha(160)
                        : AppTheme.successColor.withAlpha(160),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.isPaused ? 'PAUSED' : 'LIVE ROTATION',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
