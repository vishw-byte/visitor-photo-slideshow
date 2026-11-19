from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from typing import Optional
from app.application.dtos.schemas import (
    PhotoUploadResponse,
    PhotoBatchUploadResponse,
    PhotoDetailResponse,
)
from app.application.use_cases.photo_use_cases import UploadBatchPhotosUseCase
from app.application.use_cases.visitor_use_cases import GetVisitorPhotosUseCase, DeleteVisitorPhotoUseCase
from app.domain.entities.models import VisitorEntity
from app.infrastructure.repositories.sqlalchemy_repositories import (
    SqlAlchemyPhotoRepository,
    SqlAlchemyVisitorRepository,
)
from app.infrastructure.storage.local_storage import LocalStorageService
from app.presentation.dependencies.auth import (
    get_current_visitor,
    get_photo_repo,
    get_visitor_repo,
    get_storage_service,
)

router = APIRouter(prefix="/photos", tags=["Photos"])

@router.post("/upload", response_model=PhotoBatchUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_photos(
    files: list[UploadFile] = File(...),
    consent_given: bool = Form(...),
    consent_policy_version: Optional[str] = Form("v1.0"),
    visitor: VisitorEntity = Depends(get_current_visitor),
    visitor_repo: SqlAlchemyVisitorRepository = Depends(get_visitor_repo),
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
    storage_service: LocalStorageService = Depends(get_storage_service),
):
    """
    Uploads one or multiple photos for the current visitor.
    Requirements enforced:
    - Public display consent is mandatory.
    - Strict magic-byte file signature validation (JPEG, PNG, WebP).
    - Image size and batch count limits enforced.
    - EXIF stripped, optimized full image + thumbnail generated.
    - Initial status is strictly PENDING.
    - Never exposes private storage paths.
    """
    if not consent_given:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Public display consent is required before uploading photos.",
        )

    try:
        file_payloads = []
        for file in files:
            file_bytes = await file.read()
            content_type = file.content_type or "image/jpeg"
            file_payloads.append((file_bytes, file.filename or "photo.jpg", content_type))

        use_case = UploadBatchPhotosUseCase(
            visitor_repo=visitor_repo,
            photo_repo=photo_repo,
            storage_service=storage_service,
        )
        created_photos = use_case.execute(
            session_token=visitor.session_token,
            files=file_payloads,
            consent_given=consent_given,
            consent_policy_version=consent_policy_version,
        )

        responses = [
            PhotoUploadResponse(
                id=p.id,
                original_filename=p.original_filename,
                thumbnail_url=f"/api/v1/media/thumbnails/{p.id}",
                photo_url=f"/api/v1/media/photos/{p.id}",
                status=p.status,
                consent_given=p.consent_given,
                consent_given_at=p.consent_given_at,
                consent_policy_version=p.consent_policy_version,
                created_at=p.created_at,
            )
            for p in created_photos
        ]

        return PhotoBatchUploadResponse(
            uploaded_count=len(responses),
            photos=responses,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Upload failed: {str(e)}")


@router.get("/my-photos", response_model=list[PhotoDetailResponse])
@router.get("/my-uploads", response_model=list[PhotoDetailResponse], include_in_schema=False)
def get_my_photos(
    visitor: VisitorEntity = Depends(get_current_visitor),
    visitor_repo: SqlAlchemyVisitorRepository = Depends(get_visitor_repo),
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
):
    """
    Returns previously uploaded photos for the authenticated visitor.
    Shows review status: PENDING, APPROVED, REJECTED.
    Strictly isolated: visitors can only access their own uploads.
    """
    try:
        use_case = GetVisitorPhotosUseCase(photo_repo=photo_repo, visitor_repo=visitor_repo)
        photos = use_case.execute(visitor.session_token)
        return [
            PhotoDetailResponse(
                id=p.id,
                visitor_id=p.visitor_id,
                original_filename=p.original_filename,
                thumbnail_url=f"/api/v1/media/thumbnails/{p.id}",
                photo_url=f"/api/v1/media/photos/{p.id}",
                status=p.status,
                consent_given=p.consent_given,
                consent_given_at=p.consent_given_at,
                consent_policy_version=p.consent_policy_version,
                is_deleted=p.is_deleted,
                rejection_reason=p.rejection_reason,
                created_at=p.created_at,
                width=p.width,
                height=p.height,
            )
            for p in photos
        ]
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.delete("/{photo_id}", status_code=status.HTTP_200_OK)
def delete_my_photo(
    photo_id: str,
    visitor: VisitorEntity = Depends(get_current_visitor),
    visitor_repo: SqlAlchemyVisitorRepository = Depends(get_visitor_repo),
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
    storage_service: LocalStorageService = Depends(get_storage_service),
):
    """
    Allows a visitor to delete any of their own uploaded photos.
    Immediately purges disk storage and flags the record as deleted,
    preventing any public slideshow exposure.
    """
    try:
        use_case = DeleteVisitorPhotoUseCase(
            photo_repo=photo_repo,
            visitor_repo=visitor_repo,
            storage_service=storage_service,
        )
        success = use_case.execute(photo_id=photo_id, session_token=visitor.session_token)
        if not success:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo not found")
        return {"detail": "Photo deleted successfully and removed from slideshow"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
