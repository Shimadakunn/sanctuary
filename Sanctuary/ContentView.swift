//
//  ContentView.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

internal import SwiftUI

struct ContentView: View {
    @StateObject private var browserManager = BrowserManager()
    @State private var isLocked = false
    @State private var isUnlocked = false
    @State private var previousScenePhase: ScenePhase = .active
    @State private var hasLaunchedStartupPage = false
    @AppStorage("startupPageURL") private var startupPageURL: String = ""
    @Environment(\.scenePhase) private var scenePhase

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

            if isLocked && !isUnlocked {
                AppLockView(isUnlocked: $isUnlocked)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .statusBar(hidden: false)
        .onAppear {
            checkLockStatus()
            launchStartupPage()
        }
        .onChange(of: isUnlocked) { _, newValue in
            if newValue {
                launchStartupPage()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Only re-lock when coming back from background
            if newPhase == .active && previousScenePhase == .background {
                if UserDefaults.standard.bool(forKey: "appLockEnabled") {
                    isUnlocked = false
                }
            }
            previousScenePhase = newPhase
        }
    }

    private func checkLockStatus() {
        let appLockEnabled = UserDefaults.standard.bool(forKey: "appLockEnabled")
        isLocked = appLockEnabled
        // Only set isUnlocked to false on initial load
        if appLockEnabled && !isUnlocked {
            isUnlocked = false
        }
    }

    private func launchStartupPage() {
        // Only launch startup page once and if not locked or already unlocked
        guard !hasLaunchedStartupPage else { return }
        guard !isLocked || isUnlocked else { return }

        hasLaunchedStartupPage = true

        // If startupPageURL is not empty, navigate to it immediately
        if !startupPageURL.isEmpty {
            browserManager.navigateToURL(startupPageURL)
            print("🚀 [Startup] Launched startup page: \(startupPageURL)")
        }
    }
}

#Preview {
    ContentView()
}
