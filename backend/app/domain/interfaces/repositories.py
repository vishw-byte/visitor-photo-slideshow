from abc import ABC, abstractmethod
from typing import Optional
from datetime import datetime
from app.domain.entities.models import (
    VisitorEntity,
    PhotoEntity,
    PhotoStatus,
    AdminUserEntity,
    SlideshowSettingsEntity,
)

class IVisitorRepository(ABC):
    @abstractmethod
    def create(
        self,
        name: str,
        session_token: str,
        email: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> VisitorEntity:
        pass

    @abstractmethod
    def get_by_session_token(self, session_token: str) -> Optional[VisitorEntity]:
        pass

    @abstractmethod
    def get_by_id(self, visitor_id: str) -> Optional[VisitorEntity]:
        pass

    @abstractmethod
    def count_visitors(self) -> int:
        pass

    @abstractmethod
    def update_last_active(self, visitor_id: str) -> None:
        pass


class IPhotoRepository(ABC):
    @abstractmethod
    def create(
        self,
        visitor_id: str,
        original_filename: str,
        storage_path: str,
        thumbnail_path: str,
        file_size_bytes: int,
        mime_type: str,
        width: Optional[int],
        height: Optional[int],
        consent_given: bool,
        consent_given_at: Optional[datetime],
        consent_policy_version: Optional[str],
        status: PhotoStatus = PhotoStatus.PENDING,
    ) -> PhotoEntity:
        pass

    @abstractmethod
    def get_by_id(self, photo_id: str) -> Optional[PhotoEntity]:
        pass

    @abstractmethod
    def get_by_visitor_id(self, visitor_id: str, include_deleted: bool = False) -> list[PhotoEntity]:
        pass

    @abstractmethod
    def get_by_status_with_visitor(
        self,
        status: PhotoStatus,
        skip: int = 0,
        limit: int = 50,
    ) -> list[dict]:
        pass

    @abstractmethod
    def get_dashboard_counts(self) -> dict:
        pass

    @abstractmethod
    def get_approved_with_consent(self, shuffle: bool = False, limit: int = 100) -> list[dict]:
        pass

    @abstractmethod
    def update_status(
        self,
        photo_id: str,
        status: PhotoStatus,
        reviewed_by: str,
        rejection_reason: Optional[str] = None,
    ) -> Optional[PhotoEntity]:
        pass

    @abstractmethod
    def soft_delete(self, photo_id: str) -> bool:
        pass

    @abstractmethod
    def hard_delete(self, photo_id: str) -> bool:
        pass


class IAdminRepository(ABC):
    @abstractmethod
    def get_by_username_or_email(self, identifier: str) -> Optional[tuple[AdminUserEntity, str]]:
        pass

    @abstractmethod
    def get_by_id(self, admin_id: str) -> Optional[AdminUserEntity]:
        pass

    @abstractmethod
    def create_admin(self, username: str, hashed_password: str, email: Optional[str] = None) -> AdminUserEntity:
        pass


class ISettingsRepository(ABC):
    @abstractmethod
    def get_settings(self) -> SlideshowSettingsEntity:
        pass

    @abstractmethod
    def update_settings(self, updates: dict) -> SlideshowSettingsEntity:
        pass


class IStorageService(ABC):
    @abstractmethod
    def validate_magic_bytes(self, file_bytes: bytes) -> str:
        pass

    @abstractmethod
    def save_image(self, file_bytes: bytes, original_filename: str, content_type: str) -> tuple[str, str, int, int]:
        pass

    @abstractmethod
    def delete_image(self, storage_path: str, thumbnail_path: Optional[str] = None) -> None:
        pass
