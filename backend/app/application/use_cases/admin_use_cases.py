from typing import Optional
from app.core.security import verify_password, create_access_token
from app.domain.entities.models import PhotoEntity, PhotoStatus
from app.domain.interfaces.repositories import (
    IAdminRepository,
    IPhotoRepository,
    IVisitorRepository,
)

class AdminLoginUseCase:
    def __init__(self, admin_repo: IAdminRepository):
        self.admin_repo = admin_repo

    def execute(self, identifier: str, password: str) -> dict:
        result = self.admin_repo.get_by_username_or_email(identifier.strip())
        if not result:
            raise ValueError("Invalid credentials")
        
        admin, hashed_password = result
        if not admin.is_active:
            raise ValueError("Admin account is deactivated")

        if not verify_password(password, hashed_password):
            raise ValueError("Invalid credentials")

        token = create_access_token({
            "sub": admin.id,
            "username": admin.username,
            "role": admin.role,
        })
        return {"access_token": token, "username": admin.username}


class GetDashboardStatsUseCase:
    def __init__(self, photo_repo: IPhotoRepository, visitor_repo: IVisitorRepository):
        self.photo_repo = photo_repo
        self.visitor_repo = visitor_repo

    def execute(self) -> dict:
        counts = self.photo_repo.get_dashboard_counts()
        total_visitors = self.visitor_repo.count_visitors()
        counts["total_visitors"] = total_visitors
        return counts


class GetPhotosByStatusUseCase:
    def __init__(self, photo_repo: IPhotoRepository):
        self.photo_repo = photo_repo

    def execute(self, status: PhotoStatus, skip: int = 0, limit: int = 50) -> list[dict]:
        return self.photo_repo.get_by_status_with_visitor(status=status, skip=skip, limit=limit)


class ApprovePhotoUseCase:
    def __init__(self, photo_repo: IPhotoRepository):
        self.photo_repo = photo_repo

    def execute(self, photo_id: str, admin_id: str) -> PhotoEntity:
        photo = self.photo_repo.get_by_id(photo_id)
        if not photo or photo.is_deleted:
            raise ValueError("Photo not found or has been deleted by visitor")

        # RULE: A photo must have valid public-display consent before approval
        if not photo.consent_given:
            raise ValueError("Cannot approve photo: Public display consent was not granted by the visitor")

        updated = self.photo_repo.update_status(
            photo_id=photo_id,
            status=PhotoStatus.APPROVED,
            reviewed_by=admin_id,
            rejection_reason=None,
        )
        if not updated:
            raise ValueError("Failed to approve photo")
        return updated


class RejectPhotoUseCase:
    def __init__(self, photo_repo: IPhotoRepository):
        self.photo_repo = photo_repo

    def execute(self, photo_id: str, admin_id: str, reason: str) -> PhotoEntity:
        cleaned_reason = reason.strip()
        if not cleaned_reason:
            raise ValueError("A valid rejection reason must be provided")

        photo = self.photo_repo.get_by_id(photo_id)
        if not photo or photo.is_deleted:
            raise ValueError("Photo not found or has been deleted by visitor")

        updated = self.photo_repo.update_status(
            photo_id=photo_id,
            status=PhotoStatus.REJECTED,
            reviewed_by=admin_id,
            rejection_reason=cleaned_reason,
        )
        if not updated:
            raise ValueError("Failed to reject photo")
        return updated
