import io
import pytest
from PIL import Image
from app.infrastructure.storage.local_storage import LocalStorageService

def create_dummy_jpeg() -> bytes:
    img = Image.new("RGB", (100, 100), color="blue")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()

def create_dummy_png() -> bytes:
    img = Image.new("RGBA", (100, 100), color=(255, 0, 0, 128))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()

def test_valid_jpeg_magic_bytes(tmp_path):
    upload_dir = tmp_path / "uploads"
    thumb_dir = tmp_path / "thumbnails"
    service = LocalStorageService(upload_dir=str(upload_dir), thumbnail_dir=str(thumb_dir))
    jpeg_bytes = create_dummy_jpeg()
    
    # Check signature recognition
    mime = service.validate_magic_bytes(jpeg_bytes)
    assert mime == "image/jpeg"

    # Save and verify no exceptions
    storage_path, thumb_path, width, height = service.save_image(jpeg_bytes, "test.jpg", "image/jpeg")
    assert width == 100
    assert height == 100
    assert storage_path.endswith(".jpg")
    assert thumb_path.endswith(".jpg")

def test_valid_png_magic_bytes(tmp_path):
    upload_dir = tmp_path / "uploads"
    thumb_dir = tmp_path / "thumbnails"
    service = LocalStorageService(upload_dir=str(upload_dir), thumbnail_dir=str(thumb_dir))
    png_bytes = create_dummy_png()

    mime = service.validate_magic_bytes(png_bytes)
    assert mime == "image/png"

    storage_path, thumb_path, width, height = service.save_image(png_bytes, "test.png", "image/png")
    assert width == 100
    assert height == 100

def test_disguised_executable_rejected(tmp_path):
    """A malicious script or binary disguised with a .jpg filename must be rejected."""
    upload_dir = tmp_path / "uploads"
    thumb_dir = tmp_path / "thumbnails"
    service = LocalStorageService(upload_dir=str(upload_dir), thumbnail_dir=str(thumb_dir))
    
    malicious_bytes = b"<?php echo 'malicious payload'; ?>#!/bin/bash rm -rf /"
    
    with pytest.raises(ValueError, match="Invalid file signature"):
        service.validate_magic_bytes(malicious_bytes)

    with pytest.raises(ValueError, match="Invalid file signature"):
        service.save_image(malicious_bytes, "exploit.jpg", "image/jpeg")

def test_corrupt_truncated_bytes_rejected(tmp_path):
    upload_dir = tmp_path / "uploads"
    thumb_dir = tmp_path / "thumbnails"
    service = LocalStorageService(upload_dir=str(upload_dir), thumbnail_dir=str(thumb_dir))
    
    # Has JPEG header FF D8 FF but truncated/corrupt payload
    fake_header = b"\xff\xd8\xff\x00\x00corrupt"
    
    with pytest.raises(ValueError, match="Corrupt image or failed raster decoding"):
        service.save_image(fake_header, "corrupt.jpg", "image/jpeg")
