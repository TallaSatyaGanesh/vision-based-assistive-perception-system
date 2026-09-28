"""Standardized API-level custom exceptions and error handlers.

Ensures client-safe responses with consistent JSON schemas without exposing
stack traces, internal paths, or credentials.
"""

from typing import Any, Dict, Optional
from fastapi import Request, status
from fastapi.responses import JSONResponse
from app.services.vision.models import PerceptionErrorResponse


class AppBaseException(Exception):
    """Base exception for application-level errors."""

    def __init__(
        self,
        message: str,
        error_code: str = "INTERNAL_ERROR",
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        details: Optional[Dict[str, Any]] = None,
    ):
        self.message = message
        self.error_code = error_code
        self.status_code = status_code
        self.details = details or {}
        super().__init__(message)


class MissingImageError(AppBaseException):
    """Raised when an expected image payload is missing."""

    def __init__(self, message: str = "An image file is required for perception analysis."):
        super().__init__(
            message=message,
            error_code="MISSING_IMAGE",
            status_code=status.HTTP_400_BAD_REQUEST,
        )


class ImageValidationError(AppBaseException):
    """Raised when an image fails format, dimensions, or corruption checks."""

    def __init__(self, message: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(
            message=message,
            error_code="INVALID_IMAGE",
            status_code=getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", 422),
            details=details,
        )


class ImageTooLargeError(AppBaseException):
    """Raised when image payload exceeds the allowed upload limit."""

    def __init__(self, max_size_mb: int = 15):
        super().__init__(
            message=f"Image file exceeds the maximum allowed size of {max_size_mb} MB.",
            error_code="IMAGE_TOO_LARGE",
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            details={"max_size_mb": max_size_mb},
        )


class MissingVideoError(AppBaseException):
    """Raised when an expected video payload is missing."""

    def __init__(self, message: str = "A video file is required for perception analysis."):
        super().__init__(
            message=message,
            error_code="MISSING_VIDEO",
            status_code=status.HTTP_400_BAD_REQUEST,
        )


class VideoValidationError(AppBaseException):
    """Raised when a video fails format, integrity, or decodability checks."""

    def __init__(self, message: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(
            message=message,
            error_code="INVALID_VIDEO",
            status_code=getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", 422),
            details=details,
        )


class VideoTooLargeError(AppBaseException):
    """Raised when video payload exceeds the allowed upload limit."""

    def __init__(self, max_size_mb: int = 25):
        super().__init__(
            message=f"Video file exceeds the maximum allowed size of {max_size_mb} MB.",
            error_code="VIDEO_TOO_LARGE",
            status_code=getattr(status, "HTTP_413_CONTENT_TOO_LARGE", 413),
            details={"max_size_mb": max_size_mb},
        )


class VideoDurationExceededError(AppBaseException):
    """Raised when video duration exceeds the allowed duration limit."""

    def __init__(self, duration_seconds: float, max_duration_seconds: float = 10.0):
        super().__init__(
            message=(
                f"Video duration ({duration_seconds:.1f}s) exceeds the maximum "
                f"allowed limit of {max_duration_seconds:.1f} seconds."
            ),
            error_code="VIDEO_TOO_LONG",
            status_code=getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", 422),
            details={
                "duration_seconds": round(duration_seconds, 2),
                "max_duration_seconds": round(max_duration_seconds, 2),
            },
        )


class UnsupportedLanguageError(AppBaseException):
    """Raised when a requested language is not supported."""

    def __init__(self, language: str, supported: list):
        super().__init__(
            message=f"Requested language '{language}' is not supported. Supported languages: {', '.join(supported)}.",
            error_code="UNSUPPORTED_LANGUAGE",
            status_code=status.HTTP_400_BAD_REQUEST,
            details={"requested_language": language, "supported_languages": supported},
        )


class VisionProcessingError(AppBaseException):
    """Raised when the vision perception pipeline fails to analyze the image."""

    def __init__(self, message: str = "Failed to process visual scene information."):
        super().__init__(
            message=message,
            error_code="PROCESSING_FAILURE",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


class ProviderUnavailableError(AppBaseException):
    """Raised when the vision AI provider is unreachable or down."""

    def __init__(self, message: str = "Vision perception provider is temporarily unavailable."):
        super().__init__(
            message=message,
            error_code="PROVIDER_UNAVAILABLE",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        )


class ServiceTimeoutError(AppBaseException):
    """Raised when perception pipeline exceeds allowed time limit."""

    def __init__(self, message: str = "Perception analysis timed out."):
        super().__init__(
            message=message,
            error_code="TIMEOUT",
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
        )


async def app_exception_handler(request: Request, exc: AppBaseException) -> JSONResponse:
    """Handle custom application exceptions and format uniform JSON response."""
    request_id = getattr(request.state, "request_id", "req-unknown")
    error_response = PerceptionErrorResponse(
        request_id=request_id,
        status="error",
        error_code=exc.error_code,
        message=exc.message,
        details=exc.details if exc.details else None,
    )
    return JSONResponse(
        status_code=exc.status_code,
        content=error_response.model_dump(),
    )


async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Handle unexpected server exceptions cleanly without exposing internal traces."""
    request_id = getattr(request.state, "request_id", "req-unknown")
    error_response = PerceptionErrorResponse(
        request_id=request_id,
        status="error",
        error_code="INTERNAL_ERROR",
        message="An unexpected error occurred while processing your request. Please try again.",
        details=None,
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=error_response.model_dump(),
    )
