"""Provider-independent Vision Interface.

Defines the contract for vision understanding services without binding
the backend to any specific VLM vendor (Gemini, OpenAI, Qwen, LLaVA, etc.).
"""

from abc import ABC, abstractmethod
from typing import Optional
from app.services.vision.models import StructuredScene


class VisionProvider(ABC):
    """Abstract interface defining the contract for any Vision AI provider."""

    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Return the unique identifier/name of this vision provider."""
        pass

    @abstractmethod
    async def analyze_scene(
        self,
        image_bytes: bytes,
        language: str = "en",
        context_hint: Optional[str] = None,
    ) -> StructuredScene:
        """Analyze an image and return a standardized StructuredScene.

        Args:
            image_bytes: Raw binary bytes of the pre-validated image.
            language: Requested target output language (e.g. 'en', 'te').
            context_hint: Optional client-provided contextual hint.

        Returns:
            StructuredScene containing observed objects, context, and orientation.

        Raises:
            ProviderUnavailableError: If the underlying model service is unreachable.
            VisionProcessingError: If analysis fails or produces unparseable output.
        """
        pass

    @abstractmethod
    async def analyze_video(
        self,
        video_bytes: bytes,
        language: str = "en",
        context_hint: Optional[str] = None,
    ) -> StructuredScene:
        """Analyze a short MP4 video and return a standardized StructuredScene.

        Args:
            video_bytes: Raw binary bytes of the pre-validated MP4 video.
            language: Requested target output language (e.g. 'en', 'te').
            context_hint: Optional client-provided contextual hint.

        Returns:
            StructuredScene containing observed objects, movement, context, and orientation.

        Raises:
            ProviderUnavailableError: If the underlying model service is unreachable.
            VisionProcessingError: If analysis fails or produces unparseable output.
            ServiceTimeoutError: If analysis exceeds the configured timeout.
        """
        pass

