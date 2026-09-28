"""Comprehensive test suite for POST /api/v1/perceive and perception pipeline.

All tests utilize local mocked vision providers with zero external cloud calls.
No API keys or cloud credentials required.
"""

import io
import pytest
from PIL import Image
from fastapi.testclient import TestClient

from app.main import app
from app.services.vision.mock_provider import MockVisionProvider
from app.services.vision.orchestrator import orchestrator

client = TestClient(app)


def create_test_image_bytes(format_name: str = "JPEG", size: tuple = (200, 200)) -> bytes:
    """Helper to generate a valid in-memory image for testing."""
    img = Image.new("RGB", size, color=(73, 109, 137))
    buf = io.BytesIO()
    img.save(buf, format=format_name)
    return buf.getvalue()


@pytest.fixture(autouse=True)
def reset_orchestrator_provider():
    """Ensure the orchestrator uses normal mock provider for each test."""
    orchestrator.vision_provider = MockVisionProvider(simulate_failure=False)
    yield
    orchestrator.vision_provider = MockVisionProvider(simulate_failure=False)


def test_missing_image_payload():
    """Verify that omitting the image field returns a standardized 400 MISSING_IMAGE error."""
    response = client.post("/api/v1/perceive", data={"language": "en"})
    assert response.status_code == 400
    data = response.json()
    assert data["status"] == "error"
    assert data["error_code"] == "MISSING_IMAGE"
    assert "request_id" in data
    assert "message" in data


def test_empty_image_bytes():
    """Verify that uploading an empty file (0 bytes) returns 400 error."""
    files = {"image": ("empty.jpg", b"", "image/jpeg")}
    response = client.post("/api/v1/perceive", files=files, data={"language": "en"})
    assert response.status_code == 400
    data = response.json()
    assert data["status"] == "error"
    assert data["error_code"] == "MISSING_IMAGE"


def test_invalid_corrupted_image():
    """Verify that uploading corrupted/non-image bytes returns 422 INVALID_IMAGE error."""
    files = {"image": ("corrupted.jpg", b"not-a-valid-image-byte-stream", "image/jpeg")}
    response = client.post("/api/v1/perceive", files=files, data={"language": "en"})
    assert response.status_code == 422
    data = response.json()
    assert data["status"] == "error"
    assert data["error_code"] == "INVALID_IMAGE"
    assert "message" in data


def test_unsupported_language():
    """Verify that requesting an unsupported language code returns 400 UNSUPPORTED_LANGUAGE."""
    img_bytes = create_test_image_bytes()
    files = {"image": ("test.jpg", img_bytes, "image/jpeg")}
    response = client.post("/api/v1/perceive", files=files, data={"language": "fr"})
    assert response.status_code == 400
    data = response.json()
    assert data["status"] == "error"
    assert data["error_code"] == "UNSUPPORTED_LANGUAGE"
    assert "supported_languages" in data["details"]
    assert "en" in data["details"]["supported_languages"]
    assert "te" in data["details"]["supported_languages"]


def test_valid_english_perception():
    """Verify successful perception with English output using mocked vision provider."""
    img_bytes = create_test_image_bytes()
    files = {"image": ("test.jpg", img_bytes, "image/jpeg")}
    response = client.post(
        "/api/v1/perceive",
        files=files,
        data={"language": "en", "request_id": "test-req-en-001"},
    )
    assert response.status_code == 200
    data = response.json()

    # Contract verification
    assert data["request_id"] == "test-req-en-001"
    assert data["status"] == "success"
    assert data["language"] == "en"
    assert isinstance(data["processing_time_ms"], (int, float))
    assert data["processing_time_ms"] > 0

    # Natural language description verification
    assert "person" in data["description"]
    assert "in front of you" in data["description"]
    assert "chair is on your left" in data["description"]

    # Structured scene verification
    scene = data["scene_data"]
    assert "objects" in scene
    assert len(scene["objects"]) >= 2
    assert scene["objects"][0]["label"] == "person"
    assert scene["objects"][0]["position"] == "front"


def test_valid_telugu_perception():
    """Verify successful perception with Telugu output using mocked vision provider."""
    img_bytes = create_test_image_bytes()
    files = {"image": ("test.jpg", img_bytes, "image/jpeg")}
    response = client.post(
        "/api/v1/perceive",
        files=files,
        data={"language": "te", "request_id": "test-req-te-002"},
    )
    assert response.status_code == 200
    data = response.json()

    assert data["request_id"] == "test-req-te-002"
    assert data["status"] == "success"
    assert data["language"] == "te"

    # Natural language description in Telugu
    desc = data["description"]
    assert "మీ ముందు ఒక వ్యక్తి ఉన్నారు" in desc
    assert "కుర్చీ" in desc
    assert "ఎడమ వైపున" in desc


def test_provider_failure_handling():
    """Verify that vision provider failures return clean 503 PROVIDER_UNAVAILABLE without leaking traces."""
    orchestrator.vision_provider = MockVisionProvider(simulate_failure=True)
    img_bytes = create_test_image_bytes()
    files = {"image": ("test.jpg", img_bytes, "image/jpeg")}

    response = client.post("/api/v1/perceive", files=files, data={"language": "en"})
    assert response.status_code == 503
    data = response.json()
    assert data["status"] == "error"
    assert data["error_code"] == "PROVIDER_UNAVAILABLE"
    assert "message" in data
    # Ensure no internal Python traceback was exposed
    assert "Traceback" not in data["message"]


def test_response_schema_completeness():
    """Verify that all required fields from PerceptionResponse schema are present."""
    img_bytes = create_test_image_bytes()
    files = {"image": ("test.jpg", img_bytes, "image/jpeg")}
    response = client.post("/api/v1/perceive", files=files, data={"language": "en"})
    assert response.status_code == 200
    data = response.json()

    expected_keys = {
        "request_id",
        "status",
        "language",
        "description",
        "scene_data",
        "processing_time_ms",
        "warnings",
        "errors",
    }
    assert expected_keys.issubset(data.keys())


def test_distinguish_observed_vs_inferred_vs_unknown():
    """Verify that the structured scene model strictly separates observed, inferred, and unknown fields."""
    img_bytes = create_test_image_bytes()
    files = {"image": ("test.jpg", img_bytes, "image/jpeg")}
    response = client.post("/api/v1/perceive", files=files, data={"language": "en"})
    assert response.status_code == 200
    scene = response.json()["scene_data"]
    context = scene["context"]

    assert "observed_features" in context
    assert "inferred_context" in context
    assert "unavailable_information" in context
    assert len(context["unavailable_information"]) > 0
