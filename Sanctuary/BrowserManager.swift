//
//  BrowserManager.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

internal import SwiftUI
import Combine

enum BrowserState {
    case home
    case browsing
}

class BrowserManager: ObservableObject {
    @Published var state: BrowserState = .home
    @Published var currentURL: URL?
    @Published var searchText: String = ""
    @Published var canGoBack: Bool = false
    @Published var currentTitle: String = "Sanctuary"

    let webViewStore = WebViewStore()
    let favoritesManager = FavoritesManager()
    let historyManager = HistoryManager()

    func navigateToURL(_ urlString: String) {
        print("🌐 [BrowserManager] navigateToURL called with: \(urlString)")
        var processedURL = urlString.trimmingCharacters(in: .whitespaces)

        if !processedURL.contains(".") && !processedURL.hasPrefix("http") {
            processedURL = "https://www.google.com/search?q=\(processedURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? processedURL)"
        } else if !processedURL.hasPrefix("http://") && !processedURL.hasPrefix("https://") {
            processedURL = "https://\(processedURL)"
        }

        if let url = URL(string: processedURL) {
            print("🌐 [BrowserManager] Processed URL: \(url.absoluteString)")
            currentURL = url
            state = .browsing
            searchText = ""
        }
    }

    func openQuickAccess(_ domain: String) {
        print("⚡ [BrowserManager] openQuickAccess called with: \(domain)")
        navigateToURL(domain)
    }

    func goBackToHome() {
        print("🏠 [BrowserManager] goBackToHome called - changing state to .home")
        state = .home
    }

    func handleSearch() {
        guard !searchText.isEmpty else { return }
        navigateToURL(searchText)
    }
}
