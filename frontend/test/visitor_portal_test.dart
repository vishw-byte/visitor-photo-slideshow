import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visitor_app/presentation/providers/auth_provider.dart';
import 'package:visitor_app/presentation/screens/welcome_screen.dart';
import 'package:visitor_app/presentation/screens/registration_screen.dart';
import 'package:visitor_app/presentation/widgets/status_badge.dart';
import 'package:visitor_app/data/models/photo_model.dart';
import 'package:visitor_app/data/models/visitor_model.dart';

void main() {
  group('Visitor Model Tests', () {
    test('VisitorModel JSON serialization', () {
      final now = DateTime.now();
      final model = VisitorModel(
        id: '123',
        name: 'Alice',
        email: 'alice@example.com',
        sessionToken: 'token_abc',
        createdAt: now,
      );

      final json = model.toJson();
      expect(json['id'], '123');
      expect(json['name'], 'Alice');
      expect(json['email'], 'alice@example.com');
      expect(json['session_token'], 'token_abc');

      final fromJson = VisitorModel.fromJson(json);
      expect(fromJson.name, 'Alice');
      expect(fromJson.email, 'alice@example.com');
      expect(fromJson.sessionToken, 'token_abc');
    });

    test('PhotoModel status parsing', () {
      expect(PhotoStatus.fromString('PENDING'), PhotoStatus.pending);
      expect(PhotoStatus.fromString('APPROVED'), PhotoStatus.approved);
      expect(PhotoStatus.fromString('REJECTED'), PhotoStatus.rejected);
      expect(PhotoStatus.fromString('UNKNOWN'), PhotoStatus.pending);
    });
  });

  group('Widget Tests', () {
    testWidgets('WelcomeScreen renders app name and Get Started button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifier(autoLoad: false)),
          ],
          child: const MaterialApp(
            home: WelcomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visitor Photo Slideshow'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });

    testWidgets('StatusBadge displays correct text and colors for each status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(status: PhotoStatus.pending),
                StatusBadge(status: PhotoStatus.approved),
                StatusBadge(status: PhotoStatus.rejected),
              ],
            ),
          ),
        ),
      );

      expect(find.text('In Review'), findsOneWidget);
      expect(find.text('Approved for Slideshow'), findsOneWidget);
      expect(find.text('Not Displayed'), findsOneWidget);
    });

    testWidgets('RegistrationScreen validates empty name submission', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifier(autoLoad: false)),
          ],
          child: const MaterialApp(
            home: RegistrationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitButton = find.widgetWithText(ElevatedButton, 'Continue to Photo Upload');
      expect(submitButton, findsOneWidget);
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name'), findsOneWidget);
    });
  });
}
