from fastapi import APIRouter, status
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.infrastructure.database.session import check_db_connectivity
from app.core.exceptions import DatabaseConnectionException

router = APIRouter(tags=["Health"])

@router.get("/health", status_code=status.HTTP_200_OK)
def health_check():
    """
    Health check endpoint returning application status and database connectivity.
    Returns:
    - 200 OK when both application and database are healthy.
    - 503 SERVICE UNAVAILABLE if the database connectivity check fails.
    """
    try:
        db_health = check_db_connectivity()
        return {
            "status": "healthy",
            "app_name": settings.PROJECT_NAME,
            "version": settings.VERSION,
            "environment": settings.ENVIRONMENT,
            "database": db_health,
        }
    except DatabaseConnectionException as e:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "unhealthy",
                "app_name": settings.PROJECT_NAME,
                "version": settings.VERSION,
                "environment": settings.ENVIRONMENT,
                "database": {
                    "status": "disconnected",
                    "error": str(e.details or e.message),
                },
            },
        )
