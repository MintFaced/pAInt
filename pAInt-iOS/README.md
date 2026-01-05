# pAInt iOS Prototype

Quick AR prototype for image-triggered video playback using ARKit.

## What This Prototype Does

- ✅ Detects trigger images using ARKit image tracking
- ✅ Plays video overlaid on detected image
- ✅ Dark theme UI with status updates
- ✅ Sound toggle button
- ✅ Looping video playback
- ✅ Multi-trigger support

## Setup Instructions

### 1. Open in Xcode

```bash
cd pAInt-iOS
open pAInt.xcodeproj
```

If the project file doesn't exist, create a new Xcode project manually:

1. Open Xcode
2. Create New Project → iOS → App
3. Product Name: `pAInt`
4. Organization Identifier: `com.mintface`
5. Interface: `Storyboard` (we're using programmatic UI)
6. Language: `Swift`
7. Replace the generated files with the files in this directory

### 2. Add Required Assets

You need two test assets in the `SampleAssets` folder:

#### Test Trigger Image (`test_trigger.jpg`)
- High-resolution image (2000x2000px+)
- High contrast, detailed artwork
- Save as: `pAInt/SampleAssets/test_trigger.jpg`

**Quick test image options:**
- Use a painting, movie poster, or detailed photo
- Print it out (A4/Letter size) for testing
- **Important:** The image should have good detail and contrast for AR tracking

#### Test Video (`test_video.mp4`)
- MP4 format (H.264 + AAC)
- Duration: 5-20 seconds
- Save as: `pAInt/SampleAssets/test_video.mp4`

**Quick test video:**
- Any short MP4 video will work
- Ideally same aspect ratio as trigger image
- Keep file size under 50MB for testing

### 3. Project Configuration

In Xcode:

1. Select the project in navigator
2. Go to "Signing & Capabilities"
3. Select your Team (Apple Developer Account required)
4. Ensure Bundle Identifier is unique: `com.mintface.paint` or similar

### 4. Required Frameworks

The prototype uses these frameworks (should auto-link):
- ARKit
- SceneKit
- SpriteKit
- AVFoundation
- UIKit

### 5. Device Requirements

- iPhone XS or newer (ARKit 3.0+)
- iOS 15.0 or later
- Physical device (AR doesn't work in Simulator)

## Testing the Prototype

1. Build and run on your iPhone
2. Grant camera permission when prompted
3. Point camera at your printed trigger image
4. Video should appear overlaid on the image
5. Tap speaker button to toggle sound
6. Move camera around - video stays pinned to image

## Architecture (Prototype)

```
ARViewController.swift
├── setupUI() - Dark theme UI with status label and sound button
├── setupAR() - Initialize ARKit scene
├── startARSession() - Configure image tracking
├── loadReferenceImages() - Load trigger images
├── playVideo() - Create video plane on detected image
└── ARSCNViewDelegate - Handle image detection events
```

## Known Limitations (Prototype)

- Hardcoded test assets only
- No NFT integration yet
- No collection management
- Single trigger image only
- No tracking quality validation
- No custom image capture
- No analytics

## Next Steps

After validating this prototype works:

1. **Phase 2:** Add NFT collection support
2. **Phase 3:** Implement collection management UI
3. **Phase 4:** Add premium features and IAP
4. **Phase 5:** Polish and TestFlight

## Troubleshooting

### "AR not supported on this device"
- Use iPhone XS or newer
- Can't test in Simulator - need physical device

### "No trigger images found"
- Ensure `test_trigger.jpg` is in `pAInt/SampleAssets/`
- Add folder to Xcode project (drag into project navigator)
- Check "Copy items if needed" and "Create folder references"

### Video not playing
- Ensure `test_video.mp4` is in `pAInt/SampleAssets/`
- Check video codec is H.264 (not HEVC)
- Verify file isn't corrupted

### Tracking not working
- Ensure good lighting
- Print trigger image at least 15cm wide
- Use matte paper (not glossy)
- Image should have high detail and contrast

### Build errors
- Clean build folder (Cmd+Shift+K)
- Delete derived data
- Restart Xcode
- Check all files are added to target

## File Structure

```
pAInt-iOS/
├── pAInt.xcodeproj/
├── pAInt/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── ARViewController.swift
│   ├── Info.plist
│   ├── Assets.xcassets/
│   └── SampleAssets/
│       ├── test_trigger.jpg    (YOU ADD THIS)
│       └── test_video.mp4      (YOU ADD THIS)
└── README.md
```

## Quick Start with Sample Assets

Don't have test assets ready? Here's how to get started quickly:

1. **Test trigger image:** Download any high-res artwork from Unsplash or use a photo of a painting
2. **Test video:** Use any short screen recording or video clip
3. Print the trigger image on standard paper
4. Run the app and point at the printed image

---

**Built with:** Swift 5, ARKit, SceneKit
**Platform:** iOS 15+
**Device:** iPhone XS+ (ARKit 3.0 required)
**Author:** MintFace
**Date:** 2026-01-05
