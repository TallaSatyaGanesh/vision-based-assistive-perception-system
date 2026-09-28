# Vision-Based Assistive Perception System with Voice Assistance for the Visually Impaired

## 1. Project Title
**Vision-Based Assistive Perception System with Voice Assistance for the Visually Impaired**

---

## 2. Project Objective
The primary goal of this project is to build an assistive perception platform that helps visually impaired individuals comprehend their immediate physical surroundings through natural-language voice guidance. 

Rather than simply outputting raw object bounding-box labels, the system perceives environmental context, spatial relationships (e.g., *"to your left"*, *"directly in front"*), and obstacles, communicating them through spoken voice output in selectable languages—initially **English** and **Telugu**.

---

## 3. Approved Technology Stack
* **Mobile Client**: Flutter (Targeting Android initially)
* **Backend API**: Python 3 + FastAPI (Asynchronous REST API)
* **AI Perception Engine**: Provider-Independent Architecture (Decoupled Vision-Language Model interface)
* **Voice Output**: Dual-language support (**English** and **Telugu**)
* **Client-Server Communication**: REST API (`POST /api/v1/perceive`)

---

## 4. Current Development Status
* **Phase**: Provider-Independent Perception Architecture (Phase 2 Completed)
* **Status**: 
  - Standardized `POST /api/v1/perceive` endpoint contract created and tested.
  - Decoupled `VisionProvider` abstract interface implemented with offline `MockVisionProvider`.
  - Canonical `StructuredScene` models distinguishing observed facts, inferred context, and unknown data.
  - Dedicated `AssistiveDescriptionService` with Strategy-based English and Telugu description builders.
  - Image validation pipeline (`ImageValidator`) ensuring format, size, and integrity.
  - Comprehensive unit test suite with 10 passing tests (100% pass rate).
  - Flutter accessibility UI verified with zero lint errors and passing widget tests.

---

## 5. Project Folder Structure

```
Vision Based Assistive Perception System/
├── backend/                              # Python FastAPI Backend
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                       # Application entrypoint & CORS setup
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── routes.py                 # Route aggregator
│   │   │   └── v1/
│   │   │       ├── __init__.py
│   │   │       └── endpoints/
│   │   │           ├── __init__.py
│   │   │           ├── health.py         # GET /health endpoint
│   │   │           ├── perception.py     # POST /api/v1/perceive endpoint
│   │   │           └── tts.py            # TTS endpoint (placeholder)
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── config.py                 # Pydantic Settings & environment variables
│   │   │   ├── errors.py                 # Error handling & custom exceptions
│   │   │   └── logging.py                # Structured logger configuration
│   │   └── services/
│   │       ├── __init__.py
│   │       ├── vision/                   # Vision pipeline
│   │       │   ├── models.py             # StructuredScene & PerceptionResponse models
│   │       │   ├── vision_provider.py    # Abstract VisionProvider interface
│   │       │   ├── mock_provider.py      # Offline mock vision provider for testing
│   │       │   ├── image_validator.py    # Image format, size, and integrity validator
│   │       │   └── orchestrator.py       # End-to-end perception pipeline orchestrator
│   │       ├── language/                 # Language & description generation
│   │       │   ├── description_builders.py # English & Telugu description strategies
│   │       │   ├── description_service.py  # Audio-optimized narrative generator
│   │       │   └── language_manager.py     # Language registry & validation
│   │       └── tts/                      # Text-to-Speech synthesis interface
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── test_health.py                # Health endpoint test suite
│   │   └── test_perceive.py              # Perception API test suite (10 test cases)
│   ├── .env.example                      # Configuration template (no hardcoded secrets)
│   └── requirements.txt                  # Python dependencies
│
├── mobile/                               # Flutter Mobile Client (Android)
│   ├── lib/
│   │   ├── main.dart                     # App entry point with AccessibleTheme
│   │   ├── core/
│   │   │   ├── accessibility/            # Sizing standards & TalkBack announcement helper
│   │   │   ├── audio/                    # Sound chimes & haptic feedback services
│   │   │   ├── constants/                # App colors (WCAG AAA) & API constants
│   │   │   ├── network/                  # dart:io HttpClient backend caller
│   │   │   └── theme/                    # High-contrast dark accessible theme
│   │   └── features/
│   │       ├── camera/                   # Camera & capture service placeholders
│   │       ├── language/                 # English/Telugu language model & service
│   │       ├── perception/               # Models, accessible touch cards, & screen
│   │       ├── tts/                      # Mobile TTS service placeholder
│   │       └── voice_command/            # Mobile voice command service placeholder
│   ├── test/
│   │   └── widget_test.dart              # Accessibility widget test suite
│   └── pubspec.yaml                      # Flutter dependencies
│
├── evaluation/                           # Evaluation & Benchmarking Suite
│   └── README.md                         # Benchmark criteria & latency metrics
│
├── docs/                                 # Architectural & Technical Documentation
│   └── architecture.md                   # System design & component breakdown
│
├── .gitignore                            # Excludes credentials, .env, build caches
└── README.md                             # Project overview and setup instructions
```

---

## 6. How to Run the FastAPI Backend

### Prerequisites
* Python 3.10+ (Current environment uses Python 3.14)

### Starting the Server
```bash
cd backend
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Running Backend Tests
```bash
cd backend
python -m pytest tests/
```

---

## 7. How to Run the Flutter Application

### Running Flutter Tests & Analysis
```bash
cd mobile
flutter analyze
flutter test
```
