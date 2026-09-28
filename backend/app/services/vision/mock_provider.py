"""Mock Vision Provider for local testing and offline development.

Simulates provider responses adhering to the StructuredScene contract
without requiring external network calls or cloud credentials.
"""

from typing import Optional
from app.core.errors import ProviderUnavailableError
from app.services.vision.models import (
    DistanceEstimate,
    DetectedObject,
    SceneContext,
    SpatialPosition,
    StructuredScene,
)
from app.services.vision.vision_provider import VisionProvider


class MockVisionProvider(VisionProvider):
    """Deterministic mock vision provider for testing perception contracts."""

    def __init__(self, simulate_failure: bool = False):
        self.simulate_failure = simulate_failure

    @property
    def provider_name(self) -> str:
        return "mock_provider"

    async def analyze_scene(
        self,
        image_bytes: bytes,
        language: str = "en",
        context_hint: Optional[str] = None,
    ) -> StructuredScene:
        """Simulate scene analysis returning standard structured objects."""
        if self.simulate_failure:
            raise ProviderUnavailableError("Simulated mock provider network failure.")

        # Canonical example matching project proposal:
        # A person is standing in front of you, chair on left, table nearby.
        return StructuredScene(
            primary_focus="person standing in front",
            context=SceneContext(
                setting="indoor room",
                lighting="well-lit",
                hazards_or_obstacles=[],
                observed_features=["person", "chair", "table"],
                inferred_context=["indoor residential or office space"],
                unavailable_information=["exact distance to rear wall is unknown"],
            ),
            objects=[
                DetectedObject(
                    label="person",
                    position=SpatialPosition.FRONT,
                    distance=DistanceEstimate.NEAR,
                    confidence=0.95,
                    attributes=["standing"],
                    interaction="facing towards you",
                    is_obstacle=False,
                ),
                DetectedObject(
                    label="chair",
                    position=SpatialPosition.LEFT,
                    distance=DistanceEstimate.NEAR,
                    confidence=0.91,
                    attributes=["wooden", "office chair"],
                    interaction=None,
                    is_obstacle=False,
                ),
                DetectedObject(
                    label="table",
                    position=SpatialPosition.CENTER,
                    distance=DistanceEstimate.MEDIUM,
                    confidence=0.88,
                    attributes=["nearby"],
                    interaction=None,
                    is_obstacle=False,
                ),
            ],
        )

    async def analyze_video(
        self,
        video_bytes: bytes,
        language: str = "en",
        context_hint: Optional[str] = None,
    ) -> StructuredScene:
        """Simulate video analysis returning canonical structured scene with motion."""
        if self.simulate_failure:
            raise ProviderUnavailableError("Simulated mock provider network failure.")

        return StructuredScene(
            primary_focus="person walking towards you",
            context=SceneContext(
                setting="hallway",
                lighting="well-lit",
                hazards_or_obstacles=[],
                observed_features=["person walking", "clear walkway"],
                inferred_context=["indoor corridor"],
                unavailable_information=[],
            ),
            objects=[
                DetectedObject(
                    label="person",
                    position=SpatialPosition.FRONT,
                    distance=DistanceEstimate.NEAR,
                    confidence=0.95,
                    attributes=["walking"],
                    activity="walking towards you",
                    interaction="approaching along the corridor",
                    is_obstacle=False,
                ),
            ],
            relationships=["person is walking towards you in the hallway"],
        )

