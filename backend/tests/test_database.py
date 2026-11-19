from sqlalchemy import text
from app.infrastructure.database.session import check_db_connectivity, get_db

def test_check_db_connectivity():
    health = check_db_connectivity()
    assert health["status"] == "connected"
    assert "dialect" in health
    assert "latency_ms" in health
    assert isinstance(health["latency_ms"], float)

def test_get_db_generator():
    db_gen = get_db()
    session = next(db_gen)
    assert session is not None
    result = session.execute(text("SELECT 1")).scalar()
    assert result == 1
    # Cleanup generator
    try:
        next(db_gen)
    except StopIteration:
        pass
