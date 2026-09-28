"""Image validation service for pre-flight quality and integrity checks.

Validates format, size, dimensions, and basic corruption before sending frames
to vision models. Does NOT implement complex CV pipelines at this foundation stage.
"""

import io
from typing import List, Set
from pydantic import BaseModel, Field
from PIL import Image

from app.core.errors import ImageTooLargeError, ImageValidationError


class ImageValidationResult(BaseModel):
    """Result metadata of successful image validation."""
    is_valid: bool = True
    format: str
    width: int
    height: int
    size_bytes: int
    warnings: List[str] = Field(default_factory=list)


class ImageValidator:
    """Performs safety and integrity validation on uploaded image bytes."""

    SUPPORTED_FORMATS: Set[str] = {"JPEG", "JPG", "PNG", "WEBP"}
    MAX_FILE_SIZE_BYTES: int = 15 * 1024 * 1024  # 15 MB
    MIN_FILE_SIZE_BYTES: int = 100               # 100 Bytes
    MIN_DIMENSION: int = 64                      # Minimum width/height
    MAX_DIMENSION: int = 8192                    # Maximum width/height

    def validate(self, image_bytes: bytes) -> ImageValidationResult:
        """Validate raw image bytes.

        Raises:
            ImageValidationError: If format is invalid, corrupted, or undersized.
            ImageTooLargeError: If payload exceeds size limits.
        """
        size_bytes = len(image_bytes)

        # 1. Size bounds check
        if size_bytes < self.MIN_FILE_SIZE_BYTES:
            raise ImageValidationError(
                message="Uploaded image file is empty or corrupted (insufficient data bytes)."
            )

        if size_bytes > self.MAX_FILE_SIZE_BYTES:
            raise ImageTooLargeError(max_size_mb=self.MAX_FILE_SIZE_BYTES // (1024 * 1024))

        # 2. Decode and integrity check using Pillow
        try:
            with Image.open(io.BytesIO(image_bytes)) as img:
                # Verify format
                img_format = (img.format or "").upper()
                if img_format not in self.SUPPORTED_FORMATS:
                    raise ImageValidationError(
                        message=f"Unsupported image format '{img_format}'. Supported formats: {', '.join(sorted(self.SUPPORTED_FORMATS))}."
                    )

                width, height = img.size
                if width < self.MIN_DIMENSION or height < self.MIN_DIMENSION:
                    raise ImageValidationError(
                        message=f"Image resolution ({width}x{height}) is too small. Minimum resolution is {self.MIN_DIMENSION}x{self.MIN_DIMENSION}."
                    )

                # Collect non-fatal quality warnings
                warnings: List[str] = []
                if width > 4096 or height > 4096:
                    warnings.append("high_resolution_image_may_increase_latency")

                return ImageValidationResult(
                    is_valid=True,
                    format=img_format,
                    width=width,
                    height=height,
                    size_bytes=size_bytes,
                    warnings=warnings,
                )

        except ImageValidationError:
            raise
        except ImageTooLargeError:
            raise
        except Exception as exc:
            raise ImageValidationError(
                message=f"Image file is corrupted or cannot be decoded: {str(exc)}"
            )


# Default shared validator instance
image_validator = ImageValidator()
