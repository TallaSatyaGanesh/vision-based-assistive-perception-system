"""Vision Provider Factory.

Selects the active vision provider based on environment configuration.
If GEMINI_API_KEY is configured, returns GeminiVisionProvider.
Otherwise, returns MockVisionProvider for offline development and testing.
"""

from app.core.config import settings
from app.core.logging import logger
from app.services.vision.gemini_provider import GeminiVisionProvider
from app.services.vision.mock_provider import MockVisionProvider
from app.services.vision.vision_provider import VisionProvider


def get_vision_provider() -> VisionProvider:
    """Return the configured VisionProvider instance.

    Returns:
        GeminiVisionProvider if GEMINI_API_KEY is set; otherwise MockVisionProvider.
    """
    api_key = (settings.GEMINI_API_KEY or "").strip()
    if api_key:
        logger.info(f"Vision Provider: GeminiVisionProvider (model='{settings.GEMINI_MODEL}')")
        return GeminiVisionProvider(
            api_key=api_key,
            model_name=settings.GEMINI_MODEL,
            timeout_seconds=settings.GEMINI_TIMEOUT_SECONDS,
            video_timeout_seconds=settings.GEMINI_VIDEO_TIMEOUT_SECONDS,
        )

    logger.info("Vision Provider: MockVisionProvider (GEMINI_API_KEY is not configured)")
    return MockVisionProvider()
