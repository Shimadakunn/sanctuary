//
//  ContentView.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

import SwiftUI

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
                    }
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
                    webViewStore: browserManager.webViewStore
                )
            }
        }
        .statusBar(hidden: false)
    }
}

#Preview {
    ContentView()
}
