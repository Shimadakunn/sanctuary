//
//  SanctuaryApp.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

internal import SwiftUI

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
