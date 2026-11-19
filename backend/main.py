from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.security import hash_password
from app.core.exceptions import AppException, app_exception_handler, generic_exception_handler
from app.infrastructure.database.session import check_db_connectivity, SessionLocal, engine, Base
from app.infrastructure.database.models import DBAdminUser, DBSlideshowSettings
from app.presentation.api.v1.health import router as health_router
from app.presentation.api.v1.visitors import router as visitors_router
from app.presentation.api.v1.photos import router as photos_router
from app.presentation.api.v1.media import router as media_router
from app.presentation.api.v1.admin import router as admin_router
from app.presentation.api.v1.display import router as display_router

def init_db_and_seed():
    """Initializes tables and seeds default admin and settings if not present."""
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # Seed default Admin User if not present
        existing_admin = (
            db.query(DBAdminUser)
            .filter(DBAdminUser.username == settings.ADMIN_DEFAULT_USERNAME)
            .first()
        )
        if not existing_admin:
            hashed_pw = hash_password(settings.ADMIN_DEFAULT_PASSWORD)
            default_admin = DBAdminUser(
                username=settings.ADMIN_DEFAULT_USERNAME,
                email="admin@eventslideshow.local",
                hashed_password=hashed_pw,
                role="ADMIN",
                is_active=True,
            )
            db.add(default_admin)
            db.commit()

        # Seed default Slideshow Settings if not present
        existing_settings = db.query(DBSlideshowSettings).filter(DBSlideshowSettings.id == 1).first()
        if not existing_settings:
            default_settings = DBSlideshowSettings(
                id=1,
                slide_duration_seconds=10,
                slideshow_autoplay=True,
                slideshow_enabled=True,
                transition_effect="FADE",
                show_visitor_name=True,
                shuffle_playback=False,
                refresh_interval_seconds=15,
            )
            db.add(default_settings)
            db.commit()
    finally:
        db.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Verify database connectivity and ensure initial seed
    init_db_and_seed()
    try:
        db_info = check_db_connectivity()
        print(f"[{settings.PROJECT_NAME}] Database connected successfully: {db_info['dialect']} (latency: {db_info['latency_ms']}ms)")
    except Exception as e:
        print(f"[{settings.PROJECT_NAME}] WARNING: Database connectivity check failed on startup: {e}")
    yield
    print(f"[{settings.PROJECT_NAME}] Application shutdown complete.")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS Middleware (allows Flutter Web, Mobile, and Desktop)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global Exception Handlers
app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(Exception, generic_exception_handler)

# Mount API v1 Routers (Health, Visitors, Photos, Media, Admin, Display)
app.include_router(health_router, prefix="/api/v1")
app.include_router(visitors_router, prefix="/api/v1")
app.include_router(photos_router, prefix="/api/v1")
app.include_router(media_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")
app.include_router(display_router, prefix="/api/v1")

@app.get("/", tags=["Root"])
def root():
    return {
        "message": f"Welcome to {settings.PROJECT_NAME}",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
        "docs_url": "/docs",
        "health_url": "/api/v1/health",
    }

if __name__ == "__main__":
    import os
    import uvicorn
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("main:app", host=host, port=port, reload=True)
