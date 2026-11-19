from io import BytesIO
from typing import Optional
import qrcode
from fastapi import APIRouter, Depends, HTTPException, Response, status
from app.core.config import settings
from app.application.dtos.schemas import DisplayPhotosResponse, DisplaySettingsResponse
from app.application.use_cases.slideshow_use_cases import (
    GetSlideshowFeedUseCase,
    GetSlideshowSettingsUseCase,
)
from app.infrastructure.repositories.sqlalchemy_repositories import (
    SqlAlchemyPhotoRepository,
    SqlAlchemySettingsRepository,
)
from app.presentation.dependencies.auth import get_photo_repo, get_settings_repo

router = APIRouter(prefix="/display", tags=["Public Smart TV Display"])

@router.get("/photos", response_model=DisplayPhotosResponse)
def get_display_photos(
    photo_repo: SqlAlchemyPhotoRepository = Depends(get_photo_repo),
    settings_repo: SqlAlchemySettingsRepository = Depends(get_settings_repo),
):
    """
    Public continuous Smart TV slideshow photo feed.
    SECURITY & PRIVACY RULES:
    1. Returns ONLY photos with status APPROVED.
    2. Requires visitor explicit consent (consent_given == True).
    3. Excludes any deleted photos (is_deleted == False) immediately.
    4. Excludes any pending or rejected photos.
    5. Excludes photos whose file does not exist on disk.
    6. Respects slideshow_enabled (if false, returns empty photos list).
    7. Respects shuffle setting.
    8. Does not expose private visitor tokens, emails, or filesystem storage paths.
    """
    use_case = GetSlideshowFeedUseCase(photo_repo, settings_repo)
    result = use_case.execute()
    return DisplayPhotosResponse(**result)


def resolve_portal_url(configured_url: Optional[str]) -> str:
    """
    Resolves the public visitor portal URL for the Smart TV display and QR code.
    In production: Strictly requires a valid public HTTPS URL and forbids localhost fallbacks.
    In development: Allows configured URL or defaults to settings.PUBLIC_PORTAL_URL (e.g. http://127.0.0.1:3000).
    """
    clean_url = (configured_url or "").strip()
    if settings.is_production:
        # Check DB setting first
        if clean_url:
            if clean_url.lower().startswith("https://") and not any(h in clean_url.lower() for h in ("localhost", "127.0.0.1", "0.0.0.0")):
                return clean_url

        # Fallback to configured settings.PUBLIC_PORTAL_URL in production
        fallback = (settings.PUBLIC_PORTAL_URL or "").strip()
        if fallback and fallback.lower().startswith("https://") and not any(h in fallback.lower() for h in ("localhost", "127.0.0.1", "0.0.0.0")):
            return fallback

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Production configuration error: A valid public HTTPS visitor portal URL is required.",
        )

    # Development / local network mode:
    env_portal = (settings.PUBLIC_PORTAL_URL or "").strip()
    if clean_url:
        # If DB has a custom non-localhost URL, use it
        if not any(h in clean_url.lower() for h in ("localhost", "127.0.0.1")):
            return clean_url
        # If DB was left on localhost but env configures a LAN IP or custom URL, prefer env
        if env_portal and not any(h in env_portal.lower() for h in ("localhost", "127.0.0.1")):
            return env_portal
        return clean_url

    return env_portal or "http://127.0.0.1:3000"


@router.get("/settings", response_model=DisplaySettingsResponse)
def get_display_settings(
    settings_repo: SqlAlchemySettingsRepository = Depends(get_settings_repo),
):
    """
    Public Smart TV slideshow configuration.
    Returns timing, transitions, visitor name display flag, autoplay, enabled state,
    and verified visitor portal URL.
    """
    use_case = GetSlideshowSettingsUseCase(settings_repo)
    settings_entity = use_case.execute()
    portal_url = resolve_portal_url(settings_entity.visitor_portal_url)

    resp = DisplaySettingsResponse.model_validate(settings_entity)
    resp.portal_url = portal_url
    return resp


@router.get("/qr-code")
def get_display_qr_code(
    settings_repo: SqlAlchemySettingsRepository = Depends(get_settings_repo),
):
    """
    Generates a crisp PNG QR code containing the public visitor portal URL.
    Smart TVs display this QR code so visitors can scan and upload photos.
    In production, strictly verifies the URL is public HTTPS and not a localhost address.
    """
    settings_entity = settings_repo.get_settings()
    portal_url = resolve_portal_url(settings_entity.visitor_portal_url)

    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=10,
        border=2,
    )
    qr.add_data(portal_url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    buf = BytesIO()
    img.save(buf, format="PNG")
    return Response(content=buf.getvalue(), media_type="image/png")
