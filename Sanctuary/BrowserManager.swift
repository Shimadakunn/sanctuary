//
//  BrowserManager.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

import SwiftUI
import Combine

enum BrowserState {
    case home
    case browsing
    case tabs
}

class BrowserManager: ObservableObject {
    @Published var state: BrowserState = .home
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTabIndex: Int = 0
    @Published var searchText: String = ""
    @Published var canGoBack: Bool = false
    @Published var currentTitle: String = "Sanctuary"

    let webViewStore = WebViewStore()

    var currentTab: BrowserTab? {
        guard selectedTabIndex < tabs.count else { return nil }
        return tabs[selectedTabIndex]
    }

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
            if tabs.isEmpty {
                tabs.append(BrowserTab(url: url, title: "Loading..."))
                selectedTabIndex = 0
            } else {
                tabs[selectedTabIndex].url = url
                tabs[selectedTabIndex].title = "Loading..."
            }
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

    func showTabs() {
        print("📑 [BrowserManager] showTabs called - changing state to .tabs")
        state = .tabs
    }

    func selectTab(_ index: Int) {
        selectedTabIndex = index
        state = .browsing
    }

    func createNewTab() {
        tabs.append(BrowserTab())
        selectedTabIndex = tabs.count - 1
        state = .home
    }

    func closeTab(_ index: Int) {
        guard tabs.count > 0 else { return }

        tabs.remove(at: index)

        if tabs.isEmpty {
            state = .home
            selectedTabIndex = 0
        } else {
            if selectedTabIndex >= tabs.count {
                selectedTabIndex = tabs.count - 1
            }
            if state == .browsing && tabs[selectedTabIndex].url == nil {
                state = .home
            }
        }
    }

    func handleSearch() {
        guard !searchText.isEmpty else { return }
        navigateToURL(searchText)
    }
}
