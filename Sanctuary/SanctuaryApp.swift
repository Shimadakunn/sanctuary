//
//  SanctuaryApp.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

import SwiftUI
import AVFoundation

@main
struct SanctuaryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure audio session for Picture-in-Picture and background playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ [Audio Session] Configured for PiP and background playback")
        } catch {
            print("❌ [Audio Session] Failed to configure: \(error.localizedDescription)")
        }
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard let window = window else {
            print("🔄 [Orientation] Window is nil - returning .portrait")
            return .portrait
        }

        let windowClassName = String(describing: type(of: window))
        print("🔄 [Orientation] Window class: \(windowClassName)")

        if windowClassName.contains("AVFullScreen") ||
           windowClassName.contains("PGHostedWindow") ||
           window.rootViewController?.presentedViewController?.description.contains("AVFullScreen") == true {
            print("🔄 [Orientation] Fullscreen video detected - returning .landscape")
            return .landscape
        }

        print("🔄 [Orientation] Normal window - returning .portrait")
        return .portrait
    }
}
