import 'package:go_router/go_router.dart';
import '../../presentation/screens/welcome_screen.dart';
import '../../presentation/screens/registration_screen.dart';
import '../../presentation/screens/upload_screen.dart';
import '../../presentation/screens/my_photos_screen.dart';
import '../../presentation/screens/admin/admin_login_screen.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';
import '../../presentation/screens/admin/photo_moderation_screen.dart';
import '../../presentation/screens/admin/slideshow_settings_screen.dart';
import '../../presentation/screens/display/smart_tv_display_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Visitor Routes
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegistrationScreen(),
    ),
    GoRoute(
      path: '/upload',
      builder: (context, state) => const UploadScreen(),
    ),
    GoRoute(
      path: '/my-photos',
      builder: (context, state) => const MyPhotosScreen(),
    ),

    // Admin Routes
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/moderation',
      builder: (context, state) => const PhotoModerationScreen(),
    ),
    GoRoute(
      path: '/admin/settings',
      builder: (context, state) => const SlideshowSettingsScreen(),
    ),

    // Smart TV Continuous Slideshow Route (Phase 4)
    GoRoute(
      path: '/display',
      builder: (context, state) => const SmartTvDisplayScreen(),
    ),
  ],
);
