import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    String,
    Boolean,
    Integer,
    DateTime,
    ForeignKey,
)
from sqlalchemy.orm import relationship
from app.infrastructure.database.session import Base
from app.domain.entities.models import PhotoStatus

def get_utc_now():
    return datetime.now(timezone.utc)

class DBVisitor(Base):
    __tablename__ = "visitors"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(100), nullable=False)
    email = Column(String(120), nullable=True)
    session_token = Column(String(64), unique=True, index=True, nullable=False)
    ip_address = Column(String(45), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_now, nullable=False)
    last_active_at = Column(DateTime(timezone=True), default=get_utc_now, onupdate=get_utc_now, nullable=False)

    photos = relationship("DBPhoto", back_populates="visitor", cascade="all, delete-orphan")


class DBPhoto(Base):
    __tablename__ = "photos"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    visitor_id = Column(String(36), ForeignKey("visitors.id", ondelete="CASCADE"), nullable=False, index=True)
    original_filename = Column(String(255), nullable=False)
    storage_path = Column(String(500), nullable=False)
    thumbnail_path = Column(String(500), nullable=False)
    file_size_bytes = Column(Integer, nullable=False)
    mime_type = Column(String(50), nullable=False)
    width = Column(Integer, nullable=True)
    height = Column(Integer, nullable=True)
    
    # Consent fields
    consent_given = Column(Boolean, default=False, nullable=False)
    consent_given_at = Column(DateTime(timezone=True), nullable=True)
    consent_policy_version = Column(String(20), nullable=True)

    # Status & Moderation
    status = Column(String(20), default=PhotoStatus.PENDING.value, index=True, nullable=False)
    reviewed_by = Column(String(36), ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    rejection_reason = Column(String(255), nullable=True)

    # Deletion Lifecycle (soft-deletion for immediate slideshow eviction & auditing)
    is_deleted = Column(Boolean, default=False, index=True, nullable=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), default=get_utc_now, index=True, nullable=False)

    visitor = relationship("DBVisitor", back_populates="photos")
    reviewer = relationship("DBAdminUser", back_populates="reviewed_photos")


class DBAdminUser(Base):
    __tablename__ = "admin_users"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(120), unique=True, nullable=True)
    hashed_password = Column(String(255), nullable=False)
    role = Column(String(20), default="ADMIN", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=get_utc_now, nullable=False)

    reviewed_photos = relationship("DBPhoto", back_populates="reviewer")


class DBSlideshowSettings(Base):
    __tablename__ = "slideshow_settings"

    id = Column(Integer, primary_key=True, default=1)
    slide_duration_seconds = Column(Integer, default=10, nullable=False)
    slideshow_autoplay = Column(Boolean, default=True, nullable=False)
    slideshow_enabled = Column(Boolean, default=True, nullable=False)
    transition_effect = Column(String(50), default="FADE", nullable=False)
    show_visitor_name = Column(Boolean, default=True, nullable=False)
    shuffle_playback = Column(Boolean, default=False, nullable=False)
    refresh_interval_seconds = Column(Integer, default=15, nullable=False)
    show_qr_code = Column(Boolean, default=True, nullable=False)
    visitor_portal_url = Column(String(255), nullable=True)
    updated_at = Column(DateTime(timezone=True), default=get_utc_now, onupdate=get_utc_now, nullable=False)
