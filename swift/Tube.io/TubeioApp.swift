//
//  Tube.ioApp.swift
//
//  Created by Léo Combaret on 26/11/2025.
//

internal import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency
import AVFoundation

@main
struct TubeioApp: App {
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
        // Configure audio session for background playback
        configureAudioSession()

        // Initialize background playback manager
        _ = BackgroundPlaybackManager.shared

        // Initialize Google Mobile Ads SDK
        MobileAds.shared.start { _ in
            // Load app open ad after SDK is ready
            AppOpenAdManager.shared.loadAd()
        }

        // Initialize AdBlockManager to start loading/caching filter lists
        _ = AdBlockManager.shared

        // Initialize free trial for new users
        Task { @MainActor in
            FreeTrialManager.shared.checkAndActivateTrial()
        }

        // Request App Tracking Transparency permission
        if #available(iOS 14.5, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("ATT Status: \(status.rawValue)")
                }
            }
        }

        // Swizzle UIHostingController to support all orientations
        swizzleHostingController()

        return true
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            try audioSession.setActive(true)
            print("🔊 [Audio] Audio session configured for background playback")
        } catch {
            print("❌ [Audio] Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func swizzleHostingController() {
        // Swizzle UIViewController's supportedInterfaceOrientations to always return all orientations
        let originalSelector = #selector(getter: UIViewController.supportedInterfaceOrientations)
        let swizzledSelector = #selector(UIViewController.swizzled_supportedInterfaceOrientations)

        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
            print("❌ [Swizzle] Failed to get methods")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
        print("✅ [Swizzle] UIViewController orientation swizzled to allow all orientations")
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

extension UIViewController {
    @objc func swizzled_supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
