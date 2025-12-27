//
//  AdMobBannerView.swift
//
//  Created on 29/11/2025.
//

internal import SwiftUI
import GoogleMobileAds

/// A SwiftUI wrapper for Google Mobile Ads banner ad view
struct AdMobBannerView: UIViewRepresentable {
    // MARK: - Properties

    /// The AdMob ad unit ID for this banner
    let adUnitID: String

    /// The size of the banner ad
    let adSize: AdSize

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator

        // Get the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootViewController
        }

        // Load the ad
        let request = Request()
        banner.load(request)

        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // No updates needed for static banner
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ [AdMob] Banner ad loaded successfully")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("❌ [AdMob] Banner ad failed to load: \(error.localizedDescription)")
        }

        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            print("ℹ️ [AdMob] Banner ad will present full screen")
        }

        func bannerViewDidDismissScreen(_ bannerView: BannerView) {
            print("ℹ️ [AdMob] Banner ad dismissed full screen")
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        AdMobBannerView(
            adUnitID: "ca-app-pub-3940256099942544/2435281174",  // Test ad unit
            adSize: AdSizeMediumRectangle
        )
        .frame(height: 250)
        .background(Color.gray.opacity(0.1))

        Spacer()
    }
}
