from app.domain.entities.models import SlideshowSettingsEntity
from app.domain.interfaces.repositories import IPhotoRepository, ISettingsRepository

class GetSlideshowFeedUseCase:
    def __init__(self, photo_repo: IPhotoRepository, settings_repo: ISettingsRepository):
        self.photo_repo = photo_repo
        self.settings_repo = settings_repo

    def execute(self, limit: int = 100) -> dict:
        settings = self.settings_repo.get_settings()
        if not settings.slideshow_enabled:
            return {
                "photos": [],
                "total_count": 0,
                "slideshow_enabled": False,
            }

        shuffle = settings.shuffle_playback
        photos = self.photo_repo.get_approved_with_consent(shuffle=shuffle, limit=limit)
        return {
            "photos": photos,
            "total_count": len(photos),
            "slideshow_enabled": True,
        }


class GetSlideshowSettingsUseCase:
    def __init__(self, settings_repo: ISettingsRepository):
        self.settings_repo = settings_repo

    def execute(self) -> SlideshowSettingsEntity:
        return self.settings_repo.get_settings()


class UpdateSlideshowSettingsUseCase:
    def __init__(self, settings_repo: ISettingsRepository):
        self.settings_repo = settings_repo

    def execute(self, updates: dict) -> SlideshowSettingsEntity:
        return self.settings_repo.update_settings(updates)
