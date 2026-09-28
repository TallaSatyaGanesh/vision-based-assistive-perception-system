"""Language-specific description builders for assistive voice output.

Transforms canonical StructuredScene data into natural, scene-adaptive spoken narratives
tailored for audio listening by visually impaired users.
Prioritizes:
1. Immediate obstacles/hazards with visual evidence
2. People and visible activities/interactions
3. Key objects, landmarks, and spatial placement
4. Environmental setting and pathway conditions
"""

from abc import ABC, abstractmethod
import re
from typing import Dict, List, Optional, Set, Tuple
from app.services.vision.models import (
    DetectedObject,
    DistanceEstimate,
    SpatialPosition,
    StructuredScene,
    sanitize_scene_safety,
)


def _with_article(phrase: str) -> str:
    """Prefix a noun or adjective-noun phrase with the correct indefinite article ('a' or 'an')."""
    cleaned = phrase.strip()
    if not cleaned:
        return ""
    tokens = cleaned.split()
    first = tokens[0].lower()
    if first in ("a", "an", "the", "some", "two", "three", "four", "five", "multiple", "several", "no"):
        return cleaned
    if first in ("gravel", "grass", "sand", "dirt", "traffic", "foliage", "debris", "concrete"):
        return cleaned
    if first in ("hour", "honest", "honor", "honourable"):
        return f"an {cleaned}"
    if first in ("user", "university", "unique", "uniform", "one", "european", "useful"):
        return f"a {cleaned}"
    if first[0] in ("a", "e", "i", "o", "u"):
        return f"an {cleaned}"
    return f"a {cleaned}"


def _format_object_name(obj: DetectedObject) -> str:
    """Format an object's visual label, incorporating meaningful visual attributes without redundancy."""
    label = obj.label.strip().lower()
    skip_attrs = {
        "nearby", "front", "left", "right", "center", "surrounding",
        "unknown", "none", "facing", "standing", "sitting", "walking"
    }
    meaningful_attrs = [
        a.strip().lower() for a in obj.attributes
        if a.strip().lower() not in skip_attrs and a.strip().lower() not in label
    ]
    if meaningful_attrs:
        return f"{meaningful_attrs[0]} {label}"
    return label


def _extract_keywords(text: str) -> Set[str]:
    """Extract non-trivial semantic keywords for redundancy tracking."""
    words = set(re.findall(r"\b[a-z]{3,}\b", text.lower()))
    stop_words = {
        "the", "and", "for", "with", "you", "your", "are", "there",
        "this", "that", "from", "into", "some", "side", "front",
        "left", "right", "ahead", "near", "nearby", "caution", "has",
        "have", "about", "also", "been", "being", "such", "one", "two"
    }
    return words - stop_words


def _clean_prep_phrase(text: str, action: str, non_people: List[DetectedObject]) -> Tuple[str, Set[str]]:
    """Clean and synthesize prepositional location phrases, linking to detected objects where appropriate."""
    t = text.strip()
    mentioned: Set[str] = set()

    # Normalize unnatural spatial phrasing
    t = re.sub(r"\bin a front of\b", "in front of", t, flags=re.IGNORECASE)
    t = re.sub(r"\bcentered in a front of\b", "centered in front of", t, flags=re.IGNORECASE)

    for prefix in ("person is ", "the person is ", "a person is ", "is "):
        if t.lower().startswith(prefix):
            t = t[len(prefix):].strip()
    if action and t.lower().startswith(action.lower() + " "):
        t = t[len(action):].strip()

    compound_preps = [
        ("centered in front of a ", "centered in front of"),
        ("centered in front of an ", "centered in front of"),
        ("centered in front of the ", "centered in front of"),
        ("centered in front of ", "centered in front of"),
        ("in front of a ", "in front of"),
        ("in front of an ", "in front of"),
        ("in front of the ", "in front of"),
        ("in front of ", "in front of"),
        ("in the center foreground with a ", "in the center foreground with"),
        ("in the center foreground with an ", "in the center foreground with"),
        ("in the center foreground with the ", "in the center foreground with"),
        ("in the center foreground with ", "in the center foreground with"),
        ("in the center of a ", "in the center of"),
        ("in the center of an ", "in the center of"),
        ("in the center of the ", "in the center of"),
        ("in the center of ", "in the center of"),
        ("in the foreground with a ", "in the foreground with"),
        ("in the foreground with an ", "in the foreground with"),
        ("in the foreground with the ", "in the foreground with"),
        ("in the foreground with ", "in the foreground with"),
        ("next to a ", "next to"),
        ("next to an ", "next to"),
        ("next to the ", "next to"),
        ("next to ", "next to"),
    ]

    simple_preps = [
        ("on the ", "on"), ("on a ", "on"), ("on an ", "on"), ("on ", "on"),
        ("in the ", "in"), ("in a ", "in"), ("in an ", "in"), ("in ", "in"),
        ("at the ", "at"), ("at a ", "at"), ("at an ", "at"), ("at ", "at"),
        ("near an ", "near"), ("near a ", "near"), ("near the ", "near"), ("near ", "near"),
        ("by a ", "by"), ("by an ", "by"), ("by the ", "by"), ("by ", "by"),
        ("beside a ", "beside"), ("beside an ", "beside"), ("beside the ", "beside"), ("beside ", "beside"),
        ("along the ", "along"), ("along a ", "along"), ("along an ", "along"), ("along ", "along"),
    ]

    matched_prep = None
    prep_word = None
    for p, pw in compound_preps:
        if t.lower().startswith(p):
            matched_prep = p
            prep_word = pw
            break

    if not matched_prep:
        for p, pw in simple_preps:
            if t.lower().startswith(p):
                matched_prep = p
                prep_word = pw
                break

    if not matched_prep:
        if t.lower() in ("roadside", "the roadside"):
            return "on the roadside", {"roadside", "road"}
        return "", set()

    remainder = t[len(matched_prep):].strip()
    if remainder.lower().startswith("front of "):
        prep_word = f"{prep_word} front of"
        remainder = remainder[len("front of "):].strip()

    for obj in non_people:
        if obj.label.lower() in remainder.lower() or remainder.lower() in obj.label.lower():
            obj_name = _format_object_name(obj)
            art_obj = _with_article(obj_name)
            mentioned.add(obj.label.lower())
            if obj.attributes:
                for a in obj.attributes:
                    mentioned.add(a.lower())
            return f"{prep_word} {art_obj}", mentioned

    if remainder.lower() == "roadside":
        return f"{prep_word} the roadside", {"roadside", "road"}

    tokens = remainder.split()
    if tokens and tokens[0].lower() not in ("a", "an", "the"):
        remainder = _with_article(remainder)
    return f"{prep_word} {remainder}", set(remainder.lower().split())


def _is_unsupported_or_generic_setting(setting: Optional[str]) -> bool:
    """Check if setting is a generic classification, photographic label, or unsupported interpretation.

    Unsupported examples that must NOT be promoted into primary spoken descriptions:
    - 'portrait setting', 'outdoor portrait setting', 'professional portrait', 'headshot'
    - 'photo setting', 'studio portrait', 'outdoor setting', 'indoor setting'
    - 'general', 'unknown', 'none', 'indoor room'
    """
    if not setting:
        return True
    s = setting.lower().strip()
    if s in ("unknown", "none", "indoor room", "general", "", "scene", "environment", "room"):
        return True

    # Check for photography, portrait, or framing meta-labels
    disallowed_substrings = (
        "portrait", "headshot", "close-up", "closeup", "selfie",
        "photo", "photograph", "photography", "photoshoot", "shot",
        "camera", "framing", "studio", "picture", "lighting setup"
    )
    if any(sub in s for sub in disallowed_substrings):
        return True

    # Generic settings lacking concrete physical environmental meaning
    if s in (
        "outdoor setting", "indoor setting", "outdoor", "indoor",
        "natural setting", "artificial setting", "open setting"
    ):
        return True

    return False


class BaseDescriptionBuilder(ABC):
    """Abstract contract for generating natural-language descriptions from structured scenes."""

    @property
    @abstractmethod
    def language_code(self) -> str:
        """Supported language code (e.g. 'en', 'te')."""
        pass

    @abstractmethod
    def build_description(self, scene: StructuredScene) -> str:
        """Produce a scene-adaptive assistive narrative."""
        pass


class EnglishDescriptionBuilder(BaseDescriptionBuilder):
    """Generates natural, scene-adaptive English audio-optimized descriptions."""

    @property
    def language_code(self) -> str:
        return "en"

    def build_description(self, scene: StructuredScene) -> str:
        # Enforce conservative, evidence-based obstacle and hazard classification
        scene = sanitize_scene_safety(scene)
        sentences: List[str] = []
        mentioned_keywords: Set[str] = set()

        # 1. Immediate Safety & Obstacle Hazards (Highest Priority)
        hazards = [obj for obj in scene.objects if obj.is_obstacle]
        explicit_hazards = [h for h in scene.context.hazards_or_obstacles if h.strip()]

        if hazards or explicit_hazards:
            hazard_items = [h.label for h in hazards] + explicit_hazards
            unique_hazards = list(dict.fromkeys(hazard_items))
            hazard_str = ", ".join(unique_hazards)
            hazard_sentence = f"Caution: there is an obstacle ({hazard_str}) in your path."
            sentences.append(hazard_sentence)
            mentioned_keywords.update(_extract_keywords(hazard_sentence))

        # 2. People & Visible Activities / Interactions / Locations
        people = [
            obj for obj in scene.objects
            if obj.label.lower() in ("person", "people", "man", "woman", "child", "boy", "girl", "individual", "pedestrian") and not obj.is_obstacle
        ]
        non_people = [obj for obj in scene.objects if obj not in people and not obj.is_obstacle]

        if people:
            people_desc, people_mentioned = self._describe_people(people, scene, non_people)
            if people_desc:
                sentences.append(people_desc)
                mentioned_keywords.update(_extract_keywords(people_desc))
                mentioned_keywords.update(people_mentioned)

        # 3. Key Objects & Spatial Landmarks (Filtered for unmentioned objects)
        remaining_objects = [
            obj for obj in non_people
            if obj.label.lower() not in mentioned_keywords and not (set(obj.label.lower().split()) & mentioned_keywords)
        ]

        if remaining_objects and len(sentences) < 3:
            # Check if there is a single ambient/surrounding ground element that coordinates naturally with the people sentence
            is_single_ambient = (
                len(remaining_objects) == 1
                and bool(people)
                and len(sentences) == 1
                and sentences[0].endswith(".")
                and (
                    remaining_objects[0].position == SpatialPosition.SURROUNDING
                    or any(
                        w in remaining_objects[0].label.lower()
                        for w in ("ground", "gravel", "grass", "dirt", "terrain")
                    )
                )
            )

            if is_single_ambient:
                amb_name = _format_object_name(remaining_objects[0])
                amb_phrase = _with_article(amb_name)
                if any(w in amb_name.lower() for w in ("background", "backdrop", "wall")):
                    coordinated = f"{sentences[0][:-1]} with {amb_phrase}."
                else:
                    coordinated = f"{sentences[0][:-1]}, with {amb_phrase} nearby."
                sentences[0] = coordinated
                mentioned_keywords.update(_extract_keywords(coordinated))
            else:
                objects_desc = self._describe_objects(remaining_objects, people_present=bool(people))
                if objects_desc:
                    sentences.append(objects_desc)
                    mentioned_keywords.update(_extract_keywords(objects_desc))

        # 4. Contextual Relationships (Only if adding new, unmentioned entities/facts)
        if scene.relationships and len(sentences) < 3:
            for rel in scene.relationships:
                rel_clean = rel.strip()
                if not rel_clean or rel_clean.lower() in ("unknown", "none"):
                    continue
                rel_keywords = _extract_keywords(rel_clean)
                # If all meaningful keywords in the relationship are already mentioned, skip it
                if rel_keywords.issubset(mentioned_keywords):
                    continue
                # If relationship introduces new information, state it naturally without filler words like "Notably"
                rel_sentence = f"{rel_clean[0].upper()}{rel_clean[1:]}."
                sentences.append(rel_sentence)
                mentioned_keywords.update(rel_keywords)
                break  # At most one supplementary relationship sentence

        # 5. Environmental Setting & Context (Only when informative, unmentioned, and supported)
        setting = scene.context.setting
        if setting and not _is_unsupported_or_generic_setting(setting):
            setting_keywords = _extract_keywords(setting)
            is_subword = any(kw in s or s in kw for s in setting_keywords for kw in mentioned_keywords)
            if not (setting_keywords & mentioned_keywords) and not is_subword:
                if not sentences:
                    sentences.append(f"You are in {setting}. The path ahead appears clear.")
                elif len(sentences) <= 2:
                    sentences.append(f"You are in a {setting}.")
                mentioned_keywords.update(setting_keywords)

        # 6. Fallback for completely empty or clear scenes
        if not sentences:
            if scene.context.observed_features:
                clean_features = [
                    f.strip() for f in scene.context.observed_features
                    if f.strip() and f.strip().lower() not in ("unknown", "none")
                ]
                if clean_features:
                    features_str = ", ".join(clean_features[:3])
                    return f"The area has {features_str} with no immediate obstacles detected."
            return "The path in front of you appears clear. No immediate obstacles detected."

        # Cap strictly at 3 sentences
        sentences = sentences[:3]
        return " ".join(sentences)

    def _describe_people(
        self,
        people: List[DetectedObject],
        scene: StructuredScene,
        non_people: List[DetectedObject],
    ) -> Tuple[str, Set[str]]:
        """Describe visible people, postures, activities, and interactions naturally."""
        if len(people) == 1:
            person = people[0]
            label_lower = person.label.lower().strip()
            subject = "A person"
            # Avoid unnecessary gender inference (man, woman, boy, girl) - prefer 'A person'
            if label_lower in ("child",):
                subject = "A child"
            elif label_lower not in ("person", "man", "woman", "boy", "girl", "individual", "pedestrian"):
                subject = _with_article(label_lower).capitalize()

            # Determine posture / activity only when body/posture is clearly visible enough
            # For close-up, head-and-shoulders, passport-style, or partially visible people, omit posture
            is_partial_or_closeup = any(
                term in a.lower()
                for a in person.attributes + (scene.context.observed_features or []) + (scene.context.inferred_context or [])
                for term in ("close-up", "closeup", "head-and-shoulders", "head and shoulders", "partially visible", "passport", "headshot", "upper body")
            )
            action = ""
            if not is_partial_or_closeup:
                if person.activity and person.activity.lower().strip() not in ("unknown", "none"):
                    action = person.activity.lower().strip()
                elif person.attributes:
                    for attr in person.attributes:
                        if attr.lower().strip() in ("standing", "sitting", "walking", "running"):
                            action = attr.lower().strip()
                            break

            pos = self._format_position(person.position)

            # Check interaction, relationship, and appearance candidates
            candidates = []
            if person.relationship and person.relationship.lower().strip() not in ("unknown", "none"):
                candidates.append(person.relationship.strip())
            if person.interaction and person.interaction.lower().strip() not in ("unknown", "none"):
                candidates.append(person.interaction.strip())
            for r in scene.relationships:
                if r and r.lower().strip() not in ("unknown", "none") and ("person" in r.lower() or label_lower in r.lower()):
                    candidates.append(r.strip())
            if person.attributes:
                for attr in person.attributes:
                    a_low = attr.strip().lower()
                    if a_low not in ("standing", "sitting", "walking", "running", "unknown", "none", "person", "man", "woman", "close-up", "head-and-shoulders", "partially visible"):
                        candidates.append(attr.strip())

            loc_phrase = ""
            mentioned: Set[str] = set()
            for cand in candidates:
                cand_lower = cand.lower().strip()
                if cand_lower.startswith(("holding ", "carrying ", "using ", "reading ", "talking ", "wearing ", "dressed in ")):
                    loc_phrase = f", {cand}"
                    mentioned.update(_extract_keywords(cand))
                    break
                elif cand_lower in ("facing towards you", "facing the camera", "looking at the camera", "smiling"):
                    loc_phrase = f", {cand}"
                    mentioned.update(_extract_keywords(cand))
                    break
                else:
                    lp, ment = _clean_prep_phrase(cand, action, non_people)
                    if lp:
                        loc_phrase = f" {lp}"
                        mentioned.update(ment)
                        break

            clean_loc = loc_phrase.strip().lstrip(",").strip()
            loc_lower = clean_loc.lower()

            if loc_lower.startswith(("centered in front of", "in the center foreground with")):
                if action:
                    return f"{subject} is {action}, {clean_loc}.", mentioned
                return f"{subject} is {clean_loc}.", mentioned

            if loc_lower.startswith("in front of"):
                if person.position == SpatialPosition.CENTER:
                    if action:
                        return f"{subject} is {action} centered {clean_loc}.", mentioned
                    return f"{subject} is centered {clean_loc}.", mentioned
                else:
                    if action:
                        return f"{subject} is {action} {clean_loc}.", mentioned
                    return f"{subject} is {clean_loc}.", mentioned

            if person.position == SpatialPosition.CENTER and person.distance == DistanceEstimate.NEAR and not loc_phrase:
                pos = "in the center foreground"

            if action and pos:
                return f"{subject} is {action} {pos}{loc_phrase}.", mentioned
            elif action:
                return f"{subject} is {action}{loc_phrase}.", mentioned
            elif pos:
                return f"{subject} is {pos}{loc_phrase}.", mentioned
            elif loc_phrase:
                return f"{subject} is {loc_phrase.strip()}.", mentioned
            else:
                return f"{subject} is nearby.", mentioned
        else:
            count = len(people)
            positions = [p.position for p in people if p.position != SpatialPosition.UNKNOWN]
            pos_str = self._format_position(positions[0]) if positions else "nearby"
            activities = [p.activity for p in people if p.activity and p.activity.lower() not in ("unknown", "none")]
            if len(people) == 2 and len(activities) == 2 and activities[0] != activities[1]:
                pos1 = self._format_position(people[0].position) or "nearby"
                pos2 = self._format_position(people[1].position) or "nearby"
                return (
                    f"There are two people nearby: one is {activities[0]} {pos1}, and one is {activities[1]} {pos2}.",
                    set(),
                )
            return f"There are {count} people {pos_str}.", set()

    def _describe_objects(self, objects: List[DetectedObject], people_present: bool) -> str:
        """Group and describe key objects by spatial position naturally."""
        left_objects = [o for o in objects if o.position == SpatialPosition.LEFT]
        right_objects = [o for o in objects if o.position == SpatialPosition.RIGHT]
        front_objects = [o for o in objects if o.position in (SpatialPosition.FRONT, SpatialPosition.CENTER)]
        surrounding_objects = [o for o in objects if o.position == SpatialPosition.SURROUNDING]

        parts: List[str] = []

        if not people_present and front_objects:
            primary = front_objects[0]
            obj_name = _format_object_name(primary)
            art = _with_article(obj_name)
            parts.append(f"{art} is directly in front of you")
            front_objects = front_objects[1:]

        if left_objects:
            obj = left_objects[0]
            obj_name = _format_object_name(obj)
            art = _with_article(obj_name)
            parts.append(f"{art} is on your left side")

        if right_objects:
            obj = right_objects[0]
            obj_name = _format_object_name(obj)
            art = _with_article(obj_name)
            parts.append(f"{art} is on your right side")

        if front_objects:
            obj = front_objects[0]
            obj_name = _format_object_name(obj)
            art = _with_article(obj_name)
            parts.append(f"{art} is nearby")
        elif surrounding_objects:
            obj = surrounding_objects[0]
            obj_name = _format_object_name(obj)
            art = _with_article(obj_name)
            parts.append(f"{art} is nearby")

        if not parts:
            if objects:
                art = _with_article(_format_object_name(objects[0]))
                return f"Nearby objects include {art}."
            return ""

        if len(parts) == 1:
            desc = parts[0]
        elif len(parts) == 2:
            desc = f"{parts[0]}, and {parts[1]}"
        else:
            desc = f"{parts[0]}, {parts[1]}, and {parts[2]}"

        return f"{desc[0].upper()}{desc[1:]}."

    def _format_position(self, pos: SpatialPosition) -> str:
        """Convert SpatialPosition enum to natural English prepositional phrase."""
        mapping = {
            SpatialPosition.FRONT: "in front of you",
            SpatialPosition.LEFT: "on your left side",
            SpatialPosition.RIGHT: "on your right side",
            SpatialPosition.CENTER: "in front of you",
            SpatialPosition.SURROUNDING: "nearby",
            SpatialPosition.UNKNOWN: "",
        }
        return mapping.get(pos, "")


def _clean_telugu_text(text: str) -> str:
    """Clean Telugu text by removing formatting artifacts, repeated punctuation, and extra whitespace."""
    if not text:
        return ""
    t = re.sub(r"[ \t]+", " ", text)
    t = re.sub(r"\s+([.,;:!?])", r"\1", t)
    t = re.sub(r"\.+", ".", t)
    t = re.sub(r"([.,;:!?])\s*\1+", r"\1", t)
    raw_sentences = [s.strip() for s in t.split(".") if s.strip()]
    cleaned_sentences: List[str] = []
    seen: Set[str] = set()
    for s in raw_sentences:
        s_clean = s.strip(" .,;:!?")
        if not s_clean:
            continue
        if s_clean.lower() in seen:
            continue
        seen.add(s_clean.lower())
        cleaned_sentences.append(s_clean)

    if not cleaned_sentences:
        return ""
    result = ". ".join(cleaned_sentences) + "."
    return re.sub(r"\s+", " ", result).strip()


class TeluguDescriptionBuilder(BaseDescriptionBuilder):
    """Generates natural, scene-adaptive Telugu audio-optimized descriptions."""

    @property
    def language_code(self) -> str:
        return "te"

    _TELUGU_LABELS: Dict[str, str] = {
        "person": "వ్యక్తి",
        "people": "వ్యక్తులు",
        "man": "వ్యక్తి",
        "woman": "మహిళ",
        "child": "పిల్లవాడు",
        "chair": "కుర్చీ",
        "chairs": "కుర్చీలు",
        "wooden chair": "చెక్క కుర్చీ",
        "table": "టేబుల్",
        "tables": "టేబుళ్ళు",
        "desk": "డెస్క్",
        "bed": "మంచం",
        "bench": "బెంచ్",
        "door": "ద్వారం",
        "doorway": "ద్వారం",
        "open doorway": "తెరిచి ఉన్న ద్వారం",
        "stairs": "మెట్లు",
        "steps": "మెట్లు",
        "wall": "గోడ",
        "walls": "గోడలు",
        "window": "కిటికీ",
        "windows": "కిటికీలు",
        "building": "భవనం",
        "buildings": "భవనాలు",
        "vehicle": "వాహనం",
        "vehicles": "వాహనాలు",
        "car": "కారు",
        "cars": "కార్లు",
        "bus": "బస్సు",
        "buses": "బస్సులు",
        "bicycle": "సైకిల్",
        "motorcycle": "మోటార్ సైకిల్",
        "truck": "ట్రక్",
        "tree": "చెట్టు",
        "trees": "చెట్లు",
        "foliage": "పచ్చని చెట్లు",
        "green foliage": "పచ్చని చెట్లు",
        "green foliage trees": "పచ్చని చెట్లు",
        "green trees": "పచ్చని చెట్లు",
        "plant": "మొక్క",
        "plants": "మొక్కలు",
        "bush": "పొద",
        "bushes": "పొదలు",
        "branch": "కొమ్మ",
        "branches": "కొమ్మలు",
        "leaves": "ఆకులు",
        "phone": "ఫోన్",
        "laptop": "ల్యాప్‌టాప్",
        "computer": "కంప్యూటర్",
        "screen": "స్క్రీన్",
        "bag": "బ్యాగ్",
        "backpack": "బ్యాగ్",
        "cup": "కప్పు",
        "bottle": "బాటిల్",
        "curb": "కర్బ్",
        "sidewalk": "ఫుట్‌పాత్",
        "footpath": "ఫుట్‌పాత్",
        "road": "రోడ్డు",
        "asphalt road": "తారు రోడ్డు",
        "asphalt": "తారు రోడ్డు",
        "paved road": "తారు రోడ్డు",
        "roadway": "రోడ్డు",
        "street": "వీధి",
        "highway": "హైవే",
        "pathway": "నడిచే దారి",
        "path": "దారి",
        "walkway": "నడిచే దారి",
        "ground": "నేల",
        "gravel": "కంకర నేల",
        "gravel ground": "కంకర నేల",
        "dirt": "మట్టి నేల",
        "grass": "గడ్డి",
        "floor": "నేల",
        "roadside": "రోడ్డు పక్కన",
        "cable": "కేబుల్",
        "wire": "వైరు",
        "obstacle": "అడ్డంకి",
        "barrier": "అడ్డంకి",
        "conference room": "సమావేశ గది",
        "meeting room": "సమావేశ గది",
        "living room": "గది",
        "office": "కార్యాలయం",
        "hallway": "హాలు",
        "corridor": "కారిడార్",
        "park": "పార్కు",
        "store": "దుకాణం",
    }

    _TELUGU_ACTIVITIES: Dict[str, str] = {
        "standing": "నిలబడి ఉన్నారు",
        "sitting": "కూర్చుని ఉన్నారు",
        "walking": "నడుస్తున్నారు",
        "running": "పరిగెడుతున్నారు",
        "talking": "మాట్లాడుతున్నారు",
        "speaking": "మాట్లాడుతున్నారు",
        "holding": "పట్టుకుని ఉన్నారు",
        "using": "ఉపయోగిస్తున్నారు",
    }

    def _get_label(self, label: str) -> str:
        """Translate label to Telugu or return original if loanword."""
        l = label.lower().strip()
        if l in self._TELUGU_LABELS:
            return self._TELUGU_LABELS[l]
        for k, v in self._TELUGU_LABELS.items():
            if k in l:
                return v
        return label.strip()

    def _translate_entity(self, obj: DetectedObject) -> Tuple[str, bool, bool]:
        """Translate a detected object into a natural Telugu noun phrase with plural and mass metadata.

        Returns:
            (telugu_phrase, is_plural, is_mass_noun)
        """
        raw_label = obj.label.lower().strip()
        attrs = [a.lower().strip() for a in obj.attributes if a.strip()]
        all_tokens = set(re.findall(r"\b[a-z]+\b", raw_label + " " + " ".join(attrs)))

        # 1. Vegetation, Foliage & Trees
        if "foliage" in all_tokens or ("tree" in all_tokens and "green" in all_tokens) or ("trees" in all_tokens and "green" in all_tokens):
            return ("పచ్చని చెట్లు", True, False)
        if "trees" in all_tokens:
            return ("చెట్లు", True, False)
        if "tree" in all_tokens:
            return ("చెట్టు", False, False)
        if "plants" in all_tokens:
            return ("మొక్కలు", True, False)
        if "plant" in all_tokens:
            return ("మొక్క", False, False)
        if "bushes" in all_tokens:
            return ("పొదలు", True, False)
        if "bush" in all_tokens:
            return ("పొద", False, False)
        if "branches" in all_tokens:
            return ("కొమ్మలు", True, False)
        if "branch" in all_tokens:
            return ("కొమ్మ", False, False)
        if "leaves" in all_tokens:
            return ("ఆకులు", True, False)
        if "grass" in all_tokens:
            return ("గడ్డి", False, True)

        # 2. Roads, Walkways & Surfaces
        if "asphalt" in all_tokens or "tar" in all_tokens or ("road" in all_tokens and "paved" in all_tokens):
            return ("తారు రోడ్డు", False, False)
        if "road" in all_tokens or "roadway" in all_tokens:
            return ("రోడ్డు", False, False)
        if "street" in all_tokens:
            return ("వీధి", False, False)
        if "highway" in all_tokens:
            return ("హైవే", False, False)
        if "sidewalk" in all_tokens or "footpath" in all_tokens:
            return ("ఫుట్‌పాత్", False, False)
        if "pathway" in all_tokens or "walkway" in all_tokens or "path" in all_tokens:
            return ("నడిచే దారి", False, False)
        if "gravel" in all_tokens:
            return ("కంకర నేల", False, True)
        if "dirt" in all_tokens:
            return ("మట్టి నేల", False, True)
        if "ground" in all_tokens or "floor" in all_tokens:
            return ("నేల", False, True)
        if "curb" in all_tokens:
            return ("కర్బ్", False, False)

        # 3. People
        if "people" in all_tokens:
            return ("వ్యక్తులు", True, False)
        if "woman" in all_tokens:
            return ("మహిళ", False, False)
        if "child" in all_tokens or "boy" in all_tokens or "girl" in all_tokens:
            return ("పిల్లవాడు", False, False)
        if any(w in all_tokens for w in ("person", "man", "pedestrian", "individual")):
            return ("వ్యక్తి", False, False)

        # 4. Vehicles
        if "cars" in all_tokens:
            return ("కార్లు", True, False)
        if "car" in all_tokens:
            return ("కారు", False, False)
        if "buses" in all_tokens:
            return ("బస్సులు", True, False)
        if "bus" in all_tokens:
            return ("బస్సు", False, False)
        if "bicycle" in all_tokens or "bicycles" in all_tokens or "cycle" in all_tokens:
            return ("సైకిల్", False, False)
        if "motorcycle" in all_tokens or "motorbike" in all_tokens or "bike" in all_tokens:
            return ("మోటార్ సైకిల్", False, False)
        if "vehicles" in all_tokens:
            return ("వాహనాలు", True, False)
        if "vehicle" in all_tokens:
            return ("వాహనం", False, False)
        if "truck" in all_tokens:
            return ("ట్రక్", False, False)

        # 5. Architecture & Physical Structures
        if "stairs" in all_tokens or "steps" in all_tokens:
            return ("మెట్లు", True, False)
        if "door" in all_tokens or "doorway" in all_tokens:
            if "open" in all_tokens:
                return ("తెరిచి ఉన్న ద్వారం", False, False)
            return ("ద్వారం", False, False)
        if "windows" in all_tokens:
            return ("కిటికీలు", True, False)
        if "window" in all_tokens:
            return ("కిటికీ", False, False)
        if "walls" in all_tokens:
            return ("గోడలు", True, False)
        if "wall" in all_tokens:
            return ("గోడ", False, False)
        if "buildings" in all_tokens:
            return ("భవనాలు", True, False)
        if "building" in all_tokens:
            return ("భవనం", False, False)

        # 6. Objects & Furniture
        if "chairs" in all_tokens:
            return ("కుర్చీలు", True, False)
        if "chair" in all_tokens:
            if "wooden" in all_tokens:
                return ("చెక్క కుర్చీ", False, False)
            return ("కుర్చీ", False, False)
        if "tables" in all_tokens:
            return ("టేబుళ్ళు", True, False)
        if "table" in all_tokens:
            return ("టేబుల్", False, False)
        if "desk" in all_tokens:
            return ("డెస్క్", False, False)
        if "bed" in all_tokens:
            return ("మంచం", False, False)
        if "bench" in all_tokens:
            return ("బెంచ్", False, False)
        if "bottle" in all_tokens:
            return ("బాటిల్", False, False)
        if "cup" in all_tokens:
            return ("కప్పు", False, False)
        if "screen" in all_tokens:
            return ("స్క్రీన్", False, False)
        if "bag" in all_tokens or "backpack" in all_tokens:
            return ("బ్యాగ్", False, False)
        if "phone" in all_tokens:
            return ("ఫోన్", False, False)
        if "laptop" in all_tokens:
            return ("ల్యాప్‌టాప్", False, False)
        if "computer" in all_tokens:
            return ("కంప్యూటర్", False, False)
        if "cables" in all_tokens or "wires" in all_tokens:
            return ("కేబుల్స్", True, False)
        if "cable" in all_tokens or "wire" in all_tokens:
            return ("కేబుల్", False, False)
        if "barrier" in all_tokens or "obstacle" in all_tokens:
            return ("అడ్డంకి", False, False)

        # 7. Fallback to dictionary
        name = _format_object_name(obj)
        lbl = self._get_label(name)
        is_pl = raw_label.endswith("s") and not raw_label.endswith("ss")
        is_mass = any(w in all_tokens for w in ("ground", "gravel", "grass", "dirt", "terrain", "water"))
        return (lbl, is_pl, is_mass)

    def build_description(self, scene: StructuredScene) -> str:
        # Enforce conservative, evidence-based obstacle and hazard classification
        scene = sanitize_scene_safety(scene)
        sentences: List[str] = []
        mentioned_labels: Set[str] = set()

        # 1. Immediate Safety Hazards (Highest Priority)
        hazards = [obj for obj in scene.objects if obj.is_obstacle]
        explicit_hazards = [h for h in scene.context.hazards_or_obstacles if h.strip()]

        if hazards or explicit_hazards:
            hazard_items = [self._get_label(h.label) for h in hazards] + [self._get_label(h) for h in explicit_hazards]
            unique_hazards = list(dict.fromkeys(hazard_items))
            hazard_names = ", ".join(unique_hazards)
            sentences.append(f"హెచ్చరిక: మీ మార్గంలో అడ్డంకి ({hazard_names}) ఉంది.")
            for h in hazards:
                mentioned_labels.add(h.label.lower().strip())

        # 2. People & Visible Activities / Postures
        people = [
            obj for obj in scene.objects
            if obj.label.lower() in ("person", "people", "man", "woman", "child", "boy", "girl", "individual", "pedestrian") and not obj.is_obstacle
        ]
        non_people = [obj for obj in scene.objects if obj not in people and not obj.is_obstacle]

        if people:
            people_desc, people_mentioned = self._describe_people(people, scene, non_people)
            if people_desc:
                sentences.append(people_desc)
                for p in people:
                    mentioned_labels.add(p.label.lower().strip())
                mentioned_labels.update(people_mentioned)

        # 3. Key Objects & Spatial Landmarks
        remaining_objects = [
            obj for obj in non_people
            if obj.label.lower().strip() not in mentioned_labels
        ]
        if remaining_objects and len(sentences) < 2:
            objects_desc = self._describe_objects(remaining_objects, people_present=bool(people))
            if objects_desc:
                sentences.append(objects_desc)

        # 4. Contextual Setting (Only when unmentioned, supported, and translated)
        setting = scene.context.setting
        if setting and not _is_unsupported_or_generic_setting(setting):
            setting_clean = setting.strip()
            if not any(lbl in setting_clean.lower() or setting_clean.lower() in lbl for lbl in mentioned_labels):
                setting_telugu = self._get_label(setting_clean)
                if setting_telugu and setting_telugu.lower() != setting_clean.lower():
                    if not sentences:
                        sentences.append(f"మీరు {setting_telugu} లో ఉన్నారు. మీ ముందు మార్గం స్పష్టంగా ఉంది.")
                    elif len(sentences) < 2:
                        sentences.append(f"మీరు {setting_telugu} లో ఉన్నారు.")

        # 5. Fallback for completely clear/empty scenes
        if not sentences:
            return "మీ ముందు మార్గం స్పష్టంగా ఉంది. ఎటువంటి అడ్డంకులు కనిపించలేదు."

        sentences = sentences[:2]
        raw_result = " ".join(sentences)
        return _clean_telugu_text(raw_result)

    def _describe_people(
        self,
        people: List[DetectedObject],
        scene: StructuredScene,
        non_people: List[DetectedObject],
    ) -> Tuple[str, Set[str]]:
        """Formulate natural Telugu phrasing for people and activities."""
        mentioned: Set[str] = set()
        if len(people) == 1:
            person = people[0]
            pos = person.position

            # Prioritize explicit activity; omit posture if partial or close-up
            is_partial_or_closeup = any(
                term in a.lower()
                for a in person.attributes + (scene.context.observed_features or []) + (scene.context.inferred_context or [])
                for term in ("close-up", "closeup", "head-and-shoulders", "head and shoulders", "partially visible", "passport", "headshot", "upper body")
            )
            activity_key = "" if is_partial_or_closeup else (person.activity or "").lower().strip()
            if not is_partial_or_closeup and not activity_key and person.attributes:
                for attr in person.attributes:
                    if attr.lower().strip() in ("sitting", "walking", "running", "talking", "speaking"):
                        activity_key = attr.lower().strip()
                        break

            rel_label = ""
            for obj in non_people:
                if (person.relationship and obj.label.lower() in person.relationship.lower()) or \
                   (person.interaction and obj.label.lower() in person.interaction.lower()) or \
                   any(r for r in scene.relationships if obj.label.lower() in r.lower() and ("person" in r.lower() or person.label.lower() in r.lower())):
                    t_lbl, _, _ = self._translate_entity(obj)
                    rel_label = t_lbl
                    mentioned.add(obj.label.lower().strip())
                    for tk in obj.label.lower().split():
                        mentioned.add(tk)
                    break

            if not rel_label:
                rel_candidates = []
                if person.relationship:
                    rel_candidates.append(person.relationship.lower())
                if person.interaction:
                    rel_candidates.append(person.interaction.lower())
                rel_candidates.extend(r.lower() for r in scene.relationships if "person" in r.lower() or person.label.lower() in r.lower())

                for rc in rel_candidates:
                    if "asphalt" in rc or "paved road" in rc:
                        rel_label = "తారు రోడ్డు"
                        mentioned.add("road")
                        mentioned.add("roadside")
                        mentioned.add("asphalt")
                        break
                    elif "road" in rc or "street" in rc:
                        rel_label = "రోడ్డు"
                        mentioned.add("road")
                        mentioned.add("roadside")
                        break

            if not rel_label and scene.context.setting and "road" in scene.context.setting.lower():
                rel_label = "రోడ్డు"
                mentioned.add("road")
                mentioned.add("roadside")

            act_phrase = self._TELUGU_ACTIVITIES.get(activity_key, "")

            if pos in (SpatialPosition.FRONT, SpatialPosition.CENTER):
                if act_phrase:
                    if rel_label:
                        return f"మీ ముందు {rel_label} దగ్గర ఒక వ్యక్తి {act_phrase}.", mentioned
                    return f"మీ ముందు ఒక వ్యక్తి {act_phrase}.", mentioned
                else:
                    if rel_label:
                        return f"మీ ముందు {rel_label} దగ్గర ఒక వ్యక్తి ఉన్నారు.", mentioned
                    return "మీ ముందు ఒక వ్యక్తి ఉన్నారు.", mentioned

            elif pos == SpatialPosition.LEFT:
                if act_phrase:
                    if rel_label:
                        return f"మీ ఎడమ వైపున {rel_label} దగ్గర ఒక వ్యక్తి {act_phrase}.", mentioned
                    return f"మీ ఎడమ వైపున ఒక వ్యక్తి {act_phrase}.", mentioned
                if rel_label:
                    return f"మీ ఎడమ వైపున {rel_label} దగ్గర ఒక వ్యక్తి ఉన్నారు.", mentioned
                return "మీ ఎడమ వైపున ఒక వ్యక్తి ఉన్నారు.", mentioned

            elif pos == SpatialPosition.RIGHT:
                if act_phrase:
                    if rel_label:
                        return f"మీ కుడి వైపున {rel_label} దగ్గర ఒక వ్యక్తి {act_phrase}.", mentioned
                    return f"మీ కుడి వైపున ఒక వ్యక్తి {act_phrase}.", mentioned
                if rel_label:
                    return f"మీ కుడి వైపున {rel_label} దగ్గర ఒక వ్యక్తి ఉన్నారు.", mentioned
                return "మీ కుడి వైపున ఒక వ్యక్తి ఉన్నారు.", mentioned

            else:  # SURROUNDING, UNKNOWN
                if act_phrase:
                    if rel_label:
                        return f"దగ్గరలో {rel_label} వద్ద ఒక వ్యక్తి {act_phrase}.", mentioned
                    return f"దగ్గరలో ఒక వ్యక్తి {act_phrase}.", mentioned
                if rel_label:
                    return f"దగ్గరలో {rel_label} వద్ద ఒక వ్యక్తి ఉన్నారు.", mentioned
                return "దగ్గరలో ఒక వ్యక్తి ఉన్నారు.", mentioned

        else:
            count = len(people)
            positions = [p.position for p in people if p.position != SpatialPosition.UNKNOWN]
            pos_str = "మీ ముందు" if (positions and positions[0] in (SpatialPosition.FRONT, SpatialPosition.CENTER)) else "మీ పరిసరాల్లో"
            activities = [p.activity for p in people if p.activity and p.activity.lower().strip() not in ("unknown", "none")]
            if len(people) == 2 and len(activities) == 2 and activities[0] != activities[1]:
                act1 = self._TELUGU_ACTIVITIES.get(activities[0].lower().strip(), activities[0])
                act2 = self._TELUGU_ACTIVITIES.get(activities[1].lower().strip(), activities[1])
                return f"{pos_str} ఇద్దరు వ్యక్తులు ఉన్నారు: ఒకరు {act1}, మరొకరు {act2}.", set()
            return f"{pos_str} {count} మంది వ్యక్తులు ఉన్నారు.", set()

    def _describe_objects(self, objects: List[DetectedObject], people_present: bool) -> str:
        """Group and describe objects in natural Telugu syntax."""
        if not objects:
            return ""

        left_objects = [o for o in objects if o.position == SpatialPosition.LEFT]
        right_objects = [o for o in objects if o.position == SpatialPosition.RIGHT]
        front_objects = [o for o in objects if o.position in (SpatialPosition.FRONT, SpatialPosition.CENTER)]
        surrounding_objects = [o for o in objects if o.position == SpatialPosition.SURROUNDING]

        spatial_parts: List[str] = []

        def _format_part(obj: DetectedObject, pos_prefix: str) -> str:
            t_label, is_pl, is_mass = self._translate_entity(obj)
            noun_phrase = t_label if (is_pl or is_mass or t_label.startswith("ఒక ")) else f"ఒక {t_label}"
            verb = "ఉన్నాయి" if is_pl else "ఉంది"
            return f"{pos_prefix} {noun_phrase} {verb}"

        if not people_present and front_objects:
            obj = front_objects[0]
            spatial_parts.append(_format_part(obj, "మీ ముందు"))
            front_objects = front_objects[1:]

        if left_objects:
            obj = left_objects[0]
            spatial_parts.append(_format_part(obj, "మీ ఎడమ వైపున"))

        if right_objects:
            obj = right_objects[0]
            spatial_parts.append(_format_part(obj, "మీ కుడి వైపున"))

        if front_objects:
            obj = front_objects[0]
            pref = "సమీపంలో" if people_present else "మీ ముందు"
            spatial_parts.append(_format_part(obj, pref))
        elif surrounding_objects:
            obj = surrounding_objects[0]
            spatial_parts.append(_format_part(obj, "దగ్గరలో"))

        if not spatial_parts:
            for o in objects:
                spatial_parts.append(_format_part(o, "సమీపంలో"))
                break

        max_parts = 1 if people_present else 2
        selected_parts = spatial_parts[:max_parts]

        if len(selected_parts) == 1:
            return f"{selected_parts[0]}."
        return f"{selected_parts[0]}, మరియు {selected_parts[1]}."
