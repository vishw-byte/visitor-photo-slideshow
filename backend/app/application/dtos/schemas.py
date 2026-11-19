from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict, field_validator, AliasChoices
from app.domain.entities.models import PhotoStatus
from app.core.config import settings

# Visitor DTOs
class VisitorRegisterRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100, description="Visitor display name")
    email: Optional[str] = Field(None, max_length=120, description="Optional visitor email address")

class VisitorResponse(BaseModel):
    id: str
    name: str
    email: Optional[str] = None
    session_token: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# Photo DTOs
class PhotoUploadResponse(BaseModel):
    id: str
    original_filename: str
    thumbnail_url: str
    photo_url: str
    status: PhotoStatus
    consent_given: bool
    consent_given_at: Optional[datetime] = None
    consent_policy_version: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class PhotoBatchUploadResponse(BaseModel):
    uploaded_count: int
    photos: list[PhotoUploadResponse]

class PhotoDetailResponse(BaseModel):
    id: str
    visitor_id: str
    original_filename: str
    thumbnail_url: str
    photo_url: str
    status: PhotoStatus
    consent_given: bool
    consent_given_at: Optional[datetime] = None
    consent_policy_version: Optional[str] = None
    is_deleted: bool = False
    rejection_reason: Optional[str] = None
    created_at: datetime
    width: Optional[int] = None
    height: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)

class AdminPhotoDetailResponse(BaseModel):
    id: str
    visitor_id: str
    visitor_name: str
    visitor_email: Optional[str] = None
    original_filename: str
    thumbnail_url: str
    photo_url: str
    status: PhotoStatus
    consent_given: bool
    consent_given_at: Optional[datetime] = None
    consent_policy_version: Optional[str] = None
    rejection_reason: Optional[str] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    created_at: datetime
    width: Optional[int] = None
    height: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)

class PhotoFeedItemResponse(BaseModel):
    id: str
    visitor_name: str
    photo_url: str
    thumbnail_url: str
    width: Optional[int] = None
    height: Optional[int] = None
    created_at: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

# Admin DTOs
class AdminLoginRequest(BaseModel):
    username: str = Field(..., min_length=1, description="Admin username or email")
    password: str = Field(..., min_length=1, description="Admin password")

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    username: str

class DashboardStatsResponse(BaseModel):
    total_photos: int
    pending_photos: int
    approved_photos: int
    rejected_photos: int
    total_visitors: int

    model_config = ConfigDict(from_attributes=True)

class RejectPhotoRequest(BaseModel):
    rejection_reason: str = Field(
        ...,
        validation_alias=AliasChoices("rejection_reason", "reason"),
        min_length=1,
        max_length=255,
        description="Reason for rejecting the photo",
    )

class PhotoModerationRequest(BaseModel):
    status: PhotoStatus
    rejection_reason: Optional[str] = None

class BatchModerationRequest(BaseModel):
    photo_ids: list[str]
    status: PhotoStatus
    rejection_reason: Optional[str] = None

# Settings DTOs
class SettingsResponse(BaseModel):
    slide_duration_seconds: int
    slideshow_autoplay: bool
    slideshow_enabled: bool
    transition_effect: str
    show_visitor_name: bool
    shuffle_playback: bool
    refresh_interval_seconds: int
    show_qr_code: bool = True
    visitor_portal_url: Optional[str] = None
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

class SettingsUpdateRequest(BaseModel):
    slide_duration_seconds: Optional[int] = Field(None, ge=3, le=120)
    slideshow_autoplay: Optional[bool] = None
    slideshow_enabled: Optional[bool] = None
    transition_effect: Optional[str] = None
    show_visitor_name: Optional[bool] = None
    shuffle_playback: Optional[bool] = None
    refresh_interval_seconds: Optional[int] = Field(None, ge=5, le=300)
    show_qr_code: Optional[bool] = None
    visitor_portal_url: Optional[str] = Field(None, max_length=255)

    @field_validator("visitor_portal_url")
    @classmethod
    def validate_visitor_portal_url(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        v = v.strip()
        if not v:
            return None
        if settings.is_production:
            if not v.lower().startswith("https://"):
                raise ValueError("In production, the visitor portal URL must start with 'https://'.")
            if any(h in v.lower() for h in ("localhost", "127.0.0.1", "0.0.0.0")):
                raise ValueError("In production, the visitor portal URL cannot be a localhost address.")
        return v

# Public Display DTOs (Phase 4 & 5)
class DisplayPhotoItem(BaseModel):
    id: str
    url: str
    visitor_name: str
    created_at: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None

class DisplayPhotosResponse(BaseModel):
    photos: list[DisplayPhotoItem]
    total_count: int
    slideshow_enabled: bool

class DisplaySettingsResponse(BaseModel):
    slide_duration_seconds: int
    transition_effect: str
    show_visitor_name: bool
    shuffle_playback: bool
    slideshow_autoplay: bool
    slideshow_enabled: bool
    refresh_interval_seconds: int
    show_qr_code: bool = True
    visitor_portal_url: Optional[str] = None
    portal_url: Optional[str] = None
    qr_code_url: str = "/api/v1/display/qr-code"
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
