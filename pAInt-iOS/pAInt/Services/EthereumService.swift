//
//  EthereumService.swift
//  pAInt
//
//  Created by MintFace on 2026-01-06.
//  Copyright © 2026 MintFace. All rights reserved.
//

import Foundation

enum EthereumError: Error {
    case invalidContractAddress
    case networkError(Error)
    case invalidResponse
    case noNFTsFound
    case apiKeyMissing

    var localizedDescription: String {
        switch self {
        case .invalidContractAddress:
            return "Invalid contract address. Please check and try again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .noNFTsFound:
            return "No NFTs found in this collection."
        case .apiKeyMissing:
            return "Alchemy API key is missing. Please add it in Settings."
        }
    }
}

class EthereumService {

    // MARK: - Properties

    private let alchemyAPIKey: String
    private let baseURL = "https://eth-mainnet.g.alchemy.com/nft/v3"

    // MARK: - Initialization

    init(apiKey: String) {
        self.alchemyAPIKey = apiKey
    }

    // MARK: - Public Methods

    /// Fetch all NFTs from a contract address
    func fetchCollection(contractAddress: String) async throws -> NFTCollection {
        guard isValidAddress(contractAddress) else {
            throw EthereumError.invalidContractAddress
        }

        var allTokens: [NFTToken] = []
        var pageKey: String? = nil
        var contractName: String = ""
        var contractSymbol: String? = nil
        var totalSupply: Int = 0

        repeat {
            let url = buildNFTsURL(contractAddress: contractAddress, pageKey: pageKey)

            NSLog("🌐 Making API request to: %@", url.absoluteString)

            let (data, response) = try await URLSession.shared.data(from: url)

            NSLog("📡 Response received")
            if let httpResponse = response as? HTTPURLResponse {
                NSLog("   Status code: %d", httpResponse.statusCode)
                NSLog("   Headers: %@", String(describing: httpResponse.allHeaderFields))
            }
            NSLog("   Data size: %d bytes", data.count)

            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                NSLog("   Raw response: %@", String(responseString.prefix(500)))
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("❌ Response is not HTTPURLResponse")
                throw EthereumError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                NSLog("❌ HTTP Status code: %d", httpResponse.statusCode)
                if let errorString = String(data: data, encoding: .utf8) {
                    NSLog("❌ Error response: %@", errorString)
                }
                throw EthereumError.invalidResponse
            }

            let alchemyResponse: AlchemyNFTResponse
            do {
                alchemyResponse = try JSONDecoder().decode(AlchemyNFTResponse.self, from: data)
            } catch {
                NSLog("❌ JSON Decode Error: %@", error.localizedDescription)
                if let responseString = String(data: data, encoding: .utf8) {
                    NSLog("❌ Failed to parse response: %@", responseString)
                }
                throw EthereumError.invalidResponse
            }

            NSLog("📦 Received %d NFTs from API", alchemyResponse.nfts.count)

            // Extract tokens
            for nft in alchemyResponse.nfts {
                NSLog("🔍 Processing token #%@", nft.tokenId)
                NSLog("   - Has metadata: %d", nft.metadata != nil)
                NSLog("   - Has raw.metadata: %d", nft.raw?.metadata != nil)
                if let metadata = nft.metadata ?? nft.raw?.metadata {
                    NSLog("   - Image: %@", metadata.image ?? "nil")
                    NSLog("   - ImageUrl: %@", metadata.imageUrl ?? "nil")
                }

                if let token = parseNFTToken(from: nft) {
                    allTokens.append(token)
                    NSLog("   ✅ Added token")
                } else {
                    NSLog("   ❌ Skipped (no image)")
                }

                // Get contract info from first NFT
                if contractName.isEmpty {
                    contractName = nft.contract.name ?? "Unknown Collection"
                    contractSymbol = nft.contract.symbol
                    if let supply = nft.contract.totalSupply, let supplyInt = Int(supply) {
                        totalSupply = supplyInt
                    }
                }
            }

            pageKey = alchemyResponse.pageKey

        } while pageKey != nil

        // If totalSupply wasn't in contract info, use count
        if totalSupply == 0 {
            totalSupply = allTokens.count
        }

        NSLog("📊 Final result: %d valid tokens out of total processed", allTokens.count)

        guard !allTokens.isEmpty else {
            NSLog("❌ ERROR: No tokens with valid images found")
            throw EthereumError.noNFTsFound
        }

        return NFTCollection(
            contractAddress: contractAddress.lowercased(),
            name: contractName,
            symbol: contractSymbol,
            totalSupply: totalSupply,
            tokens: allTokens,
            downloadedAt: Date()
        )
    }

    /// Fetch metadata for a single token
    func fetchTokenMetadata(contractAddress: String, tokenId: String) async throws -> NFTToken? {
        guard isValidAddress(contractAddress) else {
            throw EthereumError.invalidContractAddress
        }

        let urlString = "\(baseURL)/\(alchemyAPIKey)/getNFTMetadata?contractAddress=\(contractAddress)&tokenId=\(tokenId)&refreshCache=false"

        guard let url = URL(string: urlString) else {
            throw EthereumError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EthereumError.invalidResponse
        }

        let nft = try JSONDecoder().decode(AlchemyNFT.self, from: data)
        return parseNFTToken(from: nft)
    }

    // MARK: - Private Methods

    private func buildNFTsURL(contractAddress: String, pageKey: String?) -> URL {
        var urlString = "\(baseURL)/\(alchemyAPIKey)/getNFTsForContract?contractAddress=\(contractAddress)&withMetadata=true&refreshCache=true"

        if let pageKey = pageKey {
            urlString += "&pageKey=\(pageKey)"
        }

        return URL(string: urlString)!
    }

    private func parseNFTToken(from nft: AlchemyNFT) -> NFTToken? {
        // Try metadata field first, then raw.metadata field
        guard let metadata = nft.metadata ?? nft.raw?.metadata else { return nil }

        // Get image URL
        guard let imageURL = metadata.finalImageURL, !imageURL.isEmpty else {
            return nil // Skip NFTs without images
        }

        // Get animation URL (optional)
        let animationURL = metadata.finalAnimationURL

        return NFTToken(
            tokenId: nft.tokenId,
            name: metadata.name ?? nft.title ?? "Token #\(nft.tokenId)",
            imageURL: normalizeURL(imageURL),
            animationURL: animationURL != nil ? normalizeURL(animationURL!) : nil,
            imageDetails: metadata.imageDetails,
            animationDetails: metadata.animationDetails,
            attributes: metadata.attributes,
            localImagePath: nil,
            localVideoPath: nil,
            localCustomImagePath: nil,
            imageSize: nil,
            videoSize: nil
        )
    }

    private func normalizeURL(_ urlString: String) -> String {
        // Convert IPFS URLs to HTTP gateway URLs
        if urlString.hasPrefix("ipfs://") {
            let hash = urlString.replacingOccurrences(of: "ipfs://", with: "")
            return "https://ipfs.io/ipfs/\(hash)"
        }

        // Arweave URLs are already HTTP
        return urlString
    }

    private func isValidAddress(_ address: String) -> Bool {
        // Ethereum addresses are 42 characters (0x + 40 hex chars)
        NSLog("🔍 Validating address: '%@'", address)
        NSLog("   - Length: %d (expected: 42)", address.count)
        NSLog("   - Has 0x prefix: %d", address.hasPrefix("0x"))

        guard address.count == 42 else {
            NSLog("   ❌ Invalid length")
            return false
        }
        guard address.hasPrefix("0x") else {
            NSLog("   ❌ Missing 0x prefix")
            return false
        }

        let hexChars = address.dropFirst(2)
        let isValidHex = hexChars.allSatisfy { $0.isHexDigit }
        NSLog("   - Is valid hex: %d", isValidHex)

        if !isValidHex {
            NSLog("   ❌ Contains non-hex characters")
        } else {
            NSLog("   ✅ Valid address")
        }

        return isValidHex
    }
}
