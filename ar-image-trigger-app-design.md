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
\`\`\`

### 8.2 NFT Metadata Standard
pAInt works with ERC-721 and ERC-1155 NFT collections on Ethereum. Expected metadata structure:

\`\`\`json
{
  "name": "Firmware for Nectar",
  "attributes": [
    {
      "trait_type": "Artist",
      "value": "MintFace",
      "display_type": "text"
    }
  ],
  "animation_details": {
    "bytes": 94612550,
    "format": "MP4",
    "duration": 15,
    "sha256": "78ebb93afa4e8074eaba29e17e01533f78e6f23558870da60612fcff7c89c478",
    "width": 2160,
    "height": 3840,
    "codecs": ["H.264", "AAC"]
  },
  "animation": "https://arweave.net/lRlPaR5nX59xe4Af4NptuWzPwrdFb1rZ9Re60fCRafs",
  "animation_url": "https://arweave.net/lRlPaR5nX59xe4Af4NptuWzPwrdFb1rZ9Re60fCRafs",
  "image_details": {
    "bytes": 14301427,
    "format": "JPEG",
    "sha256": "a621abf540dec099b62a7e0a6b07bd64ba64d69ee9f627cf23cb7c134d8f03bf",
    "width": 2374,
    "height": 4870
  },
  "image": "https://arweave.net/kBhMpeLgxV5HJCA5EZb_erMvyZgvVHiM2P1V9vGDHYE",
  "image_url": "https://arweave.net/kBhMpeLgxV5HJCA5EZb_erMvyZgvVHiM2P1V9vGDHYE"
}
\`\`\`

**Key fields:**
- \`image\` or \`image_url\`: Trigger image (JPEG from Arweave/IPFS)
- \`animation\` or \`animation_url\`: Video file (MP4 from Arweave/IPFS)
- \`name\`: NFT name (displayed when trigger found)
- \`attributes\`: Optional artist metadata

### 8.3 Collection Import Workflow
1. User pastes Ethereum contract address (0x...)
2. App queries Etherscan/Alchemy API to:
   - Validate contract exists
   - Detect ERC-721 or ERC-1155 standard
   - Fetch total supply (collection size)
3. App fetches metadata for all tokens in collection
4. Preview screen shows:
   - Collection name
   - Total NFTs found
   - Number with valid image + video pairs
   - Estimated download size
   - Warnings for any NFTs missing assets
5. User confirms download (all or selective)
6. Progress bar shows download status
7. Assets cached locally for offline use

**Fallback handling:**
- NFT missing video: Skip (use image-only as static trigger)
- Image unsuitable for AR tracking: Offer in-app camera to capture high-res photo of physical artwork
- Download failure: Retry with exponential backoff, show friendly error

### 8.4 Asset Specifications
**Trigger Images:**
- Format: JPEG, PNG
- Min resolution: 1024x1024px (higher is better for tracking)
- Max file size: 20MB
- Requirements for tracking: High contrast, rich detail, non-repetitive patterns

**Videos:**
- Format: MP4 (H.264 + AAC)
- Duration: 5-20 seconds typical
- File size: 30-60MB per video
- Resolution: 1080p-4K (scaled for device)
- Compression: Optimized for mobile playback

**Collection Bundle Size Estimate:**
- 35 NFTs = ~35 images (10-15MB each) + 35 videos (30-60MB each)
- Total: ~1.4-2.6GB per collection
- Premium users with multiple collections: 5-10GB typical

### 8.5 Content Storage Structure
\`\`\`
/Documents/pAInt/
  collections/
    [contractAddress]/
      metadata.json          # Collection info
      triggers.json          # Generated trigger library
      assets/
        [tokenId]_image.jpg  # Trigger images
        [tokenId]_video.mp4  # AR videos
        [tokenId]_custom.jpg # Optional user-captured image
  sample/
    artificial_flowers/      # Bundled demo collection
      metadata.json
      triggers.json
      assets/
        ...
  analytics/
    scan_events.json         # User-identifiable scan logs
  cache/
    downloaded_metadata/     # Cached API responses
\`\`\`

## 9) Branding & Visual Design

### 9.1 Brand Identity
- **Name:** pAInt by MintFace
- **Typography:** "pAInt" in Helvetica font (capital A and I)
- **Logo:** Cherry emoji 🍒 with 'A' in left cherry, 'I' in right cherry
- **Tagline:** "Animate your paintings with AI-generated NFTs"

### 9.2 Color Palette
- **Primary:** Luxury off-black (#0F0F0F)
- **Secondary:** Payne's grey (#536878, #3D4F5C)
- **Accent:** White highlights (#FFFFFF, #F5F5F5)
- **Theme:** Dark mode default
- **Neon accents:** Subtle cyberpunk touches (electric blue, magenta) for CTAs and highlights

### 9.3 UI Style
- **Aesthetic:** Tech-forward, cyberpunk-inspired, sophisticated and subtle
- **Typography:** Sans-serif (system fonts: SF Pro on iOS)
- **Visual language:** Minimal, futuristic, clean lines
- **Motion:** Smooth transitions, particle effects on trigger detection

### 9.4 App Icon
Cherry emoji 🍒 with stylized 'A' and 'I' letters integrated into each cherry sphere. Dark background with subtle gradient.

## 10) User Experience Flows

### 10.1 Onboarding (First Launch)
1. **Splash screen:** pAInt logo with cherry icon
2. **Permissions:** Request camera access
3. **Tutorial (3 screens):**
   - "Point your camera at artwork"
   - "Watch it come alive in AR"
   - "Collect and share NFT animations"
4. **Sample collection:** Auto-load "Artificial Flowers" demo collection
5. **Call to action:** "Scan your first artwork" → Camera view
6. **Hint overlay:** "Try scanning the sample image" (provide printable PDF)

### 10.2 Collection Management Flow
**Main screen tabs:**
- **Scan** (default): AR camera view
- **Collections**: List of imported collections
- **Settings**: Preferences and premium upgrade

**Import new collection:**
1. Collections tab → "+" button
2. Modal: "Enter NFT Contract Address"
3. Paste 0x... address
4. Loading: "Fetching collection..."
5. Preview: Collection name, NFT count, download size
6. Confirm: "Download [35] NFTs (~1.8 GB)"
7. Progress bar with cancel option
8. Success: "Ready to scan!" → Return to camera

**Collection list view:**
- Card layout with collection thumbnail grid
- Show: Name, NFT count, storage size
- Actions: View details, Refresh, Delete
- Search bar for filtering

### 10.3 AR Scanning Flow
1. **Camera active:** "Scanning for artwork..."
2. **Trigger detected:**
   - Corner highlights appear on detected image
   - Waterfall animation of 🎉 party hats and 🍒 cherries
   - NFT name overlay fades in
3. **Video playback:**
   - Video anchored to trigger image plane
   - Auto-play, looped
   - Sound toggle button (bottom right)
4. **Multiple triggers:** Each plays independently
5. **Tracking lost:**
   - Video continues for 3-5 seconds
   - If not reacquired: Fade out gracefully
6. **No collections loaded:**
   - Overlay: "No collections yet. Tap here to import your first NFT collection."

### 10.4 Custom Image Capture Flow
If NFT image unsuitable for tracking:
1. Warning in preview: "⚠️ Low tracking quality detected for [NFT name]"
2. Option: "Capture high-res photo of physical artwork"
3. Camera opens in high-res photo mode
4. User captures physical painting/print
5. Confirm: "Use this as trigger image?"
6. Saved as \`[tokenId]_custom.jpg\`, overrides default

## 11) Monetization & Premium Features

### 11.1 Free Tier
- 1 NFT collection loaded at a time
- Can swap collections (previous downloads deleted)
- Full AR scanning functionality
- Sample "Artificial Flowers" collection included
- Basic analytics (on-device only)

### 11.2 Premium Tier ($4.99 one-time IAP)
- Unlimited NFT collections loaded simultaneously
- Scan any trigger from any collection
- Priority support
- Early access to new features
- Collections persist (no deletion on swap)

### 11.3 Upgrade Prompt
- Triggered when user tries to import 2nd collection (free tier)
- Modal: "Unlock Unlimited Collections"
- Benefits list
- "Upgrade for $4.99" button
- Apple In-App Purchase flow

## 12) Technical Architecture

### 12.1 Platform Choice
**Primary:** iOS native (Swift + ARKit)
- Faster development for solo dev
- Better AR performance on iPhone
- ARKit's image tracking optimized for this use case

**Future:** Android (Kotlin + ARCore) if successful

### 12.2 Key Technologies
- **AR Framework:** ARKit (ARImageTrackingConfiguration)
- **Networking:** URLSession for API calls, async/await
- **Blockchain API:** Etherscan/Alchemy (user provides API key)
- **IPFS Gateway:** Public gateway (ipfs.io or Cloudflare IPFS)
- **Video Playback:** AVPlayer with VideoNode in SceneKit/RealityKit
- **Local Storage:** FileManager for asset caching, UserDefaults for settings
- **Analytics:** Custom on-device JSON logging
- **IAP:** StoreKit 2 for premium unlock

### 12.3 Core Components
1. **CollectionManager:** Fetch, parse, store NFT metadata
2. **ARSessionManager:** Handle AR session, image tracking, anchor management
3. **VideoPlayerManager:** Preload, play, sync videos with AR anchors
4. **AssetDownloader:** Download and cache images/videos from IPFS
5. **AnalyticsLogger:** Log scan events to local JSON
6. **IAPManager:** Handle premium purchase and entitlement

### 12.4 AR Implementation Details
- **ARImageTrackingConfiguration:** Track up to 100 reference images
- **Dynamic reference image loading:** Load trigger images from collection at runtime
- **Physical size estimation:** Use image_details.width/height for aspect ratio, default physical width 0.3m
- **Anchor management:** Create ARAnchor per detected trigger
- **Video rendering:** SceneKit plane with AVPlayer texture, or RealityKit VideoMaterial
- **Performance:** Limit simultaneous video playback to 3-4 for frame rate

## 13) Implementation Phases

### Phase 1: Core MVP (Weeks 1-2)
- [ ] Project setup: Xcode, ARKit, basic UI
- [ ] AR image tracking with single test image
- [ ] Video playback on detected plane
- [ ] Basic camera view UI

### Phase 2: NFT Integration (Weeks 3-4)
- [ ] Etherscan/Alchemy API integration
- [ ] Metadata parser for ERC-721/1155
- [ ] IPFS download manager
- [ ] Collection import flow

### Phase 3: Collection Management (Week 5)
- [ ] Collections list UI
- [ ] Local storage and caching
- [ ] Search and filtering
- [ ] Delete/refresh collections

### Phase 4: Premium & Polish (Week 6)
- [ ] In-app purchase integration
- [ ] Free vs premium tier logic
- [ ] Onboarding flow with sample collection
- [ ] Visual effects (corner highlights, emoji waterfall)

### Phase 5: Testing & Launch (Week 7-8)
- [ ] TestFlight beta testing
- [ ] Bug fixes and optimization
- [ ] App Store assets (screenshots, description)
- [ ] Privacy policy
- [ ] Submit for review

## 14) Risk & Mitigation

### 14.1 Technical Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| AR tracking fails on certain NFT images | High | Custom image capture fallback, validate before download |
| Large video files cause memory issues | Medium | Limit simultaneous playback, compressed formats, streaming |
| IPFS download slow/unreliable | Medium | Retry logic, multiple gateway fallbacks, progress feedback |
| Device compatibility (older iPhones) | Low | Require iOS 15+, ARKit 4.0+ (iPhone XS and newer) |

### 14.2 UX Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| Users don't understand NFT import flow | High | Clear onboarding, demo collection, help docs |
| Download sizes too large for mobile data | Medium | Wi-Fi warning, show size estimate, selective download |
| Tracking requires good lighting | Medium | "Move to better lit area" hints, tutorial |

### 14.3 Business Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| Low adoption by artists | High | Direct outreach, partnerships, showcase at NFT events |
| Premium conversion low | Medium | Clear value prop, trial collections, artist testimonials |
| Blockchain gas fees barrier | Low | App doesn't require transactions, read-only queries |

## 15) Analytics & Privacy

### 15.1 Tracked Events (On-Device Only)
\`\`\`json
{
  "userId": "device-uuid",
  "events": [
    {
      "timestamp": "2026-01-05T14:32:11Z",
      "eventType": "trigger_scanned",
      "collectionAddress": "0x...",
      "tokenId": "12",
      "nftName": "Firmware for Nectar",
      "scanDuration": 4.2,
      "videoPlayed": true
    }
  ]
}
\`\`\`

**User-identifiable data:**
- Device UUID (for unique user count)
- Collection addresses scanned
- Token IDs and names
- Timestamps

**Not tracked:**
- Location
- Personal information
- Network activity beyond app functionality

### 15.2 Privacy Policy
Standard Apple privacy policy required:
- Data collected: Scan events, device ID
- Storage: On-device only, not transmitted
- User control: Can clear analytics in Settings
- Camera: Used only for AR scanning, not recorded
- Third-party: Etherscan/Alchemy API calls (user provides keys)

## 16) Future Enhancements (Post-MVP)

### 16.1 Short-term (3-6 months)
- Android version (ARCore)
- Artist dashboard: See scan analytics for their collections
- Social sharing: Screenshot AR video, share to Instagram/Twitter
- Collection preview before download: Gallery view
- Selective NFT download: Choose specific tokens from collection
- Video quality options: HD vs compressed

### 16.2 Medium-term (6-12 months)
- Backend API for analytics aggregation
- Artist verification and featured collections
- In-app NFT marketplace integration (OpenSea links)
- AR effects library: Particles, transitions, filters
- Multi-language support
- Offline mode improvements

### 16.3 Long-term (12+ months)
- NFT ownership verification (connect wallet)
- Exclusive content for NFT holders
- Creator tools: Upload custom trigger images
- AR social features: Share sessions, collaborative viewing
- Integration with physical galleries (QR codes, beacons)
- Subscription model for artists (analytics, promotion)

## 17) Open Questions & Decisions

### 17.1 To Resolve Before Development
- [x] Blockchain: Ethereum confirmed
- [x] NFT standards: ERC-721 and ERC-1155
- [x] Pricing: $4.99 one-time IAP
- [x] Platform: iOS first, Android later
- [ ] **API key distribution:** How will users get Etherscan/Alchemy keys? In-app instructions? Pre-configured demo key?
- [ ] **Sample collection size:** How many NFTs in "Artificial Flowers"? 5-10 for quick demo?
- [ ] **Video auto-play sound:** Default muted or unmuted?

### 17.2 Design Decisions Needed
- [ ] Exact neon accent colors (hex codes)
- [ ] Icon design: Mockup needed for app icon with cherry + A/I letters
- [ ] Emoji waterfall animation: Duration, frequency, physics?
- [ ] Corner highlight style: Solid lines, dashed, glowing?

### 17.3 Technical Investigations
- [ ] RealityKit vs SceneKit for video rendering (performance comparison)
- [ ] IPFS gateway reliability: Test multiple providers
- [ ] ARKit image tracking limits: Max simultaneous tracked images in practice
- [ ] Video codec: H.264 vs HEVC for iOS (compatibility vs file size)

## 18) Success Metrics

### 18.1 MVP Launch Goals
- 50 beta testers via TestFlight
- 10 artist collections imported
- Average 5 scans per user per week
- < 5% crash rate
- App Store approval on first submission

### 18.2 3-Month Goals
- 500 active users
- 50 premium conversions (10% conversion rate)
- 100 NFT collections in the wild
- 4.5+ star App Store rating
- Featured artist showcase on social media

### 18.3 Key Performance Indicators
- **User retention:** Day 1, Day 7, Day 30
- **Collection import rate:** % of users who import ≥1 collection
- **Premium conversion:** Free → Paid %
- **Scan engagement:** Avg scans per user per session
- **Technical:** Crash-free rate, AR tracking success rate

## 19) Appendix

### 19.1 Example NFT Collections for Testing
1. **Artificial Flowers** (bundled sample)
2. **MintFace Geodetic Series** (if available)
3. Test collection with 5-10 diverse images (portraits, landscapes, abstract)

### 19.2 Resources & References
- [ARKit Image Tracking](https://developer.apple.com/documentation/arkit/arkit_in_ios/content_anchors/tracking_and_visualizing_images)
- [ERC-721 Standard](https://eips.ethereum.org/EIPS/eip-721)
- [ERC-1155 Standard](https://eips.ethereum.org/EIPS/eip-1155)
- [Arweave Documentation](https://docs.arweave.org/)
- [Etherscan API](https://docs.etherscan.io/)
- [Alchemy NFT API](https://docs.alchemy.com/reference/nft-api)

### 19.3 Design Assets Needed
- [ ] App icon (1024x1024)
- [ ] Logo variations (light/dark)
- [ ] Onboarding tutorial images
- [ ] App Store screenshots (6.5", 5.5" displays)
- [ ] Promotional artwork
- [ ] Sample collection: "Artificial Flowers" NFTs

---

**Document Version:** 1.0
**Last Updated:** 2026-01-05
**Author:** MintFace
**Status:** Ready for Implementation
