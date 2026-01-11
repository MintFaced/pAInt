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
            return "API key is missing. Please add it in Settings."
        }
    }
}

class EthereumService {

    // MARK: - Properties

    private let baseURL = "https://api.opensea.io/api/v2/chain/ethereum/contract"

    // MARK: - Initialization

    init(apiKey: String) {
        // OpenSea doesn't require API key for basic public reads
        NSLog("🔧 EthereumService initialized with OpenSea API")
    }

    // MARK: - Public Methods

    /// Fetch all NFTs from a contract address
    func fetchCollection(contractAddress: String) async throws -> NFTCollection {
        NSLog("🚀 fetchCollection called for: %@", contractAddress)

        guard isValidAddress(contractAddress) else {
            NSLog("❌ Invalid contract address format")
            throw EthereumError.invalidContractAddress
        }

        var allTokens: [NFTToken] = []
        var nextCursor: String? = nil
        var contractName: String = ""
        var contractSymbol: String? = nil
        var totalSupply: Int = 0
        var pageCount = 0
        let maxPages = 5  // Limit to 5 pages (~250 NFTs) for now

        repeat {
            pageCount += 1
            NSLog("📄 Fetching page %d", pageCount)

            let url = buildNFTsURL(contractAddress: contractAddress, cursor: nextCursor)

            NSLog("🌐 Making API request to: %@", url.absoluteString)

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                NSLog("📡 Response received")
                if let httpResponse = response as? HTTPURLResponse {
                    NSLog("   Status code: %d", httpResponse.statusCode)
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

                let openSeaResponse: OpenSeaNFTResponse
                do {
                    openSeaResponse = try JSONDecoder().decode(OpenSeaNFTResponse.self, from: data)
                    NSLog("✅ JSON decoded successfully")
                } catch {
                    NSLog("❌ JSON Decode Error: %@", error.localizedDescription)
                    if let responseString = String(data: data, encoding: .utf8) {
                        NSLog("❌ Failed to parse response: %@", responseString)
                    }
                    throw EthereumError.invalidResponse
                }

                NSLog("📦 Received %d NFTs from API", openSeaResponse.nfts.count)

                // Extract tokens
                for nft in openSeaResponse.nfts {
                    NSLog("🔍 Processing token #%@", nft.identifier)

                    if let token = parseNFTToken(from: nft) {
                        allTokens.append(token)
                        NSLog("   ✅ Added token")
                    } else {
                        NSLog("   ❌ Skipped (no image)")
                    }

                    // Get contract info from first NFT
                    if contractName.isEmpty {
                        contractName = nft.contract ?? "Unknown Collection"
                        // OpenSea doesn't provide symbol easily, extract from contract if needed
                    }
                }

                nextCursor = openSeaResponse.next

            } catch let error as EthereumError {
                throw error
            } catch {
                NSLog("❌ Network error: %@", error.localizedDescription)
                throw EthereumError.networkError(error)
            }

        } while nextCursor != nil && pageCount < maxPages

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

        let urlString = "\(baseURL)/\(contractAddress)/nfts/\(tokenId)"

        guard let url = URL(string: urlString) else {
            throw EthereumError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EthereumError.invalidResponse
        }

        let nft = try JSONDecoder().decode(OpenSeaNFT.self, from: data)
        return parseNFTToken(from: nft)
    }

    // MARK: - Private Methods

    private func buildNFTsURL(contractAddress: String, cursor: String?) -> URL {
        var urlString = "\(baseURL)/\(contractAddress)/nfts?limit=50"

        if let cursor = cursor {
            urlString += "&next=\(cursor)"
        }

        return URL(string: urlString)!
    }

    private func parseNFTToken(from nft: OpenSeaNFT) -> NFTToken? {
        // Get image URL from OpenSea's image_url field
        guard let imageURL = nft.image_url, !imageURL.isEmpty else {
            return nil // Skip NFTs without images
        }

        // Get animation URL (optional)
        let animationURL = nft.animation_url

        // Use display_image_url if available (usually better quality)
        let finalImageURL = nft.display_image_url ?? imageURL

        return NFTToken(
            tokenId: nft.identifier,
            name: nft.name ?? "Token #\(nft.identifier)",
            imageURL: normalizeURL(finalImageURL),
            animationURL: animationURL != nil ? normalizeURL(animationURL!) : nil,
            imageDetails: nil,
            animationDetails: nil,
            attributes: nil,
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
