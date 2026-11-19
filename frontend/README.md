# Visitor Photo Slideshow — Flutter Client, Admin & Smart TV Portal (Phase 1 to 4)

A cross-platform Flutter application (Web, Smart TV, Android TV, Windows, macOS, Android, iOS) delivering:
1. **The Visitor Experience**: Event guest registration, multi-photo uploading with public-display consent, upload status history, and immediate deletion.
2. **The Admin Moderation Portal**: Secure JWT authentication, dashboard analytics, tabbed photo moderation (pending, approved, rejected), consent-enforced approval, and slideshow settings.
3. **The Smart TV Continuous Slideshow**: Ambient full-screen display running on Smart TVs and computers, with automatic photo rotation, smooth transitions (Fade, Slide, Zoom), visitor attribution overlay, auto-hiding controls, and periodic background synchronization.

---

## 1. Architecture Overview

```
frontend/lib/
├── core/
│   ├── constants/api_constants.dart    # API URL & endpoint definitions
│   ├── network/dio_client.dart         # Dio with token routing & user-friendly error mapping
│   ├── storage/session_storage.dart    # flutter_secure_storage for visitor & admin JWT tokens
│   ├── theme/app_theme.dart            # Material 3 theme (Indigo, Amber, Emerald, Rose)
│   └── router/app_router.dart          # GoRouter routes (Visitor, Admin & Smart TV paths)
├── data/
│   ├── models/
│   │   ├── visitor_model.dart          # Visitor profile & session token model
│   │   ├── photo_model.dart            # Photo model with Status enum & URLs
│   │   ├── admin_models.dart           # AdminSession, DashboardStats, AdminPhotoDetail, SlideshowSettings
│   │   └── display_models.dart         # DisplayPhotoModel, DisplayFeedModel, DisplaySettingsModel
│   └── repositories/
│       ├── visitor_repository.dart     # Visitor registration, uploads, gallery, deletion
│       ├── admin_repository.dart       # Admin login, metrics, moderation actions, settings
│       └── display_repository.dart     # Public Smart TV display photo feed & settings fetch
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart          # Riverpod StateNotifier for visitor session
│   │   ├── photo_provider.dart         # Riverpod StateNotifier for visitor photos & uploads
│   │   ├── admin_auth_provider.dart    # Riverpod StateNotifier for admin JWT auth session
│   │   ├── moderation_provider.dart    # Riverpod StateNotifier for stats & photo moderation tabs
│   │   ├── settings_provider.dart      # Riverpod StateNotifier for slideshow configuration
│   │   └── display_provider.dart       # Riverpod StateNotifier for TV rotation & real-time polling
│   ├── screens/
│   │   ├── welcome_screen.dart         # Visitor: App greeting, highlights, Get Started CTA, TV link
│   │   ├── registration_screen.dart    # Visitor: Name & optional email with validation
│   │   ├── upload_screen.dart          # Visitor: Multi-image picker, preview, consent checkbox
│   │   ├── my_photos_screen.dart       # Visitor: Photo history with Pending/Approved/Rejected badges
│   │   ├── admin/
│   │   │   ├── admin_login_screen.dart         # Admin: Secure JWT authentication form
│   │   │   ├── admin_dashboard_screen.dart     # Admin: KPI metrics overview & action shortcuts
│   │   │   ├── photo_moderation_screen.dart    # Admin: Pending/Approved/Rejected tabs, consent checks
│   │   │   └── slideshow_settings_screen.dart  # Admin: Duration slider, transitions, autoplay toggles
│   │   └── display/
│   │       └── smart_tv_display_screen.dart    # Smart TV: Continuous full-screen ambient slideshow
│   └── widgets/
│       └── status_badge.dart           # Visual status pill widget
└── main.dart                           # Entry point with ProviderScope & MaterialApp.router
```

---

## 2. Smart TV Slideshow Screen (`/display`)

### 2.1 Key Features
- **Continuous Auto-Rotation**: Automatically advances through approved photos at the configured duration (default: 10 seconds).
- **Smooth Visual Transitions**:
  - `FADE`: Cinematic cross-fade between photos.
  - `SLIDE`: Dynamic horizontal sliding transition.
  - `ZOOM`: Subtle scale and depth transition.
- **Ambient Visitor Attribution**: Bottom-left card displaying `"Shared by {Visitor Name}"` (can be toggled in admin settings).
- **Auto-Hiding Controls**: Mouse movement or tap reveals top header (fullscreen toggle, exit) and bottom playback controls (previous, next, pause/resume), auto-fading after 4 seconds of inactivity.
- **5 Resilient Display States**:
  1. **Loading**: Professional animated spinner while fetching display feed.
  2. **Empty**: Warm invitation banner encouraging guests to upload photos.
  3. **Active**: Continuous landscape playback with dark backdrop.
  4. **Network Interrupted**: Floating subtle badge in the corner during network drops; retains cached photos without breaking the screen.
  5. **Paused / Disabled**: Standby screen displayed when event hosts disable the slideshow.
- **Real-Time Polling Synchronization**:
  - Periodically checks backend every 15s (configurable).
  - Newly approved photos are added to rotation dynamically.
  - Deleted or rejected photos are immediately evicted from memory and display.
  - No manual page refresh required.

---

## 3. How to Run the Application

### 3.1 Run in Chrome (Web Browser)
```bash
cd frontend
flutter run -d chrome
```

### 3.2 Launch Directly into TV Slideshow
Open in browser:
```
http://localhost:PORT/#/display
```
Press `F` or click the fullscreen icon in the top right to enter immersive TV presentation mode.

---

## 4. Automated Tests

```bash
cd frontend
flutter analyze
flutter test
```
All widget, state notifier, and serialization tests pass cleanly with 0 analysis issues.
