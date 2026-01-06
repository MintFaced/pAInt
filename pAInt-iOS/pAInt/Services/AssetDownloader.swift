//
//  AssetDownloader.swift
//  pAInt
//
//  Created by MintFace on 2026-01-06.
//  Copyright © 2026 MintFace. All rights reserved.
//

import Foundation
import UIKit

enum DownloadError: Error {
    case invalidURL
    case downloadFailed(Error)
    case saveFailed(Error)
    case invalidData

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid file URL"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Save failed: \(error.localizedDescription)"
        case .invalidData:
            return "Downloaded data is invalid"
        }
    }
}

actor AssetDownloader {

    // MARK: - Properties

    private let maxRetries = 3
    private let retryDelay: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds

    // MARK: - Download Methods

    /// Download and save an image
    func downloadImage(from urlString: String, to localPath: String) async throws -> Int64 {
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }

        let data = try await downloadWithRetry(url: url)

        // Validate it's an image
        guard UIImage(data: data) != nil else {
            throw DownloadError.invalidData
        }

        // Save to disk
        try saveFile(data: data, to: localPath)

        return Int64(data.count)
    }

    /// Download and save a video
    func downloadVideo(from urlString: String, to localPath: String) async throws -> Int64 {
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }

        let data = try await downloadWithRetry(url: url)

        // Save to disk
        try saveFile(data: data, to: localPath)

        return Int64(data.count)
    }

    /// Download entire collection assets
    func downloadCollection(
        _ collection: NFTCollection,
        to baseDirectory: URL,
        progressHandler: @Sendable @escaping (DownloadProgress) async -> Void
    ) async throws -> NFTCollection {

        var updatedTokens: [NFTToken] = []
        var progress = DownloadProgress(totalItems: collection.tokens.count * 2) // image + video per token

        // Create directories
        let assetsDir = baseDirectory.appendingPathComponent("assets")
        try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        for var token in collection.tokens {
            // Download image
            progress.currentItem = "\(token.name) (image)"
            await progressHandler(progress)

            let imagePath = assetsDir.appendingPathComponent("\(token.tokenId)_image.jpg").path
            do {
                let imageSize = try await downloadImage(from: token.imageURL, to: imagePath)
                token.localImagePath = imagePath
                token.imageSize = imageSize
                progress.downloadedBytes += imageSize
                progress.downloadedItems += 1
                await progressHandler(progress)
            } catch {
                print("Failed to download image for token \(token.tokenId): \(error)")
                // Continue even if image fails
            }

            // Download video (if exists)
            if let videoURL = token.animationURL {
                progress.currentItem = "\(token.name) (video)"
                await progressHandler(progress)

                let videoPath = assetsDir.appendingPathComponent("\(token.tokenId)_video.mp4").path
                do {
                    let videoSize = try await downloadVideo(from: videoURL, to: videoPath)
                    token.localVideoPath = videoPath
                    token.videoSize = videoSize
                    progress.downloadedBytes += videoSize
                    progress.downloadedItems += 1
                    await progressHandler(progress)
                } catch {
                    print("Failed to download video for token \(token.tokenId): \(error)")
                    // Continue even if video fails
                }
            } else {
                // No video, skip
                progress.downloadedItems += 1
                await progressHandler(progress)
            }

            updatedTokens.append(token)
        }

        // Create updated collection
        var updatedCollection = collection
        updatedCollection.tokens = updatedTokens

        return updatedCollection
    }

    // MARK: - Private Methods

    private func downloadWithRetry(url: URL) async throws -> Data {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw DownloadError.invalidURL
                }

                return data

            } catch {
                lastError = error

                // Exponential backoff
                if attempt < maxRetries - 1 {
                    let delay = retryDelay * UInt64(pow(2.0, Double(attempt)))
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw DownloadError.downloadFailed(lastError ?? NSError(domain: "Unknown", code: -1))
    }

    private func saveFile(data: Data, to path: String) throws {
        let url = URL(fileURLWithPath: path)

        // Create parent directory if needed
        let parentDir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        do {
            try data.write(to: url)
        } catch {
            throw DownloadError.saveFailed(error)
        }
    }
}
