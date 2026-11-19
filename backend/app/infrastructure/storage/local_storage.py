import uuid
import io
from pathlib import Path
from typing import Optional
from PIL import Image, ImageOps
from app.core.config import settings
from app.domain.interfaces.repositories import IStorageService

class LocalStorageService(IStorageService):
    def __init__(self, upload_dir: str = settings.UPLOAD_DIR, thumbnail_dir: str = settings.THUMBNAIL_DIR):
        self.upload_dir = Path(upload_dir)
        self.thumbnail_dir = Path(thumbnail_dir)
        self.upload_dir.mkdir(parents=True, exist_ok=True)
        self.thumbnail_dir.mkdir(parents=True, exist_ok=True)

    def validate_magic_bytes(self, file_bytes: bytes) -> str:
        """
        Validates the raw file signature (magic bytes) to guarantee
        that the uploaded content is a genuine image file.
        """
        if len(file_bytes) < 12:
            raise ValueError("File is too small to be a valid image")

        # JPEG signature: FF D8 FF
        if file_bytes.startswith(b"\xff\xd8\xff"):
            return "image/jpeg"

        # PNG signature: 89 50 4E 47 0D 0A 1A 0A
        if file_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
            return "image/png"

        # WebP signature: RIFF....WEBP
        if file_bytes.startswith(b"RIFF") and file_bytes[8:12] == b"WEBP":
            return "image/webp"

        raise ValueError("Invalid file signature: file does not match any supported image format (JPEG, PNG, WebP)")

    def save_image(self, file_bytes: bytes, original_filename: str, content_type: str) -> tuple[str, str, int, int]:
        # 1. Enforce strict magic byte validation
        detected_type = self.validate_magic_bytes(file_bytes)

        # 2. Decode using Pillow to verify internal integrity & raster data
        try:
            image = Image.open(io.BytesIO(file_bytes))
            # Auto-orient based on EXIF tag if available
            image = ImageOps.exif_transpose(image)
        except Exception as e:
            raise ValueError(f"Corrupt image or failed raster decoding: {str(e)}")

        # 3. Strip all EXIF / embedded metadata by creating a fresh RGB canvas
        if image.mode in ("RGBA", "P"):
            # Create a clean RGB canvas with a white background for alpha channels
            background = Image.new("RGB", image.size, (255, 255, 255))
            if image.mode == "RGBA":
                background.paste(image, mask=image.split()[3])
            else:
                background.paste(image.convert("RGB"))
            clean_image = background
        else:
            clean_image = image.convert("RGB")

        file_id = uuid.uuid4().hex
        ext = ".jpg"  # Standardize on clean JPEG for universal TV/Browser compatibility
        
        saved_filename = f"{file_id}{ext}"
        thumb_filename = f"thumb_{file_id}{ext}"

        full_path = self.upload_dir / saved_filename
        thumb_path = self.thumbnail_dir / thumb_filename

        # Downscale full image if larger than standard 2560px boundary
        max_dimension = 2560
        orig_width, orig_height = clean_image.size
        if orig_width > max_dimension or orig_height > max_dimension:
            clean_image.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)
        
        final_width, final_height = clean_image.size

        # Save clean sanitized image (strips original EXIF / scripts)
        clean_image.save(full_path, format="JPEG", quality=88, optimize=True)

        # Generate lightweight thumbnail (max 400x400)
        thumb_image = clean_image.copy()
        thumb_image.thumbnail((400, 400), Image.Resampling.LANCZOS)
        thumb_image.save(thumb_path, format="JPEG", quality=80, optimize=True)

        # Return relative paths
        rel_storage_path = saved_filename
        rel_thumb_path = f"thumbnails/{thumb_filename}"

        return rel_storage_path, rel_thumb_path, final_width, final_height

    def delete_image(self, storage_path: str, thumbnail_path: Optional[str] = None) -> None:
        try:
            full_path = self.upload_dir / Path(storage_path).name
            if full_path.exists():
                full_path.unlink()
            
            if thumbnail_path:
                thumb_path = self.thumbnail_dir / Path(thumbnail_path).name
                if thumb_path.exists():
                    thumb_path.unlink()
        except Exception:
            pass
