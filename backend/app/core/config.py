import os
from pathlib import Path
from typing import Union
from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent.parent

class Settings(BaseSettings):
    PROJECT_NAME: str = "Visitor Photo Slideshow API"
    VERSION: str = "1.0.0"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    
    # Security
    SECRET_KEY: str = "local-dev-secret-key-32-chars-minimum-entropy-abc123"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    
    # Initial Admin Seed Credentials
    ADMIN_DEFAULT_USERNAME: str = "admin"
    ADMIN_DEFAULT_PASSWORD: str = "ChangeMeInProduction123!"
    
    # Database: SQLite by default for instant local execution, or PostgreSQL via DATABASE_URL
    DATABASE_URL: str = "sqlite:///./slideshow.db"
    
    # File Storage
    UPLOAD_DIR: str = str(BASE_DIR / "uploads")
    THUMBNAIL_DIR: str = str(BASE_DIR / "uploads" / "thumbnails")
    MAX_FILE_SIZE_MB: int = 15
    MAX_UPLOAD_BATCH_SIZE: int = 10
    ALLOWED_IMAGE_TYPES: list[str] = [
        "image/jpeg",
        "image/jpg",
        "image/png",
        "image/webp",
    ]
    
    # Public Visitor Portal URL (for Smart TV QR Code generation)
    PUBLIC_PORTAL_URL: str = "http://127.0.0.1:3000"
    
    # CORS
    CORS_ORIGINS: Union[list[str], str] = ["*"]

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT.lower() in ("production", "prod")

    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        if self.is_production:
            # 1. SECRET_KEY validation: Must be non-default and at least 32 chars
            if (
                not self.SECRET_KEY
                or self.SECRET_KEY == "local-dev-secret-key-32-chars-minimum-entropy-abc123"
                or len(self.SECRET_KEY) < 32
            ):
                raise ValueError(
                    "Production security failure: SECRET_KEY must be set in environment variables "
                    "with at least 32 characters and cannot use the development default."
                )

            # 2. PUBLIC_PORTAL_URL validation: Must start with https:// and not be localhost
            portal = (self.PUBLIC_PORTAL_URL or "").strip()
            if (
                not portal
                or not portal.lower().startswith("https://")
                or any(h in portal.lower() for h in ("localhost", "127.0.0.1", "0.0.0.0"))
            ):
                raise ValueError(
                    "Production configuration failure: PUBLIC_PORTAL_URL is required in production, "
                    "must start with 'https://', and cannot be a localhost address."
                )

            # 3. ADMIN_DEFAULT_PASSWORD: Must be changed
            if self.ADMIN_DEFAULT_PASSWORD == "ChangeMeInProduction123!":
                raise ValueError(
                    "Production security failure: ADMIN_DEFAULT_PASSWORD must be changed from the development default."
                )

            # 4. CORS_ORIGINS: No wildcard in production
            if "*" in self.CORS_ORIGINS:
                raise ValueError(
                    "Production security failure: CORS_ORIGINS cannot contain '*' in production. "
                    "Specify exact allowed domains."
                )
        return self

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, list[str]]) -> list[str]:
        if isinstance(v, str):
            if v == "*":
                return ["*"]
            return [i.strip() for i in v.split(",") if i.strip()]
        return v
    
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()

# Ensure local upload directories exist
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
os.makedirs(settings.THUMBNAIL_DIR, exist_ok=True)
