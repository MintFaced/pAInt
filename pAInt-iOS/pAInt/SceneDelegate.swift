//
//  SceneDelegate.swift
//  pAInt
//
//  Created by MintFace on 2026-01-05.
//  Copyright © 2026 MintFace. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Create full-screen window
        let window = UIWindow(windowScene: windowScene)
        window.frame = UIScreen.main.bounds

        NSLog("🪟 Window frame: \(window.frame)")
        NSLog("📱 Screen bounds: \(UIScreen.main.bounds)")

        let viewController = ARViewController()
        viewController.modalPresentationStyle = .fullScreen

        window.rootViewController = viewController
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
