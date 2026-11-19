# API Specification & Integration Reference

The **Visitor Photo Slideshow API** is a RESTful service adhering to Clean Architecture principles.

- **Base URL**: `/api/v1`
- **Response Format**: `application/json`
- **Error Format**: Standardized JSON with `detail` error descriptions

---

## 1. Authentication Schemes

1. **Visitor Token Authentication**:
   - Header: `X-Visitor-Token: <256-bit-token>`
   - Acquired via: `POST /api/v1/visitors/register`
   - Scope: Photo upload, personal upload history, photo deletion.

2. **Admin JWT Authentication**:
   - Header: `Authorization: Bearer <jwt-token>`
   - Acquired via: `POST /api/v1/admin/login`
   - Scope: Moderation queue, photo approval/rejection, dashboard analytics, display settings.

3. **Public Smart TV Display**:
   - No credentials required.
   - Strictly scoped to approved, consented, and active photos.

---

## 2. Health & System Endpoints

### 2.1 Health Check Probe
`GET /api/v1/health`

**Headers**: None

**Response (200 OK)**:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "environment": "development",
  "database": {
    "status": "connected",
    "dialect": "sqlite",
    "latency_ms": 1.25
  }
}
```

---

## 3. Visitor Endpoints

### 3.1 Visitor Registration
`POST /api/v1/visitors/register`

Registers a new event guest and generates a secure session token.

**Request Body**:
```json
{
  "name": "Alex Morgan",
  "email": "alex.morgan@example.com"
}
```

**Response (201 Created)**:
```json
{
  "id": "c1f7b022-7f28-4e6a-b2f5-30fa1db19201",
  "name": "Alex Morgan",
  "email": "alex.morgan@example.com",
  "session_token": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2",
  "created_at": "2026-11-18T14:30:00Z"
}
```

### 3.2 Upload Photos Batch
`POST /api/v1/photos/upload`

Uploads up to 10 photos in a single batch. Validates magic bytes (JPEG/PNG/WebP).

**Headers**: `X-Visitor-Token: <session_token>`

**Form Data (Multipart)**:
- `files`: File byte streams (Max 15 MB each)
- `consent_given`: `true` (Mandatory public-display consent)

**Response (201 Created)**:
```json
{
  "uploaded_count": 2,
  "photos": [
    {
      "id": "photo-uuid-1",
      "original_filename": "dance_floor.jpg",
      "thumbnail_url": "/api/v1/media/thumbnails/photo-uuid-1",
      "photo_url": "/api/v1/media/photos/photo-uuid-1",
      "status": "PENDING",
      "consent_given": true,
      "consent_given_at": "2026-11-18T14:32:00Z",
      "consent_policy_version": "v1.0",
      "created_at": "2026-11-18T14:32:00Z"
    }
  ]
}
```

**Error (400 Bad Request)**:
```json
{
  "detail": "Explicit public-display consent is required to upload event photos."
}
```

### 3.3 Visitor Photo History
`GET /api/v1/photos/my-photos`

Retrieves all photos submitted by the authenticated visitor.

**Headers**: `X-Visitor-Token: <session_token>`

**Response (200 OK)**:
```json
[
  {
    "id": "photo-uuid-1",
    "visitor_id": "c1f7b022-7f28-4e6a-b2f5-30fa1db19201",
    "original_filename": "dance_floor.jpg",
    "thumbnail_url": "/api/v1/media/thumbnails/photo-uuid-1",
    "photo_url": "/api/v1/media/photos/photo-uuid-1",
    "status": "APPROVED",
    "consent_given": true,
    "consent_given_at": "2026-11-18T14:32:00Z",
    "consent_policy_version": "v1.0",
    "is_deleted": false,
    "rejection_reason": null,
    "created_at": "2026-11-18T14:32:00Z",
    "width": 1920,
    "height": 1080
  }
]
```

### 3.4 Delete Photo (Instant Eviction)
`DELETE /api/v1/photos/{id}`

Visitors can delete any of their own photos at any time.

**Headers**: `X-Visitor-Token: <session_token>`

**Response (200 OK)**:
```json
{
  "message": "Photo deleted successfully",
  "photo_id": "photo-uuid-1"
}
```

---

## 4. Admin Moderation Endpoints

### 4.1 Admin Login
`POST /api/v1/admin/login`

**Request Body**:
```json
{
  "username": "admin",
  "password": "StrongAdminPassword123!"
}
```

**Response (200 OK)**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "username": "admin"
}
```

### 4.2 Dashboard Analytics
`GET /api/v1/admin/dashboard`

**Headers**: `Authorization: Bearer <jwt-token>`

**Response (200 OK)**:
```json
{
  "total_photos": 142,
  "pending_photos": 7,
  "approved_photos": 128,
  "rejected_photos": 7,
  "total_visitors": 45
}
```

### 4.3 Moderation Queue (Pending / Approved / Rejected)
- `GET /api/v1/admin/photos/pending`
- `GET /api/v1/admin/photos/approved`
- `GET /api/v1/admin/photos/rejected`

**Headers**: `Authorization: Bearer <jwt-token>`

**Query Parameters**:
- `skip`: Integer (default 0)
- `limit`: Integer (default 50)

**Response (200 OK)**:
```json
[
  {
    "id": "photo-uuid-1",
    "visitor_id": "visitor-uuid-1",
    "visitor_name": "Alex Morgan",
    "visitor_email": "alex@example.com",
    "original_filename": "cake_cutting.jpg",
    "thumbnail_url": "/api/v1/media/thumbnails/photo-uuid-1",
    "photo_url": "/api/v1/media/photos/photo-uuid-1",
    "status": "PENDING",
    "consent_given": true,
    "consent_given_at": "2026-11-18T14:32:00Z",
    "consent_policy_version": "v1.0",
    "rejection_reason": null,
    "reviewed_by": null,
    "reviewed_at": null,
    "created_at": "2026-11-18T14:32:00Z",
    "width": 1920,
    "height": 1080
  }
]
```

### 4.4 Approve Photo
`PATCH /api/v1/admin/photos/{id}/approve`

**Headers**: `Authorization: Bearer <jwt-token>`

**Response (200 OK)**:
```json
{
  "id": "photo-uuid-1",
  "status": "APPROVED",
  "reviewed_by": "admin-uuid-1",
  "reviewed_at": "2026-11-18T14:35:00Z",
  "detail": "Photo approved successfully"
}
```

### 4.5 Reject Photo
`PATCH /api/v1/admin/photos/{id}/reject`

**Headers**: `Authorization: Bearer <jwt-token>`

**Request Body**:
```json
{
  "rejection_reason": "Image out of focus or duplicate"
}
```

**Response (200 OK)**:
```json
{
  "id": "photo-uuid-1",
  "status": "REJECTED",
  "rejection_reason": "Image out of focus or duplicate",
  "reviewed_by": "admin-uuid-1",
  "reviewed_at": "2026-11-18T14:35:00Z",
  "detail": "Photo rejected"
}
```

### 4.6 Get / Update Slideshow Settings
- `GET /api/v1/admin/settings`
- `PUT /api/v1/admin/settings`

**Headers**: `Authorization: Bearer <jwt-token>`

**PUT Request Body**:
```json
{
  "slide_duration_seconds": 12,
  "transition_effect": "ZOOM",
  "show_visitor_name": true,
  "shuffle_playback": false,
  "slideshow_autoplay": true,
  "slideshow_enabled": true,
  "refresh_interval_seconds": 20,
  "show_qr_code": true,
  "visitor_portal_url": "https://photos.yourdomain.com"
}
```

**Response (200 OK)**:
```json
{
  "slide_duration_seconds": 12,
  "slideshow_autoplay": true,
  "slideshow_enabled": true,
  "transition_effect": "ZOOM",
  "show_visitor_name": true,
  "shuffle_playback": false,
  "refresh_interval_seconds": 20,
  "show_qr_code": true,
  "visitor_portal_url": "https://photos.yourdomain.com",
  "updated_at": "2026-11-18T14:40:00Z"
}
```

---

## 5. Public Smart TV Display Endpoints

### 5.1 Public Slideshow Photos
`GET /api/v1/display/photos`

**Headers**: None (Public Gated Feed)

**Response (200 OK)**:
```json
{
  "photos": [
    {
      "id": "photo-uuid-1",
      "url": "/api/v1/media/slideshow/photo-uuid-1",
      "visitor_name": "Alex Morgan",
      "created_at": "2026-11-18T14:32:00Z",
      "width": 1920,
      "height": 1080
    }
  ],
  "total_count": 1,
  "slideshow_enabled": true
}
```

### 5.2 Public Display Settings
`GET /api/v1/display/settings`

**Headers**: None (Public Gated Feed)

**Response (200 OK)**:
```json
{
  "slide_duration_seconds": 12,
  "transition_effect": "ZOOM",
  "show_visitor_name": true,
  "shuffle_playback": false,
  "slideshow_autoplay": true,
  "slideshow_enabled": true,
  "refresh_interval_seconds": 20,
  "show_qr_code": true,
  "visitor_portal_url": "https://photos.yourdomain.com",
  "portal_url": "https://photos.yourdomain.com",
  "qr_code_url": "/api/v1/display/qr-code",
  "updated_at": "2026-11-18T14:40:00Z"
}
```

### 5.3 Public TV QR Code
`GET /api/v1/display/qr-code`

**Headers**: None (Public Feed)

**Response (200 OK)**: Binary PNG stream (`Content-Type: image/png`). Contains verified public HTTPS URL.

---

## 6. Media Streaming Gatekeeper

| Endpoint | Access Level | Description |
|---|---|---|
| `GET /api/v1/media/slideshow/{id}` | Public Gated | Strictly streams photos that are `APPROVED`, `consent_given == True`, and not deleted. Otherwise returns `404 Not Found`. |
| `GET /api/v1/media/photos/{id}` | Restricted | Full-resolution image. Allowed only for authenticated Admin or the uploading Visitor. |
| `GET /api/v1/media/thumbnails/{id}` | Restricted | Compressed thumbnail preview. Allowed if photo is approved with consent, or for Admin/owner. |
