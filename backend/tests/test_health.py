from unittest.mock import patch
from app.core.exceptions import DatabaseConnectionException

def test_root_endpoint(client):
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "Visitor Photo Slideshow" in data["message"]
    assert data["version"] == "1.0.0"
    assert data["health_url"] == "/api/v1/health"

def test_health_check_success(client):
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["version"] == "1.0.0"
    assert "database" in data
    assert data["database"]["status"] == "connected"
    assert data["database"]["dialect"] == "sqlite"
    assert "latency_ms" in data["database"]

def test_health_check_database_failure(client):
    with patch("app.presentation.api.v1.health.check_db_connectivity") as mock_check:
        mock_check.side_effect = DatabaseConnectionException("Simulated connection timeout")
        response = client.get("/api/v1/health")
        assert response.status_code == 503
        data = response.json()
        assert data["status"] == "unhealthy"
        assert data["database"]["status"] == "disconnected"
        assert "Simulated connection timeout" in data["database"]["error"]
