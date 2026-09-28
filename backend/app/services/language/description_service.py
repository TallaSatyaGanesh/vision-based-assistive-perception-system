"""Assistive Description Service.

Orchestrates conversion from canonical StructuredScene into concise natural language
guidance tailored for visually impaired auditory consumption.
"""

from app.services.language.language_manager import language_manager
from app.services.vision.models import StructuredScene


class AssistiveDescriptionService:
    """Service to convert structured scene perception into natural language voice descriptions."""

    def __init__(self, manager=None):
        self.manager = manager or language_manager

    def generate_description(self, scene: StructuredScene, language_code: str = "en") -> str:
        """Generate a concise 1-3 sentence assistive narrative in the target language.

        Args:
            scene: Structured environmental scene representation.
            language_code: Target language (e.g. 'en', 'te').

        Returns:
            Concise, audio-optimized natural language description.
        """
        builder = self.manager.get_builder(language_code)
        return builder.build_description(scene)


# Shared description service instance
description_service = AssistiveDescriptionService()
