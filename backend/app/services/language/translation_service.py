"""Translation service interface placeholder.

Responsible for translating scene descriptions to target languages if required.
Full translation pipeline will be implemented in subsequent phases.
"""

from abc import ABC, abstractmethod


class BaseTranslationService(ABC):
    """Abstract interface for language translation."""

    @abstractmethod
    async def translate(self, text: str, source_lang: str, target_lang: str) -> str:
        """Translate text from source_lang to target_lang."""
        pass
