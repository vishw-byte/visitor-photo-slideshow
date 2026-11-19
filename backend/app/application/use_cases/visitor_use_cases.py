from typing import Optional
from app.core.security import generate_secure_visitor_token
from app.domain.interfaces.repositories import IVisitorRepository, IPhotoRepository, IStorageService
from app.domain.entities.models import VisitorEntity, PhotoEntity

class RegisterVisitorUseCase:
    def __init__(self, visitor_repo: IVisitorRepository):
        self.visitor_repo = visitor_repo

    def execute(self, name: str, email: Optional[str] = None, ip_address: Optional[str] = None) -> VisitorEntity:
        cleaned_name = name.strip()
        if not cleaned_name:
            raise ValueError("Visitor name cannot be empty")
        
        cleaned_email = email.strip().lower() if email and email.strip() else None
        
        # Cryptographically secure 256-bit token
        session_token = generate_secure_visitor_token()
        return self.visitor_repo.create(
            name=cleaned_name,
            email=cleaned_email,
            session_token=session_token,
            ip_address=ip_address,
        )


class GetVisitorPhotosUseCase:
    def __init__(self, photo_repo: IPhotoRepository, visitor_repo: IVisitorRepository):
        self.photo_repo = photo_repo
        self.visitor_repo = visitor_repo

    def execute(self, session_token: str) -> list[PhotoEntity]:
        visitor = self.visitor_repo.get_by_session_token(session_token)
        if not visitor:
            raise ValueError("Invalid visitor session")
        self.visitor_repo.update_last_active(visitor.id)
        # Returns only active, non-deleted photos for this visitor
        return self.photo_repo.get_by_visitor_id(visitor.id, include_deleted=False)


class DeleteVisitorPhotoUseCase:
    def __init__(self, photo_repo: IPhotoRepository, visitor_repo: IVisitorRepository, storage_service: IStorageService):
        self.photo_repo = photo_repo
        self.visitor_repo = visitor_repo
        self.storage_service = storage_service

    def execute(self, photo_id: str, session_token: str) -> bool:
        """
        Allows a visitor to delete ANY of their own uploaded photos,
        including photos that were already APPROVED and displayed.
        Immediately purges disk files and marks the record as deleted
        to evict it instantly from the public slideshow feed.
        """
        visitor = self.visitor_repo.get_by_session_token(session_token)
        if not visitor:
            raise ValueError("Invalid visitor session")

        photo = self.photo_repo.get_by_id(photo_id)
        if not photo or photo.visitor_id != visitor.id:
            raise ValueError("Photo not found or you do not have permission to delete it")

        if photo.is_deleted:
            return True

        # 1. Immediately delete files from disk
        self.storage_service.delete_image(photo.storage_path, photo.thumbnail_path)

        # 2. Mark as deleted in database (soft delete)
        success = self.photo_repo.soft_delete(photo_id)
        self.visitor_repo.update_last_active(visitor.id)
        return success
