//
//  NFTMetadata.swift
//  pAInt
//
//  Created by MintFace on 2026-01-06.
//  Copyright © 2026 MintFace. All rights reserved.
//

import Foundation

// MARK: - NFT Metadata Models

struct NFTCollection: Codable {
    let contractAddress: String
    let name: String
    let symbol: String?
    let totalSupply: Int
    var tokens: [NFTToken]
    let downloadedAt: Date

    var storageSize: Int64 {
        tokens.reduce(0) { $0 + ($1.imageSize ?? 0) + ($1.videoSize ?? 0) }
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: storageSize)
    }
}

struct NFTToken: Codable {
    let tokenId: String
    let name: String
    let imageURL: String
    let animationURL: String?
    let imageDetails: ImageDetails?
    let animationDetails: AnimationDetails?
    let attributes: [NFTAttribute]?

    // Local file paths (set after download)
    var localImagePath: String?
    var localVideoPath: String?
    var localCustomImagePath: String? // User-captured high-res image

    var imageSize: Int64?
    var videoSize: Int64?

    var hasVideo: Bool {
        animationURL != nil && !animationURL!.isEmpty
    }

    var artist: String? {
        attributes?.first(where: { $0.traitType == "Artist" })?.value
    }
}

struct ImageDetails: Codable {
    let bytes: Int?
    let format: String?
    let width: Int?
    let height: Int?
    let sha256: String?

    var aspectRatio: Double? {
        guard let w = width, let h = height, h > 0 else { return nil }
        return Double(w) / Double(h)
    }
}

struct AnimationDetails: Codable {
    let bytes: Int?
    let format: String?
    let duration: Int?
    let width: Int?
    let height: Int?
    let codecs: [String]?
    let sha256: String?
}

struct NFTAttribute: Codable {
    let traitType: String
    let value: String
    let displayType: String?

    enum CodingKeys: String, CodingKey {
        case traitType = "trait_type"
        case value
        case displayType = "display_type"
    }
}

// MARK: - API Response Models

struct AlchemyNFTResponse: Codable {
    let nfts: [AlchemyNFT]
    let totalCount: Int?
    let pageKey: String?
}

struct AlchemyNFT: Codable {
    let tokenId: String
    let tokenType: String
    let title: String
    let description: String?
    let metadata: NFTMetadataRaw?
    let contract: ContractInfo

    struct ContractInfo: Codable {
        let address: String
        let name: String?
        let symbol: String?
        let totalSupply: String?
    }
}

struct NFTMetadataRaw: Codable {
    let name: String?
    let image: String?
    let imageUrl: String?
    let animation: String?
    let animationUrl: String?
    let imageDetails: ImageDetails?
    let animationDetails: AnimationDetails?
    let attributes: [NFTAttribute]?

    enum CodingKeys: String, CodingKey {
        case name
        case image
        case imageUrl = "image_url"
        case animation
        case animationUrl = "animation_url"
        case imageDetails = "image_details"
        case animationDetails = "animation_details"
        case attributes
    }

    var finalImageURL: String? {
        image ?? imageUrl
    }

    var finalAnimationURL: String? {
        animation ?? animationUrl
    }
}

// MARK: - Download Progress

struct DownloadProgress {
    let totalItems: Int
    var downloadedItems: Int = 0
    var currentItem: String = ""
    var totalBytes: Int64 = 0
    var downloadedBytes: Int64 = 0

    var percentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(downloadedItems) / Double(totalItems)
    }

    var formattedProgress: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let downloaded = formatter.string(fromByteCount: downloadedBytes)
        let total = formatter.string(fromByteCount: totalBytes)
        return "\(downloaded) / \(total)"
    }
}
