"""Perception API Endpoint.

Handles image upload, runs validation, executes scene perception,
and returns structured environmental understanding with audio-optimized natural language description.
"""

import uuid
from typing import Optional
from fastapi import APIRouter, File, Form, Request, UploadFile, status

from app.core.errors import MissingImageError, MissingVideoError
from app.services.vision.models import PerceptionErrorResponse, PerceptionResponse
from app.services.vision.orchestrator import orchestrator
from app.services.vision.video_validator import video_validator

router = APIRouter()



@router.post(
    "/perceive",
    response_model=PerceptionResponse,
    status_code=status.HTTP_200_OK,
    responses={
        400: {"model": PerceptionErrorResponse, "description": "Bad Request (e.g. Unsupported Language)"},
        413: {"model": PerceptionErrorResponse, "description": "Payload Too Large"},
        422: {"model": PerceptionErrorResponse, "description": "Unprocessable Entity (e.g. Invalid/Corrupted Image)"},
        500: {"model": PerceptionErrorResponse, "description": "Internal Processing Error"},
        503: {"model": PerceptionErrorResponse, "description": "AI Provider Unavailable"},
    },
    tags=["Perception"],
    summary="Analyze environment image and generate assistive voice description",
)
async def perceive_environment(
    request: Request,
    image: Optional[UploadFile] = File(default=None, description="Captured camera image (JPEG/PNG/WEBP)"),
    language: str = Form(default="en", description="Target spoken language code ('en', 'te')"),
    client_metadata: Optional[str] = Form(default=None, description="Optional client context / sensor metadata"),
    request_id: Optional[str] = Form(default=None, description="Optional client-specified request ID"),
) -> PerceptionResponse:
    """Perceive surrounding environment from captured camera image.

    Validates the image, analyzes spatial objects and scene context,
    and returns a concise natural-language description suitable for speech output.
    """
    req_id = request_id or f"req-{uuid.uuid4().hex[:12]}"
    request.state.request_id = req_id

    # Check for missing file
    if image is None:
        raise MissingImageError("An image file must be uploaded under the 'image' field.")

    image_bytes = await image.read()
    if not image_bytes:
        raise MissingImageError("Uploaded image file is empty (0 bytes received).")

    return await orchestrator.perceive(
        image_bytes=image_bytes,
        language=language,
        client_metadata=client_metadata,
        request_id=req_id,
    )


@router.post(
    "/perceive/video",
    response_model=PerceptionResponse,
    status_code=status.HTTP_200_OK,
    responses={
        400: {"model": PerceptionErrorResponse, "description": "Bad Request (e.g. Missing Video or Unsupported Language)"},
        413: {"model": PerceptionErrorResponse, "description": "Payload Too Large (Exceeds 25 MiB)"},
        422: {"model": PerceptionErrorResponse, "description": "Unprocessable Entity (e.g. Corrupted Video or Duration > 10s)"},
        500: {"model": PerceptionErrorResponse, "description": "Internal Processing Error"},
        503: {"model": PerceptionErrorResponse, "description": "AI Provider Unavailable"},
    },
    tags=["Perception"],
    summary="Analyze environment video and generate assistive voice description",
)
async def perceive_video_environment(
    request: Request,
    video: Optional[UploadFile] = File(default=None, description="Captured or selected video (MP4, <= 10s, <= 25 MiB)"),
    language: str = Form(default="en", description="Target spoken language code ('en', 'te')"),
    client_metadata: Optional[str] = Form(default=None, description="Optional client context / sensor metadata"),
    request_id: Optional[str] = Form(default=None, description="Optional client-specified request ID"),
) -> PerceptionResponse:
    """Perceive surrounding environment from short camera video.

    Validates that the video is a genuine MP4 (<= 10 seconds, <= 25 MiB),
    analyzes dynamic objects, movement, and scene context with Gemini,
    and returns a concise natural-language description suitable for speech output.
    """
    req_id = request_id or f"req-{uuid.uuid4().hex[:12]}"
    request.state.request_id = req_id

    # Check for missing file
    if video is None:
        raise MissingVideoError("A video file must be uploaded under the 'video' field.")

    # Bounded streaming read to avoid unbounded memory loading
    video_bytes = await video_validator.read_bounded_upload(video)
    if not video_bytes:
        raise MissingVideoError("Uploaded video file is empty (0 bytes received).")

    return await orchestrator.perceive_video(
        video_bytes=video_bytes,
        language=language,
        client_metadata=client_metadata,
        request_id=req_id,
    )

