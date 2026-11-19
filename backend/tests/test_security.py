from app.core.security import (
    generate_secure_visitor_token,
    hash_password,
    verify_password,
    create_access_token,
    decode_access_token,
)

def test_generate_secure_visitor_token():
    token1 = generate_secure_visitor_token()
    token2 = generate_secure_visitor_token()
    assert len(token1) >= 40  # 32 bytes base64url is 43 characters
    assert token1 != token2

def test_password_hashing_and_verification():
    raw_password = "SecurePassword123!"
    hashed = hash_password(raw_password)
    assert hashed != raw_password
    assert verify_password(raw_password, hashed) is True
    assert verify_password("WrongPassword", hashed) is False

def test_jwt_token_creation_and_decoding():
    payload_data = {"sub": "admin_uuid_123", "username": "admin", "role": "ADMIN"}
    token = create_access_token(payload_data)
    assert isinstance(token, str)

    decoded = decode_access_token(token)
    assert decoded is not None
    assert decoded["sub"] == "admin_uuid_123"
    assert decoded["username"] == "admin"
    assert decoded["role"] == "ADMIN"
    assert "exp" in decoded

def test_jwt_invalid_token_decoding():
    decoded = decode_access_token("completely.invalid.token")
    assert decoded is None
