import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visitor_app/data/models/display_models.dart';
import 'package:visitor_app/presentation/providers/display_provider.dart';
import 'package:visitor_app/presentation/screens/display/smart_tv_display_screen.dart';

void main() {
  group('Display Models Tests', () {
    test('DisplayPhotoModel serialization', () {
      final json = {
        'id': 'photo-tv-1',
        'url': '/api/v1/media/slideshow/photo-tv-1',
        'visitor_name': 'Alex Morgan',
        'created_at': '2026-11-18T12:00:00Z',
        'width': 1920,
        'height': 1080,
      };

      final model = DisplayPhotoModel.fromJson(json);
      expect(model.id, 'photo-tv-1');
      expect(model.visitorName, 'Alex Morgan');
      expect(model.url, '/api/v1/media/slideshow/photo-tv-1');
      expect(model.width, 1920);

      final outJson = model.toJson();
      expect(outJson['visitor_name'], 'Alex Morgan');
    });

    test('DisplayFeedModel serialization and parsing', () {
      final json = {
        'photos': [
          {
            'id': 'p1',
            'url': '/api/v1/media/slideshow/p1',
            'visitor_name': 'John Doe',
          },
          {
            'id': 'p2',
            'url': '/api/v1/media/slideshow/p2',
            'visitor_name': 'Jane Smith',
          },
        ],
        'total_count': 2,
        'slideshow_enabled': true,
      };

      final feed = DisplayFeedModel.fromJson(json);
      expect(feed.photos.length, 2);
      expect(feed.totalCount, 2);
      expect(feed.slideshowEnabled, true);
      expect(feed.photos[0].visitorName, 'John Doe');
    });

    test('DisplaySettingsModel serialization and defaults', () {
      const defaultSettings = DisplaySettingsModel();
      expect(defaultSettings.slideDurationSeconds, 10);
      expect(defaultSettings.transitionEffect, 'FADE');
      expect(defaultSettings.showVisitorName, true);
      expect(defaultSettings.shufflePlayback, false);
      expect(defaultSettings.slideshowAutoplay, true);
      expect(defaultSettings.slideshowEnabled, true);

      final json = {
        'slide_duration_seconds': 15,
        'transition_effect': 'zoom',
        'show_visitor_name': false,
        'shuffle_playback': true,
        'slideshow_autoplay': true,
        'slideshow_enabled': true,
        'refresh_interval_seconds': 20,
      };

      final parsed = DisplaySettingsModel.fromJson(json);
      expect(parsed.slideDurationSeconds, 15);
      expect(parsed.transitionEffect, 'ZOOM');
      expect(parsed.showVisitorName, false);
      expect(parsed.shufflePlayback, true);
      expect(parsed.refreshIntervalSeconds, 20);
    });
  });

  group('DisplayNotifier Logic Tests', () {
    test('Automatic rotation and next/previous navigation', () {
      final notifier = DisplayNotifier(autoStart: false);

      final p1 = const DisplayPhotoModel(id: '1', url: '/p1', visitorName: 'Alice');
      final p2 = const DisplayPhotoModel(id: '2', url: '/p2', visitorName: 'Bob');
      final p3 = const DisplayPhotoModel(id: '3', url: '/p3', visitorName: 'Charlie');

      notifier.state = notifier.state.copyWith(
        photos: [p1, p2, p3],
        currentIndex: 0,
      );

      expect(notifier.state.currentIndex, 0);
      expect(notifier.state.currentPhoto?.id, '1');

      // Next
      notifier.nextPhoto();
      expect(notifier.state.currentIndex, 1);
      expect(notifier.state.currentPhoto?.id, '2');

      // Next
      notifier.nextPhoto();
      expect(notifier.state.currentIndex, 2);
      expect(notifier.state.currentPhoto?.id, '3');

      // Loop back to 0
      notifier.nextPhoto();
      expect(notifier.state.currentIndex, 0);
      expect(notifier.state.currentPhoto?.id, '1');

      // Previous loops back to 2
      notifier.previousPhoto();
      expect(notifier.state.currentIndex, 2);
      expect(notifier.state.currentPhoto?.id, '3');

      // Pause toggle
      expect(notifier.state.isPaused, false);
      notifier.togglePause();
      expect(notifier.state.isPaused, true);
      notifier.togglePause();
      expect(notifier.state.isPaused, false);

      notifier.dispose();
    });

    test('Slideshow settings consistency and dynamic update in state', () {
      final notifier = DisplayNotifier(autoStart: false);
      expect(notifier.state.settings.slideDurationSeconds, 10);
      expect(notifier.state.settings.transitionEffect, 'FADE');
      expect(notifier.state.settings.showVisitorName, true);
      expect(notifier.state.settings.showQrCode, true);

      // Simulate admin changing settings
      const updatedSettings = DisplaySettingsModel(
        slideDurationSeconds: 14,
        transitionEffect: 'ZOOM',
        showVisitorName: false,
        shufflePlayback: true,
        slideshowAutoplay: false,
        slideshowEnabled: true,
        refreshIntervalSeconds: 25,
        showQrCode: false,
        visitorPortalUrl: 'https://photos.productionevent.com',
        portalUrl: 'https://photos.productionevent.com',
      );

      notifier.state = notifier.state.copyWith(settings: updatedSettings);

      expect(notifier.state.settings.slideDurationSeconds, 14);
      expect(notifier.state.settings.transitionEffect, 'ZOOM');
      expect(notifier.state.settings.showVisitorName, false);
      expect(notifier.state.settings.shufflePlayback, true);
      expect(notifier.state.settings.slideshowAutoplay, false);
      expect(notifier.state.settings.refreshIntervalSeconds, 25);
      expect(notifier.state.settings.showQrCode, false);
      expect(notifier.state.settings.portalUrl, 'https://photos.productionevent.com');
      notifier.dispose();
    });
  });

  group('SmartTvDisplayScreen UI States', () {
    testWidgets('Renders Loading State when connecting', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            displayProvider.overrideWith((ref) {
              final notifier = DisplayNotifier(autoStart: false);
              notifier.state = notifier.state.copyWith(isLoading: true, photos: []);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: SmartTvDisplayScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Connecting to Event Slideshow...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Renders Empty Queue State when no approved photos exist', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            displayProvider.overrideWith((ref) {
              final notifier = DisplayNotifier(autoStart: false);
              notifier.state = notifier.state.copyWith(isLoading: false, photos: []);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: SmartTvDisplayScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your event memories will appear here soon!'), findsOneWidget);
      expect(find.text('Open Visitor Upload Portal'), findsOneWidget);
    });

    testWidgets('Renders Disabled State when slideshow_enabled is false', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            displayProvider.overrideWith((ref) {
              final notifier = DisplayNotifier(autoStart: false);
              notifier.state = notifier.state.copyWith(
                isLoading: false,
                settings: const DisplaySettingsModel(slideshowEnabled: false),
                photos: [],
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: SmartTvDisplayScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Event Display Paused'), findsOneWidget);
      expect(find.textContaining('temporarily suspended by event hosts'), findsOneWidget);
    });

    testWidgets('Renders Active Slideshow with Visitor Name Overlay', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testPhoto = const DisplayPhotoModel(
        id: 'photo-100',
        url: 'http://127.0.0.1:8000/api/v1/media/slideshow/photo-100',
        visitorName: 'Diana Prince',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            displayProvider.overrideWith((ref) {
              final notifier = DisplayNotifier(autoStart: false);
              notifier.state = notifier.state.copyWith(
                isLoading: false,
                settings: const DisplaySettingsModel(
                  showVisitorName: true,
                  transitionEffect: 'FADE',
                ),
                photos: [testPhoto],
                currentIndex: 0,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: SmartTvDisplayScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Diana Prince'), findsOneWidget);
      expect(find.text('Shared by'), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
    });

    testWidgets('Hides Visitor Name Overlay when showVisitorName is false', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testPhoto = const DisplayPhotoModel(
        id: 'photo-101',
        url: 'http://127.0.0.1:8000/api/v1/media/slideshow/photo-101',
        visitorName: 'Jordan Lee',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            displayProvider.overrideWith((ref) {
              final notifier = DisplayNotifier(autoStart: false);
              notifier.state = notifier.state.copyWith(
                isLoading: false,
                settings: const DisplaySettingsModel(showVisitorName: false),
                photos: [testPhoto],
                currentIndex: 0,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: SmartTvDisplayScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Jordan Lee'), findsNothing);
      expect(find.text('Shared by'), findsNothing);
    });
    testWidgets('Renders QR code widget when showQrCode is true', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testPhoto = const DisplayPhotoModel(
        id: 'photo-102',
        url: 'http://127.0.0.1:8000/api/v1/media/slideshow/photo-102',
        visitorName: 'Taylor Smith',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            displayProvider.overrideWith((ref) {
              final notifier = DisplayNotifier(autoStart: false);
              notifier.state = notifier.state.copyWith(
                isLoading: false,
                settings: const DisplaySettingsModel(showQrCode: true),
                photos: [testPhoto],
                currentIndex: 0,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: SmartTvDisplayScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('display_qr_code_widget')), findsOneWidget);
      expect(find.text('Scan to Share'), findsOneWidget);
    });

    testWidgets('Hides QR code widget when showQrCode is false', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testPhoto = const DisplayPhotoModel(
        id: 'photo-103',
        url: 'http://127.0.0.1:8000/api/v1/media/slideshow/photo-103',
        visitorName: 'Casey Riley',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            displayProvider.overrideWith((ref) {
              final notifier = DisplayNotifier(autoStart: false);
              notifier.state = notifier.state.copyWith(
                isLoading: false,
                settings: const DisplaySettingsModel(showQrCode: false),
                photos: [testPhoto],
                currentIndex: 0,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: SmartTvDisplayScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('display_qr_code_widget')), findsNothing);
    });
  });
}
