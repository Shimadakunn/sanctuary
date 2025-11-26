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
                if let currentTab = browserManager.currentTab {
                    BrowserView(
                        url: currentTab.url,
                        canGoBack: $browserManager.canGoBack,
                        title: $browserManager.currentTitle,
                        onBack: {
                            browserManager.goBackToHome()
                        },
                        onShowTabs: {
                            browserManager.showTabs()
                        },
                        webViewStore: browserManager.webViewStore
                    )
                }

            case .tabs:
                TabsView(
                    tabs: $browserManager.tabs,
                    selectedTabIndex: $browserManager.selectedTabIndex,
                    searchText: $browserManager.searchText,
                    onSelectTab: { index in
                        browserManager.selectTab(index)
                    },
                    onNewTab: {
                        browserManager.createNewTab()
                    },
                    onCloseTab: { index in
                        browserManager.closeTab(index)
                    },
                    onSubmit: {
                        browserManager.handleSearch()
                    }
                )
            }
        }
        .statusBar(hidden: false)
    }
}

#Preview {
    ContentView()
}
