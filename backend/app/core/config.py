"""Configuration module for Vision-Based Assistive Perception System.

All configuration is loaded from environment variables or .env file.
Secrets and API credentials must NEVER be hard-coded.
"""

import json
from typing import List, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings with environment variable fallbacks."""

    # Server configuration
    APP_TITLE: str = "Vision-Based Assistive Perception API"
    APP_VERSION: str = "0.1.0"
    APP_ENV: str = "development"
    DEBUG: bool = True
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    LOG_LEVEL: str = "INFO"

    # Cross-Origin Resource Sharing
    ALLOWED_ORIGINS: List[str] = ["*"]

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        """Parse ALLOWED_ORIGINS from JSON list, comma-separated string, or wildcard."""
        if isinstance(v, list):
            return v
        if isinstance(v, str):
            v_clean = v.strip()
            if v_clean.startswith("[") and v_clean.endswith("]"):
                try:
                    parsed = json.loads(v_clean)
                    if isinstance(parsed, list):
                        return [str(item).strip() for item in parsed]
                except Exception:
                    pass
            if "," in v_clean:
                return [item.strip() for item in v_clean.split(",") if item.strip()]
            if v_clean:
                return [v_clean]
        return ["*"]

    # Google Gemini Vision-Language Model Configuration
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-3.5-flash-lite"
    GEMINI_TIMEOUT_SECONDS: float = 35.0
    GEMINI_VIDEO_TIMEOUT_SECONDS: float = 45.0

    # Placeholders for future services (configured in later approved phases)
    TRANSLATION_PROVIDER: str = "placeholder"
    TRANSLATION_API_KEY: str = ""

    TTS_PROVIDER: str = "placeholder"
    TTS_API_KEY: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
