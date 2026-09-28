# Google Gemini API Setup & Configuration Guide

This guide explains how the Vision-Based Assistive Perception System integrates with Google Gemini and how to configure your API key when you are ready to test with live cloud AI models.

---

## 1. What is the Gemini API?
The Google Gemini API provides programmatic access to Google's multimodal Vision-Language Models (VLMs). These models can simultaneously process visual information (images) and textual instructions, reasoning about spatial relationships, identifying objects, and generating structured representations.

---

## 2. Why Our Project Uses It
In an assistive perception system for visually impaired individuals, raw bounding-box object detectors (such as standard YOLO) only output isolated labels (e.g. `["person", "chair"]`). In contrast, Gemini:
* Understands **spatial relationships** (e.g., *"the chair is on your left, a table is in front"*).
* Comprehends **environmental context** (e.g., *"indoor corridor"*, *"crosswalk"*).
* Evaluates **immediate obstacles and hazards** in a single multimodal inference pass.
* Emits structured JSON strictly following our `StructuredScene` schema.

---

## 3. How to Create an Official Gemini API Key
Google provides free and pay-as-you-go API access through **Google AI Studio**:

1. Visit the official Google AI Studio website: [https://aistudio.google.com/](https://aistudio.google.com/)
2. Sign in with your standard Google Account.
3. Click on the **"Get API key"** button in the top navigation or left sidebar.
4. Click **"Create API key"**.
   * You can choose to create a key in a new Google Cloud project or select an existing project.
5. Copy the generated API key.
   > [!CAUTION]
   > Treat your API key like a password. Never share it publicly, never commit it to Git, and never post it in public repositories or chat transcripts.

---

## 4. Where the Key Should Be Stored
Your API key must be placed in a local `.env` file inside the `backend/` directory:

```
Vision Based Assistive Perception System/
└── backend/
    ├── .env          <-- Place your key here (never commit this file)
    └── .env.example  <-- Template committed to Git (contains NO real keys)
```

The `.env` file is already listed in `.gitignore` to prevent accidental commits.

---

## 5. How to Configure `GEMINI_API_KEY`
1. Navigate to the `backend/` directory.
2. If `.env` does not exist, copy `.env.example`:
   * **Windows (PowerShell)**:
     ```powershell
     Copy-Item .env.example .env
     ```
   * **Linux / macOS**:
     ```bash
     cp .env.example .env
     ```
3. Open `.env` in any text editor and paste your API key:
   ```env
   GEMINI_API_KEY=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
   ```
4. Save the file.

---

## 6. How to Configure `GEMINI_MODEL`
The default model configured in the system is `gemini-2.5-flash`, which is Google's recommended multimodal model for low-latency image understanding.

To change or experiment with other models (e.g., `gemini-1.5-flash`), adjust the `GEMINI_MODEL` line in your `.env` file:
```env
GEMINI_MODEL=gemini-2.5-flash
GEMINI_TIMEOUT_SECONDS=15.0
```
No changes to application Python code are needed.

---

## 7. How to Test the Backend After Adding the Key
1. Start the FastAPI backend server:
   ```powershell
   cd backend
   python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
   *You will see the startup log:*
   ```
   [INFO] [assistive_perception]: Vision Provider: GeminiVisionProvider (model='gemini-2.5-flash')
   ```
2. Send a test perception request using PowerShell:
   ```powershell
   curl.exe -X POST "http://localhost:8000/api/v1/perceive" `
     -F "image=@sample.jpg" `
     -F "language=en"
   ```
3. For Telugu output:
   ```powershell
   curl.exe -X POST "http://localhost:8000/api/v1/perceive" `
     -F "image=@sample.jpg" `
     -F "language=te"
   ```

---

## 8. What Happens When No Key is Configured
**The application will NOT crash.**

If `GEMINI_API_KEY` is empty, unset, or omitted:
* The backend automatically and safely selects `MockVisionProvider`.
* All API endpoints (`/health` and `/api/v1/perceive`) remain 100% operational for development and offline testing.
* Automated unit tests run completely offline without external network dependencies.

---

## 9. How to Remove or Rotate the Key
1. To disable live Gemini calls and return to mock mode:
   * Simply delete or comment out the `GEMINI_API_KEY` value in `.env`:
     ```env
     GEMINI_API_KEY=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
     ```
2. To rotate an expired or compromised key:
   * Delete the old key in [Google AI Studio](https://aistudio.google.com/).
   * Generate a new key and update `GEMINI_API_KEY=` in `.env`.
   * Restart the FastAPI server.
