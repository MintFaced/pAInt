//
//  ARViewController.swift
//  pAInt
//
//  Created by MintFace on 2026-01-05.
//  Copyright © 2026 MintFace. All rights reserved.
//

import UIKit
import ARKit
import AVFoundation

class ARViewController: UIViewController {

    // MARK: - Properties

    private var arView: ARSCNView!
    private var statusLabel: UILabel!
    private var soundButton: UIButton!
    private var updatesButton: UIButton!  // Check for new artworks
    private var emailButton: UIButton!     // Get email updates

    private var bundleLoader: BundleLoader!
    private var collection: NFTCollection?
    private var videoPlayers: [String: AVPlayer] = [:]
    private var videoNodes: [String: SKVideoNode] = [:]
    private var tokenLookup: [String: NFTToken] = [:] // Map trigger name -> token
    private var isMuted: Bool = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            NSLog("✅ Audio session configured for playback")
        } catch {
            NSLog("❌ Failed to configure audio session: \(error.localizedDescription)")
        }

        // Initialize BundleLoader and load Artificial Flowers collection
        bundleLoader = BundleLoader()
        collection = bundleLoader.loadCollection()

        setupUI()
        setupAR()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startARSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.059, green: 0.059, blue: 0.059, alpha: 1.0) // #0F0F0F

        // AR View
        arView = ARSCNView(frame: view.bounds)
        arView.delegate = self
        arView.automaticallyUpdatesLighting = true
        view.addSubview(arView)

        // Status Label - Enhanced styling
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Scanning for artwork..."
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        statusLabel.textAlignment = .center

        // Payne's grey background with subtle gradient effect
        statusLabel.backgroundColor = UIColor(red: 0.33, green: 0.31, blue: 0.36, alpha: 0.85) // #536878 with alpha
        statusLabel.layer.cornerRadius = 12
        statusLabel.layer.borderWidth = 1
        statusLabel.layer.borderColor = UIColor(white: 1.0, alpha: 0.15).cgColor
        statusLabel.clipsToBounds = true

        view.addSubview(statusLabel)

        // Sound Toggle Button - Enhanced styling
        soundButton = UIButton(type: .system)
        soundButton.translatesAutoresizingMaskIntoConstraints = false
        soundButton.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
        soundButton.tintColor = .white
        soundButton.backgroundColor = UIColor(red: 0.33, green: 0.31, blue: 0.36, alpha: 0.85) // #536878
        soundButton.layer.cornerRadius = 28
        soundButton.layer.borderWidth = 1
        soundButton.layer.borderColor = UIColor(white: 1.0, alpha: 0.15).cgColor

        // Add subtle shadow
        soundButton.layer.shadowColor = UIColor.black.cgColor
        soundButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        soundButton.layer.shadowOpacity = 0.3
        soundButton.layer.shadowRadius = 4

        soundButton.addTarget(self, action: #selector(toggleSound), for: .touchUpInside)
        view.addSubview(soundButton)

        // Updates Button - Check for new artworks
        updatesButton = UIButton(type: .system)
        updatesButton.translatesAutoresizingMaskIntoConstraints = false
        updatesButton.setImage(UIImage(systemName: "arrow.down.circle.fill"), for: .normal)
        updatesButton.tintColor = .white
        updatesButton.backgroundColor = UIColor(red: 0.33, green: 0.31, blue: 0.36, alpha: 0.85)
        updatesButton.layer.cornerRadius = 28
        updatesButton.layer.borderWidth = 1
        updatesButton.layer.borderColor = UIColor(white: 1.0, alpha: 0.15).cgColor
        updatesButton.layer.shadowColor = UIColor.black.cgColor
        updatesButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        updatesButton.layer.shadowOpacity = 0.3
        updatesButton.layer.shadowRadius = 4
        updatesButton.addTarget(self, action: #selector(checkForUpdates), for: .touchUpInside)
        view.addSubview(updatesButton)

        // Email Button - Get updates via email
        emailButton = UIButton(type: .system)
        emailButton.translatesAutoresizingMaskIntoConstraints = false
        emailButton.setImage(UIImage(systemName: "envelope.fill"), for: .normal)
        emailButton.tintColor = .white
        emailButton.backgroundColor = UIColor(red: 0.33, green: 0.31, blue: 0.36, alpha: 0.85)
        emailButton.layer.cornerRadius = 28
        emailButton.layer.borderWidth = 1
        emailButton.layer.borderColor = UIColor(white: 1.0, alpha: 0.15).cgColor
        emailButton.layer.shadowColor = UIColor.black.cgColor
        emailButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        emailButton.layer.shadowOpacity = 0.3
        emailButton.layer.shadowRadius = 4
        emailButton.addTarget(self, action: #selector(showEmailSignup), for: .touchUpInside)
        view.addSubview(emailButton)

        // Constraints
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            statusLabel.heightAnchor.constraint(equalToConstant: 44),

            soundButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            soundButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            soundButton.widthAnchor.constraint(equalToConstant: 56),
            soundButton.heightAnchor.constraint(equalToConstant: 56),

            updatesButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            updatesButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            updatesButton.widthAnchor.constraint(equalToConstant: 56),
            updatesButton.heightAnchor.constraint(equalToConstant: 56),

            emailButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            emailButton.leadingAnchor.constraint(equalTo: updatesButton.trailingAnchor, constant: 12),
            emailButton.widthAnchor.constraint(equalToConstant: 56),
            emailButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func setupAR() {
        arView.scene = SCNScene()
    }

    private func startARSession() {
        guard ARImageTrackingConfiguration.isSupported else {
            updateStatus("AR not supported on this device")
            return
        }

        let configuration = ARImageTrackingConfiguration()

        // Load reference images
        if let referenceImages = loadReferenceImages() {
            configuration.trackingImages = referenceImages
            configuration.maximumNumberOfTrackedImages = 10
        } else {
            updateStatus("No trigger images found")
            return
        }

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        updateStatus("Scanning for artwork...")
    }

    private func loadReferenceImages() -> Set<ARReferenceImage>? {
        var referenceImages = Set<ARReferenceImage>()

        // Load from Artificial Flowers collection
        guard let collection = collection else {
            NSLog("❌ No collection loaded")
            return nil
        }

        for token in collection.tokens {
            guard let imagePath = token.localImagePath else { continue }

            // Load image
            guard let image = UIImage(contentsOfFile: imagePath),
                  let cgImage = image.cgImage else { continue }

            // Use default physical width of 30cm (A4-ish size)
            let physicalWidth: CGFloat = 0.3

            // Create reference image
            let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: physicalWidth)
            let triggerName = "af_\(token.tokenId)"
            referenceImage.name = triggerName

            referenceImages.insert(referenceImage)

            // Store token for lookup
            tokenLookup[triggerName] = token

            NSLog("✅ Loaded trigger: \(token.name)")
        }

        // Fallback: Load test image from bundle if no collections
        if referenceImages.isEmpty {
            if let testImagePath = Bundle.main.path(forResource: "test_trigger", ofType: "jpg"),
               let testImage = UIImage(contentsOfFile: testImagePath),
               let cgImage = testImage.cgImage {

                let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.3)
                referenceImage.name = "test_trigger"
                referenceImages.insert(referenceImage)
            }
        }

        print("Loaded \(referenceImages.count) reference images for AR tracking")
        return referenceImages.isEmpty ? nil : referenceImages
    }

    // MARK: - Video Playback

    private func playVideo(for imageName: String, on anchor: ARAnchor, imageSize: CGSize) {
        // Get video path from token
        var videoURL: URL?

        if let token = tokenLookup[imageName], let videoPath = token.localVideoPath {
            // Use NFT collection video
            videoURL = URL(fileURLWithPath: videoPath)
        } else if let testVideoPath = Bundle.main.path(forResource: "test_video", ofType: "mp4") {
            // Fallback to test video
            videoURL = URL(fileURLWithPath: testVideoPath)
        }

        guard let videoURL = videoURL else {
            print("Video file not found for \(imageName)")
            return
        }

        // Create video player
        let player = AVPlayer(url: videoURL)
        player.isMuted = isMuted
        videoPlayers[imageName] = player

        // Create video node
        let videoNode = SKVideoNode(avPlayer: player)
        videoNode.size = CGSize(width: imageSize.width * 1000, height: imageSize.height * 1000) // Scale up for SpriteKit
        videoNode.position = CGPoint(x: videoNode.size.width / 2, y: videoNode.size.height / 2)
        videoNode.yScale = -1.0 // Flip video right-side up

        videoNodes[imageName] = videoNode

        // Create SpriteKit scene
        let spriteScene = SKScene(size: videoNode.size)
        spriteScene.scaleMode = .aspectFit
        spriteScene.addChild(videoNode)

        // Create plane geometry matching image aspect ratio
        let plane = SCNPlane(width: imageSize.width, height: imageSize.height)
        plane.firstMaterial?.diffuse.contents = spriteScene
        plane.firstMaterial?.isDoubleSided = true

        // Create plane node
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi / 2 // Rotate to lie flat
        planeNode.opacity = 0.95

        // Add to anchor
        if let anchorNode = arView.node(for: anchor) {
            anchorNode.addChildNode(planeNode)
        }

        // Play video with loop
        player.play()

        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        // Show artwork name if available
        let artworkName = tokenLookup[imageName]?.name ?? imageName
        updateStatus("\(artworkName)")
    }

    // MARK: - Actions

    @objc private func toggleSound() {
        isMuted.toggle()

        // Update all active players
        for player in videoPlayers.values {
            player.isMuted = isMuted
        }

        // Update button icon
        let iconName = isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        soundButton.setImage(UIImage(systemName: iconName), for: .normal)
    }

    // MARK: - Button Actions

    @objc private func checkForUpdates() {
        NSLog("🔍 Checking for artwork updates")
        updateStatus("Checking for new artworks...")
        updatesButton.isEnabled = false

        Task {
            do {
                let updateInfo = try await bundleLoader.checkForUpdates()

                await MainActor.run {
                    if let updateInfo = updateInfo {
                        // New artworks available!
                        let alert = UIAlertController(
                            title: "New Artworks Available!",
                            message: "\(updateInfo.newArtworksCount) new pieces have been added to the Artificial Flowers collection. Would you like to download them now?",
                            preferredStyle: .alert
                        )

                        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { [weak self] _ in
                            self?.updateStatus("Scanning for artwork...")
                            self?.updatesButton.isEnabled = true
                        })

                        alert.addAction(UIAlertAction(title: "Download", style: .default) { [weak self] _ in
                            self?.downloadUpdates(updateInfo)
                        })

                        present(alert, animated: true)
                    } else {
                        // Already up to date
                        updateStatus("Collection up to date ✓")
                        updatesButton.isEnabled = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                            self?.updateStatus("Scanning for artwork...")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    NSLog("❌ Update check failed: %@", error.localizedDescription)
                    updateStatus("Update check failed")
                    updatesButton.isEnabled = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.updateStatus("Scanning for artwork...")
                    }
                }
            }
        }
    }

    private func downloadUpdates(_ updateInfo: UpdateInfo) {
        updateStatus("Downloading new artworks...")

        Task {
            do {
                try await bundleLoader.downloadUpdates(updateInfo) { progress in
                    await MainActor.run {
                        self.updateStatus("Downloading \(Int(progress * 100))%...")
                    }
                }

                await MainActor.run {
                    updateStatus("Download complete! Reloading...")
                    // Reload collection and restart AR
                    collection = bundleLoader.loadCollection()
                    startARSession()
                    updatesButton.isEnabled = true

                    NSLog("✅ Updates downloaded and loaded")
                }
            } catch {
                await MainActor.run {
                    NSLog("❌ Download failed: %@", error.localizedDescription)
                    updateStatus("Download failed")
                    updatesButton.isEnabled = true
                }
            }
        }
    }

    @objc private func showEmailSignup() {
        NSLog("📧 Opening email signup")

        // Create a styled view controller for Google Forms
        let emailVC = EmailSignupViewController()
        emailVC.modalPresentationStyle = .formSheet
        present(emailVC, animated: true)
    }

    private func updateStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = text

            // Animate status label
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                self?.statusLabel.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    self?.statusLabel.transform = .identity
                }
            }
        }
    }

    // MARK: - Frame Border

    private func addFrameBorder(to node: SCNNode, imageSize: CGSize) {
        // Frame width is 5% of image width
        let frameWidth = imageSize.width * 0.05
        let frameDepth: CGFloat = 0.002 // 2mm depth for subtle 3D effect

        // Almost black frame color (deep charcoal)
        let frameMaterial = SCNMaterial()
        frameMaterial.diffuse.contents = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0) // Very dark grey, almost black
        frameMaterial.metalness.contents = 0.3 // Slight metallic sheen
        frameMaterial.roughness.contents = 0.7 // Matte finish

        let halfWidth = imageSize.width / 2
        let halfHeight = imageSize.height / 2

        // Create 4 frame sides

        // Top frame
        let topFrame = SCNBox(width: imageSize.width + (frameWidth * 2), height: frameDepth, length: frameWidth, chamferRadius: 0)
        topFrame.materials = [frameMaterial]
        let topNode = SCNNode(geometry: topFrame)
        topNode.position = SCNVector3(0, 0.001, -halfHeight - (frameWidth / 2))
        node.addChildNode(topNode)

        // Bottom frame
        let bottomFrame = SCNBox(width: imageSize.width + (frameWidth * 2), height: frameDepth, length: frameWidth, chamferRadius: 0)
        bottomFrame.materials = [frameMaterial]
        let bottomNode = SCNNode(geometry: bottomFrame)
        bottomNode.position = SCNVector3(0, 0.001, halfHeight + (frameWidth / 2))
        node.addChildNode(bottomNode)

        // Left frame
        let leftFrame = SCNBox(width: frameWidth, height: frameDepth, length: imageSize.height, chamferRadius: 0)
        leftFrame.materials = [frameMaterial]
        let leftNode = SCNNode(geometry: leftFrame)
        leftNode.position = SCNVector3(-halfWidth - (frameWidth / 2), 0.001, 0)
        node.addChildNode(leftNode)

        // Right frame
        let rightFrame = SCNBox(width: frameWidth, height: frameDepth, length: imageSize.height, chamferRadius: 0)
        rightFrame.materials = [frameMaterial]
        let rightNode = SCNNode(geometry: rightFrame)
        rightNode.position = SCNVector3(halfWidth + (frameWidth / 2), 0.001, 0)
        node.addChildNode(rightNode)
    }
}

// MARK: - ARSCNViewDelegate

extension ARViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }

        let referenceImage = imageAnchor.referenceImage
        let imageName = referenceImage.name ?? "unknown"
        let imageSize = referenceImage.physicalSize

        // Get artwork name if available
        let artworkName = tokenLookup[imageName]?.name ?? imageName

        print("Detected image: \(imageName)")
        updateStatus("\(artworkName)")

        // Add elegant frame border around the detected image
        addFrameBorder(to: node, imageSize: imageSize)

        // Play video on detected image
        DispatchQueue.main.async { [weak self] in
            self?.playVideo(for: imageName, on: anchor, imageSize: imageSize)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Handle tracking updates
        guard let imageAnchor = anchor as? ARImageAnchor else { return }

        if !imageAnchor.isTracked {
            let imageName = imageAnchor.referenceImage.name ?? "unknown"
            print("Tracking lost for: \(imageName)")

            // Stop video and remove player when tracking is lost
            if let player = videoPlayers[imageName] {
                player.pause()
                videoPlayers.removeValue(forKey: imageName)
                videoNodes.removeValue(forKey: imageName)
                NSLog("🛑 Stopped video for: \(imageName)")
            }

            // Reset status message
            updateStatus("Scanning for artwork...")
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        // Handle anchor removal
        guard let imageAnchor = anchor as? ARImageAnchor else { return }

        let imageName = imageAnchor.referenceImage.name ?? "unknown"
        print("Anchor removed for: \(imageName)")

        // Stop video and clean up
        if let player = videoPlayers[imageName] {
            player.pause()
            videoPlayers.removeValue(forKey: imageName)
            videoNodes.removeValue(forKey: imageName)
            NSLog("🛑 Removed video for: \(imageName)")
        }

        // Reset status message
        updateStatus("Scanning for artwork...")
    }
}
