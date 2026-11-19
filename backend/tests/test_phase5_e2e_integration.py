import io
import pytest
from PIL import Image
from fastapi.testclient import TestClient
from app.core.security import hash_password
from app.infrastructure.database.models import DBAdminUser

def create_image(color="purple", size=(200, 200)) -> bytes:
    buf = io.BytesIO()
    img = Image.new("RGB", size, color=color)
    img.save(buf, format="JPEG")
    return buf.getvalue()

def seed_admin(db_session, username="e2e_admin", password="E2EPassword123!"):
    admin = db_session.query(DBAdminUser).filter(DBAdminUser.username == username).first()
    if not admin:
        admin = DBAdminUser(
            username=username,
            email=f"{username}@e2e.test",
            hashed_password=hash_password(password),
            role="ADMIN",
            is_active=True,
        )
        db_session.add(admin)
        db_session.commit()
    return admin

def test_full_visitor_to_slideshow_e2e_workflow(client: TestClient, db_session):
    """
    COMPLETE LIFECYCLE VERIFICATION (Phase 5 E2E):
    1. Visitor registers.
    2. Visitor attempts upload without consent -> REJECTED (400).
    3. Visitor uploads 2 valid photos with consent -> PENDING.
    4. Admin authenticates via JWT.
    5. Admin inspects dashboard and moderation queue.
    6. Admin approves photo 1 and rejects photo 2 (with reason).
    7. Public Smart TV feed receives photo 1 ONLY.
    8. Smart TV QR code endpoint renders valid PNG image.
    9. Visitor deletes photo 1 -> photo 1 evicted immediately from Smart TV feed.
    10. Admin updates settings (toggles transition to ZOOM, slide duration to 15s, show_qr_code=True).
    11. Smart TV public settings reflect updated values.
    12. Security: Visitor token rejected on admin routes, unapproved media returns 404.
    """
    # ==========================================
    # STEP 1: Visitor Registration
    # ==========================================
    v_res = client.post("/api/v1/visitors/register", json={"name": "Emma Watson", "email": "emma@event.local"})
    assert v_res.status_code == 201
    visitor_data = v_res.json()
    assert visitor_data["name"] == "Emma Watson"
    v_token = visitor_data["session_token"]
    assert len(v_token) >= 32

    # ==========================================
    # STEP 2: Consent Enforcement on Upload
    # ==========================================
    img_bytes1 = create_image("blue")
    img_bytes2 = create_image("green")

    # Upload with consent=false must be rejected
    no_consent_res = client.post(
        "/api/v1/photos/upload",
        headers={"X-Visitor-Token": v_token},
        data={"consent_given": "false"},
        files=[("files", ("no_consent.jpg", img_bytes1, "image/jpeg"))],
    )
    assert no_consent_res.status_code == 400
    assert "consent" in no_consent_res.json()["detail"].lower()

    # Upload with explicit consent=true succeeds
    upload_res = client.post(
        "/api/v1/photos/upload",
        headers={"X-Visitor-Token": v_token},
        data={"consent_given": "true", "consent_policy_version": "v1.0"},
        files=[
            ("files", ("emma_1.jpg", img_bytes1, "image/jpeg")),
            ("files", ("emma_2.jpg", img_bytes2, "image/jpeg")),
        ],
    )
    assert upload_res.status_code == 201
    photos = upload_res.json()["photos"]
    assert len(photos) == 2
    p1_id = photos[0]["id"]
    p2_id = photos[1]["id"]
    assert photos[0]["status"] == "PENDING"
    assert photos[1]["status"] == "PENDING"

    # Verify photos are in visitor history
    my_photos_res = client.get("/api/v1/photos/my-photos", headers={"X-Visitor-Token": v_token})
    assert my_photos_res.status_code == 200
    assert len(my_photos_res.json()) >= 2

    # Verify TV display is initially empty (neither photo is approved yet)
    tv_feed_initial = client.get("/api/v1/display/photos")
    assert tv_feed_initial.status_code == 200
    assert not any(p["id"] in [p1_id, p2_id] for p in tv_feed_initial.json()["photos"])

    # ==========================================
    # STEP 3: Admin Login & Authentication
    # ==========================================
    seed_admin(db_session, "e2e_lead_admin", "SuperSecureAdminPass999!")
    login_res = client.post(
        "/api/v1/admin/login",
        json={"username": "e2e_lead_admin", "password": "SuperSecureAdminPass999!"},
    )
    assert login_res.status_code == 200
    jwt_token = login_res.json()["access_token"]
    admin_auth = {"Authorization": f"Bearer {jwt_token}"}

    # ==========================================
    # STEP 4: Admin Moderation
    # ==========================================
    # Dashboard check
    dash_res = client.get("/api/v1/admin/dashboard", headers=admin_auth)
    assert dash_res.status_code == 200
    assert dash_res.json()["pending_photos"] >= 2

    # Admin approves photo 1
    appr_res = client.patch(f"/api/v1/admin/photos/{p1_id}/approve", headers=admin_auth)
    assert appr_res.status_code == 200
    assert appr_res.json()["status"] == "APPROVED"

    # Admin rejects photo 2 with mandatory reason
    rej_res = client.patch(
        f"/api/v1/admin/photos/{p2_id}/reject",
        headers=admin_auth,
        json={"rejection_reason": "Out of focus image"},
    )
    assert rej_res.status_code == 200
    assert rej_res.json()["status"] == "REJECTED"
    assert rej_res.json()["rejection_reason"] == "Out of focus image"

    # ==========================================
    # STEP 5: Smart TV Public Display Verification
    # ==========================================
    tv_feed = client.get("/api/v1/display/photos").json()
    assert any(p["id"] == p1_id for p in tv_feed["photos"])
    assert not any(p["id"] == p2_id for p in tv_feed["photos"])

    # Verify media streaming route: p1 streams image, p2 returns 404
    p1_stream = client.get(f"/api/v1/media/slideshow/{p1_id}")
    assert p1_stream.status_code == 200
    assert p1_stream.headers["content-type"] == "image/jpeg"

    p2_stream = client.get(f"/api/v1/media/slideshow/{p2_id}")
    assert p2_stream.status_code == 404

    # ==========================================
    # STEP 6: Smart TV QR Code Generation
    # ==========================================
    qr_res = client.get("/api/v1/display/qr-code")
    assert qr_res.status_code == 200
    assert qr_res.headers["content-type"] == "image/png"
    # Verify PNG header magic bytes (\x89PNG)
    assert qr_res.content[:4] == b"\x89PNG"

    # ==========================================
    # STEP 7: Visitor Deletion Eviction
    # ==========================================
    del_res = client.delete(f"/api/v1/photos/{p1_id}", headers={"X-Visitor-Token": v_token})
    assert del_res.status_code == 200

    # TV display refreshed: photo 1 must be gone immediately!
    tv_feed_after_del = client.get("/api/v1/display/photos").json()
    assert not any(p["id"] == p1_id for p in tv_feed_after_del["photos"])

    # Media streaming route now returns 404 for deleted photo
    assert client.get(f"/api/v1/media/slideshow/{p1_id}").status_code == 404

    # ==========================================
    # STEP 8: Slideshow Settings Synchronization
    # ==========================================
    update_sett_res = client.put(
        "/api/v1/admin/settings",
        headers=admin_auth,
        json={
            "slide_duration_seconds": 20,
            "transition_effect": "ZOOM",
            "show_visitor_name": False,
            "show_qr_code": True,
            "visitor_portal_url": "https://myevent.example.com/photos",
        },
    )
    assert update_sett_res.status_code == 200

    # Public display settings reflect updates
    disp_sett = client.get("/api/v1/display/settings").json()
    assert disp_sett["slide_duration_seconds"] == 20
    assert disp_sett["transition_effect"] == "ZOOM"
    assert disp_sett["show_visitor_name"] is False
    assert disp_sett["show_qr_code"] is True
    assert disp_sett["portal_url"] == "https://myevent.example.com/photos"

    # ==========================================
    # STEP 9: Security & Authorization Boundary Checks
    # ==========================================
    # Visitor token cannot access admin routes
    assert client.get("/api/v1/admin/dashboard", headers={"Authorization": f"Bearer {v_token}"}).status_code == 401
    assert client.get("/api/v1/admin/photos/pending", headers={"X-Visitor-Token": v_token}).status_code == 401
