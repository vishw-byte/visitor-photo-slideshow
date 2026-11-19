from typing import Optional
from pathlib import Path
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy.sql.expression import func
from sqlalchemy import or_
from app.core.config import settings
from app.domain.entities.models import (
    VisitorEntity,
    PhotoEntity,
    PhotoStatus,
    AdminUserEntity,
    SlideshowSettingsEntity,
)
from app.domain.interfaces.repositories import (
    IVisitorRepository,
    IPhotoRepository,
    IAdminRepository,
    ISettingsRepository,
)
from app.infrastructure.database.models import (
    DBVisitor,
    DBPhoto,
    DBAdminUser,
    DBSlideshowSettings,
)

class SqlAlchemyVisitorRepository(IVisitorRepository):
    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        name: str,
        session_token: str,
        email: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> VisitorEntity:
        db_visitor = DBVisitor(
            name=name,
            email=email,
            session_token=session_token,
            ip_address=ip_address,
        )
        self.db.add(db_visitor)
        self.db.commit()
        self.db.refresh(db_visitor)
        return VisitorEntity.model_validate(db_visitor)

    def get_by_session_token(self, session_token: str) -> Optional[VisitorEntity]:
        db_visitor = self.db.query(DBVisitor).filter(DBVisitor.session_token == session_token).first()
        if not db_visitor:
            return None
        return VisitorEntity.model_validate(db_visitor)

    def get_by_id(self, visitor_id: str) -> Optional[VisitorEntity]:
        db_visitor = self.db.query(DBVisitor).filter(DBVisitor.id == visitor_id).first()
        if not db_visitor:
            return None
        return VisitorEntity.model_validate(db_visitor)

    def count_visitors(self) -> int:
        return self.db.query(DBVisitor).count()

    def update_last_active(self, visitor_id: str) -> None:
        db_visitor = self.db.query(DBVisitor).filter(DBVisitor.id == visitor_id).first()
        if db_visitor:
            db_visitor.last_active_at = datetime.now(timezone.utc)
            self.db.commit()


class SqlAlchemyPhotoRepository(IPhotoRepository):
    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        visitor_id: str,
        original_filename: str,
        storage_path: str,
        thumbnail_path: str,
        file_size_bytes: int,
        mime_type: str,
        width: Optional[int],
        height: Optional[int],
        consent_given: bool,
        consent_given_at: Optional[datetime],
        consent_policy_version: Optional[str],
    ) -> PhotoEntity:
        db_photo = DBPhoto(
            visitor_id=visitor_id,
            original_filename=original_filename,
            storage_path=storage_path,
            thumbnail_path=thumbnail_path,
            file_size_bytes=file_size_bytes,
            mime_type=mime_type,
            width=width,
            height=height,
            consent_given=consent_given,
            consent_given_at=consent_given_at,
            consent_policy_version=consent_policy_version,
            status=PhotoStatus.PENDING.value,
            is_deleted=False,
        )
        self.db.add(db_photo)
        self.db.commit()
        self.db.refresh(db_photo)
        return PhotoEntity.model_validate(db_photo)

    def get_by_id(self, photo_id: str) -> Optional[PhotoEntity]:
        db_photo = self.db.query(DBPhoto).filter(DBPhoto.id == photo_id).first()
        if not db_photo:
            return None
        return PhotoEntity.model_validate(db_photo)

    def get_by_visitor_id(self, visitor_id: str, include_deleted: bool = False) -> list[PhotoEntity]:
        query = self.db.query(DBPhoto).filter(DBPhoto.visitor_id == visitor_id)
        if not include_deleted:
            query = query.filter(DBPhoto.is_deleted == False)
        db_photos = query.order_by(DBPhoto.created_at.desc()).all()
        return [PhotoEntity.model_validate(p) for p in db_photos]

    def get_by_status_with_visitor(
        self,
        status: PhotoStatus,
        skip: int = 0,
        limit: int = 50,
    ) -> list[dict]:
        query = (
            self.db.query(
                DBPhoto,
                DBVisitor.name.label("visitor_name"),
                DBVisitor.email.label("visitor_email"),
            )
            .join(DBVisitor, DBPhoto.visitor_id == DBVisitor.id)
            .filter(DBPhoto.status == status.value)
            .filter(DBPhoto.is_deleted == False)
            .order_by(DBPhoto.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        results = query.all()
        items = []
        for photo, visitor_name, visitor_email in results:
            items.append({
                "id": photo.id,
                "visitor_id": photo.visitor_id,
                "visitor_name": visitor_name,
                "visitor_email": visitor_email,
                "original_filename": photo.original_filename,
                "thumbnail_url": f"/api/v1/media/thumbnails/{photo.id}",
                "photo_url": f"/api/v1/media/photos/{photo.id}",
                "status": photo.status,
                "consent_given": photo.consent_given,
                "consent_given_at": photo.consent_given_at,
                "consent_policy_version": photo.consent_policy_version,
                "rejection_reason": photo.rejection_reason,
                "reviewed_by": photo.reviewed_by,
                "reviewed_at": photo.reviewed_at,
                "created_at": photo.created_at,
                "width": photo.width,
                "height": photo.height,
            })
        return items

    def get_dashboard_counts(self) -> dict:
        total = self.db.query(DBPhoto).filter(DBPhoto.is_deleted == False).count()
        pending = (
            self.db.query(DBPhoto)
            .filter(DBPhoto.status == PhotoStatus.PENDING.value, DBPhoto.is_deleted == False)
            .count()
        )
        approved = (
            self.db.query(DBPhoto)
            .filter(DBPhoto.status == PhotoStatus.APPROVED.value, DBPhoto.is_deleted == False)
            .count()
        )
        rejected = (
            self.db.query(DBPhoto)
            .filter(DBPhoto.status == PhotoStatus.REJECTED.value, DBPhoto.is_deleted == False)
            .count()
        )
        return {
            "total_photos": total,
            "pending_photos": pending,
            "approved_photos": approved,
            "rejected_photos": rejected,
        }

    def get_approved_with_consent(self, shuffle: bool = False, limit: int = 100) -> list[dict]:
        query = (
            self.db.query(DBPhoto, DBVisitor.name.label("visitor_name"))
            .join(DBVisitor, DBPhoto.visitor_id == DBVisitor.id)
            .filter(DBPhoto.status == PhotoStatus.APPROVED.value)
            .filter(DBPhoto.consent_given == True)
            .filter(DBPhoto.is_deleted == False)
        )
        if shuffle:
            query = query.order_by(func.random())
        else:
            query = query.order_by(DBPhoto.created_at.desc())
            
        results = query.limit(limit).all()
        feed_items = []
        for photo, visitor_name in results:
            # Verify file exists on disk
            file_path = Path(settings.UPLOAD_DIR) / photo.storage_path
            if not file_path.exists():
                continue

            feed_items.append({
                "id": photo.id,
                "url": f"/api/v1/media/slideshow/{photo.id}",
                "visitor_name": visitor_name,
                "width": photo.width,
                "height": photo.height,
                "created_at": photo.created_at.isoformat() if photo.created_at else None,
            })
        return feed_items

    def update_status(
        self,
        photo_id: str,
        status: PhotoStatus,
        reviewed_by: str,
        rejection_reason: Optional[str] = None,
    ) -> Optional[PhotoEntity]:
        db_photo = self.db.query(DBPhoto).filter(DBPhoto.id == photo_id).first()
        if not db_photo:
            return None
        db_photo.status = status.value
        db_photo.reviewed_by = reviewed_by
        db_photo.reviewed_at = datetime.now(timezone.utc)
        db_photo.rejection_reason = rejection_reason if status == PhotoStatus.REJECTED else None
        self.db.commit()
        self.db.refresh(db_photo)
        return PhotoEntity.model_validate(db_photo)

    def soft_delete(self, photo_id: str) -> bool:
        db_photo = self.db.query(DBPhoto).filter(DBPhoto.id == photo_id).first()
        if not db_photo:
            return False
        db_photo.is_deleted = True
        db_photo.deleted_at = datetime.now(timezone.utc)
        self.db.commit()
        return True

    def hard_delete(self, photo_id: str) -> bool:
        db_photo = self.db.query(DBPhoto).filter(DBPhoto.id == photo_id).first()
        if not db_photo:
            return False
        self.db.delete(db_photo)
        self.db.commit()
        return True


class SqlAlchemyAdminRepository(IAdminRepository):
    def __init__(self, db: Session):
        self.db = db

    def get_by_username_or_email(self, identifier: str) -> Optional[tuple[AdminUserEntity, str]]:
        admin = (
            self.db.query(DBAdminUser)
            .filter(or_(DBAdminUser.username == identifier, DBAdminUser.email == identifier))
            .first()
        )
        if not admin:
            return None
        return AdminUserEntity.model_validate(admin), admin.hashed_password

    def get_by_id(self, admin_id: str) -> Optional[AdminUserEntity]:
        admin = self.db.query(DBAdminUser).filter(DBAdminUser.id == admin_id).first()
        if not admin:
            return None
        return AdminUserEntity.model_validate(admin)

    def create_admin(self, username: str, hashed_password: str, email: Optional[str] = None) -> AdminUserEntity:
        admin = DBAdminUser(
            username=username,
            hashed_password=hashed_password,
            email=email,
        )
        self.db.add(admin)
        self.db.commit()
        self.db.refresh(admin)
        return AdminUserEntity.model_validate(admin)


class SqlAlchemySettingsRepository(ISettingsRepository):
    def __init__(self, db: Session):
        self.db = db

    def get_settings(self) -> SlideshowSettingsEntity:
        settings_record = self.db.query(DBSlideshowSettings).filter(DBSlideshowSettings.id == 1).first()
        if not settings_record:
            settings_record = DBSlideshowSettings(id=1)
            self.db.add(settings_record)
            self.db.commit()
            self.db.refresh(settings_record)
        return SlideshowSettingsEntity.model_validate(settings_record)

    def update_settings(self, updates: dict) -> SlideshowSettingsEntity:
        settings_record = self.db.query(DBSlideshowSettings).filter(DBSlideshowSettings.id == 1).first()
        if not settings_record:
            settings_record = DBSlideshowSettings(id=1)
            self.db.add(settings_record)

        for key, value in updates.items():
            if hasattr(settings_record, key) and value is not None:
                setattr(settings_record, key, value)
        settings_record.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(settings_record)
        return SlideshowSettingsEntity.model_validate(settings_record)
