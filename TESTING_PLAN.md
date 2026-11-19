# Testing Plan & Automated Verification Suite

This document outlines the test strategy, coverage matrix, and execution commands for the **Visitor Photo Slideshow Application**.

---

## 1. Test Strategy Overview

Every phase of the application includes automated tests verifying domain logic, presentation controllers, and security gates:

| Suite | Technology | Test Targets | Count | Status |
|---|---|---|---|---|
| **Backend Unit & API** | Pytest, TestClient, SQLite in-memory | Configuration, Database probes, Magic-byte inspection, Visitor tokens, Admin bcrypt/JWT, Upload batch limits, Consent verification, Status transitions, Deletion eviction, Display feeds, Settings propagation, Production URL validation | 46 | **PASSING** |
| **Backend E2E Lifecycle**| Pytest, TestClient | Full lifecycle from visitor registration to upload, admin review, TV display, QR code, deletion eviction, settings sync | 1 | **PASSING** |
| **Frontend Widget & Logic** | flutter_test, Riverpod mocks | Visitor registration & upload screens, Status badges, Admin login & dashboard, Photo moderation queue, Slideshow settings, Smart TV loading/empty/disabled/active states, QR code widget, Keyboard shortcut, Settings consistency | 25 | **PASSING** |
| **Static Code Analysis** | flutter analyze | Linting, types, unused imports, deprecation checks | 0 issues | **CLEAN** |

---

## 2. How to Run Backend Tests

```powershell
cd backend
.\venv\Scripts\Activate.ps1
.\venv\Scripts\pytest.exe -v
```

### Coverage by File
- `test_config.py`: Environment variable defaults, CORS origin parsing.
- `test_database.py`: SQLAlchemy engine connectivity, session lifecycle.
- `test_health.py`: Root greeting and `/api/v1/health` probes.
- `test_magic_bytes.py`: JPEG, PNG, WebP byte verification, rejection of disguised executables.
- `test_models.py`: Model creation, constraints, unique tokens, default settings.
- `test_security.py`: 256-bit visitor token entropy, bcrypt password hashing, JWT token expiration and decoding.
- `test_phase2_visitor_portal.py`: Visitor registration, duplicate name handling, multi-photo uploads, consent requirement, photo history isolation, photo deletion.
- `test_phase3_admin_moderation.py`: Admin login, JWT route guards, visitor token rejection, dashboard metrics, consent-checked approval, mandatory rejection reasons, deleted photo protection.
- `test_phase4_smart_tv_display.py`: Public display feed, settings endpoints, empty queue, approved photo isolation, instant deletion eviction, master slideshow pause toggle.
- `test_phase5_e2e_integration.py`: End-to-end multi-step integration lifecycle test.

---

## 3. How to Run Frontend Tests

```bash
cd frontend
flutter analyze
flutter test
```

### Coverage by File
- `visitor_portal_test.dart`:
  - `VisitorModel` JSON serialization.
  - `PhotoModel` status mapping.
  - `WelcomeScreen` rendering and CTA interaction.
  - `RegistrationScreen` form validation.
  - `StatusBadge` color and text rendering.
- `admin_moderation_test.dart`:
  - `AdminSessionModel`, `DashboardStatsModel`, `AdminPhotoDetailModel`, `SlideshowSettingsModel` serialization.
  - `AdminLoginScreen` credential validation and submit.
  - `AdminDashboardScreen` metric cards and quick actions.
  - `PhotoModerationScreen` tabbed views, consent chips, approve/reject triggers.
  - `SlideshowSettingsScreen` duration slider, transition selector, toggle switches, save callback.
- `smart_tv_display_test.dart`:
  - `DisplayPhotoModel`, `DisplayFeedModel`, `DisplaySettingsModel` serialization.
  - `DisplayNotifier` auto-rotation logic, loop-around, pause/play toggles.
  - `SmartTvDisplayScreen` Loading State.
  - `SmartTvDisplayScreen` Empty Queue State with scannable QR code.
  - `SmartTvDisplayScreen` Disabled State ("Event Display Paused").
  - `SmartTvDisplayScreen` Active Slideshow with Visitor Name attribution.
  - `SmartTvDisplayScreen` QR Code rendering and toggle off.
