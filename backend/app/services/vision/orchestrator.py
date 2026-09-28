"""Perception Orchestration Service.

Coordinates image validation, vision model delegation, assistive description generation,
and performance metric tracking into a unified provider-independent workflow.
"""

import time
import uuid
from typing import Optional
from app.core.logging import logger
from app.services.language.description_service import (
    AssistiveDescriptionService,
    description_service,
)
from app.services.language.language_manager import language_manager
from app.services.vision.image_validator import ImageValidator, image_validator
from app.services.vision.models import PerceptionResponse
from app.services.vision.provider_factory import get_vision_provider
from app.services.vision.video_validator import VideoValidator, video_validator
from app.services.vision.vision_provider import VisionProvider


class PerceptionOrchestrator:
    """Orchestrates end-to-end perception workflow."""

    def __init__(
        self,
        vision_provider: Optional[VisionProvider] = None,
        validator: Optional[ImageValidator] = None,
        video_val: Optional[VideoValidator] = None,
        desc_service: Optional[AssistiveDescriptionService] = None,
    ):
        self._vision_provider = vision_provider
        self.validator = validator or image_validator
        self.video_validator = video_val or video_validator
        self.desc_service = desc_service or description_service

    @property
    def vision_provider(self) -> VisionProvider:
        """Return the active vision provider (injected or dynamically resolved)."""
        if self._vision_provider is not None:
            return self._vision_provider
        return get_vision_provider()

    @vision_provider.setter
    def vision_provider(self, provider: Optional[VisionProvider]) -> None:
        """Allow injecting a specific provider for testing or custom scoping."""
        self._vision_provider = provider

    async def perceive(
        self,
        image_bytes: bytes,
        language: str = "en",
        client_metadata: Optional[str] = None,
        request_id: Optional[str] = None,
    ) -> PerceptionResponse:
        """Execute the perception pipeline.

        Args:
            image_bytes: Raw binary image payload.
            language: Requested speech output language ('en', 'te').
            client_metadata: Optional client-side device/orientation context.
            request_id: Optional client-provided request ID.

        Returns:
            PerceptionResponse with structured data and audio-ready narrative.
        """
        req_id = request_id or f"req-{uuid.uuid4().hex[:12]}"
        t_start = time.perf_counter()

        # Step 1: Language validation
        target_lang = language_manager.validate_language(language)

        # Step 2: Image safety & format validation
        t_val_start = time.perf_counter()
        validation_result = self.validator.validate(image_bytes)
        t_val_ms = (time.perf_counter() - t_val_start) * 1000

        # Step 3: Vision Provider inference (Gemini or Mock based on configuration)
        active_provider = self.vision_provider
        t_vision_start = time.perf_counter()
        structured_scene = await active_provider.analyze_scene(
            image_bytes=image_bytes,
            language=target_lang,
            context_hint=client_metadata,
        )
        t_vision_ms = (time.perf_counter() - t_vision_start) * 1000

        # Step 4: Localized assistive description generation
        t_desc_start = time.perf_counter()
        description = self.desc_service.generate_description(
            scene=structured_scene,
            language_code=target_lang,
        )
        t_desc_ms = (time.perf_counter() - t_desc_start) * 1000

        total_duration_ms = (time.perf_counter() - t_start) * 1000

        # Safe logging of performance metrics (NO image bytes, NO credentials)
        logger.info(
            f"[PERF] RequestID={req_id} Endpoint=/api/v1/perceive Lang={target_lang} "
            f"Provider={active_provider.provider_name} "
            f"Val={t_val_ms:.1f}ms Vision={t_vision_ms:.1f}ms Desc={t_desc_ms:.1f}ms "
            f"Total={total_duration_ms:.1f}ms Status=SUCCESS"
        )

        return PerceptionResponse(
            request_id=req_id,
            status="success",
            language=target_lang,
            description=description,
            scene_data=structured_scene,
            processing_time_ms=round(total_duration_ms, 2),
            warnings=validation_result.warnings,
            errors=None,
        )

    async def perceive_video(
        self,
        video_bytes: bytes,
        language: str = "en",
        client_metadata: Optional[str] = None,
        request_id: Optional[str] = None,
    ) -> PerceptionResponse:
        """Execute the video perception pipeline.

        Args:
            video_bytes: Raw binary MP4 video payload.
            language: Requested speech output language ('en', 'te').
            client_metadata: Optional client-side device/orientation context.
            request_id: Optional client-provided request ID.

        Returns:
            PerceptionResponse with structured data and audio-ready narrative.
        """
        req_id = request_id or f"req-{uuid.uuid4().hex[:12]}"
        t_start = time.perf_counter()

        # Step 1: Language validation
        target_lang = language_manager.validate_language(language)

        # Step 2: Video safety, integrity, and duration validation
        t_val_start = time.perf_counter()
        validation_result = self.video_validator.validate_bytes(video_bytes)
        t_val_ms = (time.perf_counter() - t_val_start) * 1000

        # Step 3: Vision Provider video inference
        active_provider = self.vision_provider
        t_vision_start = time.perf_counter()
        structured_scene = await active_provider.analyze_video(
            video_bytes=video_bytes,
            language=target_lang,
            context_hint=client_metadata,
        )
        t_vision_ms = (time.perf_counter() - t_vision_start) * 1000

        # Step 4: Localized assistive description generation
        t_desc_start = time.perf_counter()
        description = self.desc_service.generate_description(
            scene=structured_scene,
            language_code=target_lang,
        )
        t_desc_ms = (time.perf_counter() - t_desc_start) * 1000

        total_duration_ms = (time.perf_counter() - t_start) * 1000

        # Safe logging of performance metrics
        logger.info(
            f"[PERF] RequestID={req_id} Endpoint=/api/v1/perceive/video Lang={target_lang} "
            f"Provider={active_provider.provider_name} "
            f"Val={t_val_ms:.1f}ms Vision={t_vision_ms:.1f}ms Desc={t_desc_ms:.1f}ms "
            f"Total={total_duration_ms:.1f}ms Status=SUCCESS"
        )

        return PerceptionResponse(
            request_id=req_id,
            status="success",
            language=target_lang,
            description=description,
            scene_data=structured_scene,
            processing_time_ms=round(total_duration_ms, 2),
            warnings=validation_result.warnings,
            errors=None,
        )


# Shared orchestrator instance
orchestrator = PerceptionOrchestrator()

