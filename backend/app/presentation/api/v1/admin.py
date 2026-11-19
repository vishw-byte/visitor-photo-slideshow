from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.application.dtos.schemas import (
    AdminLoginRequest,
    TokenResponse,
    DashboardStatsResponse,
    AdminPhotoDetailResponse,
    RejectPhotoRequest,
    SettingsResponse,
    SettingsUpdateRequest,
)
from app.application.use_cases.admin_use_cases import (
    AdminLoginUseCase,
    GetDashboardStatsUseCase,
    GetPhotosByStatusUseCase,
    ApprovePhotoUseCase,
    RejectPhotoUseCase,
)
from app.application.use_cases.slideshow_use_cases import (
    GetSlideshowSettingsUseCase,
    UpdateSlideshowSettingsUseCase,
)
from app.domain.entities.models import AdminUserEntity, PhotoStatus
from app.infrastructure.repositories.sqlalchemy_repositories import (
    SqlAlchemyAdminRepository,
    SqlAlchemyPhotoRepository,
    SqlAlchemyVisitorRepository,
    SqlAlchemySettingsRepository,
)
from app.presentation.dependencies.auth import (
    get_admin_repo,
    get_photo_repo,
    get_visitor_repo,
    get_settings_repo,
    get_current_admin,
)

router = APIRouter(prefix="/admin", tags=["Admin Portal"])

@router.post("/login", response_model=TokenResponse)
def admin_login(
    payload: AdminLoginRequest,
    admin_repo: SqlAlchemyAdminRepository = Depends(get_admin_repo),
):
    """
    Authenticates an administrator with username/email and password.
    Returns a short-lived Bearer JWT access token.
    """
    try:
        use_case = AdminLoginUseCase(admin_repo)
        result = use_case.execute(payload.username, payload.password)
        return TokenResponse(
            access_token=result["access_token"],
            token_type="bearer",
            username=result["username"],
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))


@router.get("/dashboard", response_model=DashboardStatsResponse)
def get_admin_dashboard(
    admin: AdminUserEntity = Depends(get_current_admin),
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
    visitor_repo: SqlAlchemyVisitorRepository = Depends(get_visitor_repo),
):
    """
    Returns high-level statistics for the admin dashboard:
    total photos, pending, approved, rejected, and total visitors.
    """
    use_case = GetDashboardStatsUseCase(photo_repo=photo_repo, visitor_repo=visitor_repo)
    return use_case.execute()


@router.get("/photos/pending", response_model=list[AdminPhotoDetailResponse])
def get_pending_photos(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    admin: AdminUserEntity = Depends(get_current_admin),
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
):
    """Fetches moderation queue of pending photos with visitor details."""
    use_case = GetPhotosByStatusUseCase(photo_repo)
    items = use_case.execute(status=PhotoStatus.PENDING, skip=skip, limit=limit)
    return items


@router.get("/photos/approved", response_model=list[AdminPhotoDetailResponse])
def get_approved_photos(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    admin: AdminUserEntity = Depends(get_current_admin),
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
):
    """Fetches approved photos live on or queued for the slideshow."""
    use_case = GetPhotosByStatusUseCase(photo_repo)
    items = use_case.execute(status=PhotoStatus.APPROVED, skip=skip, limit=limit)
    return items


@router.get("/photos/rejected", response_model=list[AdminPhotoDetailResponse])
def get_rejected_photos(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    admin: AdminUserEntity = Depends(get_current_admin),
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
):
    """Fetches rejected photos with moderation notes."""
    use_case = GetPhotosByStatusUseCase(photo_repo)
    items = use_case.execute(status=PhotoStatus.REJECTED, skip=skip, limit=limit)
    return items


@router.patch("/photos/{photo_id}/approve", status_code=status.HTTP_200_OK)
def approve_photo(
    photo_id: str,
    admin: AdminUserEntity = Depends(get_current_admin),
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
):
    """
    Approves a visitor photo.
    Validates that:
    1. The photo exists and is not deleted.
    2. Explicit public-display consent was granted by the visitor.
    """
    try:
        use_case = ApprovePhotoUseCase(photo_repo)
        photo = use_case.execute(photo_id=photo_id, admin_id=admin.id)
        return {
            "id": photo.id,
            "status": photo.status,
            "reviewed_by": photo.reviewed_by,
            "reviewed_at": photo.reviewed_at,
            "detail": "Photo approved successfully",
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.patch("/photos/{photo_id}/reject", status_code=status.HTTP_200_OK)
def reject_photo(
    photo_id: str,
    payload: RejectPhotoRequest,
    admin: AdminUserEntity = Depends(get_current_admin),
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
):
    """
    Rejects a visitor photo with an audited explanation reason.
    Prevents photo from appearing on the public slideshow.
    """
    try:
        use_case = RejectPhotoUseCase(photo_repo)
        photo = use_case.execute(
            photo_id=photo_id,
            admin_id=admin.id,
            reason=payload.rejection_reason,
        )
        return {
            "id": photo.id,
            "status": photo.status,
            "rejection_reason": photo.rejection_reason,
            "reviewed_by": photo.reviewed_by,
            "reviewed_at": photo.reviewed_at,
            "detail": "Photo rejected",
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/settings", response_model=SettingsResponse)
def get_slideshow_settings(
    admin: AdminUserEntity = Depends(get_current_admin),
    settings_repo: SqlAlchemySettingsRepository = Depends(get_settings_repo),
):
    """Retrieves current slideshow display configuration."""
    use_case = GetSlideshowSettingsUseCase(settings_repo)
    entity = use_case.execute()
    return SettingsResponse.model_validate(entity.model_dump())


@router.put("/settings", response_model=SettingsResponse)
def update_slideshow_settings(
    payload: SettingsUpdateRequest,
    admin: AdminUserEntity = Depends(get_current_admin),
    settings_repo: SqlAlchemySettingsRepository = Depends(get_settings_repo),
):
    """Updates slideshow display timings, transition styles, and autoplay preferences."""
    use_case = UpdateSlideshowSettingsUseCase(settings_repo)
    updated = use_case.execute(payload.model_dump(exclude_unset=True))
    return SettingsResponse.model_validate(updated.model_dump())
