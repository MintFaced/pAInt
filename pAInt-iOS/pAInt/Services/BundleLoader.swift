//
//  BundleLoader.swift
//  pAInt
//
//  Loads Artificial Flowers collection from app bundle
//  Handles downloading new artworks from remote URL
//

import Foundation
import UIKit

// MARK: - Models

struct ArtworkManifest: Codable {
    let collection: CollectionInfo
    let artworks: [Artwork]

    struct CollectionInfo: Codable {
        let name: String
        let artist: String
        let description: String
        let website: String
        let total_artworks: Int
        let version: Int
        let last_updated: String
    }
}

struct Artwork: Codable {
    let id: String
    let name: String
    let image: String
    let video: String
    let description: String
}

// MARK: - Bundle Loader

class BundleLoader {

    // URL to check for updates (you'll host updated manifest + new files here)
    private let updateURL = "https://your-domain.com/artificial_flowers/manifest.json"

    private let fileManager = FileManager.default
    private let documentsDirectory: URL

    init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        NSLog("🎨 BundleLoader initialized")
    }

    // MARK: - Load Collection

    /// Load the Artificial Flowers collection from bundle
    func loadCollection() -> NFTCollection? {
        NSLog("📦 Loading Artificial Flowers from bundle")

        // Load manifest from bundle
        guard let manifestURL = Bundle.main.url(forResource: "artificial_flowers", withExtension: "json"),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(ArtworkManifest.self, from: data) else {
            NSLog("❌ Failed to load manifest from bundle")
            return nil
        }

        NSLog("✅ Loaded manifest: \(manifest.collection.name) v\(manifest.collection.version)")
        NSLog("   Artworks in manifest: \(manifest.artworks.count)")

        // Convert to NFTTokens
        var tokens: [NFTToken] = []
        var loadedIDs = Set<String>()

        // First, load artworks from manifest (these have proper names)
        for artwork in manifest.artworks {
            // Get paths to bundled files - extract filename and extension
            let imageFileName = (artwork.image as NSString).deletingPathExtension
            let imageExtension = (artwork.image as NSString).pathExtension
            let videoFileName = (artwork.video as NSString).deletingPathExtension
            let videoExtension = (artwork.video as NSString).pathExtension

            guard let imagePath = Bundle.main.path(forResource: imageFileName, ofType: imageExtension),
                  let videoPath = Bundle.main.path(forResource: videoFileName, ofType: videoExtension) else {
                NSLog("⚠️ Missing files for artwork #\(artwork.id) (\(artwork.image)) - skipping")
                continue
            }

            // Normalize ID to 3-digit format (e.g., "29" -> "029")
            let normalizedId = String(format: "%03d", Int(artwork.id) ?? 0)

            let token = NFTToken(
                tokenId: normalizedId,
                name: artwork.name,
                imageURL: "", // Not needed - using local files
                animationURL: nil,
                imageDetails: nil,
                animationDetails: nil,
                attributes: nil,
                localImagePath: imagePath,
                localVideoPath: videoPath,
                localCustomImagePath: nil,
                imageSize: nil,
                videoSize: nil
            )

            tokens.append(token)
            loadedIDs.insert(normalizedId)
            NSLog("   ✅ Loaded: \(artwork.name)")
        }

        // Now scan bundle for additional artworks (af_001 to af_050) not in manifest
        NSLog("🔍 Scanning bundle for additional artworks (af_001 to af_050)...")
        for i in 1...50 {
            let tokenId = String(format: "%03d", i) // Formats as "001", "002", etc.

            // Skip if already loaded from manifest
            if loadedIDs.contains(tokenId) {
                continue
            }

            // Try to find image file (jpg or png)
            let imageFileName = "af_\(tokenId)"
            var imagePath: String?
            var imageExtension: String?

            if let path = Bundle.main.path(forResource: imageFileName, ofType: "jpg") {
                imagePath = path
                imageExtension = "jpg"
            } else if let path = Bundle.main.path(forResource: imageFileName, ofType: "png") {
                imagePath = path
                imageExtension = "png"
            }

            // Try to find video file
            let videoFileName = "af_\(tokenId)"
            guard let foundImagePath = imagePath,
                  let videoPath = Bundle.main.path(forResource: videoFileName, ofType: "mp4") else {
                continue // Skip if image or video not found
            }

            // Found artwork not in manifest - use fallback name
            let fallbackName = "Artificial Flower #\(i)"

            let token = NFTToken(
                tokenId: tokenId,
                name: fallbackName,
                imageURL: "",
                animationURL: nil,
                imageDetails: nil,
                animationDetails: nil,
                attributes: nil,
                localImagePath: foundImagePath,
                localVideoPath: videoPath,
                localCustomImagePath: nil,
                imageSize: nil,
                videoSize: nil
            )

            tokens.append(token)
            loadedIDs.insert(tokenId)
            NSLog("   ✅ Auto-detected: af_\(tokenId).\(imageExtension!) (using fallback name: \(fallbackName))")
        }

        guard !tokens.isEmpty else {
            NSLog("❌ No valid artworks found")
            return nil
        }

        let collection = NFTCollection(
            contractAddress: "artificial-flowers", // Not a real contract
            name: manifest.collection.name,
            symbol: "AF",
            totalSupply: manifest.collection.total_artworks,
            tokens: tokens,
            downloadedAt: Date()
        )

        NSLog("🎨 Collection loaded: \(tokens.count) artworks")
        return collection
    }

    // MARK: - Check for Updates

    /// Check if new artworks are available from remote URL
    func checkForUpdates() async throws -> UpdateInfo? {
        NSLog("🔍 Checking for updates at: \(updateURL)")

        guard let url = URL(string: updateURL) else {
            throw UpdateError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            NSLog("❌ Update check failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw UpdateError.networkError
        }

        let remoteManifest = try JSONDecoder().decode(ArtworkManifest.self, from: data)

        // Load current bundle manifest to compare versions
        guard let bundleURL = Bundle.main.url(forResource: "artificial_flowers", withExtension: "json"),
              let bundleData = try? Data(contentsOf: bundleURL),
              let bundleManifest = try? JSONDecoder().decode(ArtworkManifest.self, from: bundleData) else {
            throw UpdateError.manifestError
        }

        NSLog("📊 Current version: \(bundleManifest.collection.version)")
        NSLog("📊 Remote version: \(remoteManifest.collection.version)")

        if remoteManifest.collection.version > bundleManifest.collection.version {
            let newCount = remoteManifest.artworks.count - bundleManifest.artworks.count
            NSLog("✨ Update available! \(newCount) new artworks")

            return UpdateInfo(
                newVersion: remoteManifest.collection.version,
                currentVersion: bundleManifest.collection.version,
                newArtworksCount: newCount,
                manifest: remoteManifest
            )
        } else {
            NSLog("✅ Already up to date")
            return nil
        }
    }

    /// Download new artworks from remote server
    func downloadUpdates(_ updateInfo: UpdateInfo, progressHandler: @escaping (Double) async -> Void) async throws {
        NSLog("⬇️ Downloading \(updateInfo.newArtworksCount) new artworks")

        // Get base URL (remove manifest.json from path)
        let baseURLString = updateURL.replacingOccurrences(of: "/manifest.json", with: "")

        // Create downloads directory
        let downloadsDir = documentsDirectory.appendingPathComponent("downloads")
        try? fileManager.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let totalFiles = updateInfo.newArtworksCount * 2 // image + video per artwork
        var downloadedFiles = 0

        // Download each new artwork
        for artwork in updateInfo.manifest.artworks {
            // Download image
            let imageURL = URL(string: "\(baseURLString)/\(artwork.image)")!
            let imageDest = downloadsDir.appendingPathComponent(artwork.image)

            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            try imageData.write(to: imageDest)
            downloadedFiles += 1
            await progressHandler(Double(downloadedFiles) / Double(totalFiles))
            NSLog("   ✅ Downloaded: \(artwork.image)")

            // Download video
            let videoURL = URL(string: "\(baseURLString)/\(artwork.video)")!
            let videoDest = downloadsDir.appendingPathComponent(artwork.video)

            let (videoData, _) = try await URLSession.shared.data(from: videoURL)
            try videoData.write(to: videoDest)
            downloadedFiles += 1
            await progressHandler(Double(downloadedFiles) / Double(totalFiles))
            NSLog("   ✅ Downloaded: \(artwork.video)")
        }

        // Save updated manifest
        let manifestData = try JSONEncoder().encode(updateInfo.manifest)
        let manifestDest = downloadsDir.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestDest)

        NSLog("✅ Download complete!")
    }
}

// MARK: - Update Models

struct UpdateInfo {
    let newVersion: Int
    let currentVersion: Int
    let newArtworksCount: Int
    let manifest: ArtworkManifest
}

enum UpdateError: Error {
    case invalidURL
    case networkError
    case manifestError

    var localizedDescription: String {
        switch self {
        case .invalidURL: return "Invalid update URL"
        case .networkError: return "Failed to check for updates"
        case .manifestError: return "Failed to read manifest"
        }
    }
}
