"""Video validation service for pre-flight quality, format, and duration checks.

Validates that uploaded video files are genuine MP4 containers, strictly within
size limits (<= 25 MiB) and duration bounds (<= 10 seconds), with valid decodable frames.
Does not load unbounded uploads into memory.
"""

from __future__ import annotations

import math
import os
from pathlib import Path
import tempfile
from typing import Any, Dict, List, Optional, Set, Tuple, Union

import cv2
from fastapi import UploadFile
from pydantic import BaseModel, Field

from app.core.errors import (
    VideoDurationExceededError,
    VideoTooLargeError,
    VideoValidationError,
)


class VideoValidationResult(BaseModel):
    """Result metadata of successful video validation."""

    is_valid: bool = True
    format: str = "MP4"
    width: int
    height: int
    fps: float
    frame_count: int
    duration_seconds: float
    size_bytes: int
    warnings: List[str] = Field(default_factory=list)


class VideoValidator:
    """Performs safety, integrity, and duration validation on MP4 video files."""

    SUPPORTED_FORMATS: Set[str] = {"MP4"}
    MAX_FILE_SIZE_BYTES: int = 25 * 1024 * 1024  # 25 MiB (26,214,400 bytes)
    MIN_FILE_SIZE_BYTES: int = 100               # Minimum valid MP4 container size
    MAX_DURATION_SECONDS: float = 10.0           # 10.0 seconds
    MIN_DURATION_SECONDS: float = 0.1            # 0.1 seconds
    MIN_DIMENSION: int = 64                      # Minimum frame width/height
    MAX_DIMENSION: int = 8192                    # Maximum frame width/height
    CHUNK_SIZE: int = 64 * 1024                  # 64 KiB streaming chunk

    @staticmethod
    def is_mp4_container(header_bytes: bytes) -> bool:
        """Verify that the initial bytes contain a valid ISO Base Media (ftyp) box.

        According to ISO/IEC 14496-12, an MP4 container begins with an 'ftyp' box,
        typically within the first 64 bytes.
        """
        if len(header_bytes) < 8:
            return False
        # In standard ISO files, the 4-byte box type 'ftyp' is located at offset 4..8
        if header_bytes[4:8] == b"ftyp":
            return True
        # Allow slight offset (e.g. wide or skip box preceding ftyp) within first 64 bytes
        return b"ftyp" in header_bytes[:64]

    def validate_file(
        self,
        file_path: Union[str, Path],
        size_bytes: Optional[int] = None,
    ) -> VideoValidationResult:
        """Validate a video file located on disk.

        Args:
            file_path: Path to the video file on disk.
            size_bytes: Optional pre-computed file size in bytes.

        Returns:
            VideoValidationResult with verified video metadata.

        Raises:
            VideoValidationError: If format is invalid, corrupted, or unsupported.
            VideoTooLargeError: If size exceeds MAX_FILE_SIZE_BYTES.
            VideoDurationExceededError: If duration exceeds MAX_DURATION_SECONDS.
        """
        path_str = str(file_path)
        if not os.path.exists(path_str):
            raise VideoValidationError(f"Video file not found at path: {path_str}")

        actual_size = size_bytes if size_bytes is not None else os.path.getsize(path_str)

        # 1. Size bounds check
        if actual_size < self.MIN_FILE_SIZE_BYTES:
            raise VideoValidationError(
                "Uploaded video file is empty or corrupted (insufficient data bytes)."
            )

        if actual_size > self.MAX_FILE_SIZE_BYTES:
            raise VideoTooLargeError(
                max_size_mb=self.MAX_FILE_SIZE_BYTES // (1024 * 1024)
            )

        # 2. Container magic bytes check
        try:
            with open(path_str, "rb") as f:
                header_bytes = f.read(64)
        except OSError as exc:
            raise VideoValidationError(f"Unable to read video file header: {str(exc)}")

        if not self.is_mp4_container(header_bytes):
            raise VideoValidationError(
                "Unsupported video format. Only MP4 (ISO Base Media) files are supported."
            )

        # 3. Decode & metadata inspection with OpenCV
        cap: Optional[cv2.VideoCapture] = None
        try:
            cap = cv2.VideoCapture(path_str)
            if not cap.isOpened():
                raise VideoValidationError(
                    "Video file is corrupted, truncated, or cannot be decoded."
                )

            fps = float(cap.get(cv2.CAP_PROP_FPS))
            frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

            # Validate FPS safely (guard against zero, negative, NaN, or infinity)
            if fps <= 0.0 or math.isnan(fps) or math.isinf(fps):
                raise VideoValidationError(
                    "Video metadata contains invalid or missing frame rate (FPS)."
                )

            # Validate frame count safely (guard against zero, negative, NaN, or infinity)
            if frame_count <= 0 or math.isnan(frame_count) or math.isinf(frame_count):
                raise VideoValidationError(
                    "Video metadata contains invalid or missing frame count."
                )

            # Validate resolution
            if width < self.MIN_DIMENSION or height < self.MIN_DIMENSION:
                raise VideoValidationError(
                    f"Video resolution ({width}x{height}) is too small. "
                    f"Minimum resolution is {self.MIN_DIMENSION}x{self.MIN_DIMENSION}."
                )

            # Calculate duration safely
            duration_seconds = frame_count / fps

            if (
                duration_seconds < self.MIN_DURATION_SECONDS
                or math.isnan(duration_seconds)
                or math.isinf(duration_seconds)
            ):
                raise VideoValidationError(
                    f"Video duration ({duration_seconds:.2f}s) is too short or invalid."
                )

            if duration_seconds > self.MAX_DURATION_SECONDS:
                raise VideoDurationExceededError(
                    duration_seconds=duration_seconds,
                    max_duration_seconds=self.MAX_DURATION_SECONDS,
                )

            # 4. Decodability check: verify at least the first frame can be read
            ret, frame = cap.read()
            if not ret or frame is None:
                raise VideoValidationError(
                    "Failed to decode video frames. File may be corrupted or use an unsupported codec."
                )

            # 5. Quality warnings
            warnings: List[str] = []
            if duration_seconds > 8.0:
                warnings.append("video_duration_near_limit")
            if width > 1920 or height > 1920:
                warnings.append("high_resolution_video_may_increase_latency")
            if fps > 60.0:
                warnings.append("high_framerate_video")

            return VideoValidationResult(
                is_valid=True,
                format="MP4",
                width=width,
                height=height,
                fps=round(fps, 2),
                frame_count=frame_count,
                duration_seconds=round(duration_seconds, 2),
                size_bytes=actual_size,
                warnings=warnings,
            )

        except (VideoValidationError, VideoTooLargeError, VideoDurationExceededError):
            raise
        except Exception as exc:
            raise VideoValidationError(
                f"Video file cannot be processed: {str(exc)}"
            )
        finally:
            if cap is not None:
                cap.release()

    def validate_bytes(self, video_bytes: bytes) -> VideoValidationResult:
        """Validate raw video bytes in memory.

        Writes bytes safely to a temporary file on disk for OpenCV processing,
        guaranteeing cleanup in all circumstances.

        Raises:
            VideoValidationError: If format is invalid or corrupted.
            VideoTooLargeError: If size exceeds MAX_FILE_SIZE_BYTES.
            VideoDurationExceededError: If duration exceeds MAX_DURATION_SECONDS.
        """
        size_bytes = len(video_bytes)

        # Early size bounds check before disk I/O
        if size_bytes < self.MIN_FILE_SIZE_BYTES:
            raise VideoValidationError(
                "Uploaded video file is empty or corrupted (insufficient data bytes)."
            )

        if size_bytes > self.MAX_FILE_SIZE_BYTES:
            raise VideoTooLargeError(
                max_size_mb=self.MAX_FILE_SIZE_BYTES // (1024 * 1024)
            )

        # Early container magic bytes check before disk I/O
        if not self.is_mp4_container(video_bytes[:64]):
            raise VideoValidationError(
                "Unsupported video format. Only MP4 (ISO Base Media) files are supported."
            )

        temp_path: Optional[str] = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as temp_file:
                temp_file.write(video_bytes)
                temp_path = temp_file.name

            return self.validate_file(temp_path, size_bytes=size_bytes)
        finally:
            if temp_path and os.path.exists(temp_path):
                try:
                    os.remove(temp_path)
                except OSError:
                    pass

    def validate(self, input_data: Union[bytes, str, Path]) -> VideoValidationResult:
        """Unified validation method accepting either raw bytes or a file path."""
        if isinstance(input_data, bytes):
            return self.validate_bytes(input_data)
        elif isinstance(input_data, (str, Path)):
            return self.validate_file(input_data)
        else:
            raise VideoValidationError(
                f"Unsupported input type for video validation: {type(input_data).__name__}"
            )

    async def read_bounded_upload(
        self,
        upload_file: UploadFile,
        max_size_bytes: Optional[int] = None,
    ) -> bytes:
        """Read an UploadFile stream up to max_size_bytes in bounded chunks.

        Prevents loading unbounded payloads into memory.

        Raises:
            VideoTooLargeError: If bytes read exceed max_size_bytes.
        """
        limit = max_size_bytes or self.MAX_FILE_SIZE_BYTES
        total_bytes = 0
        chunks: List[bytes] = []

        while True:
            chunk = await upload_file.read(self.CHUNK_SIZE)
            if not chunk:
                break
            total_bytes += len(chunk)
            if total_bytes > limit:
                raise VideoTooLargeError(max_size_mb=limit // (1024 * 1024))
            chunks.append(chunk)

        return b"".join(chunks)

    async def save_bounded_upload_to_temp(
        self,
        upload_file: UploadFile,
        max_size_bytes: Optional[int] = None,
    ) -> Tuple[str, int]:
        """Stream an UploadFile directly to a temporary file on disk in bounded chunks.

        Avoids buffering large payloads entirely in memory.

        Returns:
            Tuple of (temp_file_path, total_size_bytes).

        Raises:
            VideoTooLargeError: If payload exceeds max_size_bytes.
        """
        limit = max_size_bytes or self.MAX_FILE_SIZE_BYTES
        total_bytes = 0
        temp_file = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
        temp_path = temp_file.name

        try:
            with temp_file as f:
                while True:
                    chunk = await upload_file.read(self.CHUNK_SIZE)
                    if not chunk:
                        break
                    total_bytes += len(chunk)
                    if total_bytes > limit:
                        raise VideoTooLargeError(max_size_mb=limit // (1024 * 1024))
                    f.write(chunk)
            return temp_path, total_bytes
        except Exception:
            if os.path.exists(temp_path):
                try:
                    os.remove(temp_path)
                except OSError:
                    pass
            raise

    async def validate_upload(
        self,
        upload_file: UploadFile,
    ) -> Tuple[bytes, VideoValidationResult]:
        """Read a bounded upload into memory and validate it.

        Returns:
            Tuple of (video_bytes, VideoValidationResult).
        """
        video_bytes = await self.read_bounded_upload(upload_file)
        result = self.validate_bytes(video_bytes)
        return video_bytes, result


# Default shared validator instance
video_validator = VideoValidator()
