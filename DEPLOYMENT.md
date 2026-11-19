# Production Deployment & Operations Guide

This guide details the steps to deploy, configure, secure, back up, and maintain the **Visitor Photo Slideshow Application** in a production environment.

---

## 1. Prerequisites

- **Docker Engine**: 24.0+
- **Docker Compose**: 2.20+
- **Host Hardware**: Minimum 2 vCPU, 2 GB RAM, 20 GB SSD storage.
- **Domain Names & TLS**: Configured DNS records for your public visitor portal and Smart TV slideshow URLs with SSL/TLS certificates (e.g. Let's Encrypt).

---

## 2. Docker Compose Deployment (Recommended)

### Step 2.1: Clone and Configure Environment
```bash
git clone <repository_url>
cd "photo slider"
cp .env.example .env
```

Edit `.env` and configure:
1. `SECRET_KEY`: Generate a random 256-bit key:
   ```bash
   python -c "import secrets; print(secrets.token_hex(32))"
   ```
2. `POSTGRES_PASSWORD`: Strong password for the PostgreSQL container.
3. `ADMIN_DEFAULT_PASSWORD`: Temporary bootstrap password for initial admin sign-in.
4. `PUBLIC_PORTAL_URL`: The public URL that visitors will access via mobile phones (encoded in the Smart TV QR code), e.g. `https://photos.yourdomain.com`.
5. `CORS_ORIGINS`: Set to your production domains, e.g. `https://photos.yourdomain.com`.

### Step 2.2: Launch Services
```bash
docker compose up -d --build
```

### Step 2.3: Verify Deployment Health
Check running containers:
```bash
docker compose ps
```
Verify the backend health check:
```bash
curl http://localhost:8000/api/v1/health
```
Expected output:
```json
{
  "status": "healthy",
  "database": {
    "status": "connected",
    "dialect": "postgresql"
  }
}
```

---

## 3. Database & Media Backup Strategy

### 3.1 PostgreSQL Database Backup
To create a timestamped backup of the database:
```bash
docker compose exec -t db pg_dump -U slideshow_user slideshow_db > backup_slideshow_$(date +%Y%m%d_%H%M%S).sql
```

### 3.2 PostgreSQL Database Restoration
To restore from an existing SQL backup file:
```bash
cat backup_slideshow_20261118.sql | docker compose exec -i db psql -U slideshow_user -d slideshow_db
```

### 3.3 Media Storage Backup
The uploaded full-resolution images and generated thumbnails are stored in the persistent volume `media_uploads`.
To back up the media volume to a compressed archive:
```bash
docker run --rm -v "photo slider_media_uploads:/uploads" -v $(pwd):/backup alpine tar czf /backup/media_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /uploads .
```

### 3.4 Media Storage Restoration
```bash
docker run --rm -v "photo slider_media_uploads:/uploads" -v $(pwd):/backup alpine tar xzf /backup/media_backup_20261118.tar.gz -C /uploads
```

---

## 4. Production Security Hardening Checklist

1. **Environment Secrets**: Never commit `.env` or production passwords to version control.
2. **Admin Password**: After initial launch, change the admin password through the Admin Dashboard or create a unique administrator via:
   ```bash
   docker compose exec backend python scripts/create_admin.py --username production_lead --email lead@yourdomain.com --password "YourStrongPasswordHere!"
   ```
3. **Restricted CORS**: Ensure `CORS_ORIGINS` in `.env` is explicitly set to authorized domains instead of `*`.
4. **HTTPS Everywhere**: Terminate TLS at your front-facing reverse proxy (e.g. Cloudflare, AWS ALB, Nginx, or Caddy) to ensure all visitor sessions and admin JWTs are transmitted over encrypted TLS tunnels.
5. **Disk Quota & File Size**: Max upload file size is capped at 15 MB per file, and maximum batch size is 10 photos per upload request. Magic-byte signature checking strictly forbids disguised executables.
6. **Graceful Handling of Missing Files**: The backend verifies file existence on disk before including items in the Smart TV display feed; if a file was deleted from disk, it is excluded cleanly without breaking the slideshow.
