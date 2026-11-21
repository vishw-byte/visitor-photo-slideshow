import io
from PIL import Image
from datetime import datetime, timezone
from app.core.security import hash_password
from app.infrastructure.database.models import DBAdminUser, DBVisitor, DBPhoto
from app.domain.entities.models import PhotoStatus

def create_image_bytes(color: str = "blue") -> bytes:
    img = Image.new("RGB", (100, 100), color=color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()

def seed_test_admin(db_session, username="admin_tester", password="SecretPassword123!"):
    admin = db_session.query(DBAdminUser).filter(DBAdminUser.username == username).first()
    if not admin:
        admin = DBAdminUser(
            username=username,
            email=f"{username}@event.local",
            hashed_password=hash_password(password),
            role="ADMIN",
            is_active=True,
        )
        db_session.add(admin)
        db_session.commit()
        db_session.refresh(admin)
    return admin

def test_admin_login_success_and_failure(client, db_session):
    seed_test_admin(db_session, "mod_admin", "Password!123")

    # 1. Invalid password -> 401
    bad_resp = client.post("/api/v1/admin/login", json={"username": "mod_admin", "password": "WrongPassword"})
    assert bad_resp.status_code == 401
    assert "Invalid credentials" in bad_resp.json()["detail"]

    # 2. Valid login -> 200 with JWT
    good_resp = client.post("/api/v1/admin/login", json={"username": "mod_admin", "password": "Password!123"})
    assert good_resp.status_code == 200
    data = good_resp.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["username"] == "mod_admin"

def test_admin_route_protection_and_visitor_token_rejection(client, db_session):
    # 1. Unauthenticated access -> 401
    resp_no_auth = client.get("/api/v1/admin/dashboard")
    assert resp_no_auth.status_code == 401

    # 2. Invalid JWT token -> 401
    resp_bad_jwt = client.get(
        "/api/v1/admin/dashboard",
        headers={"Authorization": "Bearer totally.invalid.token"},
    )
    assert resp_bad_jwt.status_code == 401

    # 3. Visitor token passed in X-Visitor-Token without Admin Bearer JWT -> 401
    reg = client.post("/api/v1/visitors/register", json={"name": "Attacker Visitor"}).json()
    visitor_token = reg["session_token"]
    resp_visitor = client.get(
        "/api/v1/admin/dashboard",
        headers={"X-Visitor-Token": visitor_token},
    )
    assert resp_visitor.status_code == 401

def test_admin_dashboard_stats(client, db_session):
    admin = seed_test_admin(db_session, "stats_admin", "Admin123!")
    login_resp = client.post("/api/v1/admin/login", json={"username": "stats_admin", "password": "Admin123!"})
    jwt_token = login_resp.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {jwt_token}"}

    # Register 2 visitors
    v1 = client.post("/api/v1/visitors/register", json={"name": "V1"}).json()
    client.post("/api/v1/visitors/register", json={"name": "V2"}).json()

    # Upload 1 photo
    img_bytes = create_image_bytes("purple")
    client.post(
        "/api/v1/photos/upload",
        files=[("files", ("test.jpg", img_bytes, "image/jpeg"))],
        data={"consent_given": "true"},
        headers={"X-Visitor-Token": v1["session_token"]},
    )

    # Check dashboard stats
    dash_resp = client.get("/api/v1/admin/dashboard", headers=admin_headers)
    assert dash_resp.status_code == 200
    stats = dash_resp.json()
    assert stats["total_visitors"] >= 2
    assert stats["total_photos"] >= 1
    assert stats["approved_photos"] >= 1

def test_photo_approval_and_consent_validation(client, db_session):
    admin = seed_test_admin(db_session, "approver_admin", "Admin123!")
    login_resp = client.post("/api/v1/admin/login", json={"username": "approver_admin", "password": "Admin123!"})
    jwt_token = login_resp.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {jwt_token}"}

    v = client.post("/api/v1/visitors/register", json={"name": "Uploader"}).json()
    img_bytes = create_image_bytes("green")

    # Upload valid photo with consent -> automatically APPROVED
    upload = client.post(
        "/api/v1/photos/upload",
        files=[("files", ("photo.jpg", img_bytes, "image/jpeg"))],
        data={"consent_given": "true"},
        headers={"X-Visitor-Token": v["session_token"]},
    ).json()
    photo_id = upload["photos"][0]["id"]
    assert upload["photos"][0]["status"] == "APPROVED"

    # 1. Fetch approved list -> photo is present immediately
    approved_list = client.get("/api/v1/admin/photos/approved", headers=admin_headers).json()
    assert any(p["id"] == photo_id for p in approved_list)

    # 2. Test manual approval workflow on a PENDING photo with consent
    now = datetime.now(timezone.utc)
    pending_consented_photo = DBPhoto(
        visitor_id=v["id"],
        original_filename="manual_pending.jpg",
        storage_path="manual_pending.jpg",
        thumbnail_path="manual_pending.jpg",
        file_size_bytes=1000,
        mime_type="image/jpeg",
        consent_given=True,
        consent_given_at=now,
        consent_policy_version="v1.0",
        status=PhotoStatus.PENDING.value,
        is_deleted=False,
        created_at=now,
    )
    db_session.add(pending_consented_photo)
    db_session.commit()
    db_session.refresh(pending_consented_photo)

    pending_list = client.get("/api/v1/admin/photos/pending", headers=admin_headers).json()
    assert any(p["id"] == pending_consented_photo.id for p in pending_list)

    appr_resp = client.patch(f"/api/v1/admin/photos/{pending_consented_photo.id}/approve", headers=admin_headers)
    assert appr_resp.status_code == 200
    assert appr_resp.json()["status"] == "APPROVED"
    assert appr_resp.json()["reviewed_by"] == admin.id
    assert appr_resp.json()["reviewed_at"] is not None

    # 3. Consent enforcement: manually create a photo with consent_given=False in DB
    no_consent_photo = DBPhoto(
        visitor_id=v["id"],
        original_filename="no_consent.jpg",
        storage_path="no_consent.jpg",
        thumbnail_path="no_consent.jpg",
        file_size_bytes=1000,
        mime_type="image/jpeg",
        consent_given=False,
        status=PhotoStatus.PENDING.value,
        is_deleted=False,
        created_at=now,
    )
    db_session.add(no_consent_photo)
    db_session.commit()
    db_session.refresh(no_consent_photo)

    # Attempting to approve photo without consent must fail
    fail_appr = client.patch(f"/api/v1/admin/photos/{no_consent_photo.id}/approve", headers=admin_headers)
    assert fail_appr.status_code == 400
    assert "consent was not granted" in fail_appr.json()["detail"].lower()

def test_photo_rejection_flow(client, db_session):
    seed_test_admin(db_session, "rejecter_admin", "Admin123!")
    jwt_token = client.post("/api/v1/admin/login", json={"username": "rejecter_admin", "password": "Admin123!"}).json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {jwt_token}"}

    v = client.post("/api/v1/visitors/register", json={"name": "Blurry Poster"}).json()
    img_bytes = create_image_bytes("yellow")

    upload = client.post(
        "/api/v1/photos/upload",
        files=[("files", ("blurry.jpg", img_bytes, "image/jpeg"))],
        data={"consent_given": "true"},
        headers={"X-Visitor-Token": v["session_token"]},
    ).json()
    photo_id = upload["photos"][0]["id"]

    # Reject without reason -> validation failure
    bad_reject = client.patch(
        f"/api/v1/admin/photos/{photo_id}/reject",
        json={"rejection_reason": "   "},
        headers=admin_headers,
    )
    assert bad_reject.status_code == 400

    # Reject with reason -> 200 OK
    reject_resp = client.patch(
        f"/api/v1/admin/photos/{photo_id}/reject",
        json={"rejection_reason": "Photo is blurry and out of focus"},
        headers=admin_headers,
    )
    assert reject_resp.status_code == 200
    assert reject_resp.json()["status"] == "REJECTED"
    assert reject_resp.json()["rejection_reason"] == "Photo is blurry and out of focus"

    # Photo appears in rejected list
    rejected_list = client.get("/api/v1/admin/photos/rejected", headers=admin_headers).json()
    assert any(p["id"] == photo_id for p in rejected_list)

def test_deleted_photo_cannot_be_approved(client, db_session):
    seed_test_admin(db_session, "del_test_admin", "Admin123!")
    jwt_token = client.post("/api/v1/admin/login", json={"username": "del_test_admin", "password": "Admin123!"}).json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {jwt_token}"}

    v = client.post("/api/v1/visitors/register", json={"name": "Regretful Uploader"}).json()
    img_bytes = create_image_bytes("orange")

    upload = client.post(
        "/api/v1/photos/upload",
        files=[("files", ("delete_me.jpg", img_bytes, "image/jpeg"))],
        data={"consent_given": "true"},
        headers={"X-Visitor-Token": v["session_token"]},
    ).json()
    photo_id = upload["photos"][0]["id"]

    # Visitor deletes their photo
    client.delete(f"/api/v1/photos/{photo_id}", headers={"X-Visitor-Token": v["session_token"]})

    # Admin attempts to approve deleted photo -> must fail
    appr_deleted = client.patch(f"/api/v1/admin/photos/{photo_id}/approve", headers=admin_headers)
    assert appr_deleted.status_code == 400
    assert "deleted" in appr_deleted.json()["detail"].lower()

def test_slideshow_settings_lifecycle(client, db_session):
    seed_test_admin(db_session, "settings_admin", "Admin123!")
    jwt_token = client.post("/api/v1/admin/login", json={"username": "settings_admin", "password": "Admin123!"}).json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {jwt_token}"}

    # 1. Fetch current settings
    settings_resp = client.get("/api/v1/admin/settings", headers=admin_headers)
    assert settings_resp.status_code == 200
    data = settings_resp.json()
    assert data["slide_duration_seconds"] == 10
    assert data["slideshow_autoplay"] is True
    assert data["slideshow_enabled"] is True

    # 2. Update settings
    update_resp = client.put(
        "/api/v1/admin/settings",
        json={
            "slide_duration_seconds": 18,
            "slideshow_autoplay": False,
            "slideshow_enabled": True,
            "transition_effect": "ZOOM",
            "show_visitor_name": False,
        },
        headers=admin_headers,
    )
    assert update_resp.status_code == 200
    updated = update_resp.json()
    assert updated["slide_duration_seconds"] == 18
    assert updated["slideshow_autoplay"] is False
    assert updated["transition_effect"] == "ZOOM"
    assert updated["show_visitor_name"] is False


def test_admin_password_change_lifecycle(client, db_session):
    """
    Verifies that an existing admin password can be updated securely:
    1. Account ID and metadata are preserved without deleting the user.
    2. Old password immediately fails with 401 Unauthorized.
    3. New password succeeds with 200 OK and returns a valid JWT.
    4. Passwords under 8 characters are rejected.
    """
    from scripts.create_admin import create_or_update_admin

    admin = seed_test_admin(db_session, "lifecycle_admin", "OldSecurePass123!")
    initial_id = admin.id

    # 1. Login with initial password succeeds
    login_old = client.post("/api/v1/admin/login", json={"username": "lifecycle_admin", "password": "OldSecurePass123!"})
    assert login_old.status_code == 200

    # 2. Reject passwords under 8 characters
    short_result = create_or_update_admin("lifecycle_admin", "short", db=db_session)
    assert short_result is False

    # 3. Update password securely using existing bcrypt implementation
    update_result = create_or_update_admin(
        "lifecycle_admin",
        "BrandNewPass456!",
        email="new_lifecycle@event.local",
        db=db_session,
    )
    assert update_result is True

    # 4. Old password immediately ceases to work
    failed_login = client.post("/api/v1/admin/login", json={"username": "lifecycle_admin", "password": "OldSecurePass123!"})
    assert failed_login.status_code == 401
    assert "Invalid credentials" in failed_login.json()["detail"]

    # 5. New password works immediately
    success_login = client.post("/api/v1/admin/login", json={"username": "lifecycle_admin", "password": "BrandNewPass456!"})
    assert success_login.status_code == 200
    assert "access_token" in success_login.json()

    # 6. Verify account ID was preserved
    db_session.expire_all()
    updated_admin = db_session.query(DBAdminUser).filter(DBAdminUser.username == "lifecycle_admin").first()
    assert updated_admin.id == initial_id
    assert updated_admin.email == "new_lifecycle@event.local"

