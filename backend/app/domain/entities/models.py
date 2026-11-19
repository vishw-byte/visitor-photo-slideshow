from enum import Enum
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict

class PhotoStatus(str, Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"

class VisitorEntity(BaseModel):
    id: str
    name: str
    email: Optional[str] = None
    session_token: str
    ip_address: Optional[str] = None
    created_at: datetime
    last_active_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

class PhotoEntity(BaseModel):
    id: str
    visitor_id: str
    original_filename: str
    storage_path: str
    thumbnail_path: str
    file_size_bytes: int
    mime_type: str
    width: Optional[int] = None
    height: Optional[int] = None
    consent_given: bool
    consent_given_at: Optional[datetime] = None
    consent_policy_version: Optional[str] = None
    status: PhotoStatus
    is_deleted: bool = False
    deleted_at: Optional[datetime] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    rejection_reason: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class AdminUserEntity(BaseModel):
    id: str
    username: str
    email: Optional[str] = None
    role: str = "ADMIN"
    is_active: bool = True
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class SlideshowSettingsEntity(BaseModel):
    id: int = 1
    slide_duration_seconds: int = 10
    slideshow_autoplay: bool = True
    slideshow_enabled: bool = True
    transition_effect: str = "FADE"
    show_visitor_name: bool = True
    shuffle_playback: bool = False
    refresh_interval_seconds: int = 15
    show_qr_code: bool = True
    visitor_portal_url: Optional[str] = None
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
