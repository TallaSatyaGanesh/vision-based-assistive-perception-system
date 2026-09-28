"""Vision-Language Model (VLM) service interface placeholder.

Actual VLM integration (e.g., Gemini Flash / cloud VLM) will be implemented
in the approved AI vision phase. No model SDKs are imported at this stage.
"""

from abc import ABC, abstractmethod
from typing import Any, Dict


class BaseVisionService(ABC):
    """Abstract interface for scene perception and vision analysis."""

    @abstractmethod
    async def describe_scene(self, image_bytes: bytes, target_language: str = "en") -> Dict[str, Any]:
        """Analyze an image and return a natural language spatial description."""
        pass
