"""Structured scene representation models for environmental perception.

This module models the internal structured understanding of an environment,
strictly distinguishing between observed facts, inferred context, and unknown/unavailable data.
No raw vendor-specific responses are exposed here.
"""

from enum import Enum
import re
from typing import Any, Dict, List, Optional, Tuple
from pydantic import BaseModel, Field


class SpatialPosition(str, Enum):
    """Relative spatial location of an object with respect to the user."""
    FRONT = "front"
    LEFT = "left"
    RIGHT = "right"
    CENTER = "center"
    SURROUNDING = "surrounding"
    UNKNOWN = "unknown"


class DistanceEstimate(str, Enum):
    """Approximate distance bracket.

    Must only be populated if reliably determined; otherwise 'unknown'.
    """
    NEAR = "near"         # Within immediate reach (approx. 0-2 meters)
    MEDIUM = "medium"     # Across the immediate room/space (approx. 2-5 meters)
    FAR = "far"           # Distant background (> 5 meters)
    UNKNOWN = "unknown"   # Cannot be reliably determined


class DetectedObject(BaseModel):
    """An object or obstacle identified within the scene."""
    label: str = Field(..., description="Object name or category, e.g., 'chair', 'person', 'door'")
    position: SpatialPosition = Field(default=SpatialPosition.UNKNOWN, description="Relative spatial position to user")
    distance: DistanceEstimate = Field(default=DistanceEstimate.UNKNOWN, description="Distance if reliably estimable")
    confidence: Optional[float] = Field(default=None, ge=0.0, le=1.0, description="Confidence score if available (0.0 - 1.0)")
    attributes: List[str] = Field(default_factory=list, description="Visual attributes e.g., ['standing', 'wooden']")
    activity: Optional[str] = Field(default=None, description="Visible action/activity e.g. 'walking', 'sitting', 'standing'. None or 'unknown' if not determinable.")
    interaction: Optional[str] = Field(default=None, description="Contextual action/interaction, e.g., 'holding a cup', 'talking to another person'")
    relationship: Optional[str] = Field(default=None, description="Observable relationship to other entities e.g., 'sitting on chair', 'placed on table'")
    is_obstacle: bool = Field(default=False, description="Whether this object represents an immediate obstacle or hazard")


class SceneContext(BaseModel):
    """Contextual metadata describing the broader scene setting and environmental boundaries."""
    setting: Optional[str] = Field(default=None, description="e.g. 'indoor living room', 'sidewalk', 'office corridor'")
    lighting: Optional[str] = Field(default=None, description="e.g. 'well-lit', 'dim', 'bright daylight'")
    hazards_or_obstacles: List[str] = Field(default_factory=list, description="Identified hazards or movement obstacles")
    observed_features: List[str] = Field(default_factory=list, description="Explicitly verified visual elements")
    inferred_context: List[str] = Field(default_factory=list, description="Inferred contextual deductions (clearly separated from observed facts)")
    unavailable_information: List[str] = Field(default_factory=list, description="Explicitly noted unavailable/unreliable aspects (e.g., 'distance to background unknown')")


class StructuredScene(BaseModel):
    """Canonical representation of an analyzed environment."""
    objects: List[DetectedObject] = Field(default_factory=list, description="List of recognized physical objects/obstacles")
    context: SceneContext = Field(default_factory=SceneContext, description="Broader environmental setting and context")
    relationships: List[str] = Field(default_factory=list, description="Observed entity-to-entity or entity-to-surface relationships")
    primary_focus: Optional[str] = Field(default=None, description="The most immediate object or focus point for the user")


class PerceptionResponse(BaseModel):
    """Standardized response contract returned to the client mobile application."""
    request_id: str = Field(..., description="Unique trace identifier for the request")
    status: str = Field(default="success", description="Overall execution status: 'success', 'warning', 'error'")
    language: str = Field(default="en", description="Output description language code ('en', 'te')")
    description: str = Field(..., description="Concise natural-language scene narrative tailored for audio speech output")
    scene_data: StructuredScene = Field(..., description="Provider-independent structured environmental data")
    processing_time_ms: float = Field(..., description="Total server processing duration in milliseconds")
    warnings: List[str] = Field(default_factory=list, description="Non-fatal warnings (e.g. 'image_low_light', 'distance_unknown')")
    errors: Optional[List[str]] = Field(default=None, description="Error notes if partially degraded")


class PerceptionErrorResponse(BaseModel):
    """Standardized error contract returned to client on API-level failures."""
    request_id: str = Field(..., description="Unique trace identifier for the request")
    status: str = Field(default="error", description="Failure status flag")
    error_code: str = Field(..., description="Machine-readable error category")
    message: str = Field(..., description="Client-safe, human-readable error description")
    details: Optional[Dict[str, Any]] = Field(default=None, description="Optional diagnostic metadata (no secrets/stack traces)")


def is_genuine_obstacle_object(obj: DetectedObject) -> bool:
    """Determine whether an object is a verified physical obstacle to forward movement.

    A person standing/sitting/walking nearby or in front is NOT an obstacle
    unless there is explicit evidence of blocking a path, doorway, corridor, or aisle.

    Navigable environmental surfaces (roads, sidewalks, ground, gravel) and background elements
    are NOT obstacles unless there is clear evidence of an active, dangerous condition.
    """
    if not obj.is_obstacle:
        return False

    label = obj.label.lower().strip()
    text_contexts = [
        label,
        (obj.activity or "").lower(),
        (obj.interaction or "").lower(),
        (obj.relationship or "").lower(),
    ] + [a.lower() for a in obj.attributes]
    combined_text = " ".join(text_contexts)
    label_tokens = set(re.findall(r"\b[a-z]+\b", label))

    # 1. Person entity validation
    person_words = {"person", "people", "man", "woman", "child", "pedestrian", "individual", "boy", "girl"}
    if label_tokens & person_words:
        blocking_indicators = {
            "blocking", "obstructing", "in path", "in the path", "in walking path",
            "blocking path", "blocking doorway", "blocking corridor", "blocking aisle",
            "blocking way", "barricading", "impeding", "obstructing movement", "path obstruction"
        }
        return any(ind in combined_text for ind in blocking_indicators)

    # 2. Benign environmental / surface / ground entity validation
    surface_words = {
        "road", "roadway", "street", "highway", "asphalt", "pavement", "sidewalk",
        "pathway", "walkway", "ground", "gravel", "dirt", "soil", "grass", "lawn",
        "floor", "flooring", "roadside", "curb", "terrain", "wall", "sky", "background"
    }
    if label_tokens & surface_words:
        danger_indicators = {
            "broken", "damaged", "hole", "pothole", "trench", "pit", "slick",
            "slippery", "wet", "icy", "blocked", "oil", "sinkhole", "drop",
            "hazard", "danger", "steep", "uneven", "cracked", "crack", "debris", "collapsed"
        }
        return any(ind in combined_text for ind in danger_indicators)

    # 3. Distant background entities validation
    if obj.distance == DistanceEstimate.FAR or "background" in combined_text:
        danger_indicators = {"fire", "collapse", "falling", "danger", "hazard", "blocked"}
        return any(ind in combined_text for ind in danger_indicators)

    return True


def is_genuine_hazard_item(hazard_str: str) -> Tuple[bool, bool]:
    """Determine whether an entry in context.hazards_or_obstacles is a genuine physical hazard.

    Returns:
        (is_genuine, is_uncertain):
        - is_genuine: True if visually verified hazard.
        - is_uncertain: True if speculative/inferred (to be moved to inferred_context).
    """
    h_clean = hazard_str.lower().strip()
    if not h_clean or h_clean in ("none", "unknown", "no hazards", "no immediate obstacles", "clear"):
        return False, False

    # Check for uncertainty markers
    uncertainty_words = {
        "possible", "potential", "might be", "uncertain", "unknown",
        "maybe", "inferred", "unclear", "likely", "assumed", "speculative"
    }
    tokens = set(re.findall(r"\b[a-z]+\b", h_clean))
    if tokens & uncertainty_words:
        return False, True

    # Check if person without explicit blocking cues
    person_words = {"person", "people", "man", "woman", "child", "pedestrian", "individual", "boy", "girl"}
    if tokens & person_words:
        blocking_indicators = {
            "blocking", "obstructing", "in path", "in the path", "in walking path",
            "blocking path", "blocking doorway", "blocking corridor", "blocking aisle",
            "blocking way", "barricading", "impeding", "obstructing movement"
        }
        if any(ind in h_clean for ind in blocking_indicators):
            return True, False
        return False, False

    # Check if environmental surface or background without active hazard
    surface_words = {
        "road", "roadway", "street", "highway", "asphalt", "pavement", "sidewalk",
        "pathway", "walkway", "ground", "gravel", "dirt", "soil", "grass", "lawn",
        "floor", "flooring", "roadside", "curb", "terrain", "wall", "sky", "background"
    }
    if tokens & surface_words:
        danger_indicators = {
            "broken", "damaged", "hole", "pothole", "trench", "pit", "slick",
            "slippery", "wet", "icy", "blocked", "oil", "sinkhole", "drop",
            "hazard", "danger", "steep", "uneven", "cracked", "crack", "debris", "collapsed"
        }
        if any(ind in h_clean for ind in danger_indicators):
            return True, False
        return False, False

    # Background elements without active hazard
    if "in background" in h_clean or "background" in tokens:
        return False, False

    return True, False


def sanitize_scene_safety(scene: StructuredScene) -> StructuredScene:
    """Conservatively validate and sanitize obstacle flags and hazards in a StructuredScene.

    Enforces evidence-based safety rules:
    - Demotes non-blocking people from is_obstacle=True to is_obstacle=False.
    - Demotes normal roads, ground, gravel, roadside, and background scenery to is_obstacle=False.
    - Prunes non-hazard environmental features and non-blocking people from context.hazards_or_obstacles.
    - Reallocates uncertain/speculative hazards to inferred_context.
    """
    new_objects: List[DetectedObject] = []
    for obj in scene.objects:
        if obj.is_obstacle and not is_genuine_obstacle_object(obj):
            sanitized_obj = obj.model_copy(update={"is_obstacle": False})
            new_objects.append(sanitized_obj)
        else:
            new_objects.append(obj)

    new_hazards: List[str] = []
    new_inferred = list(scene.context.inferred_context) if scene.context.inferred_context else []

    for h in scene.context.hazards_or_obstacles:
        h_str = h.strip()
        if not h_str:
            continue
        is_genuine, is_uncertain = is_genuine_hazard_item(h_str)
        if is_genuine:
            new_hazards.append(h_str)
        elif is_uncertain:
            if h_str not in new_inferred:
                new_inferred.append(h_str)

    unique_hazards = list(dict.fromkeys(new_hazards))
    unique_inferred = list(dict.fromkeys(new_inferred))

    new_context = scene.context.model_copy(
        update={
            "hazards_or_obstacles": unique_hazards,
            "inferred_context": unique_inferred,
        }
    )

    return scene.model_copy(
        update={
            "objects": new_objects,
            "context": new_context,
        }
    )

