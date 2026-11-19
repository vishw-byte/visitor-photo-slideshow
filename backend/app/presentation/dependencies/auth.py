from typing import Optional
from fastapi import Header, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.infrastructure.database.session import get_db
from app.infrastructure.repositories.sqlalchemy_repositories import (
    SqlAlchemyVisitorRepository,
    SqlAlchemyPhotoRepository,
    SqlAlchemyAdminRepository,
    SqlAlchemySettingsRepository,
)
from app.infrastructure.storage.local_storage import LocalStorageService
from app.core.security import decode_access_token
from app.domain.entities.models import AdminUserEntity, VisitorEntity

security_scheme = HTTPBearer(auto_error=False)

def get_storage_service() -> LocalStorageService:
    return LocalStorageService()

def get_visitor_repo(db: Session = Depends(get_db)) -> SqlAlchemyVisitorRepository:
    return SqlAlchemyVisitorRepository(db)

def get_photo_repo(db: Session = Depends(get_db)) -> SqlAlchemyPhotoRepository:
    return SqlAlchemyPhotoRepository(db)

def get_admin_repo(db: Session = Depends(get_db)) -> SqlAlchemyAdminRepository:
    return SqlAlchemyAdminRepository(db)

def get_settings_repo(db: Session = Depends(get_db)) -> SqlAlchemySettingsRepository:
    return SqlAlchemySettingsRepository(db)

def get_current_visitor(
    x_visitor_token: Optional[str] = Header(None, alias="X-Visitor-Token"),
    visitor_repo: SqlAlchemyVisitorRepository = Depends(get_visitor_repo),
) -> VisitorEntity:
    if not x_visitor_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Visitor session token required (X-Visitor-Token header missing)",
        )
    visitor = visitor_repo.get_by_session_token(x_visitor_token)
    if not visitor:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired visitor session token",
        )
    return visitor

def get_optional_visitor(
    x_visitor_token: Optional[str] = Header(None, alias="X-Visitor-Token"),
    visitor_repo: SqlAlchemyVisitorRepository = Depends(get_visitor_repo),
) -> Optional[VisitorEntity]:
    if not x_visitor_token:
        return None
    return visitor_repo.get_by_session_token(x_visitor_token)

def get_current_admin(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
    admin_repo: SqlAlchemyAdminRepository = Depends(get_admin_repo),
) -> AdminUserEntity:
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token = credentials.credentials
    payload = decode_access_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired admin token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    admin = admin_repo.get_by_id(payload["sub"])
    if not admin or not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin account inactive or not found",
        )
    return admin

def get_optional_admin(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
    admin_repo: SqlAlchemyAdminRepository = Depends(get_admin_repo),
) -> Optional[AdminUserEntity]:
    if not credentials or not credentials.credentials:
        return None
    payload = decode_access_token(credentials.credentials)
    if not payload or "sub" not in payload:
        return None
    admin = admin_repo.get_by_id(payload["sub"])
    if admin and admin.is_active:
        return admin
    return None
