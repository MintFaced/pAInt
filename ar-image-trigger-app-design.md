# Design Doc: Image-Triggered AR Video Player (Artivive-style)

## 1) Summary
Build a mobile app that plays a specific video in augmented reality when the camera detects a matching "trigger" static image (e.g., a poster, painting label, postcard). The experience should feel instant and stable: user points camera at the trigger image, the app recognizes it, then overlays and pins the video onto the image plane.

## 2) Goals
1) Detect a trigger image in the live camera feed.
2) Match it against a known library of triggers (local-first; optional remote sync).
3) Once matched, place an AR plane aligned to the trigger image and play the associated video on it.
4) Maintain tracking so the video stays pinned to the trigger image as the camera moves.
5) Provide a simple content admin workflow (MVP: bundle triggers/videos; later: download/update).

## 3) Non-Goals (MVP)
1) Full creator marketplace / publishing platform.
2) Advanced 3D content (models, occlusion, relighting).
3) Multi-user shared AR sessions.
4) Heavy analytics beyond basic event logging.

## 4) Target Platforms
1) iOS (ARKit)
2) Android (ARCore)
Preferred approach: cross-platform engine for AR + tracking (Unity + AR Foundation), unless native is required.

## 5) Primary User Flow
1) User opens app.
2) App requests camera permission (and optionally motion permissions if needed).
3) "Scan" view opens immediately.
4) User points camera at artwork/print.
5) App recognizes trigger image.
6) App overlays video onto the detected image, aligned and scaled.
7) Video auto-plays muted/unmuted per settings (define default).
8) If trigger is lost, app either:
   8.1) pauses and waits to reacquire, or
   8.2) keeps last known placement for N seconds then hides.

## 6) UX Screens (MVP)
1) Scan Screen (default)
   - Camera view
   - Small status text: "Scanning…" / "Found: <name>" / "Move closer"
   - Optional: subtle reticle or corners overlay when found
   - Controls: Sound toggle, Help icon
2) Help / How to use
   - 3-step instructions with images
3) Settings (optional MVP)
   - Mute default
   - Download on Wi-Fi only (if remote content exists)
   - Clear cache
4) Debug (dev-only)
   - FPS, recognition confidence, current target id, tracking state

## 7) Core Functional Requirements

### 7.1 Trigger Recognition
1) Maintain a library of trigger images, each with:
   - id (string)
   - name (string)
   - reference image (high quality)
   - physical width (meters) OR "auto-scale" rules
   - associated video asset (local path or remote URL)
2) Recognize triggers in real-time camera feed.
3) Handle at least 25–100 triggers in MVP (scalable later).
4) Must work offline in MVP if assets are bundled.

### 7.2 AR Anchoring & Tracking
1) When a trigger is recognized, create an AR anchor on the detected image plane.
2) Create a rectangular plane mesh matching the image's aspect ratio.
3) Render video as a texture on that plane.
4) Maintain stable alignment while moving camera.

### 7.3 Video Playback
1) Auto-play on recognition.
2) Loop behavior configurable per trigger (default: loop).
3) Audio behavior configurable (default suggestion: muted until user taps sound).
4) Pause when tracking lost; resume when reacquired.
5) Pre-buffer video to reduce start latency.

### 7.4 Performance / Latency
1) Recognition-to-play target: < 1.0s in good conditions.
2) Maintain 30+ FPS on mid devices.
3) Use compressed video format (H.264 recommended for broad compatibility).

## 8) Content Model

### 8.1 Trigger Definition (JSON)
Example \`triggers.json\`:

\`\`\`json
{
  "version": 1,
  "triggers": [
    {
      "id": "mintface_geodetic_001",
      "name": "Geodetic Marker #001",
      "imageFile": "mintface_geodetic_001.jpg",
      "physicalWidthMeters": 0.42,
      "videoFile": "mintface_geodetic_001.mp4",
      "loop": true,
      "startMuted": true
    }
  ]
}
