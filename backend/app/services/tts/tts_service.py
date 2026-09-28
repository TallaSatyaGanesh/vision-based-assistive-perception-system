"""Text-to-Speech (TTS) service interface placeholder.

Responsible for converting natural-language descriptions into speech audio streams
in English, Telugu, and future supported languages.
Full TTS synthesis will be implemented in subsequent phases.
"""

from abc import ABC, abstractmethod


class BaseTTSService(ABC):
    """Abstract interface for speech synthesis."""

    @abstractmethod
    async def synthesize(self, text: str, language_code: str) -> bytes:
        """Synthesize text to audio bytes (e.g. MP3/WAV)."""
        pass
