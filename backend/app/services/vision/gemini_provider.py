"""Google Gemini Vision-Language Model Provider.

Implements the VisionProvider interface using the official Google GenAI SDK (google-genai).
Decoupled from client models; returns canonical StructuredScene.
"""

import asyncio
import ssl
from typing import Optional
import certifi
from google import genai
from google.genai import errors as genai_errors
from google.genai import types

from app.core.config import settings
from app.core.errors import (
    ProviderUnavailableError,
    ServiceTimeoutError,
    VisionProcessingError,
)
from app.core.logging import logger
from app.services.vision.models import StructuredScene, sanitize_scene_safety
from app.services.vision.prompts import (
    ASSISTIVE_VIDEO_SYSTEM_INSTRUCTION,
    ASSISTIVE_VISION_SYSTEM_INSTRUCTION,
)
from app.services.vision.vision_provider import VisionProvider


def _create_ssl_context() -> ssl.SSLContext:
    """Create SSL context trusting Mozilla CA bundle and system root certificates."""
    ctx = ssl.create_default_context(cafile=certifi.where())
    ctx.load_default_certs()
    return ctx


class GeminiVisionProvider(VisionProvider):
    """Concrete VisionProvider implementation utilizing Google Gemini multimodal models."""

    def __init__(
        self,
        api_key: Optional[str] = None,
        model_name: Optional[str] = None,
        timeout_seconds: Optional[float] = None,
        video_timeout_seconds: Optional[float] = None,
        client: Optional[genai.Client] = None,
    ):
        """Initialize the Gemini vision provider.

        Args:
            api_key: Google Gemini API key. Defaults to settings.GEMINI_API_KEY.
            model_name: Multimodal model name. Defaults to settings.GEMINI_MODEL.
            timeout_seconds: Network call timeout for images in seconds. Defaults to settings.GEMINI_TIMEOUT_SECONDS.
            video_timeout_seconds: Network call timeout for videos in seconds. Defaults to settings.GEMINI_VIDEO_TIMEOUT_SECONDS.
            client: Optional injected genai.Client (useful for unit testing and mocking).
        """
        self.api_key = (api_key or settings.GEMINI_API_KEY).strip()
        self.model_name = (model_name or settings.GEMINI_MODEL).strip()
        self.timeout_seconds = timeout_seconds or settings.GEMINI_TIMEOUT_SECONDS
        self.video_timeout_seconds = video_timeout_seconds or getattr(
            settings, "GEMINI_VIDEO_TIMEOUT_SECONDS", 30.0
        )

        if not self.api_key and client is None:
            raise ValueError(
                "Gemini API key is required to initialize GeminiVisionProvider. "
                "Ensure GEMINI_API_KEY is configured in your environment or .env file."
            )

        # Injected or newly initialized client
        if client is not None:
            self.client = client
        else:
            ssl_ctx = _create_ssl_context()
            http_options = types.HttpOptions(
                async_client_args={"ssl": ssl_ctx},
                client_args={"verify": ssl_ctx},
            )
            self.client = genai.Client(
                api_key=self.api_key,
                http_options=http_options,
            )

    @property
    def provider_name(self) -> str:
        return f"gemini ({self.model_name})"

    @staticmethod
    def _detect_mime_type(image_bytes: bytes) -> str:
        """Infer standard image MIME type from initial binary magic numbers."""
        if image_bytes.startswith(b"\xff\xd8\xff"):
            return "image/jpeg"
        if image_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
            return "image/png"
        if image_bytes.startswith(b"RIFF") and b"WEBP" in image_bytes[:16]:
            return "image/webp"
        return "image/jpeg"

    async def analyze_scene(
        self,
        image_bytes: bytes,
        language: str = "en",
        context_hint: Optional[str] = None,
    ) -> StructuredScene:
        """Analyze an image using Gemini with structured JSON output and anti-hallucination guardrails.

        Args:
            image_bytes: Binary bytes of the camera image.
            language: Requested language code ('en', 'te'). Kept language-neutral in StructuredScene.
            context_hint: Optional client-side context metadata.

        Returns:
            StructuredScene object populated with grounded environmental elements.
        """
        mime_type = self._detect_mime_type(image_bytes)
        image_part = types.Part.from_bytes(data=image_bytes, mime_type=mime_type)

        user_prompt = (
            "Accurately describe what is actually visible in this captured image for a visually impaired user, "
            "especially what is directly in front of the camera. "
            "Prioritize visible people, visible objects, spatial positions, visible activities, appearance, "
            "and visible background features following the system instructions without guessing generic scene classifications. "
            "Prefer 'person' over gender assumptions, and omit posture unless clearly visible."
        )
        if context_hint:
            user_prompt += f" Client sensor/device hint: {context_hint}."

        config = types.GenerateContentConfig(
            system_instruction=ASSISTIVE_VISION_SYSTEM_INSTRUCTION,
            response_mime_type="application/json",
            response_schema=StructuredScene,
            temperature=0.2,
        )

        try:
            # Execute async call with timeout guard
            response = await asyncio.wait_for(
                self.client.aio.models.generate_content(
                    model=self.model_name,
                    contents=[image_part, user_prompt],
                    config=config,
                ),
                timeout=self.timeout_seconds,
            )

            if not response or not response.text:
                raise VisionProcessingError("Gemini returned an empty response.")

            # Validate and parse structured scene from JSON
            structured_scene = StructuredScene.model_validate_json(response.text)
            structured_scene = sanitize_scene_safety(structured_scene)
            return structured_scene

        except asyncio.TimeoutError:
            logger.error(f"[GEMINI_TIMEOUT] Request to {self.model_name} timed out after {self.timeout_seconds}s.")
            raise ServiceTimeoutError("Gemini vision analysis timed out. Please try again.")

        except genai_errors.APIError as exc:
            # Map HTTP/API error codes safely
            status_code = getattr(exc, "code", 500)
            logger.error(f"[GEMINI_API_ERROR] Code={status_code} Error={type(exc).__name__}")

            if status_code in (401, 403):
                raise ProviderUnavailableError(
                    "Gemini API authentication failed. Please verify your GEMINI_API_KEY credentials."
                )
            if status_code == 429:
                raise ProviderUnavailableError(
                    "Gemini quota or rate limit exceeded. Please wait a moment before trying again."
                )
            if status_code == 400:
                raise VisionProcessingError(
                    "The perception request was rejected by Gemini as invalid."
                )
            if status_code >= 500:
                raise ProviderUnavailableError(
                    "Google Gemini vision service is currently experiencing temporary downtime."
                )
            raise ProviderUnavailableError(
                "Unable to communicate with the Gemini vision service."
            )

        except (ValueError, TypeError) as exc:
            # JSON decode or Pydantic validation error
            logger.error(f"[GEMINI_PARSE_ERROR] Failed to parse response into StructuredScene: {str(exc)}")
            raise VisionProcessingError(
                "Failed to parse structured scene from Gemini response."
            )

        except VisionProcessingError:
            raise

        except Exception as exc:
            # Catch unexpected network or library exceptions without exposing internals
            logger.error(f"[GEMINI_UNEXPECTED] {type(exc).__name__}: {str(exc)}")
            raise ProviderUnavailableError(
                "Unexpected failure connecting to Gemini vision provider."
            )

    async def analyze_video(
        self,
        video_bytes: bytes,
        language: str = "en",
        context_hint: Optional[str] = None,
    ) -> StructuredScene:
        """Analyze a short MP4 video using Gemini with structured JSON output and anti-hallucination guardrails.

        Args:
            video_bytes: Binary bytes of the MP4 video.
            language: Requested language code ('en', 'te'). Kept language-neutral in StructuredScene.
            context_hint: Optional client-side context metadata.

        Returns:
            StructuredScene object populated with grounded environmental elements and temporal dynamics.
        """
        video_part = types.Part.from_bytes(data=video_bytes, mime_type="video/mp4")

        user_prompt = (
            "Accurately describe what is actually visible and occurring in this short captured video for a visually impaired user. "
            "Prioritize visible people, their movement trajectories, visible activities over time, approaching obstacles or hazards, "
            "physical features, and spatial positions relative to the camera following the system instructions without guessing generic scene classifications. "
            "Prefer 'person' over gender assumptions, and omit posture unless clearly visible."
        )
        if context_hint:
            user_prompt += f" Client sensor/device hint: {context_hint}."

        config = types.GenerateContentConfig(
            system_instruction=ASSISTIVE_VIDEO_SYSTEM_INSTRUCTION,
            response_mime_type="application/json",
            response_schema=StructuredScene,
            temperature=0.2,
        )

        try:
            response = await asyncio.wait_for(
                self.client.aio.models.generate_content(
                    model=self.model_name,
                    contents=[video_part, user_prompt],
                    config=config,
                ),
                timeout=self.video_timeout_seconds,
            )

            if not response or not response.text:
                raise VisionProcessingError("Gemini returned an empty response.")

            # Validate and parse structured scene from JSON
            structured_scene = StructuredScene.model_validate_json(response.text)
            structured_scene = sanitize_scene_safety(structured_scene)
            return structured_scene

        except asyncio.TimeoutError:
            logger.error(
                f"[GEMINI_VIDEO_TIMEOUT] Request to {self.model_name} timed out after {self.video_timeout_seconds}s."
            )
            raise ServiceTimeoutError("Gemini video analysis timed out. Please try again.")

        except genai_errors.APIError as exc:
            status_code = getattr(exc, "code", 500)
            logger.error(f"[GEMINI_API_ERROR] Code={status_code} Error={type(exc).__name__}")

            if status_code in (401, 403):
                raise ProviderUnavailableError(
                    "Gemini API authentication failed. Please verify your GEMINI_API_KEY credentials."
                )
            if status_code == 429:
                raise ProviderUnavailableError(
                    "Gemini quota or rate limit exceeded. Please wait a moment before trying again."
                )
            if status_code == 400:
                raise VisionProcessingError(
                    "The video perception request was rejected by Gemini as invalid."
                )
            if status_code >= 500:
                raise ProviderUnavailableError(
                    "Google Gemini vision service is currently experiencing temporary downtime."
                )
            raise ProviderUnavailableError(
                "Unable to communicate with the Gemini vision service."
            )

        except (ValueError, TypeError) as exc:
            logger.error(f"[GEMINI_PARSE_ERROR] Failed to parse video response into StructuredScene: {str(exc)}")
            raise VisionProcessingError(
                "Failed to parse structured scene from Gemini video response."
            )

        except VisionProcessingError:
            raise

        except Exception as exc:
            logger.error(f"[GEMINI_UNEXPECTED] {type(exc).__name__}: {str(exc)}")
            raise ProviderUnavailableError(
                "Unexpected failure connecting to Gemini vision provider."
            )

