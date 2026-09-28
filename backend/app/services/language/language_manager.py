"""Language registry and manager module.

Centralizes configuration for supported languages (English and Telugu initially).
Architected with Strategy pattern to allow extending additional languages without
modifying the core perception pipeline.
"""

from typing import Dict, List, Optional
from pydantic import BaseModel
from app.core.errors import UnsupportedLanguageError
from app.services.language.description_builders import (
    BaseDescriptionBuilder,
    EnglishDescriptionBuilder,
    TeluguDescriptionBuilder,
)


class LanguageDefinition(BaseModel):
    """Metadata for a supported language."""
    code: str
    name: str
    native_name: str
    is_active: bool = True

    model_config = {"arbitrary_types_allowed": True}


class LanguageManager:
    """Manages language definitions and provides appropriate description builders."""

    def __init__(self):
        self._builders: Dict[str, BaseDescriptionBuilder] = {
            "en": EnglishDescriptionBuilder(),
            "te": TeluguDescriptionBuilder(),
        }

        self._languages: Dict[str, LanguageDefinition] = {
            "en": LanguageDefinition(code="en", name="English", native_name="English"),
            "te": LanguageDefinition(code="te", name="Telugu", native_name="తెలుగు"),
        }

    def list_supported_codes(self) -> List[str]:
        """Return list of supported language codes."""
        return [code for code, info in self._languages.items() if info.is_active]

    def validate_language(self, code: str) -> str:
        """Validate if a language code is supported, normalizing to lowercase.

        Raises:
            UnsupportedLanguageError: If the code is not registered/active.
        """
        normalized = (code or "en").strip().lower()
        if normalized not in self._languages or not self._languages[normalized].is_active:
            raise UnsupportedLanguageError(
                language=code,
                supported=self.list_supported_codes(),
            )
        return normalized

    def get_builder(self, code: str) -> BaseDescriptionBuilder:
        """Get the description builder for the validated language code."""
        normalized = self.validate_language(code)
        return self._builders[normalized]

    def register_language(
        self,
        definition: LanguageDefinition,
        builder: BaseDescriptionBuilder,
    ) -> None:
        """Extensibility hook for registering new languages (e.g., Hindi, Tamil) in future phases."""
        self._languages[definition.code.lower()] = definition
        self._builders[definition.code.lower()] = builder


# Shared language manager instance
language_manager = LanguageManager()
