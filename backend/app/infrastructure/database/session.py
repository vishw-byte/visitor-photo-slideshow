import time
from typing import Generator
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from app.core.config import settings
from app.core.exceptions import DatabaseConnectionException

connect_args = {}
if settings.DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    settings.DATABASE_URL,
    connect_args=connect_args,
    pool_pre_ping=True,
    echo=False,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db() -> Generator[Session, None, None]:
    """Dependency for providing a transactional database session per request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def check_db_connectivity() -> dict:
    """
    Executes a lightweight query to verify active database health
    and measures query response latency.
    """
    start_time = time.perf_counter()
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        latency_ms = round((time.perf_counter() - start_time) * 1000, 2)
        return {
            "status": "connected",
            "dialect": engine.dialect.name,
            "latency_ms": latency_ms,
        }
    except Exception as e:
        raise DatabaseConnectionException(
            message="Database connectivity check failed",
            details=str(e),
        )
