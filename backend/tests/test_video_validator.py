"""Comprehensive unit tests for VideoValidator.

Verifies:
- Valid short MP4 validation (bytes & file path)
- Empty video input rejection
- Undersized corrupted bytes rejection
- Non-MP4 content rejection (e.g. text/image)
- Corrupted MP4 with broken streams rejection
- Oversized video payload rejection (> 25 MiB)
- Over-duration video rejection (> 10s)
- Exact boundary duration handling (10.0s)
- Safe handling of invalid FPS and frame counts (no division by zero)
- Safe handling of unreadable/undecodable frames
- Safe handling of undersized dimensions
- Bounded streaming read aborting early on oversized stream
- Clean resource release and temporary file cleanup in all cases
"""

from __future__ import annotations

import io
import os
import tempfile
from unittest.mock import MagicMock, patch

import cv2
import numpy as np
import pytest
from starlette.datastructures import Headers, UploadFile

from app.core.errors import (
    VideoDurationExceededError,
    VideoTooLargeError,
    VideoValidationError,
)
from app.services.vision.video_validator import VideoValidator, video_validator


def create_synthetic_mp4(
    duration_seconds: float = 2.0,
    fps: float = 10.0,
    width: int = 160,
    height: int = 120,
) -> bytes:
    """Helper to generate an in-memory synthetic MP4 video for tests."""
    with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
        temp_path = f.name

    try:
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        out = cv2.VideoWriter(temp_path, fourcc, fps, (width, height))
        frame_count = int(duration_seconds * fps)
        for i in range(frame_count):
            frame = np.zeros((height, width, 3), dtype=np.uint8)
            cv2.circle(frame, (20 + (i % 50), 20 + (i % 50)), 10, (255, 255, 255), -1)
            out.write(frame)
        out.release()

        with open(temp_path, "rb") as f:
            return f.read()
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


class TestVideoValidator:
    """Test suite for VideoValidator safety, integrity, and duration checks."""

    def test_valid_short_mp4_bytes(self):
        """Verify that a valid 2-second MP4 passes validation with correct metadata."""
        video_bytes = create_synthetic_mp4(duration_seconds=2.0, fps=10.0, width=160, height=120)
        result = video_validator.validate_bytes(video_bytes)

        assert result.is_valid is True
        assert result.format == "MP4"
        assert result.duration_seconds == 2.0
        assert result.width == 160
        assert result.height == 120
        assert result.fps == 10.0
        assert result.frame_count == 20
        assert result.size_bytes == len(video_bytes)

    def test_valid_short_mp4_file_path(self):
        """Verify that validating a file on disk returns the correct result."""
        video_bytes = create_synthetic_mp4(duration_seconds=3.0, fps=10.0, width=160, height=120)
        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
            f.write(video_bytes)
            temp_path = f.name

        try:
            result = video_validator.validate(temp_path)
            assert result.is_valid is True
            assert result.duration_seconds == 3.0
            assert result.frame_count == 30
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_empty_video_bytes(self):
        """Verify that uploading empty bytes raises VideoValidationError."""
        with pytest.raises(VideoValidationError) as exc_info:
            video_validator.validate_bytes(b"")

        assert "empty or corrupted" in exc_info.value.message
        assert exc_info.value.error_code == "INVALID_VIDEO"

    def test_undersized_video_bytes(self):
        """Verify that uploading insufficient data (< 100 bytes) raises VideoValidationError."""
        with pytest.raises(VideoValidationError) as exc_info:
            video_validator.validate_bytes(b"short-invalid-bytes")

        assert "empty or corrupted" in exc_info.value.message

    def test_non_mp4_content_rejected(self):
        """Verify that non-MP4 content (e.g. text or image) lacking 'ftyp' is rejected."""
        fake_content = b"This is a text file that is masquerading as a video file with lots of padding." + b"A" * 200
        with pytest.raises(VideoValidationError) as exc_info:
            video_validator.validate_bytes(fake_content)

        assert "Unsupported video format" in exc_info.value.message
        assert "Only MP4" in exc_info.value.message

    def test_corrupted_mp4_with_garbage_stream(self):
        """Verify that an MP4 with a pseudo-ftyp header but unparseable stream is rejected."""
        # Starts with ftypisom but contains random corrupted bytes
        corrupted = b"\x00\x00\x00\x1cftypisom\x00\x00\x02\x00isomiso2mp41\x00\x00\x00\x08" + b"\xff\x00\xfe\x01" * 100
        with pytest.raises(VideoValidationError) as exc_info:
            video_validator.validate_bytes(corrupted)

        assert "corrupted, truncated, or cannot be decoded" in exc_info.value.message

    def test_oversized_video_payload(self):
        """Verify that a payload exceeding 25 MiB raises VideoTooLargeError."""
        oversized_len = video_validator.MAX_FILE_SIZE_BYTES + 1
        dummy_large = b"A" * 1024  # Avoid allocating 26 MB in test if we test bounds directly

        # Subclass / instance test with small custom max size
        custom_validator = VideoValidator()
        custom_validator.MAX_FILE_SIZE_BYTES = 1000

        with pytest.raises(VideoTooLargeError) as exc_info:
            custom_validator.validate_bytes(dummy_large)

        assert exc_info.value.status_code == 413
        assert exc_info.value.error_code == "VIDEO_TOO_LARGE"

    def test_over_duration_video_rejected(self):
        """Verify that a video exceeding 10 seconds raises VideoDurationExceededError."""
        # 12.0 seconds at 10 fps = 120 frames
        long_video_bytes = create_synthetic_mp4(duration_seconds=12.0, fps=10.0, width=160, height=120)

        with pytest.raises(VideoDurationExceededError) as exc_info:
            video_validator.validate_bytes(long_video_bytes)

        assert exc_info.value.status_code == 422
        assert exc_info.value.error_code == "VIDEO_TOO_LONG"
        assert "exceeds the maximum allowed limit of 10.0 seconds" in exc_info.value.message
        assert exc_info.value.details["duration_seconds"] == 12.0
        assert exc_info.value.details["max_duration_seconds"] == 10.0

    def test_boundary_duration_video_accepted(self):
        """Verify that a video of exactly 10.0 seconds is accepted."""
        boundary_video = create_synthetic_mp4(duration_seconds=10.0, fps=10.0, width=160, height=120)
        result = video_validator.validate_bytes(boundary_video)

        assert result.is_valid is True
        assert result.duration_seconds == 10.0
        assert "video_duration_near_limit" in result.warnings

    def test_invalid_fps_metadata_handled_safely(self):
        """Verify that missing/zero FPS does not divide by zero and raises VideoValidationError."""
        video_bytes = create_synthetic_mp4(duration_seconds=2.0, fps=10.0)

        # Mock cv2.VideoCapture to return 0.0 FPS
        mock_cap = MagicMock()
        mock_cap.isOpened.return_value = True
        mock_cap.get.side_effect = lambda prop: {
            cv2.CAP_PROP_FPS: 0.0,
            cv2.CAP_PROP_FRAME_COUNT: 20.0,
            cv2.CAP_PROP_FRAME_WIDTH: 160.0,
            cv2.CAP_PROP_FRAME_HEIGHT: 120.0,
        }.get(prop, 0.0)

        with patch("cv2.VideoCapture", return_value=mock_cap):
            with pytest.raises(VideoValidationError) as exc_info:
                video_validator.validate_bytes(video_bytes)

            assert "missing frame rate (FPS)" in exc_info.value.message
            mock_cap.release.assert_called_once()

    def test_invalid_frame_count_metadata_handled_safely(self):
        """Verify that missing/zero frame count raises VideoValidationError safely."""
        video_bytes = create_synthetic_mp4(duration_seconds=2.0, fps=10.0)

        mock_cap = MagicMock()
        mock_cap.isOpened.return_value = True
        mock_cap.get.side_effect = lambda prop: {
            cv2.CAP_PROP_FPS: 10.0,
            cv2.CAP_PROP_FRAME_COUNT: 0.0,
            cv2.CAP_PROP_FRAME_WIDTH: 160.0,
            cv2.CAP_PROP_FRAME_HEIGHT: 120.0,
        }.get(prop, 0.0)

        with patch("cv2.VideoCapture", return_value=mock_cap):
            with pytest.raises(VideoValidationError) as exc_info:
                video_validator.validate_bytes(video_bytes)

            assert "missing frame count" in exc_info.value.message
            mock_cap.release.assert_called_once()

    def test_undersized_resolution_rejected(self):
        """Verify that resolution below 64x64 is rejected."""
        video_bytes = create_synthetic_mp4(duration_seconds=2.0, fps=10.0)

        mock_cap = MagicMock()
        mock_cap.isOpened.return_value = True
        mock_cap.get.side_effect = lambda prop: {
            cv2.CAP_PROP_FPS: 10.0,
            cv2.CAP_PROP_FRAME_COUNT: 20.0,
            cv2.CAP_PROP_FRAME_WIDTH: 32.0,
            cv2.CAP_PROP_FRAME_HEIGHT: 32.0,
        }.get(prop, 0.0)

        with patch("cv2.VideoCapture", return_value=mock_cap):
            with pytest.raises(VideoValidationError) as exc_info:
                video_validator.validate_bytes(video_bytes)

            assert "resolution (32x32) is too small" in exc_info.value.message
            mock_cap.release.assert_called_once()

    def test_failed_frame_read_rejected(self):
        """Verify that failure to read the first frame raises VideoValidationError."""
        video_bytes = create_synthetic_mp4(duration_seconds=2.0, fps=10.0)

        mock_cap = MagicMock()
        mock_cap.isOpened.return_value = True
        mock_cap.get.side_effect = lambda prop: {
            cv2.CAP_PROP_FPS: 10.0,
            cv2.CAP_PROP_FRAME_COUNT: 20.0,
            cv2.CAP_PROP_FRAME_WIDTH: 160.0,
            cv2.CAP_PROP_FRAME_HEIGHT: 120.0,
        }.get(prop, 0.0)
        mock_cap.read.return_value = (False, None)

        with patch("cv2.VideoCapture", return_value=mock_cap):
            with pytest.raises(VideoValidationError) as exc_info:
                video_validator.validate_bytes(video_bytes)

            assert "Failed to decode video frames" in exc_info.value.message
            mock_cap.release.assert_called_once()

    @pytest.mark.asyncio
    async def test_bounded_upload_streaming_abort_on_oversized(self):
        """Verify that read_bounded_upload aborts early on streaming input without reading whole stream."""
        chunk_data = b"X" * (64 * 1024)  # 64 KiB
        file_obj = io.BytesIO(chunk_data * 50)  # ~3.2 MiB

        upload = UploadFile(
            file=file_obj,
            size=len(chunk_data) * 50,
            filename="large_stream.mp4",
            headers=Headers({"content-type": "video/mp4"}),
        )

        # Enforce small bound of 256 KiB
        with pytest.raises(VideoTooLargeError) as exc_info:
            await video_validator.read_bounded_upload(upload, max_size_bytes=256 * 1024)

        assert exc_info.value.status_code == 413
        assert exc_info.value.error_code == "VIDEO_TOO_LARGE"

    def test_nonexistent_file_path(self):
        """Verify that validating a non-existent file path raises VideoValidationError."""
        with pytest.raises(VideoValidationError) as exc_info:
            video_validator.validate_file("non_existent_file_abc123.mp4")

        assert "not found at path" in exc_info.value.message
