from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from app.core.config import settings
from app.domain.entities.models import PhotoStatus, VisitorEntity, AdminUserEntity
from app.infrastructure.repositories.sqlalchemy_repositories import SqlAlchemyPhotoRepository
from app.presentation.dependencies.auth import (
    get_photo_repo,
    get_optional_visitor,
    get_optional_admin,
)

router = APIRouter(prefix="/media", tags=["Protected Media Gate"])

@router.get("/slideshow/{photo_id}")
def serve_slideshow_photo(
    photo_id: str,
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
):
    """
    Public Smart TV media route.
    STRICT SECURITY RULE:
    Only serves the photo if:
    1. status == APPROVED
    2. consent_given == True
    3. is_deleted == False
    Any pending, rejected, or deleted photo returns 404 immediately.
    """
    photo = photo_repo.get_by_id(photo_id)
    if not photo or photo.is_deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo not found")

    if photo.status != PhotoStatus.APPROVED or not photo.consent_given:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Photo is not approved for public display",
        )

    file_path = Path(settings.UPLOAD_DIR) / photo.storage_path
    if not file_path.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Image file missing")

    return FileResponse(file_path, media_type="image/jpeg")


@router.get("/photos/{photo_id}")
def serve_full_photo(
    photo_id: str,
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
    visitor: VisitorEntity = Depends(get_optional_visitor),
    admin: AdminUserEntity = Depends(get_optional_admin),
):
    """
    Protected media route:
    Only accessible by:
    - Authenticated Admin, OR
    - The owning Visitor who uploaded this photo.
    """
    photo = photo_repo.get_by_id(photo_id)
    if not photo or photo.is_deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo not found")

    is_admin = admin is not None
    is_owner = visitor is not None and photo.visitor_id == visitor.id

    if not (is_admin or is_owner):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You do not have permission to view this photo",
        )

    file_path = Path(settings.UPLOAD_DIR) / photo.storage_path
    if not file_path.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Image file missing")

    return FileResponse(file_path, media_type="image/jpeg")


@router.get("/thumbnails/{photo_id}")
def serve_thumbnail(
    photo_id: str,
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
    visitor: VisitorEntity = Depends(get_optional_visitor),
    admin: AdminUserEntity = Depends(get_optional_admin),
):
    """
    Protected thumbnail route:
    Allowed if photo is APPROVED with consent, or if requester is Admin or owning Visitor.
    """
    photo = photo_repo.get_by_id(photo_id)
    if not photo or photo.is_deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Thumbnail not found")

    is_publicly_approved = (photo.status == PhotoStatus.APPROVED and photo.consent_given)
    is_admin = admin is not None
    is_owner = visitor is not None and photo.visitor_id == visitor.id

    if not (is_publicly_approved or is_admin or is_owner):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Thumbnail is not publicly available",
        )

    thumb_path = Path(settings.UPLOAD_DIR) / photo.thumbnail_path
    if not thumb_path.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Thumbnail file missing")

    return FileResponse(thumb_path, media_type="image/jpeg")
