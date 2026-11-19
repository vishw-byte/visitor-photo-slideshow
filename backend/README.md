# Visitor Photo Slideshow — Backend API (Phase 1, 2, 3 & 4)

Clean Architecture Python backend built with **FastAPI**, **SQLAlchemy**, and **Alembic**, supporting **SQLite** for zero-setup local development and **PostgreSQL** in production.

---

## 1. Architecture Overview

```
backend/
├── app/
│   ├── core/                   # Global configuration, security utils, exceptions
│   │   ├── config.py           # Pydantic Settings & environment variables
│   │   ├── security.py         # Cryptographic visitor tokens (secrets.token_urlsafe), bcrypt & JWT
│   │   └── exceptions.py       # Standardized application exception handlers
│   ├── domain/                 # Pure domain business models & contracts
│   │   ├── entities/models.py  # Pure entity models (Visitor, Photo, AdminUser, SlideshowSettings)
│   │   └── interfaces/         # Repository & service abstract interfaces
│   ├── application/            # Application use cases & DTOs
│   │   ├── dtos/schemas.py     # Request/Response schemas (consent, moderation, JWT, display DTOs)
│   │   └── use_cases/          # Business logic:
│   │       ├── visitor_use_cases.py   # RegisterVisitor, UploadBatchPhotos, DeletePhoto
│   │       ├── admin_use_cases.py     # AdminLogin, GetDashboardStats, ApprovePhoto, RejectPhoto
│   │       └── slideshow_use_cases.py # GetSlideshowFeed, GetSlideshowSettings, UpdateSlideshowSettings
│   ├── infrastructure/         # External tools & frameworks
│   │   ├── database/session.py # SQLAlchemy engine, session factory & DB health check
│   │   ├── database/models.py  # Portable database models (SQLite/PostgreSQL)
│   │   ├── storage/            # Magic byte validation (JPEG, PNG, WebP) & Pillow processor
│   │   └── repositories/       # SQLAlchemy repositories (Photo, Visitor, Admin, Settings)
│   └── presentation/           # Delivery mechanism
│       ├── api/v1/
│       │   ├── health.py       # GET /api/v1/health probe
│       │   ├── visitors.py     # POST /api/v1/visitors/register
│       │   ├── photos.py       # POST /upload, GET /my-photos, DELETE /{id}
│       │   ├── admin.py        # Admin login, dashboard stats, moderation, slideshow settings
│       │   ├── display.py      # Public Smart TV endpoints (/display/photos, /display/settings)
│       │   └── media.py        # Secure media gatekeeper (/media/photos, /media/thumbnails, /media/slideshow)
│       └── dependencies/       # Dependency injection (Auth guards: X-Visitor-Token, Bearer JWT, DB session)
├── alembic/                    # Database migration scripts
├── scripts/                    # Admin CLI bootstrap utilities (create_admin.py)
├── tests/                      # Automated test suite (Pytest - 49 tests)
├── .env.example                # Template environment variables
├── .env                        # Active local environment settings
├── alembic.ini                 # Migration configuration
├── main.py                     # FastAPI application entry point
├── pytest.ini                  # Pytest configuration
└── requirements.txt            # Python dependencies
```

---

## 2. API Endpoints

### 2.1 Public & Visitor Endpoints
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/v1/health` | Health check & database probe | None |
| `POST` | `/api/v1/visitors/register` | Register visitor (name & email) & return 256-bit token | None |
| `POST` | `/api/v1/photos/upload` | Upload multiple images with mandatory consent | `X-Visitor-Token` |
| `GET` | `/api/v1/photos/my-photos` | Get visitor's uploads with review status | `X-Visitor-Token` |
| `DELETE`| `/api/v1/photos/{id}` | Delete uploaded photo (instant slideshow eviction) | `X-Visitor-Token` |

### 2.2 Public Smart TV Display Endpoints (Phase 4 & 5)
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/v1/display/photos` | Fetch only approved photos with visitor consent | None (Public TV feed) |
| `GET` | `/api/v1/display/settings` | Fetch slide duration, transitions, visitor overlay, autoplay, portal URL | None (Public TV feed) |
| `GET` | `/api/v1/display/qr-code` | Dynamically generate PNG QR code for mobile photo upload | None (Public TV feed) |
| `GET` | `/api/v1/media/slideshow/{id}`| Strictly stream approved + consented + non-deleted photo | None (Gated) |

### 2.3 Media Streaming Endpoints
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/v1/media/photos/{id}` | Securely stream full-res photo | `X-Visitor-Token` / Bearer JWT |
| `GET` | `/api/v1/media/thumbnails/{id}` | Securely stream thumbnail preview | `X-Visitor-Token` / Bearer JWT |

### 2.4 Admin Portal Endpoints
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/v1/admin/login` | Admin authentication returning Bearer JWT | None |
| `GET` | `/api/v1/admin/dashboard` | Dashboard metrics (total, pending, approved, rejected, visitors) | Bearer JWT |
| `GET` | `/api/v1/admin/photos/pending` | Fetch list of photos awaiting review | Bearer JWT |
| `GET` | `/api/v1/admin/photos/approved` | Fetch list of approved photos | Bearer JWT |
| `GET` | `/api/v1/admin/photos/rejected` | Fetch list of rejected photos with reasons | Bearer JWT |
| `PATCH`| `/api/v1/admin/photos/{id}/approve` | Approve photo (Strictly requires visitor consent) | Bearer JWT |
| `PATCH`| `/api/v1/admin/photos/{id}/reject` | Reject photo (Mandatory explanation reason) | Bearer JWT |
| `GET` | `/api/v1/admin/settings` | Retrieve active slideshow configuration | Bearer JWT |
| `PUT` | `/api/v1/admin/settings` | Update slideshow timing, transitions, autoplay & display toggles | Bearer JWT |

---

## 3. Administrator CLI Bootstrap

Create or update administrators securely using the CLI utility:

```powershell
cd backend
# Masked interactive prompt (recommended - passwords never echoed or logged in shell history):
.\venv\Scripts\python.exe scripts/create_admin.py --username admin --email admin@example.com

# Non-interactive / scripted execution:
.\venv\Scripts\python.exe scripts/create_admin.py --username admin --email admin@example.com --password "YourStrongPasswordHere!"
```

---

## 4. How to Run the Backend

```powershell
cd backend
.\venv\Scripts\Activate.ps1
alembic upgrade head
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

- **Interactive API Docs:** [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **Health Check:** [http://127.0.0.1:8000/api/v1/health](http://127.0.0.1:8000/api/v1/health)
- **Smart TV Photo Feed:** [http://127.0.0.1:8000/api/v1/display/photos](http://127.0.0.1:8000/api/v1/display/photos)

---

## 5. How to Run Automated Tests

```powershell
cd backend
.\venv\Scripts\pytest.exe -v
```
All 49 automated tests cover:
- Configuration and database connectivity
- Health check probes and error handling
- Magic-byte validation (JPEG, PNG, WebP)
- Cryptographic visitor tokens and bcrypt password hashing
- Visitor registration and batch photo uploads
- Photo isolation and deletion flows
- Admin authentication and JWT route protection
- Dashboard metrics and photo moderation approval/rejection
- Slideshow settings lifecycle
- Public Smart TV display photo feeds with strict consent & approval gatekeepers
- Instant deletion eviction from continuous slideshow rotation
- Slideshow master disable behavior
