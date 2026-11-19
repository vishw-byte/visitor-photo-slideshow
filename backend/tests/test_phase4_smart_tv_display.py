import io
from PIL import Image
from fastapi.testclient import TestClient
from app.core.security import hash_password
from app.infrastructure.database.models import DBAdminUser

def create_test_image(format="JPEG", color="blue", size=(800, 600)) -> bytes:
    buf = io.BytesIO()
    img = Image.new("RGB", size, color=color)
    img.save(buf, format=format)
    return buf.getvalue()

def get_admin_token(client: TestClient, db_session, username="display_admin", password="AdminPassword123!") -> str:
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
    login_res = client.post("/api/v1/admin/login", json={"username": username, "password": password})
    return login_res.json()["access_token"]

def test_display_settings_endpoint(client: TestClient):
    """Verifies GET /api/v1/display/settings returns public slideshow parameters."""
    response = client.get("/api/v1/display/settings")
    assert response.status_code == 200
    data = response.json()
    assert "slide_duration_seconds" in data
    assert "transition_effect" in data
    assert "show_visitor_name" in data
    assert "shuffle_playback" in data
    assert "slideshow_autoplay" in data
    assert "slideshow_enabled" in data
    assert "refresh_interval_seconds" in data
    assert data["slideshow_enabled"] is True

def test_display_empty_photo_queue(client: TestClient):
    """Verifies GET /api/v1/display/photos returns empty list when no photos exist."""
    response = client.get("/api/v1/display/photos")
    assert response.status_code == 200
    data = response.json()
    assert data["photos"] == []
    assert data["total_count"] == 0
    assert data["slideshow_enabled"] is True

def test_display_only_approved_and_consented_photos(
    client: TestClient, db_session
):
    """
    STRICT SECURITY & PRIVACY VERIFICATION:
    1. Upload 3 photos for visitor:
       - photo 1: approved, consent=True -> MUST appear
       - photo 2: pending, consent=True -> MUST NOT appear
       - photo 3: rejected, consent=True -> MUST NOT appear
    """
    admin_token = get_admin_token(client, db_session, "approver_admin_tv")

    # 1. Register visitor
    v_res = client.post("/api/v1/visitors/register", json={"name": "Alice Wonderland"})
    assert v_res.status_code == 201
    v_token = v_res.json()["session_token"]

    # 2. Upload 3 photos with consent
    img1 = create_test_image(color="red")
    img2 = create_test_image(color="green")
    img3 = create_test_image(color="blue")

    up_res = client.post(
        "/api/v1/photos/upload",
        headers={"X-Visitor-Token": v_token},
        data={"consent_given": "true", "consent_policy_version": "v1.0"},
        files=[
            ("files", ("photo1.jpg", img1, "image/jpeg")),
            ("files", ("photo2.jpg", img2, "image/jpeg")),
            ("files", ("photo3.jpg", img3, "image/jpeg")),
        ],
    )
    assert up_res.status_code == 201
    uploaded = up_res.json()["photos"]
    p1_id = uploaded[0]["id"]
    p2_id = uploaded[1]["id"]
    p3_id = uploaded[2]["id"]

    # Initially, all are PENDING -> display should be empty
    disp_res = client.get("/api/v1/display/photos")
    assert disp_res.status_code == 200
    assert disp_res.json()["total_count"] == 0

    # Admin approves photo 1
    appr_res = client.patch(
        f"/api/v1/admin/photos/{p1_id}/approve",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert appr_res.status_code == 200

    # Admin rejects photo 3 with reason
    rej_res = client.patch(
        f"/api/v1/admin/photos/{p3_id}/reject",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"rejection_reason": "Low resolution image"},
    )
    assert rej_res.status_code == 200

    # Photo 2 remains PENDING

    # Now verify display feed: ONLY photo 1 should appear!
    feed_res = client.get("/api/v1/display/photos")
    assert feed_res.status_code == 200
    feed = feed_res.json()
    assert feed["total_count"] == 1
    assert len(feed["photos"]) == 1
    item = feed["photos"][0]
    assert item["id"] == p1_id
    assert item["visitor_name"] == "Alice Wonderland"
    assert item["url"] == f"/api/v1/media/slideshow/{p1_id}"

    # Verify no private data leak
    assert "visitor_token" not in item
    assert "visitor_email" not in item
    assert "storage_path" not in item

    # Verify Smart TV media streaming route for approved photo
    media_res = client.get(f"/api/v1/media/slideshow/{p1_id}")
    assert media_res.status_code == 200
    assert media_res.headers["content-type"] == "image/jpeg"

    # Verify media streaming route for pending (p2) and rejected (p3) photos returns 404
    assert client.get(f"/api/v1/media/slideshow/{p2_id}").status_code == 404
    assert client.get(f"/api/v1/media/slideshow/{p3_id}").status_code == 404

def test_deleted_photo_immediately_disappears_from_display(
    client: TestClient, db_session
):
    """
    CRITICAL REQUIREMENT:
    When a visitor deletes their photo, it must immediately be evicted from the
    continuous Smart TV display on subsequent refreshes, even if previously approved!
    """
    admin_token = get_admin_token(client, db_session, "del_admin_tv")

    # Register visitor
    v_res = client.post("/api/v1/visitors/register", json={"name": "Charlie Day"})
    v_token = v_res.json()["session_token"]

    # Upload photo
    img = create_test_image(color="yellow")
    up_res = client.post(
        "/api/v1/photos/upload",
        headers={"X-Visitor-Token": v_token},
        data={"consent_given": "true"},
        files=[("files", ("charlie.jpg", img, "image/jpeg"))],
    )
    photo_id = up_res.json()["photos"][0]["id"]

    # Admin approves photo
    client.patch(
        f"/api/v1/admin/photos/{photo_id}/approve",
        headers={"Authorization": f"Bearer {admin_token}"},
    )

    # Verify it is in display feed
    feed_before = client.get("/api/v1/display/photos").json()
    assert any(p["id"] == photo_id for p in feed_before["photos"])

    # Visitor deletes their photo
    del_res = client.delete(
        f"/api/v1/photos/{photo_id}",
        headers={"X-Visitor-Token": v_token},
    )
    assert del_res.status_code == 200

    # Check display feed again: must be gone immediately!
    feed_after = client.get("/api/v1/display/photos").json()
    assert not any(p["id"] == photo_id for p in feed_after["photos"])

    # Public slideshow media route also returns 404
    assert client.get(f"/api/v1/media/slideshow/{photo_id}").status_code == 404

def test_slideshow_disabled_behavior(client: TestClient, db_session):
    """
    When slideshow_enabled is turned off by admin:
    - GET /api/v1/display/settings returns slideshow_enabled=False
    - GET /api/v1/display/photos returns empty photos list and slideshow_enabled=False
    """
    admin_token = get_admin_token(client, db_session, "disable_admin_tv")

    # 1. Disable slideshow via admin settings
    update_res = client.put(
        "/api/v1/admin/settings",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"slideshow_enabled": False},
    )
    assert update_res.status_code == 200
    assert update_res.json()["slideshow_enabled"] is False

    # 2. Check public settings
    sett_res = client.get("/api/v1/display/settings")
    assert sett_res.status_code == 200
    assert sett_res.json()["slideshow_enabled"] is False

    # 3. Check public display feed
    feed_res = client.get("/api/v1/display/photos")
    assert feed_res.status_code == 200
    feed = feed_res.json()
    assert feed["photos"] == []
    assert feed["total_count"] == 0
    assert feed["slideshow_enabled"] is False

    # Re-enable slideshow for other tests
    client.put(
        "/api/v1/admin/settings",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"slideshow_enabled": True},
    )


def test_slideshow_settings_propagation_and_consistency(client: TestClient, db_session):
    """
    TASK 2 Verification:
    Admin updates slide duration, transition, autoplay, shuffle, visitor overlay, QR code, and portal URL.
    Verifies that public GET /api/v1/display/settings immediately reflects every saved parameter.
    """
    admin_token = get_admin_token(client, db_session, "settings_consistency_admin")

    # Update all parameters
    update_res = client.put(
        "/api/v1/admin/settings",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "slide_duration_seconds": 14,
            "transition_effect": "ZOOM",
            "show_visitor_name": False,
            "shuffle_playback": True,
            "slideshow_autoplay": False,
            "show_qr_code": False,
            "refresh_interval_seconds": 25,
            "visitor_portal_url": "https://photos.productionevent.com",
        },
    )
    assert update_res.status_code == 200
    updated_data = update_res.json()
    assert updated_data["slide_duration_seconds"] == 14
    assert updated_data["transition_effect"] == "ZOOM"
    assert updated_data["show_visitor_name"] is False
    assert updated_data["shuffle_playback"] is True
    assert updated_data["slideshow_autoplay"] is False
    assert updated_data["show_qr_code"] is False
    assert updated_data["refresh_interval_seconds"] == 25
    assert updated_data["visitor_portal_url"] == "https://photos.productionevent.com"

    # Verify public TV display settings endpoint reflects changes immediately
    public_res = client.get("/api/v1/display/settings")
    assert public_res.status_code == 200
    tv_settings = public_res.json()
    assert tv_settings["slide_duration_seconds"] == 14
    assert tv_settings["transition_effect"] == "ZOOM"
    assert tv_settings["show_visitor_name"] is False
    assert tv_settings["shuffle_playback"] is True
    assert tv_settings["slideshow_autoplay"] is False
    assert tv_settings["show_qr_code"] is False
    assert tv_settings["refresh_interval_seconds"] == 25
    assert tv_settings["portal_url"] == "https://photos.productionevent.com"

    # Reset settings back to default
    client.put(
        "/api/v1/admin/settings",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "slide_duration_seconds": 10,
            "transition_effect": "FADE",
            "show_visitor_name": True,
            "shuffle_playback": False,
            "slideshow_autoplay": True,
            "show_qr_code": True,
            "refresh_interval_seconds": 15,
            "visitor_portal_url": None,
        },
    )


def test_production_portal_url_validation_disallows_localhost(client: TestClient, db_session):
    """
    TASK 1 Verification:
    When ENVIRONMENT is production, setting a localhost visitor portal URL must be rejected.
    """
    from app.core.config import settings

    admin_token = get_admin_token(client, db_session, "prod_portal_url_admin")

    # Temporarily simulate production environment
    original_env = settings.ENVIRONMENT
    try:
        settings.ENVIRONMENT = "production"
        bad_res = client.put(
            "/api/v1/admin/settings",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"visitor_portal_url": "http://localhost:3000"},
        )
        assert bad_res.status_code == 422  # Pydantic validation error
    finally:
        settings.ENVIRONMENT = original_env


def test_production_portal_url_validation_disallows_non_https_lan(client: TestClient, db_session):
    """
    Verifies that in production mode, non-HTTPS LAN URLs are rejected with 422,
    while valid public HTTPS URLs are accepted.
    """
    from app.core.config import settings

    admin_token = get_admin_token(client, db_session, "prod_lan_url_admin")

    original_env = settings.ENVIRONMENT
    try:
        settings.ENVIRONMENT = "production"
        # Non-HTTPS LAN URL must be rejected in production
        bad_lan_res = client.put(
            "/api/v1/admin/settings",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"visitor_portal_url": "http://192.168.1.100:3000"},
        )
        assert bad_lan_res.status_code == 422

        # Valid HTTPS URL must succeed
        good_res = client.put(
            "/api/v1/admin/settings",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"visitor_portal_url": "https://photos.myevent.org"},
        )
        assert good_res.status_code == 200
        assert good_res.json()["visitor_portal_url"] == "https://photos.myevent.org"
    finally:
        settings.ENVIRONMENT = original_env
        # Clean up setting
        client.put(
            "/api/v1/admin/settings",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"visitor_portal_url": None},
        )


def test_display_portal_url_lan_ip_resolution(client: TestClient, db_session):
    """
    Verifies that in local/development mode, configuring a LAN IP in settings.PUBLIC_PORTAL_URL
    is respected by GET /api/v1/display/settings and generates a valid QR code PNG.
    """
    from app.core.config import settings

    original_portal_url = settings.PUBLIC_PORTAL_URL
    try:
        settings.PUBLIC_PORTAL_URL = "http://192.168.1.100:3000/"
        res = client.get("/api/v1/display/settings")
        assert res.status_code == 200
        data = res.json()
        assert data["portal_url"] == "http://192.168.1.100:3000/"

        # QR code endpoint returns PNG
        qr_res = client.get("/api/v1/display/qr-code")
        assert qr_res.status_code == 200
        assert qr_res.headers["content-type"] == "image/png"
        assert qr_res.content.startswith(b"\x89PNG")
    finally:
        settings.PUBLIC_PORTAL_URL = original_portal_url


