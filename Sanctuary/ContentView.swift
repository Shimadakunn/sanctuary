//
//  ContentView.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

internal import SwiftUI

struct ContentView: View {
    @StateObject private var browserManager = BrowserManager()

    var body: some View {
        ZStack {
            switch browserManager.state {
            case .home:
                HomePage(
                    searchText: $browserManager.searchText,
                    onSubmit: {
                        browserManager.handleSearch()
                    },
                    onQuickAccess: { domain in
                        browserManager.openQuickAccess(domain)
                    },
                    favoritesManager: browserManager.favoritesManager,
                    historyManager: browserManager.historyManager
                )

            case .browsing:
                BrowserView(
                    url: browserManager.currentURL,
                    canGoBack: $browserManager.canGoBack,
                    title: $browserManager.currentTitle,
                    onBack: {
                        browserManager.goBackToHome()
                    },
                    onGoHome: {
                        browserManager.goBackToHome()
                    },
                    webViewStore: browserManager.webViewStore,
                    favoritesManager: browserManager.favoritesManager,
                    historyManager: browserManager.historyManager
                )
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .statusBar(hidden: false)
    }
}

#Preview {
    ContentView()
}
