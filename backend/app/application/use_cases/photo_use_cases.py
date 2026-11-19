from datetime import datetime, timezone
from typing import Optional
from app.core.config import settings
from app.domain.interfaces.repositories import (
    IVisitorRepository,
    IPhotoRepository,
    IStorageService,
)
from app.domain.entities.models import PhotoEntity

class UploadPhotoUseCase:
    def __init__(
        self,
        visitor_repo: IVisitorRepository,
        photo_repo: IPhotoRepository,
        storage_service: IStorageService,
    ):
        self.visitor_repo = visitor_repo
        self.photo_repo = photo_repo
        self.storage_service = storage_service

    def execute(
        self,
        session_token: str,
        file_bytes: bytes,
        original_filename: str,
        content_type: str,
        consent_given: bool,
        consent_policy_version: Optional[str] = "v1.0",
    ) -> PhotoEntity:
        # 1. Validate visitor session
        visitor = self.visitor_repo.get_by_session_token(session_token)
        if not visitor:
            raise ValueError("Invalid or expired visitor session")

        # 2. Enforce explicit consent requirement
        if not consent_given:
            raise ValueError("Consent for public display is required to upload photos")

        # 3. Enforce file size limit
        max_bytes = settings.MAX_FILE_SIZE_MB * 1024 * 1024
        if len(file_bytes) > max_bytes:
            raise ValueError(f"File size exceeds maximum allowed limit of {settings.MAX_FILE_SIZE_MB}MB")

        if len(file_bytes) == 0:
            raise ValueError("Empty file uploaded")

        # 4. Validate and sanitize image (enforces magic bytes + Pillow raster decoding)
        storage_path, thumbnail_path, width, height = self.storage_service.save_image(
            file_bytes=file_bytes,
            original_filename=original_filename,
            content_type=content_type,
        )

        consent_given_at = datetime.now(timezone.utc)

        # 5. Create photo record in database (strictly PENDING status)
        photo = self.photo_repo.create(
            visitor_id=visitor.id,
            original_filename=original_filename,
            storage_path=storage_path,
            thumbnail_path=thumbnail_path,
            file_size_bytes=len(file_bytes),
            mime_type=content_type,
            width=width,
            height=height,
            consent_given=True,
            consent_given_at=consent_given_at,
            consent_policy_version=consent_policy_version,
        )

        self.visitor_repo.update_last_active(visitor.id)
        return photo


class UploadBatchPhotosUseCase:
    def __init__(
        self,
        visitor_repo: IVisitorRepository,
        photo_repo: IPhotoRepository,
        storage_service: IStorageService,
    ):
        self.upload_single = UploadPhotoUseCase(visitor_repo, photo_repo, storage_service)

    def execute(
        self,
        session_token: str,
        files: list[tuple[bytes, str, str]],  # list of (file_bytes, filename, content_type)
        consent_given: bool,
        consent_policy_version: Optional[str] = "v1.0",
    ) -> list[PhotoEntity]:
        if not files:
            raise ValueError("No files provided for upload")

        if len(files) > settings.MAX_UPLOAD_BATCH_SIZE:
            raise ValueError(f"Upload batch exceeds maximum allowed limit of {settings.MAX_UPLOAD_BATCH_SIZE} photos")

        uploaded_photos = []
        for file_bytes, filename, content_type in files:
            photo = self.upload_single.execute(
                session_token=session_token,
                file_bytes=file_bytes,
                original_filename=filename,
                content_type=content_type,
                consent_given=consent_given,
                consent_policy_version=consent_policy_version,
            )
            uploaded_photos.append(photo)

        return uploaded_photos
