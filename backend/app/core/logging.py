"""Logging configuration for Vision-Based Assistive Perception System."""

import logging
import sys
from app.core.config import settings


def setup_logging() -> logging.Logger:
    """Configure and return root application logger."""
    log_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)

    logging.basicConfig(
        level=log_level,
        format="%(asctime)s [%(levelname)s] [%(name)s]: %(message)s",
        handlers=[logging.StreamHandler(sys.stdout)],
    )

    logger = logging.getLogger("assistive_perception")
    logger.setLevel(log_level)
    return logger


logger = setup_logging()
