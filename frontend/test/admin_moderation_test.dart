import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visitor_app/data/models/admin_models.dart';
import 'package:visitor_app/presentation/providers/admin_auth_provider.dart';
import 'package:visitor_app/presentation/providers/moderation_provider.dart';
import 'package:visitor_app/presentation/providers/settings_provider.dart';
import 'package:visitor_app/presentation/screens/admin/admin_login_screen.dart';
import 'package:visitor_app/presentation/screens/admin/admin_dashboard_screen.dart';
import 'package:visitor_app/presentation/screens/admin/photo_moderation_screen.dart';
import 'package:visitor_app/presentation/screens/admin/slideshow_settings_screen.dart';

void main() {
  group('Admin Models Serialization Tests', () {
    test('AdminSessionModel JSON serialization', () {
      final model = AdminSessionModel(
        accessToken: 'jwt.token.here',
        tokenType: 'bearer',
        username: 'admin',
      );

      final json = model.toJson();
      expect(json['access_token'], 'jwt.token.here');
      expect(json['username'], 'admin');

      final fromJson = AdminSessionModel.fromJson(json);
      expect(fromJson.accessToken, 'jwt.token.here');
      expect(fromJson.username, 'admin');
    });

    test('DashboardStatsModel JSON serialization', () {
      final model = DashboardStatsModel(
        totalPhotos: 12,
        pendingPhotos: 4,
        approvedPhotos: 6,
        rejectedPhotos: 2,
        totalVisitors: 8,
      );

      final json = model.toJson();
      expect(json['total_photos'], 12);
      expect(json['pending_photos'], 4);
      expect(json['approved_photos'], 6);
      expect(json['rejected_photos'], 2);
      expect(json['total_visitors'], 8);

      final fromJson = DashboardStatsModel.fromJson(json);
      expect(fromJson.totalPhotos, 12);
      expect(fromJson.pendingPhotos, 4);
    });

    test('AdminPhotoDetailModel parsing and properties', () {
      final json = {
        'id': 'photo-1',
        'filename': 'uuid.jpg',
        'original_filename': 'vacation.jpg',
        'file_size_bytes': 1048576,
        'mime_type': 'image/jpeg',
        'status': 'PENDING',
        'visitor_id': 'v-1',
        'visitor_name': 'Alice Smith',
        'visitor_email': 'alice@example.com',
        'consent_given': true,
        'consent_policy_version': 'v1.0',
        'consent_given_at': '2026-11-18T10:00:00Z',
        'rejection_reason': null,
        'reviewed_by_admin_id': null,
        'reviewed_at': null,
        'created_at': '2026-11-18T10:00:00Z',
      };

      final model = AdminPhotoDetailModel.fromJson(json);
      expect(model.id, 'photo-1');
      expect(model.visitorName, 'Alice Smith');
      expect(model.consentGiven, true);
      expect(model.isPending, true);
      expect(model.isApproved, false);
      expect(model.formattedSize, '1.0 MB');
    });

    test('SlideshowSettingsModel serialization & copyWith', () {
      final settings = SlideshowSettingsModel(
        slideDurationSeconds: 8,
        transitionEffect: 'slide',
        displayVisitorName: true,
        shuffleMode: false,
        slideshowAutoplay: true,
        slideshowEnabled: true,
      );

      expect(settings.slideDurationSeconds, 8);
      expect(settings.transitionEffect, 'slide');

      final updated = settings.copyWith(slideDurationSeconds: 12, shuffleMode: true);
      expect(updated.slideDurationSeconds, 12);
      expect(updated.shuffleMode, true);
      expect(updated.transitionEffect, 'slide');
    });
  });

  group('Admin Portal Widget Tests', () {
    testWidgets('AdminLoginScreen renders credentials form and submit button', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthProvider.overrideWith((ref) => AdminAuthNotifier(autoLoad: false)),
          ],
          child: const MaterialApp(
            home: AdminLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Moderator Sign In'), findsOneWidget);
      expect(find.byKey(const Key('admin_username_field')), findsOneWidget);
      expect(find.byKey(const Key('admin_password_field')), findsOneWidget);
      expect(find.byKey(const Key('admin_login_button')), findsOneWidget);

      // Verify form validation
      await tester.tap(find.byKey(const Key('admin_login_button')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your admin username or email'), findsOneWidget);
    });

    testWidgets('AdminDashboardScreen renders metrics cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyStats = const DashboardStatsModel(
        totalPhotos: 25,
        pendingPhotos: 5,
        approvedPhotos: 15,
        rejectedPhotos: 5,
        totalVisitors: 10,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthProvider.overrideWith((ref) => AdminAuthNotifier(autoLoad: false)),
            moderationProvider.overrideWith((ref) {
              final notifier = ModerationNotifier();
              notifier.state = notifier.state.copyWith(stats: dummyStats);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: AdminDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.text('Pending Moderation'), findsOneWidget);
      expect(find.text('5'), findsNWidgets(2)); // pending & rejected both 5
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Photo Moderation Queue'), findsOneWidget);
      expect(find.text('Slideshow Settings'), findsOneWidget);
    });

    testWidgets('PhotoModerationScreen displays tabs and photo lists with consent badges', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyPhoto = const AdminPhotoDetailModel(
        id: 'photo-test-1',
        filename: 'sample.jpg',
        originalFilename: 'family_photo.jpg',
        fileSizeBytes: 204800,
        mimeType: 'image/jpeg',
        status: 'PENDING',
        visitorId: 'visitor-1',
        visitorName: 'Bob Vance',
        consentGiven: true,
        createdAt: '2026-11-18 10:00',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthProvider.overrideWith((ref) => AdminAuthNotifier(autoLoad: false)),
            moderationProvider.overrideWith((ref) {
              final notifier = ModerationNotifier();
              notifier.state = notifier.state.copyWith(pendingPhotos: [dummyPhoto]);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: PhotoModerationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo Moderation'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Bob Vance'), findsOneWidget);
      expect(find.text('Consent Granted'), findsOneWidget);
      expect(find.byKey(const Key('approve_button_photo-test-1')), findsOneWidget);
      expect(find.byKey(const Key('reject_button_photo-test-1')), findsOneWidget);
    });

    testWidgets('SlideshowSettingsScreen renders controls and triggers save', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummySettings = const SlideshowSettingsModel(
        slideDurationSeconds: 10,
        transitionEffect: 'fade',
        displayVisitorName: true,
        shuffleMode: false,
        slideshowAutoplay: true,
        slideshowEnabled: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              final notifier = SettingsNotifier();
              notifier.state = notifier.state.copyWith(settings: dummySettings);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: SlideshowSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Slideshow Settings'), findsOneWidget);
      expect(find.text('Slide Duration'), findsOneWidget);
      expect(find.text('10 seconds'), findsOneWidget);
      expect(find.byKey(const Key('slide_duration_slider')), findsOneWidget);
      expect(find.byKey(const Key('display_visitor_name_switch')), findsOneWidget);
      expect(find.byKey(const Key('shuffle_mode_switch')), findsOneWidget);
      expect(find.byKey(const Key('save_settings_button')), findsOneWidget);
    });
  });
}
