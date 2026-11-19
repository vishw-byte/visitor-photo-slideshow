import io
import pytest
from PIL import Image
from app.core.config import settings

def create_image_bytes(format: str = "JPEG", size: tuple = (150, 150), color: str = "green") -> bytes:
    img = Image.new("RGB", size, color=color)
    buf = io.BytesIO()
    img.save(buf, format=format)
    return buf.getvalue()

def test_visitor_registration(client):
    # 1. Register with name and email
    resp = client.post("/api/v1/visitors/register", json={"name": "Alice Cooper", "email": "alice@example.com"})
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "Alice Cooper"
    assert data["email"] == "alice@example.com"
    assert len(data["session_token"]) >= 40
    assert "id" in data

    # 2. Register with empty name fails
    bad_resp = client.post("/api/v1/visitors/register", json={"name": "   ", "email": "bad@example.com"})
    assert bad_resp.status_code == 400
    assert "cannot be empty" in bad_resp.json()["detail"]

def test_duplicate_visitor_handling(client):
    """Registering with an existing name creates a distinct, secure session for that device."""
    resp1 = client.post("/api/v1/visitors/register", json={"name": "Same Name", "email": "user@example.com"})
    resp2 = client.post("/api/v1/visitors/register", json={"name": "Same Name", "email": "user@example.com"})
    assert resp1.status_code == 201
    assert resp2.status_code == 201
    # Distinct sessions
    assert resp1.json()["session_token"] != resp2.json()["session_token"]
    assert resp1.json()["id"] != resp2.json()["id"]

def test_valid_image_uploads_and_pending_status(client):
    # Register visitor
    reg = client.post("/api/v1/visitors/register", json={"name": "Bob Photographer"})
    token = reg.json()["session_token"]
    headers = {"X-Visitor-Token": token}

    jpeg_bytes = create_image_bytes("JPEG", color="blue")
    png_bytes = create_image_bytes("PNG", color="red")

    resp = client.post(
        "/api/v1/photos/upload",
        files=[
            ("files", ("photo1.jpg", jpeg_bytes, "image/jpeg")),
            ("files", ("photo2.png", png_bytes, "image/png")),
        ],
        data={"consent_given": "true", "consent_policy_version": "v1.0"},
        headers=headers,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["uploaded_count"] == 2
    for p in data["photos"]:
        # Requirement: initial status must strictly be PENDING
        assert p["status"] == "PENDING"
        assert p["consent_given"] is True
        assert p["consent_policy_version"] == "v1.0"
        assert p["consent_given_at"] is not None
        # Requirement: never expose raw filesystem paths
        assert "storage_path" not in p
        assert p["photo_url"].startswith("/api/v1/media/photos/")
        assert p["thumbnail_url"].startswith("/api/v1/media/thumbnails/")

def test_missing_consent_rejection(client):
    reg = client.post("/api/v1/visitors/register", json={"name": "No Consent Visitor"})
    token = reg.json()["session_token"]
    headers = {"X-Visitor-Token": token}

    img_bytes = create_image_bytes("JPEG")
    resp = client.post(
        "/api/v1/photos/upload",
        files=[("files", ("pic.jpg", img_bytes, "image/jpeg"))],
        data={"consent_given": "false"},
        headers=headers,
    )
    assert resp.status_code == 400
    assert "consent is required" in resp.json()["detail"].lower()

def test_invalid_image_magic_bytes_rejection(client):
    reg = client.post("/api/v1/visitors/register", json={"name": "Hacker Attempt"})
    token = reg.json()["session_token"]
    headers = {"X-Visitor-Token": token}

    malicious_bytes = b"<?php phpinfo(); ?><html><body>Not an image</body></html>"
    resp = client.post(
        "/api/v1/photos/upload",
        files=[("files", ("fake.jpg", malicious_bytes, "image/jpeg"))],
        data={"consent_given": "true"},
        headers=headers,
    )
    assert resp.status_code == 400
    assert "invalid file signature" in resp.json()["detail"].lower()

def test_oversized_image_rejection(client, monkeypatch):
    reg = client.post("/api/v1/visitors/register", json={"name": "Big Uploader"})
    token = reg.json()["session_token"]
    headers = {"X-Visitor-Token": token}

    # Temporarily set max size to 0.001 MB (1KB) to test limit
    monkeypatch.setattr(settings, "MAX_FILE_SIZE_MB", 0.001)

    large_bytes = create_image_bytes("JPEG", size=(500, 500))
    resp = client.post(
        "/api/v1/photos/upload",
        files=[("files", ("large.jpg", large_bytes, "image/jpeg"))],
        data={"consent_given": "true"},
        headers=headers,
    )
    assert resp.status_code == 400
    assert "exceeds maximum allowed limit" in resp.json()["detail"]

def test_batch_count_limit_enforcement(client, monkeypatch):
    reg = client.post("/api/v1/visitors/register", json={"name": "Batch Tester"})
    token = reg.json()["session_token"]
    headers = {"X-Visitor-Token": token}

    monkeypatch.setattr(settings, "MAX_UPLOAD_BATCH_SIZE", 2)
    img_bytes = create_image_bytes("JPEG")

    resp = client.post(
        "/api/v1/photos/upload",
        files=[
            ("files", ("p1.jpg", img_bytes, "image/jpeg")),
            ("files", ("p2.jpg", img_bytes, "image/jpeg")),
            ("files", ("p3.jpg", img_bytes, "image/jpeg")),
        ],
        data={"consent_given": "true"},
        headers=headers,
    )
    assert resp.status_code == 400
    assert "batch exceeds maximum allowed limit" in resp.json()["detail"]

def test_visitor_photo_history_and_isolation(client):
    # Register Alice and Bob
    alice = client.post("/api/v1/visitors/register", json={"name": "Alice History"}).json()
    bob = client.post("/api/v1/visitors/register", json={"name": "Bob History"}).json()

    alice_headers = {"X-Visitor-Token": alice["session_token"]}
    bob_headers = {"X-Visitor-Token": bob["session_token"]}

    # Alice uploads 2 photos
    img_bytes = create_image_bytes("JPEG")
    client.post(
        "/api/v1/photos/upload",
        files=[
            ("files", ("a1.jpg", img_bytes, "image/jpeg")),
            ("files", ("a2.jpg", img_bytes, "image/jpeg")),
        ],
        data={"consent_given": "true"},
        headers=alice_headers,
    )

    # Bob uploads 1 photo
    client.post(
        "/api/v1/photos/upload",
        files=[("files", ("b1.jpg", img_bytes, "image/jpeg"))],
        data={"consent_given": "true"},
        headers=bob_headers,
    )

    # Alice queries /my-photos -> should only see 2
    alice_photos = client.get("/api/v1/photos/my-photos", headers=alice_headers).json()
    assert len(alice_photos) == 2
    for p in alice_photos:
        assert p["visitor_id"] == alice["id"]

    # Bob queries /my-photos -> should only see 1
    bob_photos = client.get("/api/v1/photos/my-photos", headers=bob_headers).json()
    assert len(bob_photos) == 1
    assert bob_photos[0]["visitor_id"] == bob["id"]

def test_unauthorized_photo_access(client):
    # Missing X-Visitor-Token header -> 401
    resp = client.get("/api/v1/photos/my-photos")
    assert resp.status_code == 401

    # Fake X-Visitor-Token header -> 401
    resp_fake = client.get("/api/v1/photos/my-photos", headers={"X-Visitor-Token": "bad-token-xyz"})
    assert resp_fake.status_code == 401

def test_photo_deletion_flow(client):
    alice = client.post("/api/v1/visitors/register", json={"name": "Alice Deletion"}).json()
    bob = client.post("/api/v1/visitors/register", json={"name": "Bob Intruder"}).json()

    alice_headers = {"X-Visitor-Token": alice["session_token"]}
    bob_headers = {"X-Visitor-Token": bob["session_token"]}

    img_bytes = create_image_bytes("JPEG")
    upload_res = client.post(
        "/api/v1/photos/upload",
        files=[("files", ("pic.jpg", img_bytes, "image/jpeg"))],
        data={"consent_given": "true"},
        headers=alice_headers,
    ).json()

    photo_id = upload_res["photos"][0]["id"]

    # Bob tries to delete Alice's photo -> 403 Forbidden
    bob_del = client.delete(f"/api/v1/photos/{photo_id}", headers=bob_headers)
    assert bob_del.status_code == 403

    # Alice deletes her own photo -> 200 OK
    alice_del = client.delete(f"/api/v1/photos/{photo_id}", headers=alice_headers)
    assert alice_del.status_code == 200

    # Alice checks /my-photos -> photo is removed from active list
    alice_photos = client.get("/api/v1/photos/my-photos", headers=alice_headers).json()
    assert len(alice_photos) == 0
