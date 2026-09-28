"""Comprehensive test suite for POST /api/v1/perceive/video endpoint.

All tests utilize local mock vision providers or synthetic MP4 clips with zero external cloud calls.
No API keys or cloud credentials required.
"""

from __future__ import annotations

import io
import os
import tempfile
import cv2
from fastapi.testclient import TestClient
import numpy as np
import pytest

from app.main import app
from app.services.vision.mock_provider import MockVisionProvider
from app.services.vision.orchestrator import orchestrator
from app.services.vision.video_validator import VideoValidator

client = TestClient(app)


def create_test_video_bytes(
    duration_seconds: float = 2.0,
    fps: float = 10.0,
    width: int = 160,
    height: int = 120,
) -> bytes:
    """Helper to generate an in-memory synthetic MP4 video for API testing."""
    with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
        temp_path = f.name

    try:
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        out = cv2.VideoWriter(temp_path, fourcc, fps, (width, height))
        frame_count = int(duration_seconds * fps)
        for i in range(frame_count):
            frame = np.zeros((height, width, 3), dtype=np.uint8)
            cv2.circle(frame, (20 + (i % 40), 20 + (i % 40)), 10, (255, 255, 255), -1)
            out.write(frame)
        out.release()

        with open(temp_path, "rb") as f:
            return f.read()
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


@pytest.fixture(autouse=True)
def reset_orchestrator_provider():
    """Ensure the orchestrator uses normal mock provider for each test."""
    orchestrator.vision_provider = MockVisionProvider(simulate_failure=False)
    yield
    orchestrator.vision_provider = MockVisionProvider(simulate_failure=False)


def test_valid_video_english_request():
    """Verify that uploading a valid 2s MP4 with language='en' returns 200 OK and English description."""
    video_bytes = create_test_video_bytes(duration_seconds=2.0)
    files = {"video": ("scene.mp4", video_bytes, "video/mp4")}
    data = {"language": "en"}

    response = client.post("/api/v1/perceive/video", files=files, data=data)
    assert response.status_code == 200
    res = response.json()

    assert res["status"] == "success"
    assert res["language"] == "en"
    assert len(res["description"]) > 0
    assert "person" in res["description"].lower()
    assert "scene_data" in res
    assert res["processing_time_ms"] > 0
    assert "request_id" in res


def test_valid_video_telugu_request():
    """Verify that uploading a valid 2s MP4 with language='te' returns 200 OK and Telugu description."""
    video_bytes = create_test_video_bytes(duration_seconds=2.0)
    files = {"video": ("scene.mp4", video_bytes, "video/mp4")}
    data = {"language": "te"}

    response = client.post("/api/v1/perceive/video", files=files, data=data)
    assert response.status_code == 200
    res = response.json()

    assert res["status"] == "success"
    assert res["language"] == "te"
    assert len(res["description"]) > 0
    assert "scene_data" in res


def test_missing_video_field():
    """Verify that omitting the 'video' field returns HTTP 400 MISSING_VIDEO error."""
    response = client.post("/api/v1/perceive/video", data={"language": "en"})
    assert response.status_code == 400
    data = response.json()

    assert data["status"] == "error"
    assert data["error_code"] == "MISSING_VIDEO"
    assert "request_id" in data


def test_empty_video_file():
    """Verify that uploading an empty video file (0 bytes) returns HTTP 400 MISSING_VIDEO error."""
    files = {"video": ("empty.mp4", b"", "video/mp4")}
    response = client.post("/api/v1/perceive/video", files=files, data={"language": "en"})
    assert response.status_code == 400
    data = response.json()

    assert data["status"] == "error"
    assert data["error_code"] == "MISSING_VIDEO"


def test_invalid_corrupted_video_file():
    """Verify that uploading non-MP4 bytes returns HTTP 422 INVALID_VIDEO error."""
    files = {"video": ("corrupted.mp4", b"not-a-valid-mp4-file-content" * 10, "video/mp4")}
    response = client.post("/api/v1/perceive/video", files=files, data={"language": "en"})
    assert response.status_code == 422
    data = response.json()

    assert data["status"] == "error"
    assert data["error_code"] == "INVALID_VIDEO"


def test_oversized_video_file(monkeypatch):
    """Verify that uploading video exceeding 25 MiB returns HTTP 413 VIDEO_TOO_LARGE."""
    # Temporarily set max size to 1 KiB on orchestrator's video validator to test without allocating 26 MB
    monkeypatch.setattr(orchestrator.video_validator, "MAX_FILE_SIZE_BYTES", 1024)

    dummy_oversized = b"\x00\x00\x00\x1cftypisom" + b"A" * 2048
    files = {"video": ("huge.mp4", dummy_oversized, "video/mp4")}
    response = client.post("/api/v1/perceive/video", files=files, data={"language": "en"})

    assert response.status_code == 413
    data = response.json()
    assert data["status"] == "error"
    assert data["error_code"] == "VIDEO_TOO_LARGE"


def test_over_duration_video_file():
    """Verify that uploading a video longer than 10 seconds returns HTTP 422 VIDEO_TOO_LONG."""
    # 12.0 seconds at 10 fps
    long_video_bytes = create_test_video_bytes(duration_seconds=12.0)
    files = {"video": ("long.mp4", long_video_bytes, "video/mp4")}

    response = client.post("/api/v1/perceive/video", files=files, data={"language": "en"})
    assert response.status_code == 422
    data = response.json()

    assert data["status"] == "error"
    assert data["error_code"] == "VIDEO_TOO_LONG"
    assert "exceeds the maximum allowed limit of 10.0 seconds" in data["message"]


def test_unsupported_language_code():
    """Verify that requesting an unsupported language code returns HTTP 400 UNSUPPORTED_LANGUAGE."""
    video_bytes = create_test_video_bytes(duration_seconds=2.0)
    files = {"video": ("scene.mp4", video_bytes, "video/mp4")}

    response = client.post("/api/v1/perceive/video", files=files, data={"language": "spanish"})
    assert response.status_code == 400
    data = response.json()

    assert data["status"] == "error"
    assert data["error_code"] == "UNSUPPORTED_LANGUAGE"


def test_mock_provider_failure_returns_503():
    """Verify that provider failure raises 503 PROVIDER_UNAVAILABLE cleanly."""
    orchestrator.vision_provider = MockVisionProvider(simulate_failure=True)

    video_bytes = create_test_video_bytes(duration_seconds=2.0)
    files = {"video": ("scene.mp4", video_bytes, "video/mp4")}

    response = client.post("/api/v1/perceive/video", files=files, data={"language": "en"})
    assert response.status_code == 503
    data = response.json()

    assert data["status"] == "error"
    assert data["error_code"] == "PROVIDER_UNAVAILABLE"


def test_custom_request_id_and_client_metadata():
    """Verify that client-supplied request_id and client_metadata are handled properly."""
    video_bytes = create_test_video_bytes(duration_seconds=2.0)
    files = {"video": ("scene.mp4", video_bytes, "video/mp4")}
    data = {
        "language": "en",
        "request_id": "custom-video-req-777",
        "client_metadata": "facing forward",
    }

    response = client.post("/api/v1/perceive/video", files=files, data=data)
    assert response.status_code == 200
    res = response.json()

    assert res["request_id"] == "custom-video-req-777"
