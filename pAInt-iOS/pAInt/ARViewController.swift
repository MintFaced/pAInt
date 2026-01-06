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
import SpriteKit

class ARViewController: UIViewController {

    // MARK: - Properties

    private var arView: ARSCNView!
    private var statusLabel: UILabel!
    private var soundButton: UIButton!
    private var emojiOverlay: SKView!
    private var emojiScene: SKScene!

    private var videoPlayers: [String: AVPlayer] = [:]
    private var videoNodes: [String: SKVideoNode] = [:]
    private var cornerHighlights: [String: SCNNode] = [:]
    private var isMuted: Bool = true

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
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

        // Emoji Overlay (SpriteKit for particle effects)
        emojiOverlay = SKView(frame: view.bounds)
        emojiOverlay.backgroundColor = .clear
        emojiOverlay.isUserInteractionEnabled = false
        emojiScene = SKScene(size: view.bounds.size)
        emojiScene.backgroundColor = .clear
        emojiOverlay.presentScene(emojiScene)
        view.addSubview(emojiOverlay)

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

        // Add subtle shadow
        statusLabel.layer.shadowColor = UIColor.black.cgColor
        statusLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        statusLabel.layer.shadowOpacity = 0.3
        statusLabel.layer.shadowRadius = 4
        statusLabel.layer.masksToBounds = false

        view.addSubview(statusLabel)

        // Sound Toggle Button - Enhanced styling
        soundButton = UIButton(type: .system)
        soundButton.translatesAutoresizingMaskIntoConstraints = false
        soundButton.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
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

        // Constraints
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            statusLabel.heightAnchor.constraint(equalToConstant: 44),

            soundButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            soundButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            soundButton.widthAnchor.constraint(equalToConstant: 56),
            soundButton.heightAnchor.constraint(equalToConstant: 56)
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
        // For prototype: Load test image from bundle
        // In production, this will load from NFT collection data

        var referenceImages = Set<ARReferenceImage>()

        // Try to load test image from bundle
        if let testImagePath = Bundle.main.path(forResource: "test_trigger", ofType: "jpg"),
           let testImage = UIImage(contentsOfFile: testImagePath),
           let cgImage = testImage.cgImage {

            // Physical width of 0.3 meters (30cm) - adjust based on your test print
            let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.3)
            referenceImage.name = "test_trigger"
            referenceImages.insert(referenceImage)
        }

        return referenceImages.isEmpty ? nil : referenceImages
    }

    // MARK: - Video Playback

    private func playVideo(for imageName: String, on anchor: ARAnchor, imageSize: CGSize) {
        // Get video path
        guard let videoPath = Bundle.main.path(forResource: "test_video", ofType: "mp4") else {
            print("Video file not found")
            return
        }

        let videoURL = URL(fileURLWithPath: videoPath)

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
        ) { [weak self] _ in
            player.seek(to: .zero)
            player.play()
        }

        updateStatus("Playing: \(imageName)")
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

    // MARK: - Corner Highlights

    private func addCornerHighlights(to node: SCNNode, imageSize: CGSize) {
        let cornerLength: CGFloat = 0.05 // 5cm lines
        let cornerWidth: CGFloat = 0.003 // 3mm thickness
        let cornerHeight: CGFloat = 0.002

        // Create glowing material
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0) // Electric blue
        material.emission.contents = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.8)
        material.isDoubleSided = true

        let halfWidth = imageSize.width / 2
        let halfHeight = imageSize.height / 2

        // Corner positions (4 corners of the image)
        let corners: [(x: CGFloat, z: CGFloat, rotations: [(axis: SCNVector3, angle: CGFloat)])] = [
            // Top-left
            (x: -halfWidth, z: -halfHeight, rotations: [
                (SCNVector3(0, 1, 0), 0),
                (SCNVector3(0, 1, 0), .pi / 2)
            ]),
            // Top-right
            (x: halfWidth, z: -halfHeight, rotations: [
                (SCNVector3(0, 1, 0), 0),
                (SCNVector3(0, 1, 0), -.pi / 2)
            ]),
            // Bottom-left
            (x: -halfWidth, z: halfHeight, rotations: [
                (SCNVector3(0, 1, 0), .pi),
                (SCNVector3(0, 1, 0), .pi / 2)
            ]),
            // Bottom-right
            (x: halfWidth, z: halfHeight, rotations: [
                (SCNVector3(0, 1, 0), .pi),
                (SCNVector3(0, 1, 0), -.pi / 2)
            ])
        ]

        for corner in corners {
            for rotation in corner.rotations {
                let line = SCNBox(width: cornerLength, height: cornerHeight, length: cornerWidth, chamferRadius: 0)
                line.materials = [material]

                let lineNode = SCNNode(geometry: line)
                lineNode.position = SCNVector3(corner.x, 0.01, corner.z)
                lineNode.eulerAngles = SCNVector3(0, rotation.angle, 0)

                node.addChildNode(lineNode)

                // Animate glow
                let glowAction = SCNAction.sequence([
                    SCNAction.fadeOpacity(to: 0.3, duration: 0.8),
                    SCNAction.fadeOpacity(to: 1.0, duration: 0.8)
                ])
                lineNode.runAction(SCNAction.repeatForever(glowAction))
            }
        }
    }

    // MARK: - Emoji Waterfall

    private func triggerEmojiWaterfall() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Create party hat emojis
            self.createEmojiNode(emoji: "🎉", duration: 3.0)

            // Create cherry emojis (slightly delayed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.createEmojiNode(emoji: "🍒", duration: 3.0)
            }

            // Second wave
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.createEmojiNode(emoji: "🎉", duration: 3.0)
            }
        }
    }

    private func createEmojiNode(emoji: String, duration: TimeInterval) {
        let numberOfEmojis = 15
        let screenWidth = emojiScene.size.width
        let screenHeight = emojiScene.size.height

        for i in 0..<numberOfEmojis {
            let label = SKLabelNode(text: emoji)
            label.fontSize = CGFloat.random(in: 30...50)
            label.position = CGPoint(
                x: CGFloat.random(in: 0...screenWidth),
                y: screenHeight + 50
            )
            label.zRotation = CGFloat.random(in: -0.3...0.3)

            emojiScene.addChild(label)

            // Animate falling with rotation
            let fallDistance = screenHeight + 100
            let fallDuration = duration + Double.random(in: -0.5...0.5)
            let delay = Double(i) * 0.1

            let fall = SKAction.moveBy(x: CGFloat.random(in: -50...50), y: -fallDistance, duration: fallDuration)
            let rotate = SKAction.rotate(byAngle: CGFloat.random(in: -.pi...(2 * .pi)), duration: fallDuration)
            let fade = SKAction.fadeOut(withDuration: fallDuration * 0.3)
            let group = SKAction.group([fall, rotate])
            let sequence = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                group,
                SKAction.removeFromParent()
            ])

            label.run(sequence)

            // Add fade at the end
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + fallDuration * 0.7) {
                label.run(fade)
            }
        }
    }
}

// MARK: - ARSCNViewDelegate

extension ARViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }

        let referenceImage = imageAnchor.referenceImage
        let imageName = referenceImage.name ?? "unknown"
        let imageSize = referenceImage.physicalSize

        print("Detected image: \(imageName)")
        updateStatus("Found: \(imageName)")

        // Add corner highlights to the detected image
        addCornerHighlights(to: node, imageSize: imageSize)
        cornerHighlights[imageName] = node

        // Trigger emoji waterfall celebration
        triggerEmojiWaterfall()

        // Play video on detected image
        DispatchQueue.main.async { [weak self] in
            self?.playVideo(for: imageName, on: anchor, imageSize: imageSize)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Handle tracking updates
        guard let imageAnchor = anchor as? ARImageAnchor else { return }

        if !imageAnchor.isTracked {
            print("Tracking lost for: \(imageAnchor.referenceImage.name ?? "unknown")")
            // Video continues playing for 3-5 seconds (implement fade out logic if needed)
        }
    }
}
