"""API router aggregator."""

from fastapi import APIRouter
from app.api.v1.endpoints import health, perception

api_router = APIRouter()

# Root health endpoint
api_router.include_router(health.router, tags=["Health"])

# API v1 routes
api_v1_router = APIRouter(prefix="/api/v1")
api_v1_router.include_router(health.router, tags=["Health"])
api_v1_router.include_router(perception.router, tags=["Perception"])

api_router.include_router(api_v1_router)
