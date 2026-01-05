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

    private var videoPlayers: [String: AVPlayer] = [:]
    private var videoNodes: [String: SKVideoNode] = [:]
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

        // Status Label
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Scanning for artwork..."
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = UIColor(white: 0, alpha: 0.5)
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        view.addSubview(statusLabel)

        // Sound Toggle Button
        soundButton = UIButton(type: .system)
        soundButton.translatesAutoresizingMaskIntoConstraints = false
        soundButton.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
        soundButton.tintColor = .white
        soundButton.backgroundColor = UIColor(white: 0, alpha: 0.5)
        soundButton.layer.cornerRadius = 25
        soundButton.addTarget(self, action: #selector(toggleSound), for: .touchUpInside)
        view.addSubview(soundButton)

        // Constraints
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            statusLabel.heightAnchor.constraint(equalToConstant: 40),

            soundButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            soundButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            soundButton.widthAnchor.constraint(equalToConstant: 50),
            soundButton.heightAnchor.constraint(equalToConstant: 50)
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
        // For prototype: Load from SampleAssets folder
        // In production, this will load from NFT collection data

        var referenceImages = Set<ARReferenceImage>()

        // Try to load test image from bundle
        if let testImagePath = Bundle.main.path(forResource: "test_trigger", ofType: "jpg", inDirectory: "SampleAssets"),
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
        guard let videoPath = Bundle.main.path(forResource: "test_video", ofType: "mp4", inDirectory: "SampleAssets") else {
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
