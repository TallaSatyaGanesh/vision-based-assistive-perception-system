"""Unit test suite for GeminiVisionProvider and dynamic provider selection.

All tests utilize mocked responses and client stubs. Zero external network calls.
No API keys or cloud credentials required.
"""

import asyncio
import io
import pytest
from unittest.mock import AsyncMock, MagicMock
from PIL import Image
from google.genai import errors as genai_errors

from app.core.config import settings
from app.core.errors import (
    ProviderUnavailableError,
    ServiceTimeoutError,
    VisionProcessingError,
)
from app.services.vision.gemini_provider import GeminiVisionProvider
from app.services.vision.mock_provider import MockVisionProvider
from app.services.vision.models import (
    DetectedObject,
    DistanceEstimate,
    SceneContext,
    SpatialPosition,
    StructuredScene,
)
from app.services.vision.orchestrator import orchestrator
from app.services.vision.provider_factory import get_vision_provider


def create_test_image_bytes() -> bytes:
    """Helper to generate a valid in-memory JPEG byte stream."""
    img = Image.new("RGB", (100, 100), color="blue")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def sample_structured_scene_json() -> str:
    """Valid canonical JSON matching StructuredScene."""
    scene = StructuredScene(
        primary_focus="person standing in front",
        context=SceneContext(
            setting="indoor living room",
            lighting="well-lit",
            hazards_or_obstacles=[],
            observed_features=["person", "chair", "table"],
            inferred_context=["residential room"],
            unavailable_information=["rear wall distance unknown"],
        ),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.NEAR,
                confidence=0.96,
                attributes=["standing"],
                interaction="looking towards camera",
                is_obstacle=False,
            ),
            DetectedObject(
                label="chair",
                position=SpatialPosition.LEFT,
                distance=DistanceEstimate.NEAR,
                confidence=0.92,
                attributes=["wooden"],
                interaction=None,
                is_obstacle=False,
            ),
            DetectedObject(
                label="table",
                position=SpatialPosition.CENTER,
                distance=DistanceEstimate.MEDIUM,
                confidence=0.89,
                attributes=["nearby"],
                interaction=None,
                is_obstacle=False,
            ),
        ],
    )
    return scene.model_dump_json()


# 1. Gemini provider initialization without API key
def test_gemini_init_without_api_key(monkeypatch):
    """Verify that initializing GeminiVisionProvider without an API key raises ValueError."""
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "")
    with pytest.raises(ValueError, match="Gemini API key is required"):
        GeminiVisionProvider(api_key="")


# 2. Gemini provider configuration
def test_gemini_provider_configuration():
    """Verify that GeminiVisionProvider correctly reads model and timeout configurations."""
    mock_client = MagicMock()
    provider = GeminiVisionProvider(
        api_key="test-api-key",
        model_name="gemini-2.5-flash",
        timeout_seconds=20.0,
        client=mock_client,
    )
    assert provider.model_name == "gemini-2.5-flash"
    assert provider.timeout_seconds == 20.0
    assert "gemini-2.5-flash" in provider.provider_name


# 3. Mocked successful Gemini response
@pytest.mark.asyncio
async def test_gemini_mocked_successful_response():
    """Verify that GeminiVisionProvider parses valid JSON into StructuredScene."""
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = sample_structured_scene_json()
    mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

    provider = GeminiVisionProvider(api_key="test-key", client=mock_client)
    scene = await provider.analyze_scene(create_test_image_bytes(), language="en")

    assert isinstance(scene, StructuredScene)
    assert len(scene.objects) == 3
    assert scene.objects[0].label == "person"
    assert scene.objects[0].position == SpatialPosition.FRONT
    assert scene.context.setting == "indoor living room"


# 4. Mocked malformed response
@pytest.mark.asyncio
async def test_gemini_mocked_malformed_response():
    """Verify that malformed or non-JSON response raises VisionProcessingError."""
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = "This is not valid JSON content."
    mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

    provider = GeminiVisionProvider(api_key="test-key", client=mock_client)
    with pytest.raises(VisionProcessingError, match="Failed to parse structured scene"):
        await provider.analyze_scene(create_test_image_bytes(), language="en")


# 5. Mocked timeout
@pytest.mark.asyncio
async def test_gemini_mocked_timeout():
    """Verify that network timeout raises ServiceTimeoutError."""
    mock_client = MagicMock()
    mock_client.aio.models.generate_content = AsyncMock(side_effect=asyncio.TimeoutError())

    provider = GeminiVisionProvider(api_key="test-key", client=mock_client, timeout_seconds=0.1)
    with pytest.raises(ServiceTimeoutError, match="timed out"):
        await provider.analyze_scene(create_test_image_bytes(), language="en")


# 6. Mocked authentication failure (401/403)
@pytest.mark.asyncio
async def test_gemini_mocked_auth_failure():
    """Verify that 401/403 error raises ProviderUnavailableError without leaking keys."""
    mock_client = MagicMock()
    mock_client.aio.models.generate_content = AsyncMock(
        side_effect=genai_errors.APIError(code=401, response_json={"error": "Invalid API key"})
    )

    provider = GeminiVisionProvider(api_key="test-key", client=mock_client)
    with pytest.raises(ProviderUnavailableError, match="authentication failed"):
        await provider.analyze_scene(create_test_image_bytes(), language="en")


# 7. Mocked provider unavailable (503)
@pytest.mark.asyncio
async def test_gemini_mocked_provider_unavailable():
    """Verify that 503 error raises ProviderUnavailableError."""
    mock_client = MagicMock()
    mock_client.aio.models.generate_content = AsyncMock(
        side_effect=genai_errors.APIError(code=503, response_json={"error": "Service unavailable"})
    )

    provider = GeminiVisionProvider(api_key="test-key", client=mock_client)
    with pytest.raises(ProviderUnavailableError, match="temporary downtime"):
        await provider.analyze_scene(create_test_image_bytes(), language="en")


# 8. English perception pipeline with mocked Gemini provider
@pytest.mark.asyncio
async def test_gemini_english_perception_pipeline():
    """Verify end-to-end perception flow for English using mocked Gemini provider."""
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = sample_structured_scene_json()
    mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

    gemini_provider = GeminiVisionProvider(api_key="test-key", client=mock_client)
    orchestrator.vision_provider = gemini_provider

    try:
        response = await orchestrator.perceive(create_test_image_bytes(), language="en")
        assert response.status == "success"
        assert response.language == "en"
        assert "person is standing in front of you" in response.description or "person standing in front of you" in response.description
        assert "chair is on your left" in response.description
    finally:
        orchestrator.vision_provider = None


# 9. Telugu perception pipeline with mocked Gemini provider
@pytest.mark.asyncio
async def test_gemini_telugu_perception_pipeline():
    """Verify end-to-end perception flow for Telugu using mocked Gemini provider."""
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = sample_structured_scene_json()
    mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

    gemini_provider = GeminiVisionProvider(api_key="test-key", client=mock_client)
    orchestrator.vision_provider = gemini_provider

    try:
        response = await orchestrator.perceive(create_test_image_bytes(), language="te")
        assert response.status == "success"
        assert response.language == "te"
        assert "మీ ముందు ఒక వ్యక్తి ఉన్నారు" in response.description
        assert "కుర్చీ" in response.description
    finally:
        orchestrator.vision_provider = None


# 10. Fallback to MockVisionProvider when GEMINI_API_KEY is absent
def test_mock_fallback_when_gemini_key_absent(monkeypatch):
    """Verify that get_vision_provider returns MockVisionProvider when no key is set."""
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "")
    provider = get_vision_provider()
    assert isinstance(provider, MockVisionProvider)
    assert provider.provider_name == "mock_provider"


# 11. Provider selection logic when GEMINI_API_KEY is present
def test_provider_selection_when_key_present(monkeypatch):
    """Verify that get_vision_provider returns GeminiVisionProvider when key is present."""
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "real-or-test-api-key")
    provider = get_vision_provider()
    assert isinstance(provider, GeminiVisionProvider)
    assert "gemini" in provider.provider_name


# 12. No silent fallback on Gemini runtime failure during active request
@pytest.mark.asyncio
async def test_no_silent_fallback_on_gemini_runtime_failure():
    """Verify that when Gemini is active and crashes, it does NOT silently fall back to mock data."""
    mock_client = MagicMock()
    mock_client.aio.models.generate_content = AsyncMock(
        side_effect=genai_errors.APIError(code=500, response_json={"error": "Internal Error"})
    )
    gemini_provider = GeminiVisionProvider(api_key="test-key", client=mock_client)
    orchestrator.vision_provider = gemini_provider

    try:
        with pytest.raises(ProviderUnavailableError):
            await orchestrator.perceive(create_test_image_bytes(), language="en")
    finally:
        orchestrator.vision_provider = None


# 13. Gemini analyze_video success with mocked response
@pytest.mark.asyncio
async def test_gemini_analyze_video_success():
    """Verify that analyze_video properly formats Part and parses StructuredScene."""
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = sample_structured_scene_json()
    mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

    provider = GeminiVisionProvider(api_key="test-key", client=mock_client)
    dummy_video_bytes = b"\x00\x00\x00\x1cftypisom" + b"dummy-video-data"

    scene = await provider.analyze_video(dummy_video_bytes, language="en")
    assert isinstance(scene, StructuredScene)
    assert len(scene.objects) == 3
    assert scene.objects[0].label == "person"
    assert mock_client.aio.models.generate_content.called


# 14. Gemini analyze_video timeout handling
@pytest.mark.asyncio
async def test_gemini_analyze_video_timeout():
    """Verify that analyze_video converts asyncio.TimeoutError into ServiceTimeoutError."""
    mock_client = MagicMock()
    mock_client.aio.models.generate_content = AsyncMock(side_effect=asyncio.TimeoutError())

    provider = GeminiVisionProvider(
        api_key="test-key",
        video_timeout_seconds=0.01,
        client=mock_client,
    )

    with pytest.raises(ServiceTimeoutError, match="Gemini video analysis timed out"):
        await provider.analyze_video(b"dummy-video", language="en")


# 15. Gemini analyze_video 429 rate limit error
@pytest.mark.asyncio
async def test_gemini_analyze_video_rate_limit():
    """Verify that 429 APIError from Gemini video call raises ProviderUnavailableError."""
    mock_client = MagicMock()
    mock_client.aio.models.generate_content = AsyncMock(
        side_effect=genai_errors.APIError(code=429, response_json={"error": "Rate limit exceeded"})
    )

    provider = GeminiVisionProvider(api_key="test-key", client=mock_client)

    with pytest.raises(ProviderUnavailableError, match="quota or rate limit exceeded"):
        await provider.analyze_video(b"dummy-video", language="en")


# 16. Gemini analyze_video 401 authentication error
@pytest.mark.asyncio
async def test_gemini_analyze_video_auth_error():
    """Verify that 401 APIError raises ProviderUnavailableError with authentication message."""
    mock_client = MagicMock()
    mock_client.aio.models.generate_content = AsyncMock(
        side_effect=genai_errors.APIError(code=401, response_json={"error": "Unauthorized"})
    )

    provider = GeminiVisionProvider(api_key="test-key", client=mock_client)

    with pytest.raises(ProviderUnavailableError, match="authentication failed"):
        await provider.analyze_video(b"dummy-video", language="en")


# 17. Gemini analyze_video malformed JSON handling
@pytest.mark.asyncio
async def test_gemini_analyze_video_malformed_json():
    """Verify that non-JSON output from Gemini raises VisionProcessingError."""
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = "This is not valid JSON at all."
    mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

    provider = GeminiVisionProvider(api_key="test-key", client=mock_client)

    with pytest.raises(VisionProcessingError, match="Failed to parse structured scene"):
        await provider.analyze_video(b"dummy-video", language="en")


# 18. Gemini analyze_video empty response handling
@pytest.mark.asyncio
async def test_gemini_analyze_video_empty_response():
    """Verify that empty response from Gemini raises VisionProcessingError."""
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = ""
    mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

    provider = GeminiVisionProvider(api_key="test-key", client=mock_client)

    with pytest.raises(VisionProcessingError, match="Gemini returned an empty response"):
        await provider.analyze_video(b"dummy-video", language="en")


# 19. No silent fallback on Gemini video runtime failure
@pytest.mark.asyncio
async def test_no_silent_fallback_on_gemini_video_runtime_failure():
    """Verify that when Gemini fails during video perception, orchestrator does NOT fall back to mock."""
    mock_client = MagicMock()
    mock_client.aio.models.generate_content = AsyncMock(
        side_effect=genai_errors.APIError(code=500, response_json={"error": "Internal Error"})
    )
    gemini_provider = GeminiVisionProvider(api_key="test-key", client=mock_client)
    orchestrator.vision_provider = gemini_provider

    # Create synthetic short video
    from tests.test_perceive_video import create_test_video_bytes
    video_bytes = create_test_video_bytes(duration_seconds=2.0)

    try:
        with pytest.raises(ProviderUnavailableError):
            await orchestrator.perceive_video(video_bytes, language="en")
    finally:
        orchestrator.vision_provider = None

