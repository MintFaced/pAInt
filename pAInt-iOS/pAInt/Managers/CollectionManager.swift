//
//  CollectionManager.swift
//  pAInt
//
//  Created by MintFace on 2026-01-06.
//  Copyright © 2026 MintFace. All rights reserved.
//

import Foundation

@MainActor
class CollectionManager: ObservableObject {

    // MARK: - Published Properties

    @Published var collections: [NFTCollection] = []
    @Published var isLoading = false
    @Published var downloadProgress: DownloadProgress?
    @Published var error: String?

    // MARK: - Private Properties

    private let ethereumService: EthereumService
    private let assetDownloader = AssetDownloader()
    private let storageURL: URL

    private let isPremium: Bool // TODO: Connect to IAP

    // MARK: - Initialization

    init(alchemyAPIKey: String, isPremium: Bool = false) {
        self.ethereumService = EthereumService(apiKey: alchemyAPIKey)
        self.isPremium = isPremium

        // Set up storage directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.storageURL = documentsPath.appendingPathComponent("pAInt/collections")

        // Create directory
        try? FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)

        // Load existing collections
        loadCollections()
    }

    // MARK: - Public Methods

    /// Import a new NFT collection
    func importCollection(contractAddress: String) async {
        guard !isLoading else { return }

        // Check if free tier limit reached
        if !isPremium && collections.count >= 1 {
            error = "Upgrade to Premium to add unlimited collections"
            return
        }

        isLoading = true
        error = nil

        do {
            // Step 1: Fetch collection metadata from Ethereum
            print("Fetching collection metadata...")
            let collection = try await ethereumService.fetchCollection(contractAddress: contractAddress)

            print("Found \(collection.tokens.count) NFTs in \(collection.name)")

            // Step 2: Download all assets
            print("Downloading assets...")
            let collectionDir = storageURL.appendingPathComponent(contractAddress.lowercased())

            let downloadedCollection = try await assetDownloader.downloadCollection(
                collection,
                to: collectionDir
            ) { [weak self] progress in
                await MainActor.run {
                    self?.downloadProgress = progress
                }
            }

            // Step 3: Save collection metadata
            try saveCollection(downloadedCollection, to: collectionDir)

            // Step 4: Add to loaded collections
            collections.append(downloadedCollection)

            print("Collection imported successfully!")

            isLoading = false
            downloadProgress = nil

        } catch let error as EthereumError {
            self.error = error.localizedDescription
            isLoading = false
            downloadProgress = nil
        } catch let error as DownloadError {
            self.error = error.localizedDescription
            isLoading = false
            downloadProgress = nil
        } catch {
            self.error = "Failed to import collection: \(error.localizedDescription)"
            isLoading = false
            downloadProgress = nil
        }
    }

    /// Delete a collection
    func deleteCollection(_ collection: NFTCollection) {
        // Remove from array
        collections.removeAll { $0.contractAddress == collection.contractAddress }

        // Delete from disk
        let collectionDir = storageURL.appendingPathComponent(collection.contractAddress)
        try? FileManager.default.removeItem(at: collectionDir)
    }

    /// Refresh a collection (re-download metadata and missing assets)
    func refreshCollection(_ collection: NFTCollection) async {
        // TODO: Implement refresh logic
        // - Fetch latest metadata
        // - Download any missing assets
        // - Update stored collection
    }

    /// Get all reference images for AR tracking
    func getAllReferenceImages() -> [(image: URL, tokenId: String, name: String)] {
        var referenceImages: [(URL, String, String)] = []

        for collection in collections {
            for token in collection.tokens {
                if let imagePath = token.localImagePath {
                    let imageURL = URL(fileURLWithPath: imagePath)
                    referenceImages.append((imageURL, token.tokenId, token.name))
                }
            }
        }

        return referenceImages
    }

    /// Find token by ID across all collections
    func findToken(tokenId: String) -> NFTToken? {
        for collection in collections {
            if let token = collection.tokens.first(where: { $0.tokenId == tokenId }) {
                return token
            }
        }
        return nil
    }

    // MARK: - Storage Methods

    private func saveCollection(_ collection: NFTCollection, to directory: URL) throws {
        let metadataURL = directory.appendingPathComponent("metadata.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(collection)
        try data.write(to: metadataURL)

        print("Saved collection metadata to \(metadataURL.path)")
    }

    private func loadCollections() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: storageURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for collectionDir in contents where collectionDir.hasDirectoryPath {
            let metadataURL = collectionDir.appendingPathComponent("metadata.json")

            guard let data = try? Data(contentsOf: metadataURL) else { continue }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let collection = try? decoder.decode(NFTCollection.self, from: data) {
                collections.append(collection)
                print("Loaded collection: \(collection.name) (\(collection.tokens.count) NFTs)")
            }
        }

        print("Loaded \(collections.count) collections from storage")
    }
}
