from app.core.config import Settings

def test_default_settings():
    settings = Settings()
    assert settings.PROJECT_NAME == "Visitor Photo Slideshow API"
    assert settings.VERSION == "1.0.0"
    assert settings.DATABASE_URL.startswith("sqlite")
    assert settings.MAX_FILE_SIZE_MB == 15
    assert "image/jpeg" in settings.ALLOWED_IMAGE_TYPES

def test_cors_origins_parsing():
    # Test asterisk string
    s1 = Settings(CORS_ORIGINS="*")
    assert s1.CORS_ORIGINS == ["*"]

    # Test comma-separated string
    s2 = Settings(CORS_ORIGINS="http://localhost:3000, https://slideshow.app")
    assert s2.CORS_ORIGINS == ["http://localhost:3000", "https://slideshow.app"]

    # Test list directly
    s3 = Settings(CORS_ORIGINS=["http://localhost:3000"])
    assert s3.CORS_ORIGINS == ["http://localhost:3000"]


def test_production_settings_validation():
    import pytest

    # In production, default dev key must be rejected
    with pytest.raises(ValueError, match="SECRET_KEY"):
        Settings(
            ENVIRONMENT="production",
            SECRET_KEY="local-dev-secret-key-32-chars-minimum-entropy-abc123",
            PUBLIC_PORTAL_URL="https://photos.myevent.com",
            ADMIN_DEFAULT_PASSWORD="StrongProductionPassword999!",
            CORS_ORIGINS="https://photos.myevent.com",
        )

    # In production, localhost portal URL must be rejected
    with pytest.raises(ValueError, match="PUBLIC_PORTAL_URL"):
        Settings(
            ENVIRONMENT="production",
            SECRET_KEY="a-secure-random-production-key-with-over-32-chars",
            PUBLIC_PORTAL_URL="http://127.0.0.1:3000",
            ADMIN_DEFAULT_PASSWORD="StrongProductionPassword999!",
            CORS_ORIGINS="https://photos.myevent.com",
        )

    # In production, wildcard CORS must be rejected
    with pytest.raises(ValueError, match="CORS_ORIGINS"):
        Settings(
            ENVIRONMENT="production",
            SECRET_KEY="a-secure-random-production-key-with-over-32-chars",
            PUBLIC_PORTAL_URL="https://photos.myevent.com",
            ADMIN_DEFAULT_PASSWORD="StrongProductionPassword999!",
            CORS_ORIGINS="*",
        )

    # Valid production settings pass cleanly
    prod_settings = Settings(
        ENVIRONMENT="production",
        SECRET_KEY="a-secure-random-production-key-with-over-32-chars",
        PUBLIC_PORTAL_URL="https://photos.myevent.com",
        ADMIN_DEFAULT_PASSWORD="StrongProductionPassword999!",
        CORS_ORIGINS="https://photos.myevent.com",
    )
    assert prod_settings.is_production is True
    assert prod_settings.PUBLIC_PORTAL_URL == "https://photos.myevent.com"
