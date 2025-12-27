//
//  AppOpenAdManager.swift
//
//  Created by Léo Combaret on 24/12/2025.
//

import GoogleMobileAds
import UIKit

class AppOpenAdManager: NSObject {
    static let shared = AppOpenAdManager()

    // Test ad unit ID for Interstitial (replace with production ID before release)
    // Production: ca-app-pub-3387787019583333/YOUR_PRODUCTION_ID
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"

    private var interstitialAd: InterstitialAd?
    private var isLoadingAd = false
    private var isShowingAd = false
    private var loadTime: Date?

    // Cooldown period in minutes before showing ad again
    private let adCooldownMinutes: Double = 1

    // UserDefaults key for tracking last ad shown time
    private let lastAdShownKey = "lastInterstitialShownTime"

    private override init() {
        super.init()
        print("📺 [Interstitial] Manager initialized")

        // Observe app becoming active to show ad
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        // Small delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.showAdIfAvailable()
        }
    }

    /// Check if the ad is ready to be shown
    var isAdAvailable: Bool {
        return interstitialAd != nil && wasLoadTimeLessThanNHoursAgo(4)
    }

    /// Load an interstitial ad
    func loadAd() {
        // Don't load if already loading or if we have a valid ad
        guard !isLoadingAd else {
            print("📺 [Interstitial] Already loading ad")
            return
        }

        guard !isAdAvailable else {
            print("📺 [Interstitial] Ad already available")
            return
        }

        isLoadingAd = true
        print("📺 [Interstitial] Loading ad...")

        let request = Request()
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            self?.isLoadingAd = false

            if let error = error {
                print("❌ [Interstitial] Failed to load: \(error.localizedDescription)")
                return
            }

            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            self?.loadTime = Date()
            print("✅ [Interstitial] Ad loaded successfully")
        }
    }

    /// Show the interstitial ad if available (only for free users)
    func showAdIfAvailable() {
        // Check if cooldown period has passed
        guard hasAdCooldownPassed() else {
            print("📺 [Interstitial] Ad cooldown not passed yet")
            return
        }

        // Check subscription status - only show for free users
        let subscriptionStatusRaw = UserDefaults.standard.string(forKey: "subscriptionStatus") ?? "Free"
        let isPremium = subscriptionStatusRaw == "Premium" || subscriptionStatusRaw == "Free Trial"

        guard !isPremium else {
            print("📺 [Interstitial] User is premium, skipping ad")
            return
        }

        guard !isShowingAd else {
            print("📺 [Interstitial] Ad is already being shown")
            return
        }

        guard isAdAvailable else {
            print("📺 [Interstitial] Ad not available, loading new one")
            loadAd()
            return
        }

        guard let ad = interstitialAd else {
            print("📺 [Interstitial] No ad to show")
            return
        }

        // Get the root view controller to present the ad
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ [Interstitial] No root view controller found")
            return
        }

        isShowingAd = true
        recordAdShownTime()
        print("📺 [Interstitial] Showing ad...")

        ad.present(from: rootViewController)
    }

    /// Check if the ad was loaded less than n hours ago
    private func wasLoadTimeLessThanNHoursAgo(_ hours: Int) -> Bool {
        guard let loadTime = loadTime else { return false }
        let timeIntervalBetweenNowAndLoadTime = Date().timeIntervalSince(loadTime)
        let hoursInSeconds = Double(hours) * 3600
        return timeIntervalBetweenNowAndLoadTime < hoursInSeconds
    }

    /// Check if the cooldown period has passed since the last ad was shown
    private func hasAdCooldownPassed() -> Bool {
        guard let lastShownTime = UserDefaults.standard.object(forKey: lastAdShownKey) as? Date else {
            // No ad shown yet, cooldown passed
            return true
        }
        let timeSinceLastAd = Date().timeIntervalSince(lastShownTime)
        let cooldownSeconds = adCooldownMinutes * 60
        let hasPassed = timeSinceLastAd >= cooldownSeconds

        if !hasPassed {
            let remainingMinutes = (cooldownSeconds - timeSinceLastAd) / 60
            print("📺 [Interstitial] Cooldown remaining: \(String(format: "%.1f", remainingMinutes)) minutes")
        }

        return hasPassed
    }

    /// Record the time when an ad was shown
    private func recordAdShownTime() {
        UserDefaults.standard.set(Date(), forKey: lastAdShownKey)
    }

    /// Reset the cooldown (for testing purposes)
    func resetCooldown() {
        UserDefaults.standard.removeObject(forKey: lastAdShownKey)
    }
}

// MARK: - FullScreenContentDelegate
extension AppOpenAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("📺 [Interstitial] Ad dismissed")
        isShowingAd = false
        interstitialAd = nil
        // Preload the next ad
        loadAd()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ [Interstitial] Failed to present: \(error.localizedDescription)")
        isShowingAd = false
        interstitialAd = nil
        // Try to load a new ad
        loadAd()
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("📺 [Interstitial] Ad will present")
    }
}
