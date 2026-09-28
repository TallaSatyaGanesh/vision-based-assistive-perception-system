"""FastAPI Application Entry Point for Vision-Based Assistive Perception System."""

import os
import uuid
import certifi

if not os.environ.get("SSL_CERT_FILE"):
    os.environ["SSL_CERT_FILE"] = certifi.where()

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

from app.api.routes import api_router
from app.core.config import settings
from app.core.errors import (
    AppBaseException,
    app_exception_handler,
    generic_exception_handler,
)
from app.core.logging import logger


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Middleware to inject request_id and track basic request lifecycle."""

    async def dispatch(self, request: Request, call_next):
        # Generate or extract request ID
        req_id = request.headers.get("X-Request-ID") or f"req-{uuid.uuid4().hex[:12]}"
        request.state.request_id = req_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = req_id
        return response


def create_app() -> FastAPI:
    """Create and configure the FastAPI application instance."""
    app = FastAPI(
        title=settings.APP_TITLE,
        version=settings.APP_VERSION,
        description="Backend API for Vision-Based Assistive Perception System for the Visually Impaired.",
        debug=settings.DEBUG,
    )

    # Middleware
    app.add_middleware(RequestContextMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Register custom exception handlers
    app.add_exception_handler(AppBaseException, app_exception_handler)
    app.add_exception_handler(Exception, generic_exception_handler)

    # Include routes
    app.include_router(api_router)

    logger.info("Vision-Based Assistive Perception backend initialized successfully.")
    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
