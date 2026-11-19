import uuid
from datetime import datetime, timezone
import pytest
from sqlalchemy.exc import IntegrityError
from app.infrastructure.database.models import (
    DBVisitor,
    DBPhoto,
    DBAdminUser,
    DBSlideshowSettings,
)
from app.domain.entities.models import PhotoStatus

def test_create_visitor(db_session):
    visitor = DBVisitor(
        name="John Doe",
        session_token="test_token_1234567890abcdef",
        ip_address="127.0.0.1",
    )
    db_session.add(visitor)
    db_session.commit()
    db_session.refresh(visitor)

    assert visitor.id is not None
    assert visitor.name == "John Doe"
    assert visitor.session_token == "test_token_1234567890abcdef"
    assert visitor.created_at is not None

def test_visitor_unique_session_token(db_session):
    token = "duplicate_token"
    v1 = DBVisitor(name="Alice", session_token=token)
    v2 = DBVisitor(name="Bob", session_token=token)
    db_session.add(v1)
    db_session.commit()

    db_session.add(v2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()

def test_create_photo_with_consent_and_deletion_fields(db_session):
    visitor = DBVisitor(name="Sarah Connor", session_token=uuid.uuid4().hex)
    db_session.add(visitor)
    db_session.commit()

    now = datetime.now(timezone.utc)
    photo = DBPhoto(
        visitor_id=visitor.id,
        original_filename="selfie.jpg",
        storage_path="uploads/photo1.jpg",
        thumbnail_path="uploads/thumbnails/photo1.jpg",
        file_size_bytes=102400,
        mime_type="image/jpeg",
        width=1920,
        height=1080,
        consent_given=True,
        consent_given_at=now,
        consent_policy_version="v1.0",
        status=PhotoStatus.PENDING.value,
        is_deleted=False,
    )
    db_session.add(photo)
    db_session.commit()
    db_session.refresh(photo)

    assert photo.id is not None
    assert photo.consent_given is True
    assert photo.consent_policy_version == "v1.0"
    assert photo.consent_given_at is not None
    assert photo.status == "PENDING"
    assert photo.is_deleted is False
    assert photo.visitor.name == "Sarah Connor"

def test_create_admin_user(db_session):
    admin = DBAdminUser(
        username="admin_test",
        email="admin@test.local",
        hashed_password="hashed_secret_password",
        role="ADMIN",
        is_active=True,
    )
    db_session.add(admin)
    db_session.commit()
    db_session.refresh(admin)

    assert admin.id is not None
    assert admin.username == "admin_test"
    assert admin.role == "ADMIN"
    assert admin.is_active is True

def test_slideshow_settings_defaults(db_session):
    settings_obj = DBSlideshowSettings(id=1)
    db_session.add(settings_obj)
    db_session.commit()
    db_session.refresh(settings_obj)

    assert settings_obj.id == 1
    assert settings_obj.slide_duration_seconds == 10
    assert settings_obj.transition_effect == "FADE"
    assert settings_obj.show_visitor_name is True
    assert settings_obj.shuffle_playback is False
    assert settings_obj.refresh_interval_seconds == 15
