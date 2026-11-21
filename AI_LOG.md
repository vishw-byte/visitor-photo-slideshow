# AI Interaction Log & Engineering Decision Record

**Project:** Live Event Photo Slideshow Platform  
**Location:** `C:\photo slider\`  
**Document Purpose:** Formal record of AI-assisted software engineering, architectural interactions, human reviews, genuine AI mistakes, and verified technical corrections for the MCA software engineering assignment.

---

## 1. AI-Assisted Development Phases Overview

The **Live Event Photo Slideshow Platform** was engineered collaboratively between a Human Software Architect / Developer and an AI Programming Assistant across six major phases:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               DEVELOPMENT PHASES TIMELINE                              │
├──────────────────────────┬─────────────────────────────────────────────────────────────┤
│ Phase 1: Backend Base    │ Clean Architecture, FastAPI, SQLAlchemy ORM, SQLite/Postgres │
│ Phase 2: Visitor Portal  │ Mobile Flutter Web, Batch Uploads, Explicit Consent Gate   │
│ Phase 3: Admin Console   │ JWT Authentication, Review Queue, Approval/Rejection Audits │
│ Phase 4: Smart TV Player │ Ambient Landscape UI, Auto-Rotation, Dynamic QR Pairing     │
│ Phase 5: Hardening & QA  │ E2E Verification, Magic-Byte Inspection, Network Wi-Fi Fix  │
│ Phase 6: Release & Audit │ Security Sanitization, Git Init, GitHub Push, Documentation │
└──────────────────────────┴─────────────────────────────────────────────────────────────┘
```

---

## 2. Documented AI Interactions

### Interaction 1: Backend Foundation & Clean Architecture Design (Phase 1)
* **Objective:** Establish a maintainable, decoupled backend using Clean Architecture and SQLAlchemy 2.0 with support for SQLite (local development) and PostgreSQL 16 (production).
* **Prompt / Instruction Summary:** Design pure domain entities, repository interfaces, and use cases separating business logic from FastAPI HTTP controllers. Implement database models for visitors, photos, admin users, and slideshow settings.
* **AI's Proposed Implementation:** 
  - Domain layer: `VisitorEntity`, `PhotoEntity`, `AdminUserEntity`, `SlideshowSettingsEntity`.
  - Repository interfaces in `app/domain/interfaces/repositories.py`.
  - SQLAlchemy implementations in `app/infrastructure/repositories/sqlalchemy_repositories.py`.
  - Lifespan initialization script in `main.py` seeding default admin and display settings.
* **How Evaluated:** Automated tests in `backend/tests/test_database.py` and `test_models.py` verifying connection pooling, entity validation, and constraint enforcement.
* **Final Outcome:** **PASS**. Robust multi-tier structure allowing zero-config SQLite local execution and PostgreSQL container compatibility.

---

### Interaction 2: Visitor Portal & Explicit Consent Gatekeeper (Phase 2)
* **Objective:** Build a mobile-first web client allowing guests to select up to 10 photos, preview thumbnails, provide explicit public-display consent, and track upload status.
* **Prompt / Instruction Summary:** Create a Flutter Web client using Riverpod state management and GoRouter. Enforce that public display consent is unchecked by default and mandatory at the API layer.
* **AI's Proposed Implementation:**
  - `UploadScreen` with multi-image picker (`image_picker`), thumbnail chips, and consent checkbox.
  - `POST /api/v1/photos/upload` endpoint enforcing `consent_given == True`.
  - Magic-byte signature verification rejecting non-image payloads before Pillow processing.
* **How Evaluated:** 
  - Backend unit test `test_phase2_visitor_portal.py` asserting HTTP 400 when `consent_given=False`.
  - Flutter widget tests verifying form validation and disabled upload buttons when consent is unchecked.
* **Final Outcome:** **PASS**. Consent timestamps (`consent_given_at`) and policy versions (`v1.0`) recorded immutably in the database.

---

### Interaction 3: Admin Moderation Console & Rejection Handling (Phase 3)
* **Objective:** Implement an authenticated administrative dashboard for event moderators to review pending photos, view event statistics, approve/reject submissions, and adjust TV settings.
* **Prompt / Instruction Summary:** Create admin authentication via bcrypt password hashing and HS256 JWT tokens. Implement `/admin/moderation` with tabbed status views (`Pending`, `Approved`, `Rejected`) and audited rejection reasons.
* **AI's Proposed Implementation:**
  - FastAPI routers in `app/presentation/api/v1/admin.py`.
  - Flutter `PhotoModerationScreen` with quick-action cards and rejection dialogue.
* **How Evaluated:** Tested via `test_phase3_admin_moderation.py` asserting that visitor tokens are rejected on admin routes and that approving a photo requires explicit consent.
* **Final Outcome:** **PARTIAL $\rightarrow$ FIXED**. Discovered a payload naming mismatch between Flutter and FastAPI during rejection (see Mistake 1 below). Corrected and verified.

---

### Interaction 4: Ambient Smart TV Slideshow Player (Phase 4)
* **Objective:** Build a dedicated, full-screen continuous slideshow screen for large Smart TVs, projectors, and venue monitors.
* **Prompt / Instruction Summary:** Create `/display` route in Flutter Web. Automatically rotate approved photos, poll backend for updates, handle empty states with a QR code, and support remote keyboard navigation (`F` for fullscreen, arrow keys).
* **AI's Proposed Implementation:**
  - `SmartTvDisplayScreen` and `DisplayNotifier` state provider.
  - Background polling timer querying `/api/v1/display/photos` every 15 seconds.
  - In-memory photo cache preventing blank screens during transient Wi-Fi drops.
  - `GET /api/v1/display/qr-code` endpoint generating dynamic PNG QR codes pointing to `PUBLIC_PORTAL_URL`.
* **How Evaluated:** Tested via `test_phase4_smart_tv_display.py` and Chrome browser execution at 1920×1080 resolution.
* **Final Outcome:** **PASS**. TV display autonomously loops approved photos and gracefully transitions to empty/standby states when the queue is clear.

---

### Interaction 5: Local Multi-Device Wi-Fi Testing & QR Code Resolution (Phase 5)
* **Objective:** Enable physical smartphones on the event Wi-Fi network to scan the Smart TV QR code and submit photos directly to the laptop server.
* **Prompt / Instruction Summary:** Configure the local testing environment with LAN IP `192.168.1.23` so the Smart TV QR code redirects to the actual phone-accessible URL rather than localhost.
* **AI's Proposed Implementation:**
  - Set `PUBLIC_PORTAL_URL="http://192.168.1.23:3000/"` in `backend/.env`.
  - Configured Uvicorn ASGI server to bind to `0.0.0.0:8000`.
  - Provided `serve_web.py` to serve the compiled Flutter SPA on `0.0.0.0:3000`.
* **How Evaluated:** Physical smartphone connected to the same Wi-Fi scanned the on-screen QR code, submitted photos, and verified live display on the host laptop.
* **Final Outcome:** **PARTIAL $\rightarrow$ FIXED**. AI initially hardcoded the developer's private LAN IP in documentation and templates, requiring subsequent sanitization (see Mistake 2 below).

---

### Interaction 6: Pre-Release Security Audit & Secret Sanitization (Phase 6)
* **Objective:** Perform a comprehensive security audit of the entire codebase prior to initializing Git and publishing to GitHub.
* **Prompt / Instruction Summary:** Inspect all source files, configuration templates, and documentation. Identify hardcoded secrets, database files, and private IP leaks.
* **AI's Proposed Implementation:**
  - Scanned codebase for `192.168.1.23`, passwords, and API keys.
  - Replaced hardcoded developer LAN IP in `README.md` and `backend/.env.example` with `<YOUR_LAN_IP>`.
  - Updated root `.gitignore` and `backend/.gitignore` to ignore SQLite WAL/SHM files (`*.db*`, `*.sqlite*`).
  - Un-ignored `serve_web.py` to ensure the multi-device server script was tracked in the repository.
* **How Evaluated:** Executed automated checks (`Select-String -Pattern "192\.168\."`) across all files and verified `git status --ignored`.
* **Final Outcome:** **PASS**. Zero secrets or local IPs present in staged files.

---

### Interaction 7: Git Initialization, First Commit & GitHub Release (Phase 6.1)
* **Objective:** Initialize Git locally, audit staged files against safety gates, create the initial commit, link the remote repository, and push to GitHub.
* **Prompt / Instruction Summary:** Execute local Git initialization, stage all project files, verify that no `.env` or `.db` files are included, create root commit, connect `https://github.com/vishw-byte/visitor-photo-slideshow.git`, and push `main`.
* **AI's Proposed Implementation:**
  - `git init` and `git branch -M main`.
  - `git add -A` (225 files staged).
  - Safety check: verified 0 database files, 0 `.env` files, 0 uploaded media files.
  - `git commit -m "feat: initial release of visitor photo slideshow platform"` (`f0e343e`).
  - `git remote add origin https://github.com/vishw-byte/visitor-photo-slideshow.git`.
  - `git push -u origin main`.
* **How Evaluated:** `git status` confirmed clean working tree and branch tracking `origin/main`.
* **Final Outcome:** **PASS**. Initial release successfully published to GitHub.

---

### Interaction 8: Root Documentation Upgrade & Read-Only QA Validation (Phase 6.2)
* **Objective:** Upgrade the root `README.md` into an open-source documentation standard, complete with Mermaid workflows, architecture diagrams, and REST API tables.
* **Prompt / Instruction Summary:** Expand incomplete workflow sections, add an architectural diagram, correct inaccurate JWT explanations, update `create_admin.py` commands, and provide Windows PowerShell commands.
* **AI's Proposed Implementation:**
  - Authored comprehensive 24-section `README.md` with official technology badges.
  - Generated 4 complete Mermaid flowcharts (Visitor, Admin, TV, Architecture).
  - Expanded API table to 20 endpoints.
  - Documented masked interactive admin creation via `getpass`.
* **How Evaluated:** Performed strict read-only QA review verifying all 20 API routes against FastAPI OpenAPI schema and validating Mermaid diagram syntax.
* **Final Outcome:** **PASS**. High-quality, production-grade documentation delivered.

---

### Interaction 9: Returning Visitor Audit & Duplicate Analysis (Phase 7)
* **Objective:** Audit the existing codebase to verify whether the system satisfies the assignment requirement: *"If the person is visiting again, the slideshow also plays their previous photos."*
* **Prompt / Instruction Summary:** Inspect database models, session tokens, and display queries. Determine whether returning visitors are recognized across devices or sessions.
* **AI's Proposed Implementation:**
  - Audited `DBVisitor` model, `RegisterVisitorUseCase`, and `SessionStorage`.
  - Queried local `slideshow.db` directly to check actual stored data.
* **How Evaluated:** Discovered that email `dangivishw82@gmail.com` had 3 duplicate rows with photos split across visitor UUIDs `578a...` and `8e23...`.
* **Final Outcome:** **PASS (Audit Complete)**. Documented that while the Smart TV plays previous photos globally, true cross-device returning visitor recognition was missing. Designed an email-OTP recovery architecture.

---

### Interaction 10: Automatic Photo Approval on Validated Upload with Host Post-Moderation (Approach A)
* **Objective:** Fulfill the MCA assignment requirement where newly uploaded visitor photos immediately appear in the Smart TV slideshow rotation without waiting for upfront manual admin approval, while maintaining server-side security checks, explicit visitor consent, and admin post-moderation capability.
* **Prompt / Instruction Summary:** Implement Approach A:
  1. `UploadPhotoUseCase` explicitly sets `PhotoStatus.APPROVED` on successfully stored visitor photos.
  2. The repository `create()` interface preserves `PhotoStatus.PENDING` as its default for other photo ingestion paths.
  3. `reviewed_by` and `reviewed_at` remain `None`/`null` for unreviewed auto-approvals (no fake admin ID invented).
  4. Preserve all existing magic-byte validations, Pillow rasterization, 15 MB file limit, and 10-photo batch bounds.
  5. Preserve admin post-moderation: admins can reject any already-approved photo, evicting it immediately from display and media endpoints.
  6. Update Flutter upload feedback messages to remove "Awaiting host review" and indicate the photo will appear on the event screen shortly.
  7. Update backend and frontend test suites and project documentation.
* **AI's Proposed Implementation:**
  - Updated `IPhotoRepository.create` and `SqlAlchemyPhotoRepository.create` with default `status: PhotoStatus = PhotoStatus.PENDING`.
  - Updated `UploadPhotoUseCase.execute` to pass `status=PhotoStatus.APPROVED` to `photo_repo.create(...)`.
  - Updated Flutter `photo_provider.dart` and `upload_screen.dart` with real-time feedback: `"Photo uploaded successfully! It will appear on the event screen shortly."`
  - Updated backend tests in `test_phase2_visitor_portal.py`, `test_phase3_admin_moderation.py`, `test_phase4_smart_tv_display.py`, and `test_phase5_e2e_integration.py`.
* **How Evaluated:** 
  - Ran backend pytest suite: **49 passed, 0 failed**.
  - Ran frontend flutter tests: **25 passed, 0 failed**.
  - Ran `flutter analyze`: **0 issues found**.
* **Final Outcome:** **PASS**. Approach A cleanly implemented and fully verified across backend, frontend, and tests.

---

## 3. Genuine AI Mistakes & Corrective Actions

### Mistake 1: Flutter Admin Rejection Payload Field Mismatch
* **What AI Implemented Incorrectly:** In the Flutter admin repository (`admin_repository.dart`), the AI implemented the photo rejection method by sending a JSON payload formatted as:
  ```json
  {"reason": "Inappropriate content"}
  ```
* **How the Issue Was Discovered:** During Phase 5.1 QA testing and manual moderation verification, attempting to reject a photo returned `HTTP 422 Unprocessable Entity` from FastAPI.
* **Why It Was Incorrect:** The backend Pydantic schema `RejectPhotoRequest` (in `backend/app/application/dtos/schemas.py`) strictly defined the expected field name as `rejection_reason`, not `reason`:
  ```python
  class RejectPhotoRequest(BaseModel):
      rejection_reason: str = Field(..., min_length=3, max_length=255)
  ```
  FastAPI rejected the request due to missing the required `rejection_reason` key.
* **How It Was Corrected:** The human developer identified the 422 validation error in FastAPI server logs. The AI was directed to inspect `schemas.py` and update `admin_repository.dart`:
  ```dart
  // Corrected implementation:
  final response = await _dio.patch(
    '/admin/photos/$photoId/reject',
    data: {'rejection_reason': reason},
  );
  ```
* **How Verified:** Re-ran backend unit test `test_phase3_admin_moderation.py` (`test_reject_photo_with_reason`) and performed manual rejection in the Flutter UI, confirming the photo transitioned to `REJECTED` with the reason logged.

---

### Mistake 2: Leaking Developer Private LAN IP in Documentation & Example Configs
* **What AI Implemented Incorrectly:** When solving the local Wi-Fi QR code issue in Phase 5, the AI hardcoded the developer's actual laptop Wi-Fi IPv4 address (`192.168.1.23`) into `backend/.env.example` and multiple command examples in `README.md`.
* **How the Issue Was Discovered:** During the pre-release security audit checklist (Task 1 of Phase 6), a regex scan for private IP ranges detected `192.168.1.23` in version-controlled documentation files.
* **Why It Was Incorrect:** Committing developer-specific local network IPs to a public GitHub repository violates security hygiene, leaks internal network topology, and causes failures for external users whose home/venue subnets differ (e.g. `10.0.0.x` or `192.168.0.x`).
* **How It Was Corrected:** 
  1. Replaced all occurrences of `192.168.1.23` in `backend/.env.example` and `README.md` with the generic template placeholder `<YOUR_LAN_IP>`.
  2. Added documentation explaining how developers find their own adapter IPv4 address via `ipconfig` (Windows) or `ip a` (Linux).
* **How Verified:** Ran automated PowerShell check `Select-String -Path "README.md", "backend/.env.example" -Pattern "192\.168\."` confirming 0 occurrences prior to Git staging.

---

### Mistake 3: Inaccurate JWT Security Claims (Confusing Signing with Encryption)
* **What AI Implemented Incorrectly:** In the Phase 5/6 security documentation, the AI wrote:
  ```markdown
  - **Admin JWT**: Encrypted with HS256, expiration enforced, password salted via bcrypt.
  ```
* **How the Issue Was Discovered:** Identified during the Step 5 technical documentation review.
* **Why It Was Incorrect:** HS256 (`HMAC-SHA256`) is a symmetric **digital signature** algorithm, NOT an encryption algorithm. JWT claims are Base64URL-encoded (publicly readable) and cryptographically signed to guarantee integrity and authenticity; they are not encrypted (which would require JWE / AES-GCM). Claiming HS256 encrypts data is a fundamental cryptographic inaccuracy.
* **How It Was Corrected:** Updated `README.md` and `ARCHITECTURE.md` to state:
  ```markdown
  - **Admin JWT Authentication**: Admin tokens are cryptographically signed using HMAC-SHA256 (`HS256`) with strict expiration enforcement; passwords hashed with salted bcrypt (cost factor 12).
  ```
* **How Verified:** Reviewed `backend/app/core/security.py` line 26 (`jwt.encode(...)`), confirming standard signed JWS token generation.

---

### Mistake 4: Documenting Insecure Plaintext `--password` CLI Flag for Admin Creation
* **What AI Implemented Incorrectly:** In early documentation, the AI provided the following setup command:
  ```bash
  python scripts/create_admin.py --username admin --email admin@event.local --password "YourPassword"
  ```
* **How the Issue Was Discovered:** Identified during the security credential audit and admin password update task.
* **Why It Was Incorrect:** Passing passwords via command-line arguments exposes credentials in plaintext in shell history files (`.bash_history`, `ConsoleHost_history.txt`) and process listing tables (`ps aux`, Task Manager). Furthermore, the actual `create_admin.py` script had already been updated to support secure interactive masked input via Python's `getpass` module.
* **How It Was Corrected:** Removed the `--password` flag from all documentation examples, updating instructions to run:
  ```powershell
  python scripts/create_admin.py --username admin --email admin@event.local
  ```
  with explicit guidance that omitting the flag triggers a secure, masked password prompt with confirmation.
* **How Verified:** Executed `create_admin.py` without `--password` in Windows PowerShell, verifying the masked input prompt and successful bcrypt hash generation.

---

### Mistake 5: Absolute File URI Scheme in Markdown Documentation
* **What AI Implemented Incorrectly:** In the updated `README.md` (line 175), the AI linked to the visual specification guide using an absolute Windows file URI:
  ```markdown
  refer to [docs/SCREENSHOTS.md](file:///C:/photo%20slider/docs/SCREENSHOTS.md).
  ```
* **How the Issue Was Discovered:** Flagged during the automated QA read-only link verification audit (Check 1 of Phase 6.2).
* **Why It Was Incorrect:** While `file:///C:/photo%20slider/...` links resolve within local development environments, they completely break when viewed on GitHub.com or cloned to other developer machines.
* **How It Was Corrected:** Identified for standard relative linking `[docs/SCREENSHOTS.md](docs/SCREENSHOTS.md)`.
* **How Verified:** Verified existence of `docs/SCREENSHOTS.md` at relative path.

---

## 4. Human Review & Decision Making

The success of the platform depended on continuous human oversight, critical verification, and proactive architectural decisions:

1. **Enforcing Pure Clean Architecture:** When initial AI code drafts mixed database session access directly inside FastAPI route functions, the human architect required strict refactoring into application use cases (`app/application/use_cases/`) and abstract repository interfaces (`app/domain/interfaces/repositories.py`).
2. **Balancing Real-Time Display with Moderation Authority (Approach A):** While strict upfront manual approval was initially implemented during early development, the human architect aligned the platform with the core MCA assignment requirement ("photos appear on the Smart TV slideshow upon upload") by directing the implementation of Approach A: automatic approval for fully validated, consented uploads with robust host post-moderation and real-time eviction.
3. **Mandating Explicit Consent:** The human developer insisted that public-display consent must be unchecked by default and immutably recorded in the database, ensuring ethical compliance with attendee privacy expectations.
4. **Inspecting Live Database for Duplicates:** Rather than accepting the AI's assumption that session persistence equals returning visitor recognition, the human developer directed an inspection of `slideshow.db`. This revealed 3 duplicate records for `dangivishw82@gmail.com`, preventing a broken unique constraint migration.
5. **Enforcing Safety Gates on Git Operations:** The human developer strictly prohibited automated commits or pushes until staging was audited, ensuring zero `.env` or `.db` files reached version control.

---

## 5. Lessons Learned in AI-Assisted Engineering

1. **Verify Contract Alignment Across Full-Stack Boundaries:** DTO schemas in the backend (Pydantic) and client network repositories (Dio) must be verified against each other. Subtle naming mismatches (e.g., `reason` vs `rejection_reason`) escape static analysis until runtime integration tests catch them.
2. **Never Trust AI Assumptions About Session Persistence:** Device-level storage (`SharedPreferences`) does not constitute user identity. A client-side "Welcome back" greeting is fragile and breaks across devices or cache clears. True identity requires server-side verified credentials (such as email OTP).
3. **Sanitize Configuration Templates Early:** AI tends to copy working values from active environments into documentation. Always enforce automated regex gates to prevent real IP addresses, tokens, or local paths from entering public repositories.
4. **Cryptographic Terminology Requires Precision:** Distinguish clearly between cryptographic signing (integrity/authenticity via HMAC/RSA) and encryption (confidentiality via AES/ChaCha). Inaccurate security claims undermine system credibility.
5. **Automated Test Suites Are Essential Guardrails:** The 49 backend tests and 25 frontend tests served as immediate regression detectors whenever AI refactored use cases or updated endpoints.

---

## 6. Status of Assignment Requirements & Evidence Gaps

| Assignment Requirement | Implementation Status | Evidence / Verification |
| :--- | :---: | :--- |
| **Full-Screen Smart TV Display** | **Complete** | Verified via `SmartTvDisplayScreen` and `test_phase4_smart_tv_display.py`. |
| **Visitor Photo Upload & Consent** | **Complete** | Verified via `UploadScreen` and `test_phase2_visitor_portal.py`. |
| **Admin Moderation & Rejection Audits** | **Complete** | Verified via `PhotoModerationScreen` and `test_phase3_admin_moderation.py`. |
| **QR Code Venue Pairing** | **Complete** | Verified via `GET /api/v1/display/qr-code` and multi-device smartphone testing. |
| **TV Playback of Prior Approved Photos** | **Complete** | Verified via `SqlAlchemyPhotoRepository.get_approved_with_consent()`. |
| **Cross-Device Returning Visitor Recovery** | **Planned (Not Implemented)** | **Architecture designed in planning document; code implementation deferred per project roadmap.** |

---

*This document accurately reflects all genuine interactions, test outcomes, and technical corrections recorded during the development lifecycle.*
