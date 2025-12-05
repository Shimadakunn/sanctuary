//
//  SanctuaryApp.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

internal import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct SanctuaryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("selectedTheme") private var selectedThemeRaw: String = AppTheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(getColorScheme())
        }
    }

    private func getColorScheme() -> ColorScheme? {
        let theme = AppTheme(rawValue: selectedThemeRaw) ?? .system
        return theme.colorScheme
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize Google Mobile Ads SDK
        MobileAds.shared.start(completionHandler: nil)

        // Initialize AdBlockManager to start loading/caching filter lists
        _ = AdBlockManager.shared

        // Request App Tracking Transparency permission
        if #available(iOS 14.5, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("ATT Status: \(status.rawValue)")
                }
            }
        }

        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard let window = window else {
            print("🔄 [Orientation] Window is nil - returning orientation lock: \(AppDelegate.orientationLock)")
            return AppDelegate.orientationLock
        }

        let windowClassName = String(describing: type(of: window))
        print("🔄 [Orientation] Window class: \(windowClassName), Orientation lock: \(AppDelegate.orientationLock)")

        // Check for web video fullscreen (for videos played in browser)
        if windowClassName.contains("AVFullScreen") ||
           windowClassName.contains("PGHostedWindow") ||
           window.rootViewController?.presentedViewController?.description.contains("AVFullScreen") == true {
            print("🔄 [Orientation] Fullscreen web video detected - returning .landscape")
            return .landscape
        }

        // Use the orientation lock set by video/audio players
        print("🔄 [Orientation] Returning orientation lock: \(AppDelegate.orientationLock)")
        return AppDelegate.orientationLock
    }
}
