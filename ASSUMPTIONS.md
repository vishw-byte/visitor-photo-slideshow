# Architectural Assumptions, Design Decisions & System Constraints

**Project:** Live Event Photo Slideshow Platform  
**Location:** `C:\photo slider\`  
**Document Version:** 1.0.0  
**Scope:** Formal record of verified application behaviors, architectural assumptions, engineering rationales, and runtime constraints.

---

## 1. Project Scope & Operational Context

### 1.1 Single-Event Architecture
* **Assumption / Decision:** The application operates as a single-tenant, dedicated event platform per deployment instance. All approved photos contribute to a single, unified ambient Smart TV rotation queue.
* **Reason:** Live events (weddings, conferences, celebrations, banquets) operate under self-contained schedules, venues, and Wi-Fi networks where complex multi-tenant routing adds unnecessary operational overhead.
* **Impact on the Application:** The system does not segregate photos by sub-events, albums, or multiple simultaneous parties out of the box. One instance serves one event screen and one attendee audience.

### 1.2 Dedicated User Personas
* **Assumption / Decision:** The platform strictly isolates three user personas: Event Guests (mobile web uploaders), Event Moderators (desktop administrative reviewers), and Ambient Smart TVs (passive display clients).
* **Reason:** Separation of concerns ensures that guest onboarding remains friction-free, moderation remains gated and audited, and large-screen displays run autonomously without operator intervention.
* **Impact on the Application:** Separate authentication schemas, separate API endpoints, and dedicated Flutter UI viewports for each persona.

---

## 2. Visitor Identity & Session Management

### 2.1 Cryptographic Token Authentication
* **Assumption / Decision:** Guests are identified via a high-entropy 256-bit cryptographic session token (`secrets.token_urlsafe(32)`) issued upon registration and transmitted via the `X-Visitor-Token` HTTP header.
* **Reason:** Eliminates the friction of passwords, account creation, or social OAuth at live events, allowing guests to begin uploading within 10 seconds of scanning the display QR code.
* **Impact on the Application:** Authentication is stateless and passwordless for visitors. If the token is lost, the visitor cannot authenticate as that specific user unless restored.

### 2.2 Device-Level Session Persistence
* **Assumption / Decision:** Visitor tokens and profile metadata are persisted in the guest's mobile browser storage using `FlutterSecureStorage` with a fallback to `SharedPreferences` on Flutter Web.
* **Reason:** Allows an attendee to close their mobile browser, socialize, take more photos, and reopen the portal later without needing to re-register.
* **Impact on the Application:** When the visitor reopens the application on the same browser instance, `WelcomeScreen` greets them with *"Welcome back, {name}!"* and allows them to continue uploading or manage their previous photos immediately.

### 2.3 Non-Unique Display Names & Optional Emails
* **Assumption / Decision:** Visitor registration requires a display name (minimum 2 characters) and accepts an optional email address. Neither field is enforced as unique in the database.
* **Reason:** Multiple guests at a large wedding or conference may share the same name (e.g., two guests named "Chris"). Forcing unique usernames or mandatory emails creates unnecessary registration roadblocks.
* **Impact on the Application:** Duplicate names are permitted in `visitors`. The application differentiates guests purely by their internal UUID `id` and session token.

### 2.4 Lack of Cross-Device Session Recovery
* **Assumption / Decision:** Cross-device session recovery and browser-agnostic account retrieval are **not supported** in the current release.
* **Reason:** Full cross-device identity recovery requires verified credentials (e.g., email OTP, SMS verification, or magic links), which requires external email/SMS gateway infrastructure not bundled with the zero-config offline event setup.
* **Impact on the Application:** If an attendee opens the visitor portal on a second device (e.g., iPad vs. iPhone), uses incognito/private mode, or clears their mobile browser cache, re-registering with the same name and email creates a **new, separate `DBVisitor` record**. Photos uploaded from the second device belong to the new record and are not grouped in "My Photos" with the first device's uploads.

---

## 3. Photo Upload & Ingestion Constraints

### 3.1 Strict File Format Whitelist & Magic-Byte Inspection
* **Assumption / Decision:** The platform strictly accepts only three raster image formats: JPEG (`image/jpeg`, `image/jpg`), PNG (`image/png`), and WebP (`image/webp`). File headers are verified against raw byte signatures (`\xFF\xD8\xFF` for JPEG, `\x89PNG\r\n\x1a\n` for PNG, and `RIFF....WEBP` for WebP).
* **Reason:** File extension checking and MIME headers sent by client browsers are easily spoofed. Inspecting raw magic bytes prevents disguised executables, malware, SVG scripts, or corrupt files from entering server storage.
* **Impact on the Application:** Non-image payloads, PDFs, HEIC formats (unless converted by the mobile browser), and renamed executables are rejected at the API boundary with `HTTP 400 Bad Request`.

### 3.2 File Size & Batch Boundaries
* **Assumption / Decision:** Upload limits are hard-capped at **15 MB per image** (`MAX_FILE_SIZE_MB = 15`) and a maximum of **10 images per batch upload request** (`MAX_UPLOAD_BATCH_SIZE = 10`).
* **Reason:** Prevents Denial-of-Service (DoS) memory exhaustion and socket timeouts when hundreds of attendees upload photos simultaneously over shared venue Wi-Fi networks.
* **Impact on the Application:** The mobile client enforces batch selection limits in the UI, and the FastAPI application layer validates file size and payload counts before writing to disk. Exceeding limits results in an immediate `HTTP 400 Bad Request`.

### 3.3 EXIF Data Stripping & Privacy
* **Assumption / Decision:** All uploaded photos have their EXIF metadata (GPS location coordinates, camera serial numbers, lens parameters, timestamps) completely stripped during backend Pillow processing.
* **Reason:** Attendees should not have their precise geographical coordinates, home locations, or device metadata exposed publicly on event screens or inspectable in media downloads.
* **Impact on the Application:** Only the raw visual image bytes and generated dimensions (`width`, `height`) are stored. Original orientation is normalized, and privacy-sensitive EXIF tags are discarded.

---

## 4. Privacy, Explicit Consent & Self-Service Eviction

### 4.1 Mandatory Explicit Consent Gatekeeper
* **Assumption / Decision:** Public display of attendee photos requires **explicit, opt-in consent**. The consent agreement checkbox on the upload screen is unchecked by default.
* **Reason:** Legal privacy compliance (GDPR, CCPA) and ethical event management mandate that guests must consciously agree to have their personal images projected on public screens before submission.
* **Impact on the Application:** If `consent_given` is false or omitted in `POST /api/v1/photos/upload`, the API rejects the entire batch with `HTTP 400 Bad Request`. The database immutably records `consent_given = True`, `consent_given_at = UTC_TIMESTAMP`, and `consent_policy_version = "v1.0"` for every accepted photo.

### 4.2 Instant Self-Service Deletion & Real-Time Eviction
* **Assumption / Decision:** Attendees maintain sovereign control over their media and can delete any of their uploaded photos at any time via `DELETE /api/v1/photos/{id}`.
* **Reason:** Guests who accidentally upload a private, blurry, or unintended photo must have the immediate ability to retract it without tracking down the event organizer.
* **Impact on the Application:** Deleting a photo performs two atomic actions: (1) physical files (full image and thumbnail) are purged from disk storage immediately, and (2) the database record is flagged `is_deleted = True` with a timestamp. Any subsequent display request immediately returns `HTTP 404 Not Found`, and the next Smart TV polling cycle removes the photo from playback without restarting the screen.

---

## 5. Photo Moderation & Admin Control

### 5.1 Automatic Approval on Validated Upload with Host Post-Moderation (Approach A)
* **Assumption / Decision:** Every uploaded photo that passes server-side security checks (magic-byte validation, Pillow rasterization, 15 MB per-file size boundary, batch count limit) and explicit visitor public-display consent is automatically assigned `PhotoStatus.APPROVED` upon upload. It immediately becomes eligible for public Smart TV slideshow rotation without requiring upfront manual admin intervention.
* **Reason:** The assignment specification requires that as soon as a visitor successfully uploads a photo, it appears on the Smart TV slideshow for the configured duration.
* **Impact on the Application:** 
  - `UploadPhotoUseCase` explicitly saves successfully validated photos with `PhotoStatus.APPROVED`.
  - The repository interface preserves `PhotoStatus.PENDING` as its default for other photo creation paths.
  - Newly uploaded photos appear on the event screen on the very next Smart TV polling cycle (0–15 seconds).
  - Unreviewed auto-approved photos preserve audit integrity: `reviewed_by` and `reviewed_at` remain `None`/`null` (no fake reviewer ID is invented).

### 5.2 Host Post-Moderation & Real-Time Eviction
* **Assumption / Decision:** Event administrators maintain complete post-moderation authority to review the live approved feed and immediately reject any inappropriate, blurry, or duplicate photo using `PATCH /api/v1/admin/photos/{id}/reject`.
* **Reason:** Live events require rapid remediation if an offensive or unintended image is uploaded by an attendee.
* **Impact on the Application:** Rejecting an already-approved photo immediately transitions its status to `REJECTED`, sets `reviewed_by` to the authenticated admin's ID, logs the mandatory `rejection_reason`, and triggers real-time eviction: the photo is excluded from the next TV feed poll and any direct streaming requests to `/api/v1/media/slideshow/{id}` return `HTTP 404 Not Found`.

### 5.3 Mandatory Rejection Reasons & Audit Trail
* **Assumption / Decision:** Rejecting a photo requires the administrator to select or provide a documented rejection reason (`rejection_reason`).
* **Reason:** Provides an audit log of moderation decisions and allows visitors viewing their personal upload history (`/my-photos`) to understand why a specific photo was not approved.
* **Impact on the Application:** Rejection requests missing a reason are rejected with `HTTP 400 Bad Request`. Rejected photos remain archived with `status = "REJECTED"` and are strictly excluded from TV feeds.

### 5.4 Administrative Authentication Isolation
* **Assumption / Decision:** Admin users authenticate exclusively via `POST /api/v1/admin/login` using salted bcrypt password hashes and short-lived HMAC-SHA256 signed JWT bearer tokens (`Authorization: Bearer <jwt>`).
* **Reason:** Ensures administrative controls (approval, rejection, display timing reconfiguration) cannot be accessed or spoofed using visitor session tokens.
* **Impact on the Application:** The API enforces dependency guards (`get_current_admin`). Visitor tokens sent to admin routes return `HTTP 401 Unauthorized`.

---

## 6. Smart TV Ambient Slideshow Playback

### 6.1 Four-Point Display Eligibility Rule
* **Assumption / Decision:** A photo is eligible to appear in the Smart TV display feed (`GET /api/v1/display/photos`) if and only if it satisfies four simultaneous criteria:
  1. `status == "APPROVED"` (Automatically approved upon validated upload, or moderator approved)
  2. `consent_given == True` (Explicit visitor consent granted)
  3. `is_deleted == False` (Active, not retracted)
  4. Physical file exists on the server filesystem (`file_path.exists() == True`)
* **Reason:** Guarantees that unreviewed photos, unconsented photos, deleted photos, and orphaned database records whose files were removed cannot trigger broken image placeholders on large venue screens.
* **Impact on the Application:** If any condition is violated, the backend query filters out the photo cleanly.

### 6.2 Polling Synchronization Architecture
* **Assumption / Decision:** Real-time updates between the backend and Smart TV display rely on **periodic HTTP REST polling** (`DisplayNotifier._setupPollingTimer`) rather than full-duplex WebSockets or Server-Sent Events (SSE).
* **Reason:** Smart TVs, set-top boxes, and venue browser sticks frequently drop persistent WebSocket connections due to aggressive power-saving, sleeping tabs, or flaky Wi-Fi routers. Stateless polling auto-recovers gracefully without connection handshake negotiation.
* **Impact on the Application:** New photo approvals, deletions, and admin settings changes propagate to the TV display within the configured polling window (default: 15 seconds; configurable between 5 and 300 seconds).

### 6.3 In-Memory Display Cache & Transient Resilience
* **Assumption / Decision:** The Smart TV web client maintains approved photos in an in-memory rotation list (`state.photos`).
* **Reason:** If venue Wi-Fi drops momentarily or experiences packet loss, the slideshow continues animating through its cached photo loop rather than displaying a blank error screen.
* **Impact on the Application:** Transient network failures trigger a subtle reconnection message (`"Network interrupted. Retrying..."`) while active playback continues uninterrupted. However, performing a hard page reload (`Ctrl+F5`) when the network is completely down requires connectivity to fetch the initial manifest.

### 6.4 Slide Timing & Playback Controls
* **Assumption / Decision:** Slide duration is dynamically controlled by `slide_duration_seconds` (clamped between 3 and 120 seconds in `DisplayNotifier`, default 10 seconds). Admins can also toggle autoplay, shuffle playback, show/hide visitor name overlays, and enable a global display pause.
* **Reason:** Event hosts need flexibility: fast rotations for high-volume parties, longer durations for intimate dinners, and instant pause for speeches or announcements.
* **Impact on the Application:** When the TV display polls updated settings, the rotation timer resets on the fly without page reloads. If `slideshow_enabled` is set to `False`, the TV transitions to a standby screen.

---

## 7. Returning Visitors & Cross-Visit Retrieval

### 7.1 Same-Device Photo History Retrieval
* **Assumption / Decision:** When a guest returns using the **same browser and device** where their session was created, `GET /api/v1/photos/my-photos` retrieves their complete historical uploads.
* **Reason:** The stored `session_token` maps directly to their existing `DBVisitor.id`, querying all active non-deleted photos associated with that record.
* **Impact on the Application:** Returning attendees can track approval progress and delete earlier photos from their history screen throughout the multi-hour event.

### 7.2 Slideshow Retention of Previous Approved Photos
* **Assumption / Decision:** Approved photos from earlier visits remain in the database and continue rotating on the Smart TV screen alongside newly uploaded photos.
* **Reason:** The TV slideshow query fetches all approved, consented event photos globally. A visitor returning to submit additional photos does not invalidate or reset their previous contributions.
* **Impact on the Application:** If Alice uploaded approved photos at 2:00 PM, and returns at 5:00 PM to upload more photos, both her 2:00 PM and 5:00 PM approved photos rotate together on the big screen.

### 7.3 Limitations on Cross-Device / Cleared-Storage Recovery
* **Assumption / Decision:** If a returning visitor switches devices or clears browser data, **they cannot recover their previous session**.
* **Reason:** Without an authenticated credential recovery flow (e.g., email OTP, SMS verification, or account login), the server cannot securely verify that the person typing an email is the true owner of the previous uploads. Returning tokens automatically without verification would allow unauthorized access and deletion of other guests' photos.
* **Impact on the Application:** A returning visitor on a new device is treated as a new attendee. Their previous photos continue playing on the TV display, but are orphaned from their new device's "My Photos" screen.

---

## 8. Data Storage & Multi-Environment Compatibility

### 8.1 SQLite for Zero-Config Local Development
* **Assumption / Decision:** Local development uses file-based SQLite (`sqlite:///./slideshow.db`) as the default database engine out of the box.
* **Reason:** Enables immediate onboarding, offline testing, and rapid verification without requiring developers or event hosts to install and configure standalone database servers.
* **Impact on the Application:** SQLite WAL and journal files are ignored in Git. SQLite-specific quirks (e.g., lack of native foreign key cascade deletion by default) are handled via SQLAlchemy event listeners and application-level cascades.

### 8.2 PostgreSQL Compatibility for Production Deployments
* **Assumption / Decision:** Production deployments run PostgreSQL 16 Alpine via Docker Compose using standardized SQLAlchemy 2.0 ORM models and Alembic migrations.
* **Reason:** Multi-worker ASGI concurrency (Uvicorn workers), connection pooling, and row-level locking require a robust client-server relational database under heavy live event loads.
* **Impact on the Application:** Schema definitions avoid SQLite-specific dialect features. Alembic migration scripts execute identically on both SQLite and PostgreSQL.

### 8.3 Local Filesystem vs. Persistent Volume Storage
* **Assumption / Decision:** Uploaded media is organized into two directory trees: `uploads/` (original full-resolution files with UUID filenames) and `uploads/thumbnails/` (generated lightweight previews).
* **Reason:** Direct filesystem storage provides sub-millisecond retrieval latency for local servers and eliminates cloud storage costs (e.g., AWS S3) for offline venue setups.
* **Impact on the Application:** In Docker, `media_uploads` is mounted as a named persistent volume. If the container restarts, all uploaded media remains intact.

---

## 9. Security Assumptions & Threat Modeling

| Domain | Assumption / Decision | Threat Mitigated |
| :--- | :--- | :--- |
| **API Gatekeeper** | Direct static media directory mounting is strictly disabled. Media is served only via gated endpoints (`/api/v1/media/*`). | Prevents unauthenticated directory traversal and prevents unauthorized access to pending or rejected photos. |
| **Public URL Validation** | In production (`ENVIRONMENT="production"`), `PUBLIC_PORTAL_URL` must be a valid HTTPS URL and cannot be `localhost`, `127.0.0.1`, or `0.0.0.0`. | Prevents generating un-scannable local loopback QR codes on public venue screens. |
| **CORS Origins** | Wildcard `CORS_ORIGINS="*"` is accepted in local development, but strictly rejected at application startup in production. | Mitigates cross-origin request forgery and unauthorized third-party site embedding. |
| **JWT Cryptography** | Admin JWT access tokens are signed using HMAC-SHA256 (`HS256`) with a cryptographically enforced minimum 32-character secret key. | Prevents token tampering and signature forgery (tokens are signed for integrity, not encrypted). |
| **Password Hashing** | Admin passwords are salted and hashed using `bcrypt` (cost factor 12) via Passlib. | Protects administrative credentials against offline rainbow table attacks if the database file is accessed. |

---

## 10. Known Limitations

1. **Server-Side Image Processing**: Image resizing and thumbnailing execute synchronously on the backend using Pillow. Uploading high-megapixel mobile photos transmits the full payload over the network before compression.
2. **Hard Refresh TV Manifest Dependency**: The TV slideshow maintains its active playlist in client memory. If an operator triggers a hard browser refresh (`Ctrl+F5`) during a complete Wi-Fi outage, the client cannot fetch the initial JSON manifest until the network recovers.
3. **Polling Latency**: Photo approvals and deletions propagate to the TV screen on the next polling interval (default: 15 seconds) rather than with sub-second WebSocket immediacy.
4. **No Identity Federation**: There is no integration with Google/Apple Sign-In or corporate Single Sign-On (SSO) for attendees.

---

## 11. Future Architectural Roadmap

1. **Client-Side Image Downscaling**: Implement browser HTML5 Canvas / Flutter client-side downsampling prior to upload to conserve event cellular bandwidth.
2. **Email OTP Session Recovery**: Implement a secure One-Time Password (OTP) verification service enabling returning attendees to claim and manage their photo history across devices without passwords.
3. **WebSocket / Server-Sent Events (SSE)**: Implement real-time publish-subscribe channels for instantaneous TV playback upon moderator approval.
4. **PWA Offline Service Worker**: Add IndexedDB and ServiceWorker caching to enable the Smart TV display to reboot and resume playback even during complete venue ISP failures.
5. **Interactive Audience Reactions**: Allow event attendees to send floating emoji reactions (hearts, applause, congratulations) over the ambient TV display.
