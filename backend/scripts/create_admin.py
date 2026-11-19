import sys
import argparse
import getpass
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

from typing import Optional
from sqlalchemy.orm import Session
from app.core.security import hash_password
from app.infrastructure.database.session import SessionLocal
from app.infrastructure.database.models import DBAdminUser

def create_or_update_admin(
    username: str,
    password: str,
    email: Optional[str] = None,
    db: Optional[Session] = None,
) -> bool:
    """
    Creates a new admin or securely updates an existing admin's password and email.
    Preserves existing account ID, foreign keys, photos, and roles.
    Hashes the password using bcrypt via app.core.security.hash_password.
    Never stores or prints plain-text passwords.
    """
    clean_username = username.strip()
    if not clean_username:
        print("Error: Username cannot be empty.", file=sys.stderr)
        return False

    if len(password) < 8:
        print("Error: Password must be at least 8 characters long.", file=sys.stderr)
        return False

    close_db = False
    if db is None:
        db = SessionLocal()
        close_db = True

    try:
        existing = db.query(DBAdminUser).filter(DBAdminUser.username == clean_username).first()
        hashed = hash_password(password)
        if existing:
            existing.hashed_password = hashed
            if email:
                existing.email = email.strip()
            db.commit()
            print(f"Admin '{clean_username}' password updated successfully.")
            return True
        else:
            admin = DBAdminUser(
                username=clean_username,
                email=email.strip() if email else None,
                hashed_password=hashed,
                role="ADMIN",
                is_active=True,
            )
            db.add(admin)
            db.commit()
            print(f"Admin '{clean_username}' created successfully.")
            return True
    except Exception as e:
        db.rollback()
        print(f"Database error: {e}", file=sys.stderr)
        return False
    finally:
        if close_db:
            db.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create or securely update an administrator account.")
    parser.add_argument("--username", required=True, help="Admin username")
    parser.add_argument(
        "--password",
        default=None,
        help="Admin password (if omitted, you will be prompted securely with masked input)",
    )
    parser.add_argument("--email", default=None, help="Optional admin email")

    args = parser.parse_args()

    password = args.password
    if not password:
        try:
            password = getpass.getpass(f"Enter new password for admin '{args.username}': ")
            if not password:
                print("Error: Password cannot be empty.", file=sys.stderr)
                sys.exit(1)
            confirm = getpass.getpass("Confirm new password: ")
            if password != confirm:
                print("Error: Passwords do not match.", file=sys.stderr)
                sys.exit(1)
        except (KeyboardInterrupt, EOFError):
            print("\nOperation cancelled.", file=sys.stderr)
            sys.exit(1)

    success = create_or_update_admin(args.username, password, args.email)
    if not success:
        sys.exit(1)
