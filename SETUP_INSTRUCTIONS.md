# Artificial Flowers AR Viewer - Setup Instructions

## ✅ What's Been Implemented

The app now loads your Artificial Flowers collection from bundled files instead of APIs:

- **Bundle Loading**: Artworks load from app bundle (no API keys needed!)
- **Email Signup**: Google Forms integration for collecting emails
- **Update System**: "Check for Latest Artworks" downloads new pieces from your server
- **AR Tracking**: Existing AR image tracking + video playback (unchanged)

## 📋 Next Steps

### 1. Add Your Artwork Files to Xcode

1. **Prepare your files** with these exact names:
   ```
   af_001.jpg   af_001.mp4
   af_002.jpg   af_002.mp4
   ...
   af_022.jpg   af_022.mp4
   ```

2. **Add to Xcode**:
   - Open `pAInt.xcodeproj` in Xcode
   - Create a folder in the project: Right-click `pAInt` → New Group → name it `ArtworkFiles`
   - Drag all 44 files (22 JPGs + 22 MP4s) into this folder
   - **Important**: Check "Copy items if needed" and select `pAInt` target

3. **Update manifest if needed**:
   - If you want different names/descriptions, edit `Resources/artificial_flowers.json`
   - Update the `name` and `description` fields for each artwork

### 2. Set Up Google Forms Email Collection

1. **Create Google Form**:
   - Go to [forms.google.com](https://forms.google.com)
   - Create new form titled "Artificial Flowers Updates"
   - Add an Email field (mark as required)
   - Optional: Add Name, Message fields

2. **Get embed URL**:
   - Click "Send" button → Click `< >` embed icon
   - Copy the URL from the iframe src (looks like: `https://docs.google.com/forms/d/e/[FORM_ID]/viewform?embedded=true`)

3. **Update app**:
   - Open `pAInt-iOS/pAInt/EmailSignupViewController.swift`
   - Replace line 21:
     ```swift
     private let googleFormURL = "YOUR_GOOGLE_FORM_URL_HERE"
     ```

### 3. Set Up Update Server (Optional - for "Check for Latest Artworks")

When you create new artworks, host them on your own server:

1. **Upload to your server**:
   ```
   https://your-domain.com/artificial_flowers/
   ├── manifest.json          (updated version)
   ├── af_023.jpg            (new artwork)
   ├── af_023.mp4
   ├── af_024.jpg
   └── af_024.mp4
   ```

2. **Update manifest.json** with:
   - Increment `version` number (e.g., from 1 to 2)
   - Add new artworks to the `artworks` array
   - Update `total_artworks` and `last_updated`

3. **Update app URL**:
   - Open `pAInt-iOS/pAInt/Services/BundleLoader.swift`
   - Replace line 29:
     ```swift
     private let updateURL = "https://your-domain.com/artificial_flowers/manifest.json"
     ```

## 🎨 UI Layout

The app now has:
- **Top**: Status label showing AR scanning state
- **Bottom Left**:
  - Download icon = Check for Latest Artworks
  - Envelope icon = Email Signup
- **Bottom Right**: Sound toggle (mute/unmute)

## 🧪 Testing

1. **Test Bundle Loading**:
   - Build and run the app
   - Check Console for: `🎨 Collection loaded: 22 artworks`
   - Should see `✅ Loaded trigger: Artificial Flower #1` (etc)

2. **Test AR Tracking**:
   - Print one of your JPG files (or display on another screen)
   - Point camera at it - video should play!

3. **Test Email Signup**:
   - Tap envelope button
   - Google Form should load with dark styling
   - Submit test email

4. **Test Updates**:
   - Tap download button
   - Should say "Already up to date" (or show new artworks if server is set up)

## 📝 Notes

- **File naming is strict**: Must be `af_001.jpg` through `af_022.jpg` (with leading zeros)
- **Video format**: MP4 works best for iOS
- **Image size**: Recommend 1024x1024px or larger for good AR tracking
- **Physical size**: AR assumes ~30cm (A4-ish) print size for tracking

## 🐛 Troubleshooting

**"No collection loaded"**:
- Check files are in the Xcode project AND target membership is checked
- Verify file names match exactly (case-sensitive!)

**Email form won't load**:
- Check internet connection
- Verify Google Form URL is correct and ends with `?embedded=true`
- Check form privacy settings (must be public)

**AR won't track**:
- Ensure JPG files are high quality
- Print artwork or display on bright screen
- Good lighting helps tracking

## 🚀 Ready to Build!

Once you've added the artwork files, the app should work end-to-end:
1. Pull latest code: `git pull origin claude/ar-image-trigger-app-0dFKR`
2. Add your 44 artwork files to Xcode
3. Build and run on iPhone
4. Point camera at your artwork!
