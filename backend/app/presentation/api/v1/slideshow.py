from fastapi import APIRouter, Depends
from app.application.dtos.schemas import PhotoFeedItemResponse, SettingsResponse
from app.application.use_cases.slideshow_use_cases import (
    GetSlideshowFeedUseCase,
    GetSlideshowSettingsUseCase,
)
from app.infrastructure.repositories.sqlalchemy_repositories import (
    SqlAlchemyPhotoRepository,
    SqlAlchemySettingsRepository,
)
from app.presentation.dependencies.auth import get_photo_repo, get_settings_repo

router = APIRouter(prefix="/slideshow", tags=["Slideshow TV Feed"])

@router.get("/feed", response_model=list[PhotoFeedItemResponse])
def get_slideshow_feed(
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
    settings_repo: SqlAlchemySettingsRepository = Depends(get_settings_repo),
):
    """
    CRITICAL TV FEED ENDPOINT:
    Strictly serves photos where:
    - status == 'APPROVED'
    - consent_given == True
    - is_deleted == False
    """
    use_case = GetSlideshowFeedUseCase(photo_repo=photo_repo, settings_repo=settings_repo)
    result = use_case.execute()
    photos = result.get("photos", []) if isinstance(result, dict) else result
    return [
        PhotoFeedItemResponse(
            id=item["id"],
            visitor_name=item["visitor_name"],
            photo_url=f"/api/v1/media/slideshow/{item['id']}",
            thumbnail_url=f"/api/v1/media/thumbnails/{item['id']}",
            width=item["width"],
            height=item["height"],
            created_at=item["created_at"],
        )
        for item in photos
    ]


@router.get("/settings", response_model=SettingsResponse)
def get_slideshow_public_settings(
    settings_repo: SqlAlchemySettingsRepository = Depends(get_settings_repo),
):
    """Public read-only slideshow settings for Smart TV client."""
    use_case = GetSlideshowSettingsUseCase(settings_repo)
    settings = use_case.execute()
    return SettingsResponse.model_validate(settings)
