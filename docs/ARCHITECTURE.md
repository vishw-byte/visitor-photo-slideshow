# System Architecture Specification

## 1. Executive Summary & System Overview

The **Visitor Photo Slideshow Application** is an event-driven platform enabling guests at weddings, conferences, and celebrations to upload photos in real-time from mobile devices, while event moderators review incoming media, and ambient Smart TVs display continuous, animated photo loops.

```mermaid
flowchart TD
    subgraph Clients["Presentation Tier"]
        MobileGuest["Mobile Guest Web / PWA\n(Visitor Photo Upload & History)\nAuth: X-Visitor-Token"]
        AdminWeb["Admin Moderation Console\n(Review, Metrics, Configuration)\nAuth: Bearer JWT"]
        SmartTV["Smart TV / Ambient Display\n(Continuous Slideshow & QR Overlay)\nPublic Gated Feed"]
    end

    subgraph Gateway["API & Security Boundary (FastAPI)"]
        CORS["CORS & Request Limiter"]
        AuthGuards["Authentication Guards\n- get_current_visitor\n- get_current_admin"]
        SigValidator["Magic Byte File Signature Validator\n(JPEG, PNG, WebP)"]
    end

    subgraph CleanArch["Application Core (Clean Architecture)"]
        UseCases["Use Cases\n- RegisterVisitor, UploadBatch, DeletePhoto\n- AdminLogin, ApprovePhoto, RejectPhoto\n- GetSlideshowFeed, UpdateSettings"]
        Entities["Domain Entities\n- Visitor, Photo, AdminUser, SlideshowSettings"]
    end

    subgraph DataTier["Infrastructure & Storage"]
        Repo["SQLAlchemy Repositories\n(SQLite local / PostgreSQL prod)"]
        DB[(Relational DB)]
        MediaDisk["Secure Local Filesystem\n(/uploads & /uploads/thumbnails)"]
    end

    MobileGuest --> CORS
    AdminWeb --> CORS
    SmartTV --> CORS
    CORS --> AuthGuards
    AuthGuards --> SigValidator
    SigValidator --> UseCases
    UseCases --> Entities
    UseCases --> Repo
    Repo --> DB
    Repo --> MediaDisk
```

---

## 2. Frontend Layered Architecture (Flutter)

The Flutter application is structured around Clean Presentation and Riverpod state management:

```
frontend/lib/
├── core/
│   ├── constants/       # API endpoints, network timeouts, route names
│   ├── network/         # Dio HTTP client with JWT & visitor token interceptors
│   ├── storage/         # flutter_secure_storage session wrappers
│   └── theme/           # Dark and light event color palettes
├── data/
│   ├── models/          # Immutable JSON serializable DTOs
│   └── repositories/    # API abstraction interfaces (Visitor, Admin, Display)
└── presentation/
    ├── providers/       # StateNotifier providers (Display, Moderation, Auth)
    ├── screens/
    │   ├── visitor/     # Welcome, Registration, Upload, My Photos
    │   ├── admin/       # Login, Dashboard, Moderation, Settings
    │   └── display/     # Smart TV Full-Screen Slideshow & QR Pairing
    └── widgets/         # Shared UI components (StatusBadge, MetricCard)
```

### Communication Flow
- **GoRouter**: Controls navigation with route protection based on active auth states.
- **Dio Client Interceptor**: Inspects endpoint URI patterns. If `/admin/` is targeted, it automatically injects `Authorization: Bearer <jwt>`. For visitor endpoints, it injects `X-Visitor-Token: <token>`.
- **DisplayNotifier**: Implements background polling to query `/api/v1/display/settings` and `/api/v1/display/photos`. Dynamically adapts slide rotation intervals, transitions, and attribution overlays without restarting.

---

## 3. Backend Layered Architecture (FastAPI Clean Architecture)

```
backend/app/
├── core/               # Configuration, security utilities, global exceptions
├── domain/             # Pure entities, value objects, and repository interfaces
├── application/        # Application use cases and Pydantic DTO schemas
├── infrastructure/     # Database models, SQLAlchemy sessions, disk storage, Pillow processor
└── presentation/       # API routers (v1), dependencies, and HTTP handlers
```

### Layer Dependency Inversion
Inner domain entities know nothing of database tables or HTTP frameworks. The presentation layer delegates directly to use cases, which interact with abstract repository interfaces fulfilled by infrastructure classes.

---

## 4. Authentication & Security Boundaries

```mermaid
sequenceDiagram
    autonumber
    actor Guest as Mobile Guest
    actor Admin as Event Moderator
    participant API as FastAPI Backend
    participant DB as Database

    Note over Guest,DB: Visitor Authentication & Photo Submission
    Guest->>API: POST /api/v1/visitors/register (name, email)
    API->>DB: Persist Visitor & generate secrets.token_urlsafe(32)
    API-->>Guest: 201 Created (X-Visitor-Token: 256-bit secure token)
    Guest->>API: POST /api/v1/photos/upload (with X-Visitor-Token + consent=True)
    API->>API: Magic byte verification (JPEG/PNG/WebP)
    API->>DB: Store Photo (status=PENDING, consent_given=True)
    API-->>Guest: 201 Created (Photo IDs & URLs)

    Note over Admin,DB: Admin Authentication & Moderation
    Admin->>API: POST /api/v1/admin/login (username, password)
    API->>DB: Verify bcrypt password hash
    API-->>Admin: 200 OK (access_token: Bearer JWT)
    Admin->>API: PATCH /api/v1/admin/photos/{id}/approve (with Bearer JWT)
    API->>DB: Verify consent record & update status=APPROVED
    API-->>Admin: 200 OK (status: APPROVED)
```

- **Separation of Concerns**: Visitor sessions cannot authenticate administrative routes. Admin JWTs cannot manipulate visitor upload histories.
- **Public Feed Gate**: `/api/v1/display/photos` and `/api/v1/media/slideshow/{id}` strictly filter photos: `status == APPROVED`, `consent_given == True`, and `is_deleted == False`.

---

## 5. Photo Lifecycle & Immediate Deletion Eviction

```mermaid
stateDiagram-v2
    [*] --> PENDING: Uploaded with Explicit Consent
    PENDING --> APPROVED: Admin Approves (Consent Verified)
    PENDING --> REJECTED: Admin Rejects (Reason Logged)
    APPROVED --> DELETED: Visitor Requests Deletion
    PENDING --> DELETED: Visitor Requests Deletion
    REJECTED --> DELETED: Visitor Requests Deletion
    DELETED --> [*]: Evicted from TV Display & Returns HTTP 404
```

When a visitor deletes a photo via `DELETE /api/v1/photos/{id}`:
1. Database flags `is_deleted = True` and stamps `deleted_at`.
2. The photo is immediately filtered out of `/api/v1/display/photos`.
3. The media streaming endpoint `/api/v1/media/slideshow/{id}` immediately serves `HTTP 404 Not Found`.

---

## 6. Smart TV Display Architecture & QR Code Flow

- **Resolution**: Adaptive landscape layout designed for 1080p and 4K displays.
- **Transitions**: Animated cross-fade, slide, and zoom transitions.
- **Controls**: Ambient display mode hides navigation controls. Fullscreen is toggled with the `F` key; slides navigate with TV remote arrow keys and spacebar.
- **QR Code Generation**: Dynamically resolved via `GET /api/v1/display/qr-code` using configured production HTTPS domain (`PUBLIC_PORTAL_URL`). Encodes only the clean visitor portal URL without tokens.

---

## 7. Database Entity Relationship Model

```mermaid
erDiagram
    VISITOR ||--o{ PHOTO : uploads
    ADMIN_USER ||--o{ PHOTO : reviews
    SLIDESHOW_SETTINGS {
        int id PK
        int slide_duration_seconds
        bool slideshow_autoplay
        bool slideshow_enabled
        string transition_effect
        bool show_visitor_name
        bool shuffle_playback
        int refresh_interval_seconds
        bool show_qr_code
        string visitor_portal_url
        datetime updated_at
    }

    VISITOR {
        string id PK
        string name
        string email
        string session_token UK
        string ip_address
        datetime created_at
        datetime last_active_at
    }

    PHOTO {
        string id PK
        string visitor_id FK
        string original_filename
        string storage_path
        string thumbnail_path
        int file_size_bytes
        string mime_type
        int width
        int height
        bool consent_given
        datetime consent_given_at
        string consent_policy_version
        string status
        string rejection_reason
        string reviewed_by FK
        datetime reviewed_at
        bool is_deleted
        datetime deleted_at
        datetime created_at
    }

    ADMIN_USER {
        string id PK
        string username UK
        string email UK
        string hashed_password
        string role
        bool is_active
        datetime created_at
    }
```
