"""Comprehensive test suite for scene-adaptive perception and assistive description generation.

Validates that the system adaptively describes arbitrary visual scenes (simple, complex,
with/without people, activities, interactions, hazards, settings) in English and Telugu.
All tests use deterministic mocked StructuredScene data with zero external cloud calls.
"""

import pytest
from app.services.language.description_builders import (
    EnglishDescriptionBuilder,
    TeluguDescriptionBuilder,
)
from app.services.vision.models import (
    DetectedObject,
    DistanceEstimate,
    SceneContext,
    SpatialPosition,
    StructuredScene,
)

en_builder = EnglishDescriptionBuilder()
te_builder = TeluguDescriptionBuilder()


# 1. Simple scene description
def test_simple_scene_description():
    """Verify that a simple scene produces a concise, non-verbose description."""
    scene = StructuredScene(
        context=SceneContext(setting="hallway", observed_features=["open doorway"]),
        objects=[
            DetectedObject(
                label="doorway",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.NEAR,
                attributes=["open"],
            )
        ],
    )
    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    assert "doorway" in desc_en.lower()
    assert "front" in desc_en.lower()
    # Should be concise (1 or 2 sentences max)
    assert len(desc_en.split(".")) <= 3

    assert "ద్వారం" in desc_te or "doorway" in desc_te
    assert "ముందు" in desc_te


# 2. Complex multi-entity scene
def test_complex_multientity_scene():
    """Verify that a complex scene provides comprehensive spatial and contextual information."""
    scene = StructuredScene(
        context=SceneContext(
            setting="conference room",
            observed_features=["people", "chairs", "projector screen", "table"],
        ),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                attributes=["standing"],
                activity="speaking",
            ),
            DetectedObject(
                label="chair",
                position=SpatialPosition.LEFT,
                distance=DistanceEstimate.NEAR,
                attributes=["office"],
            ),
            DetectedObject(
                label="table",
                position=SpatialPosition.CENTER,
                distance=DistanceEstimate.MEDIUM,
                attributes=["wooden"],
            ),
            DetectedObject(
                label="screen",
                position=SpatialPosition.RIGHT,
                distance=DistanceEstimate.FAR,
                attributes=["large"],
            ),
        ],
        relationships=["person is standing next to table"],
    )
    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    # English checks
    assert "person" in desc_en.lower()
    assert "chair" in desc_en.lower()
    assert "left" in desc_en.lower()
    assert "table" in desc_en.lower()

    # Telugu checks
    assert "వ్యక్తి" in desc_te
    assert "కుర్చీ" in desc_te
    assert "ఎడమ" in desc_te


# 3. Multiple people with visible activities
def test_multiple_people_different_activities():
    """Verify handling of scenes with multiple people and distinct activities."""
    scene = StructuredScene(
        context=SceneContext(setting="park"),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.LEFT,
                activity="walking",
            ),
            DetectedObject(
                label="person",
                position=SpatialPosition.RIGHT,
                activity="sitting",
            ),
        ],
    )
    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    assert "people" in desc_en.lower() or "person" in desc_en.lower()
    assert "వ్యక్తులు" in desc_te or "మంది" in desc_te


# 4. Person-object interaction
def test_person_object_interaction():
    """Verify that person-object interactions (e.g., holding a cup) are included."""
    scene = StructuredScene(
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                activity="standing",
                interaction="holding a coffee mug",
            )
        ]
    )
    desc_en = en_builder.build_description(scene)

    assert "person" in desc_en.lower()
    assert "holding a coffee mug" in desc_en.lower()
    assert "in front of you" in desc_en.lower()


# 5. Unknown activity & anti-hallucination
def test_unknown_activity_anti_hallucination():
    """Verify that when an activity is unknown, the model does NOT invent actions."""
    scene = StructuredScene(
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                activity="unknown",  # explicitly unknown
            ),
            DetectedObject(
                label="phone",
                position=SpatialPosition.CENTER,
            ),
        ]
    )
    desc_en = en_builder.build_description(scene)

    # Should report the person's location without fabricating actions like 'texting'
    assert "texting" not in desc_en.lower()
    assert "reading" not in desc_en.lower()
    assert "person" in desc_en.lower()
    assert "in front of you" in desc_en.lower()


# 6. Unknown spatial position
def test_unknown_spatial_position():
    """Verify that objects with unknown position do not crash or emit confusing orientation cues."""
    scene = StructuredScene(
        objects=[
            DetectedObject(
                label="backpack",
                position=SpatialPosition.UNKNOWN,
            )
        ]
    )
    desc_en = en_builder.build_description(scene)
    assert "backpack" in desc_en.lower()


# 7. Scene with no people
def test_scene_with_no_people():
    """Verify that scenes without people focus naturally on environment and landmarks."""
    scene = StructuredScene(
        context=SceneContext(setting="sidewalk"),
        objects=[
            DetectedObject(
                label="bench",
                position=SpatialPosition.LEFT,
                distance=DistanceEstimate.NEAR,
                attributes=["wooden"],
            ),
            DetectedObject(
                label="lamppost",
                position=SpatialPosition.RIGHT,
                distance=DistanceEstimate.MEDIUM,
            ),
        ],
    )
    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    assert "person" not in desc_en.lower()
    assert "bench" in desc_en.lower()
    assert "left" in desc_en.lower()

    assert "వ్యక్తి" not in desc_te
    assert "బెంచ్" in desc_te or "bench" in desc_te


# 8. Scene with environmental context
def test_scene_with_environmental_context():
    """Verify that clear environmental context is communicated to the user."""
    scene = StructuredScene(
        context=SceneContext(
            setting="supermarket aisle",
            observed_features=["shelves", "products"],
        ),
        objects=[
            DetectedObject(
                label="cart",
                position=SpatialPosition.FRONT,
                attributes=["empty"],
            )
        ],
    )
    desc_en = en_builder.build_description(scene)

    assert "supermarket aisle" in desc_en.lower()
    assert "cart" in desc_en.lower()


# 9. Scene with visually supported hazard
def test_scene_with_visually_supported_hazard():
    """Verify that safety hazards are prioritized with prominent warning phrasing."""
    scene = StructuredScene(
        context=SceneContext(
            hazards_or_obstacles=["wet floor", "trailing cable"],
        ),
        objects=[
            DetectedObject(
                label="cable",
                position=SpatialPosition.FRONT,
                is_obstacle=True,
            )
        ],
    )
    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    # English must prioritize warning
    assert desc_en.startswith("Caution:")
    assert "cable" in desc_en.lower() or "obstacle" in desc_en.lower()

    # Telugu must prioritize warning
    assert desc_te.startswith("హెచ్చరిక:")


# 10. Scene with no hazard
def test_scene_with_no_hazard():
    """Verify that when no hazard is present, no false caution warnings are emitted."""
    scene = StructuredScene(
        context=SceneContext(setting="clean office"),
        objects=[
            DetectedObject(
                label="desk",
                position=SpatialPosition.FRONT,
                is_obstacle=False,
            )
        ],
    )
    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    assert "caution" not in desc_en.lower()
    assert "obstacle" not in desc_en.lower()
    assert "హెచ్చరిక" not in desc_te


# 11. Empty/clear scene fallback
def test_empty_clear_scene():
    """Verify that a completely empty scene produces a reassuring clear-path announcement."""
    scene = StructuredScene(
        context=SceneContext(setting="open corridor"),
        objects=[],
    )
    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    assert "clear" in desc_en.lower()
    assert "స్పష్టంగా" in desc_te


# 12. Repetitive descriptions prevention (real-image test scene)
def test_roadside_scene_no_repetition():
    """Verify that a roadside person scene synthesizes into concise speech without repetition."""
    scene = StructuredScene(
        primary_focus="person standing in front",
        context=SceneContext(
            setting="roadside",
            observed_features=["person", "asphalt road"],
        ),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                activity="standing",
                attributes=["standing"],
                interaction="standing on roadside",
                relationship="standing on roadside",
            ),
            DetectedObject(
                label="road",
                position=SpatialPosition.SURROUNDING,
                attributes=["asphalt"],
            ),
        ],
        relationships=["person is standing near a road"],
    )
    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    # 1. Natural spoken English
    assert "person is standing in front of you" in desc_en.lower()
    assert "road" in desc_en.lower()

    # 2. No awkward 'A asphalt'
    assert "a asphalt" not in desc_en.lower()

    # 3. No generic filler
    assert "notably" not in desc_en.lower()
    assert "it appears that" not in desc_en.lower()

    # 4. Removes repeated facts: road is mentioned in the unified sentence, not repeated
    sentences_en = [s for s in desc_en.split(".") if s.strip()]
    assert len(sentences_en) <= 2
    assert desc_en.lower().count("road") == 1

    # 5. Telugu support
    assert "రోడ్డు" in desc_te
    assert "వ్యక్తి" in desc_te
    sentences_te = [s for s in desc_te.split(".") if s.strip()]
    assert len(sentences_te) <= 2


# 13. Proper article generation (a vs an)
def test_article_handling():
    """Verify that nouns and adjective-noun phrases use correct indefinite articles."""
    from app.services.language.description_builders import _with_article

    assert _with_article("asphalt road") == "an asphalt road"
    assert _with_article("open doorway") == "an open doorway"
    assert _with_article("office chair") == "an office chair"
    assert _with_article("wooden table") == "a wooden table"
    assert _with_article("person") == "a person"
    assert _with_article("paved road") == "a paved road"
    assert _with_article("obstacle") == "an obstacle"


# 14. Simple multi-object scene conciseness
def test_simple_multiobject_conciseness():
    """Verify that a 2-3 object scene combines into natural non-repeating sentences <= 2 sentences."""
    scene = StructuredScene(
        context=SceneContext(setting="clean hallway"),
        objects=[
            DetectedObject(
                label="chair",
                position=SpatialPosition.LEFT,
                attributes=["wooden"],
            ),
            DetectedObject(
                label="table",
                position=SpatialPosition.RIGHT,
                attributes=["small"],
            ),
        ],
    )
    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    assert "chair is on your left" in desc_en.lower()
    assert "table is on your right" in desc_en.lower()
    sentences = [s for s in desc_en.split(".") if s.strip()]
    assert len(sentences) <= 2
    assert "notably" not in desc_en.lower()

    assert "కుర్చీ" in desc_te
    assert "టేబుల్" in desc_te
    assert len([s for s in desc_te.split(".") if s.strip()]) <= 2


# 15. Person standing nearby/front but not demonstrably blocking path -> is_obstacle=False and no caution
def test_person_in_front_not_obstacle():
    """Verify that a person standing in front/center or near camera is not classified as an obstacle."""
    from app.services.vision.models import sanitize_scene_safety

    scene = StructuredScene(
        context=SceneContext(
            setting="outdoor walkway",
            hazards_or_obstacles=["person", "person standing nearby"],
        ),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.NEAR,
                activity="standing",
                attributes=["standing"],
                is_obstacle=True,  # Initially marked incorrectly
            )
        ],
    )

    sanitized = sanitize_scene_safety(scene)
    assert sanitized.objects[0].is_obstacle is False
    assert sanitized.context.hazards_or_obstacles == []

    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    assert "caution" not in desc_en.lower()
    assert "obstacle" not in desc_en.lower()
    assert "person is standing in front of you" in desc_en.lower()
    assert "హెచ్చరిక" not in desc_te
    assert "అడ్డంకి" not in desc_te


# 16. Road in background -> is_obstacle=False
def test_road_in_background_not_obstacle():
    """Verify that a road or roadway visible in the background is not classified as an obstacle."""
    from app.services.vision.models import sanitize_scene_safety

    scene = StructuredScene(
        context=SceneContext(
            setting="roadside",
            hazards_or_obstacles=["roadway in background"],
        ),
        objects=[
            DetectedObject(
                label="road",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.FAR,
                attributes=["asphalt", "background"],
                is_obstacle=True,  # Initially marked incorrectly
            )
        ],
    )

    sanitized = sanitize_scene_safety(scene)
    assert sanitized.objects[0].is_obstacle is False
    assert sanitized.context.hazards_or_obstacles == []

    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    assert "caution" not in desc_en.lower()
    assert "obstacle" not in desc_en.lower()
    assert "హెచ్చరిక" not in desc_te


# 17. Clearly path-blocking object or person -> is_obstacle=True and safety warning is emitted
def test_clearly_path_blocking_person_or_object():
    """Verify that when a person or object is demonstrably blocking travel, is_obstacle=True and caution is emitted."""
    from app.services.vision.models import sanitize_scene_safety

    # Case A: Person explicitly blocking path
    scene_person_blocking = StructuredScene(
        context=SceneContext(setting="narrow corridor"),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.NEAR,
                attributes=["standing in path", "blocking doorway"],
                is_obstacle=True,
            )
        ],
    )
    sanitized_person = sanitize_scene_safety(scene_person_blocking)
    assert sanitized_person.objects[0].is_obstacle is True

    desc_en_person = en_builder.build_description(scene_person_blocking)
    assert desc_en_person.startswith("Caution: there is an obstacle")
    assert "person" in desc_en_person.lower()

    # Case B: Physical barrier blocking path
    scene_barrier = StructuredScene(
        context=SceneContext(
            setting="sidewalk",
            hazards_or_obstacles=["construction barrier blocking path"],
        ),
        objects=[
            DetectedObject(
                label="barrier",
                position=SpatialPosition.FRONT,
                attributes=["blocking walkway"],
                is_obstacle=True,
            )
        ],
    )
    sanitized_barrier = sanitize_scene_safety(scene_barrier)
    assert sanitized_barrier.objects[0].is_obstacle is True
    assert "construction barrier blocking path" in sanitized_barrier.context.hazards_or_obstacles

    desc_en_barrier = en_builder.build_description(scene_barrier)
    desc_te_barrier = te_builder.build_description(scene_barrier)
    assert desc_en_barrier.startswith("Caution: there is an obstacle")
    assert desc_te_barrier.startswith("హెచ్చరిక: మీ మార్గంలో అడ్డంకి")


# 18. Ordinary ground / gravel -> is_obstacle=False
def test_ordinary_ground_gravel_not_obstacle():
    """Verify that ordinary ground, gravel, or roadside surfaces are not classified as obstacles."""
    from app.services.vision.models import sanitize_scene_safety

    scene = StructuredScene(
        context=SceneContext(
            hazards_or_obstacles=["gravel ground"],
        ),
        objects=[
            DetectedObject(
                label="ground",
                position=SpatialPosition.SURROUNDING,
                attributes=["gravel"],
                is_obstacle=True,  # False alarm
            )
        ],
    )

    sanitized = sanitize_scene_safety(scene)
    assert sanitized.objects[0].is_obstacle is False
    assert sanitized.context.hazards_or_obstacles == []

    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    assert "caution" not in desc_en.lower()
    assert "obstacle" not in desc_en.lower()
    assert "హెచ్చరిక" not in desc_te


# 19. Uncertain situation -> do not convert uncertainty into a confirmed obstacle
def test_uncertain_situation_not_confirmed_obstacle():
    """Verify that uncertain/speculative hazard candidates are not converted into confirmed obstacles."""
    from app.services.vision.models import sanitize_scene_safety

    scene = StructuredScene(
        context=SceneContext(
            hazards_or_obstacles=["possible obstacle ahead", "potential uneven surface"],
        ),
        objects=[
            DetectedObject(
                label="chair",
                position=SpatialPosition.LEFT,
                is_obstacle=False,
            )
        ],
    )

    sanitized = sanitize_scene_safety(scene)
    # Uncertain items must be pruned from hazards_or_obstacles and moved to inferred_context
    assert sanitized.context.hazards_or_obstacles == []
    assert "possible obstacle ahead" in sanitized.context.inferred_context
    assert "potential uneven surface" in sanitized.context.inferred_context

    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    assert "caution" not in desc_en.lower()
    assert "obstacle" not in desc_en.lower()
    assert "హెచ్చరిక" not in desc_te


# 20. Real roadside test scene simulation (preventing false obstacle and caution warning)
def test_real_roadside_scene_simulation_no_false_warning():
    """Verify the real-image failure case produces a natural description without false caution."""
    scene = StructuredScene(
        primary_focus="person standing in front",
        context=SceneContext(
            setting="roadside",
            hazards_or_obstacles=["person", "person standing nearby", "roadway in background"],
            observed_features=["person", "asphalt road", "gravel ground"],
        ),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.NEAR,
                activity="standing",
                attributes=["standing"],
                interaction="standing near an asphalt road",
                relationship="standing near an asphalt road",
                is_obstacle=True,  # The false classification from real Gemini run
            ),
            DetectedObject(
                label="road",
                position=SpatialPosition.FRONT,
                attributes=["asphalt"],
                is_obstacle=False,
            ),
            DetectedObject(
                label="ground",
                position=SpatialPosition.SURROUNDING,
                attributes=["gravel"],
                is_obstacle=False,
            ),
        ],
        relationships=["person is standing near an asphalt road"],
    )

    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    # 1. No false caution warning in English or Telugu
    assert "caution" not in desc_en.lower()
    assert "obstacle" not in desc_en.lower()
    assert "హెచ్చరిక" not in desc_te
    assert "అడ్డంకి" not in desc_te

    # 2. Natural spoken English description of the actual scene
    assert "person is standing in front of you" in desc_en.lower()
    assert "road" in desc_en.lower()
    assert "gravel" in desc_en.lower()
    assert len([s for s in desc_en.split(".") if s.strip()]) <= 2

    # 3. Natural Telugu description
    assert "వ్యక్తి" in desc_te
    assert "రోడ్డు" in desc_te
    assert len([s for s in desc_te.split(".") if s.strip()]) <= 2


# 21. Telugu person + road scene natural description
def test_telugu_person_road_standing_natural_description():
    """Verify that a person standing near an asphalt road produces fluent Telugu without English leakage."""
    scene = StructuredScene(
        context=SceneContext(
            setting="roadside",
            observed_features=["person", "asphalt road"],
        ),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.NEAR,
                activity="standing",
                attributes=["standing"],
                relationship="standing near an asphalt road",
            ),
            DetectedObject(
                label="road",
                position=SpatialPosition.FRONT,
                attributes=["asphalt"],
            ),
        ],
        relationships=["person is standing near an asphalt road"],
    )
    desc_te = te_builder.build_description(scene)

    # Must contain Telugu terms
    assert "వ్యక్తి" in desc_te
    assert "నిలబడి ఉన్నారు" in desc_te
    assert "తారు రోడ్డు" in desc_te or "రోడ్డు" in desc_te
    # Gender neutrality
    assert "మగవాడు" not in desc_te and "పురుషుడు" not in desc_te
    # No English leakage
    assert "road" not in desc_te.lower()
    assert "asphalt" not in desc_te.lower()
    assert "standing" not in desc_te.lower()
    # Concise: <= 2 sentences
    sentences = [s.strip() for s in desc_te.split(".") if s.strip()]
    assert len(sentences) <= 2


# 22. Telugu vegetation and trees: translation and plural agreement
def test_telugu_foliage_trees_translation_and_plural_agreement():
    """Verify vegetation, green foliage, and trees use correct Telugu nouns and plural verb agreement."""
    # Scene with plural green foliage trees
    scene_foliage = StructuredScene(
        context=SceneContext(setting="outdoor"),
        objects=[
            DetectedObject(
                label="green foliage trees",
                position=SpatialPosition.SURROUNDING,
                attributes=["green", "dense"],
            )
        ],
    )
    desc_foliage = te_builder.build_description(scene_foliage)
    assert "పచ్చని చెట్లు" in desc_foliage
    assert "ఉన్నాయి" in desc_foliage
    assert "ఉంది" not in desc_foliage
    assert "green" not in desc_foliage.lower()
    assert "foliage" not in desc_foliage.lower()
    assert "trees" not in desc_foliage.lower()
    assert "ఒక పచ్చని" not in desc_foliage

    # Scene with singular tree
    scene_tree = StructuredScene(
        context=SceneContext(setting="park"),
        objects=[
            DetectedObject(
                label="tree",
                position=SpatialPosition.FRONT,
            )
        ],
    )
    desc_tree = te_builder.build_description(scene_tree)
    assert "ఒక చెట్టు ఉంది" in desc_tree
    assert "ఉన్నాయి" not in desc_tree

    # Scene with plural trees
    scene_trees = StructuredScene(
        context=SceneContext(setting="park"),
        objects=[
            DetectedObject(
                label="trees",
                position=SpatialPosition.SURROUNDING,
            )
        ],
    )
    desc_trees = te_builder.build_description(scene_trees)
    assert "చెట్లు ఉన్నాయి" in desc_trees
    assert "ఒక చెట్లు" not in desc_trees
    assert "ఉంది" not in desc_trees


# 23. Telugu singular, plural, and mass noun agreement
def test_telugu_singular_plural_and_mass_noun_agreement():
    """Verify countable singular gets 'ఒక ... ఉంది', plural gets '... ఉన్నాయి', mass noun gets '... ఉంది' without 'ఒక'."""
    # Countable singular (chair)
    scene_chair = StructuredScene(
        objects=[
            DetectedObject(label="chair", position=SpatialPosition.LEFT)
        ]
    )
    desc_chair = te_builder.build_description(scene_chair)
    assert "ఒక కుర్చీ ఉంది" in desc_chair

    # Countable plural (chairs)
    scene_chairs = StructuredScene(
        objects=[
            DetectedObject(label="chairs", position=SpatialPosition.LEFT)
        ]
    )
    desc_chairs = te_builder.build_description(scene_chairs)
    assert "కుర్చీలు ఉన్నాయి" in desc_chairs
    assert "ఒక కుర్చీలు" not in desc_chairs

    # Mass noun (gravel ground)
    scene_gravel = StructuredScene(
        objects=[
            DetectedObject(label="gravel", position=SpatialPosition.SURROUNDING)
        ]
    )
    desc_gravel = te_builder.build_description(scene_gravel)
    assert "కంకర నేల ఉంది" in desc_gravel
    assert "ఒక కంకర నేల" not in desc_gravel


# 24. Telugu formatting clean: no dangling dots, repeated spaces, or punctuation artifacts
def test_telugu_clean_formatting_no_dangling_artifacts():
    """Verify that Telugu description has no trailing spaces, multiple dots, or dangling punctuation."""
    from app.services.language.description_builders import _clean_telugu_text

    dirty_text = "మీ ముందు రోడ్డు దగ్గర ఒక వ్యక్తి ఉన్నారు. దగ్గరలో ఒక green foliage trees ఉంది.           ."
    cleaned = _clean_telugu_text(dirty_text)
    assert not cleaned.endswith(". .")
    assert not cleaned.endswith(" .")
    assert "  " not in cleaned
    assert cleaned.count("..") == 0
    assert cleaned.endswith(".")

    # Test full generation pipeline produces no artifacts
    scene = StructuredScene(
        context=SceneContext(setting="roadside"),
        objects=[
            DetectedObject(label="person", position=SpatialPosition.FRONT, activity="standing"),
            DetectedObject(label="green foliage trees", position=SpatialPosition.SURROUNDING),
        ],
    )
    desc = te_builder.build_description(scene)
    assert not desc.endswith(". .")
    assert not desc.endswith(" .")
    assert "  " not in desc
    assert ".." not in desc
    assert desc.endswith(".")


# 25. Telugu gender neutrality
def test_telugu_gender_neutrality():
    """Verify that detected people are described neutrally as 'వ్యక్తి' without assuming gender."""
    for label in ["person", "man", "pedestrian"]:
        scene = StructuredScene(
            objects=[
                DetectedObject(label=label, position=SpatialPosition.FRONT, activity="standing")
            ]
        )
        desc = te_builder.build_description(scene)
        assert "వ్యక్తి" in desc
        assert "మగవాడు" not in desc
        assert "పురుషుడు" not in desc


# 26. Telugu genuine obstacle warning vs clear scene
def test_telugu_obstacle_warning_vs_clear_scene():
    """Verify that genuine path-blocking obstacles produce clear Telugu warning, and clear scenes do not."""
    # Genuine obstacle: low branch blocking path
    scene_obstacle = StructuredScene(
        objects=[
            DetectedObject(
                label="branch",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.NEAR,
                is_obstacle=True,
                attributes=["low-hanging", "blocking path"],
                interaction="directly blocking head level walkway",
            )
        ]
    )
    desc_obs = te_builder.build_description(scene_obstacle)
    assert "హెచ్చరిక" in desc_obs
    assert "అడ్డంకి" in desc_obs
    assert "కొమ్మ" in desc_obs

    # Clear scene: person and road without obstacle
    scene_clear = StructuredScene(
        objects=[
            DetectedObject(label="person", position=SpatialPosition.FRONT, activity="standing"),
            DetectedObject(label="road", position=SpatialPosition.SURROUNDING),
        ]
    )
    desc_clear = te_builder.build_description(scene_clear)
    assert "హెచ్చరిక" not in desc_clear
    assert "అడ్డంకి" not in desc_clear


# 27. Exact real test case reproduction
def test_telugu_exact_real_test_case_output():
    """Verify that the exact scene entities from the real Gemini test produce natural, fluent Telugu."""
    scene = StructuredScene(
        primary_focus="person standing in front",
        context=SceneContext(
            setting="roadside",
            observed_features=["person", "asphalt road", "green foliage trees", "gravel ground"],
        ),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.NEAR,
                activity="standing",
                attributes=["standing"],
                relationship="standing near an asphalt road",
                is_obstacle=False,
            ),
            DetectedObject(
                label="road",
                position=SpatialPosition.FRONT,
                attributes=["asphalt"],
                is_obstacle=False,
            ),
            DetectedObject(
                label="foliage",
                position=SpatialPosition.SURROUNDING,
                attributes=["green", "trees"],
                is_obstacle=False,
            ),
        ],
        relationships=["person is standing near an asphalt road"],
    )
    desc_te = te_builder.build_description(scene)

    # 1. No false caution / hazard
    assert "హెచ్చరిక" not in desc_te
    assert "అడ్డంకి" not in desc_te

    # 2. Correct person phrasing with standing activity and road relationship
    assert "మీ ముందు తారు రోడ్డు దగ్గర ఒక వ్యక్తి నిలబడి ఉన్నారు" in desc_te

    # 3. Correct foliage / trees phrasing with plural agreement
    assert "పచ్చని చెట్లు ఉన్నాయి" in desc_te

    # 4. Zero English leakage
    assert "green" not in desc_te.lower()
    assert "foliage" not in desc_te.lower()
    assert "trees" not in desc_te.lower()
    assert "asphalt" not in desc_te.lower()

    # 5. Exactly two sentences, no dangling dots
    sentences = [s.strip() for s in desc_te.split(".") if s.strip()]
    assert len(sentences) == 2
    assert not desc_te.endswith(". .")
    assert desc_te == "మీ ముందు తారు రోడ్డు దగ్గర ఒక వ్యక్తి నిలబడి ఉన్నారు. దగ్గరలో పచ్చని చెట్లు ఉన్నాయి."


# 28. Unsupported portrait setting is not promoted into primary spoken description
def test_unsupported_portrait_setting_not_promoted_into_description():
    """Verify that unsupported scene classifications like 'outdoor portrait setting' or 'professional portrait'
    are not promoted into the spoken narrative, while actual visible entities remain available."""
    scene = StructuredScene(
        primary_focus="person in front",
        context=SceneContext(
            setting="outdoor portrait setting",
            inferred_context=["professional portrait", "passport-style photo"],
            observed_features=["person", "dark shirt", "neutral background"],
        ),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.NEAR,
                activity="standing",
                attributes=["standing", "wearing a dark shirt"],
            ),
            DetectedObject(
                label="background",
                position=SpatialPosition.SURROUNDING,
                attributes=["neutral"],
            ),
        ],
    )
    desc_en = en_builder.build_description(scene)
    desc_te = te_builder.build_description(scene)

    # 1. Spoken description focuses on visible person and attributes
    assert "person is in front of you" in desc_en.lower()
    assert "dark shirt" in desc_en.lower()
    assert "standing" not in desc_en.lower()

    # 2. Unsupported generic classifications are NOT promoted into description
    assert "portrait setting" not in desc_en.lower()
    assert "outdoor portrait" not in desc_en.lower()
    assert "professional portrait" not in desc_en.lower()
    assert "portrait" not in desc_en.lower()

    # 3. Telugu does not promote unsupported setting or assumed posture
    assert "వ్యక్తి" in desc_te
    assert "portrait" not in desc_te.lower()

    # 4. Underlying structured data still preserves observed features and inferred context
    assert "dark shirt" in scene.context.observed_features
    assert "professional portrait" in scene.context.inferred_context


# 29. Generic headshot, photoshoot, and photo settings suppressed across languages
def test_generic_headshot_and_photo_settings_suppressed():
    """Verify that generic photographic labels (headshot, photo setting, outdoor setting) are never output as sentences."""
    generic_settings = [
        "portrait setting",
        "professional portrait",
        "headshot",
        "outdoor setting",
        "indoor setting",
        "photo setting",
        "studio photoshoot",
        "close-up shot",
    ]
    for g_set in generic_settings:
        scene = StructuredScene(
            context=SceneContext(setting=g_set),
            objects=[
                DetectedObject(
                    label="person",
                    position=SpatialPosition.FRONT,
                    attributes=["standing"],
                )
            ],
        )
        desc_en = en_builder.build_description(scene)
        assert g_set.lower() not in desc_en.lower()
        assert "you are in" not in desc_en.lower()


# 30. Passport-style image focuses on visible person, clothing, expression, and background
def test_passport_style_image_focuses_on_visible_features():
    """Verify passport image test case correctly focuses on visible facial expression, clothing, and background without guessed posture."""
    scene = StructuredScene(
        primary_focus="person in front",
        context=SceneContext(
            setting="outdoor portrait setting",
            inferred_context=["passport photo"],
            observed_features=["person", "smiling expression", "collared shirt", "plain light background"],
        ),
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                distance=DistanceEstimate.NEAR,
                activity="standing",
                attributes=["standing", "wearing a collared shirt"],
            ),
            DetectedObject(
                label="background",
                position=SpatialPosition.SURROUNDING,
                attributes=["plain"],
            ),
        ],
    )
    desc_en = en_builder.build_description(scene)

    # Must describe visible person and visible details
    assert "person is in front of you" in desc_en.lower()
    # Must omit guessed posture on passport image
    assert "standing" not in desc_en.lower()
    # Must describe visible clothing
    assert "collared shirt" in desc_en.lower()
    # Must NOT describe unsupported generic setting
    assert "portrait" not in desc_en.lower()
    assert "portrait setting" not in desc_en.lower()


# 31. Concrete environmental settings remain properly supported
def test_concrete_environmental_settings_remain_supported():
    """Verify that concrete, useful physical settings (e.g. hallway, supermarket aisle, park) are still announced."""
    scene = StructuredScene(
        context=SceneContext(setting="hallway"),
        objects=[
            DetectedObject(
                label="doorway",
                position=SpatialPosition.FRONT,
                attributes=["open"],
            )
        ],
    )
    desc_en = en_builder.build_description(scene)
    assert "hallway" in desc_en.lower()
    assert "doorway" in desc_en.lower()


# 32. System prompt prioritized dimensions and strict rules coverage
def test_prompt_priority_order_and_rules_coverage():
    """Verify that ASSISTIVE_VISION_SYSTEM_INSTRUCTION contains all 7 priorities in exact order and strict rules."""
    from app.services.vision.prompts import ASSISTIVE_VISION_SYSTEM_INSTRUCTION

    # Check 7 prioritized dimensions in order
    assert "1. Visible People Present:" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "2. Visible Objects & Physical Features Present:" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "3. Egocentric Spatial Orientation & Relative Position:" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "4. Clearly Visible Activities, Posture, Appearance, or Interactions:" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "5. Important Visible Surroundings & Background Features:" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "6. Genuine Visible Hazards or Path Obstructions" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "7. Only Then, Limited Scene Context" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION

    # Check strict rules
    assert "portrait setting" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "professional portrait" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "headshot" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "outdoor setting" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "POSTURE GROUNDING" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "GENDER GROUNDING" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION
    assert "SPATIAL LANGUAGE" in ASSISTIVE_VISION_SYSTEM_INSTRUCTION


# 33. Posture Grounding: Omit posture for close-up, head-and-shoulders, or partially visible people
def test_posture_grounding_omitted_for_partial_and_closeup_people():
    """Verify that postures (standing, sitting, walking) are NOT output for partially visible or close-up people."""
    # Close-up / head-and-shoulders person: posture must be omitted
    for flag in ["close-up", "head-and-shoulders", "partially visible", "passport"]:
        scene_partial = StructuredScene(
            objects=[
                DetectedObject(
                    label="person",
                    position=SpatialPosition.FRONT,
                    attributes=[flag, "wearing a blue shirt"],
                )
            ]
        )
        desc = en_builder.build_description(scene_partial)
        assert "standing" not in desc.lower()
        assert "sitting" not in desc.lower()
        assert "walking" not in desc.lower()
        assert "person is in front of you" in desc.lower()
        assert "blue shirt" in desc.lower()

    # Full-body person with established posture: posture must be included
    scene_full = StructuredScene(
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.FRONT,
                activity="standing",
                attributes=["standing"],
            )
        ]
    )
    desc_full = en_builder.build_description(scene_full)
    assert "standing in front of you" in desc_full.lower()


# 34. Gender Grounding: Prefer 'person' and avoid unnecessary gender inference
def test_gender_grounding_prefers_person():
    """Verify that 'person' is preferred over 'man', 'woman', 'boy', 'girl' while preserving visible attributes."""
    for gender_label in ["man", "woman", "boy", "girl", "person"]:
        scene = StructuredScene(
            objects=[
                DetectedObject(
                    label=gender_label,
                    position=SpatialPosition.FRONT,
                    attributes=["beard", "wearing glasses"],
                )
            ]
        )
        desc_en = en_builder.build_description(scene)
        desc_te = te_builder.build_description(scene)

        # English must use 'A person', not 'A man', 'A woman', 'A boy', 'A girl'
        assert desc_en.startswith("A person")
        assert not desc_en.lower().startswith("a man")
        assert not desc_en.lower().startswith("a woman")
        assert not desc_en.lower().startswith("a boy")
        assert not desc_en.lower().startswith("a girl")

        # Visible attributes remain available
        assert "glasses" in desc_en.lower()

        # Telugu must use 'వ్యక్తి'
        assert "వ్యక్తి" in desc_te


# 35. Spatial Language: Natural English phrasing without 'in a front of'
def test_spatial_language_no_unnatural_phrasing():
    """Verify natural spatial language: 'centered in front of a blurred background' and 'in the center foreground with a blurred background'."""
    # 1. Person centered with blurred background via relationship
    scene_rel = StructuredScene(
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.CENTER,
                distance=DistanceEstimate.NEAR,
            ),
            DetectedObject(
                label="background",
                position=SpatialPosition.SURROUNDING,
                attributes=["blurred"],
            ),
        ],
        relationships=["person is centered in front of a blurred background"],
    )
    desc_rel = en_builder.build_description(scene_rel)
    assert "in a front of" not in desc_rel.lower()
    assert "a person is centered in front of a blurred background." in desc_rel.lower()

    # 2. Person in center foreground with blurred background via ambient coordination
    scene_amb = StructuredScene(
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.CENTER,
                distance=DistanceEstimate.NEAR,
            ),
            DetectedObject(
                label="blurred background",
                position=SpatialPosition.SURROUNDING,
            ),
        ],
    )
    desc_amb = en_builder.build_description(scene_amb)
    assert "in a front of" not in desc_amb.lower()
    assert "a person is in the center foreground with a blurred background." in desc_amb.lower()

    # 3. Relationship containing faulty 'in a front of' is sanitized
    scene_faulty = StructuredScene(
        objects=[
            DetectedObject(
                label="person",
                position=SpatialPosition.CENTER,
            ),
            DetectedObject(
                label="blurred background",
                position=SpatialPosition.SURROUNDING,
            ),
        ],
        relationships=["person is in a front of a blurred background"],
    )
    desc_faulty = en_builder.build_description(scene_faulty)
    assert "in a front of" not in desc_faulty.lower()
    assert "centered in front of a blurred background" in desc_faulty.lower()


