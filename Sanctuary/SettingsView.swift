//
//  SettingsView.swift
//  Sanctuary
//
//  Created by Léo Combaret on 29/11/2025.
//

internal import SwiftUI
import WebKit

struct SettingsView: View {
    @ObservedObject var favoritesManager: FavoritesManager
    @State private var showClearCacheAlert = false
    @State private var showClearCookiesAlert = false
    @State private var showClearAllDataAlert = false
    @State private var appLockEnabled = UserDefaults.standard.bool(forKey: "appLockEnabled")
    @AppStorage("startupPageURL") private var startupPageURL: String = ""
    @AppStorage("selectedTheme") private var selectedThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("subscriptionStatus") private var subscriptionStatusRaw: String = SubscriptionStatus.free.rawValue

    var body: some View {
        List {
            // Subscription Section
            Section(header: Text("Subscription".localized)) {
                NavigationLink(destination: SubscriptionView()) {
                    HStack {
                        Text("Subscription".localized)
                        Spacer()
                        Text(getSubscriptionTitle())
                            .foregroundColor(getSubscriptionColor())
                            .lineLimit(1)
                    }
                }

                NavigationLink(destination: DevSubscriptionView()) {
                        Text("Dev Subscript".localized)
                }
            }

            // Preferences Section
            Section(header: Text("Preferences".localized)) {
                NavigationLink(destination: StartupPageView(favoritesManager: favoritesManager)) {
                    HStack {
                        Text("Launching App".localized)
                        Spacer()
                        Text(getStartupPageTitle())
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                NavigationLink(destination: ThemeView()) {
                    HStack {
                        Text("Theme".localized)
                        Spacer()
                        Text(getThemeTitle())
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // Privacy Section
            Section(header: Text("Privacy".localized)) {
                Toggle(isOn: $appLockEnabled) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("App Lock".localized)
                    }
                }
                .onChange(of: appLockEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "appLockEnabled")
                }

                Button(action: {
                    showClearCacheAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        Text("Clear Cache".localized)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }

                Button(action: {
                    showClearCookiesAlert = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        Text("Clear Cookies".localized)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }

                Button(action: {
                    showClearAllDataAlert = true
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        Text("Clear All Website Data".localized)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }

            // About Section
            Section(header: Text("About".localized)) {
                HStack {
                    Text("Version".localized)
                    Spacer()
                    Text(getAppVersion())
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build".localized)
                    Spacer()
                    Text(getBuildNumber())
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    // Open GitHub or website
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("About Sanctuary".localized)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear Cache".localized, isPresented: $showClearCacheAlert) {
            Button("Cancel".localized, role: .cancel) { }
            Button("Clear".localized, role: .destructive) {
                clearCache()
            }
        } message: {
            Text("Clear Cache Alert Message".localized)
        }
        .alert("Clear Cookies".localized, isPresented: $showClearCookiesAlert) {
            Button("Cancel".localized, role: .cancel) { }
            Button("Clear".localized, role: .destructive) {
                clearCookies()
            }
        } message: {
            Text("Clear Cookies Alert Message".localized)
        }
        .alert("Clear All Website Data".localized, isPresented: $showClearAllDataAlert) {
            Button("Cancel".localized, role: .cancel) { }
            Button("Clear".localized, role: .destructive) {
                clearAllWebsiteData()
            }
        } message: {
            Text("Clear All Website Data Alert Message".localized)
        }
    }

    private func clearCache() {
        let websiteDataTypes = Set([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
        let date = Date(timeIntervalSince1970: 0)

        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: date) {
            print("🗑️ [Settings] Cache cleared successfully")
        }
    }

    private func clearCookies() {
        let websiteDataTypes = Set([WKWebsiteDataTypeCookies])
        let date = Date(timeIntervalSince1970: 0)

        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: date) {
            print("🗑️ [Settings] Cookies cleared successfully")
        }
    }

    private func clearAllWebsiteData() {
        let websiteDataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let date = Date(timeIntervalSince1970: 0)

        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: date) {
            print("🗑️ [Settings] All website data cleared successfully")
        }
    }

    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private func getStartupPageTitle() -> String {
        if startupPageURL.isEmpty {
            return "Home".localized
        }

        // Check if it's the "Open Last App" option
        if startupPageURL == "LAST_APP" {
            return "Open Last App".localized
        }

        // Find the favorite with matching URL
        if let favorite = favoritesManager.favorites.first(where: { $0.url == startupPageURL }) {
            return favorite.title
        }

        return "Home".localized
    }

    private func getThemeTitle() -> String {
        let theme = AppTheme(rawValue: selectedThemeRaw) ?? .system
        return theme.displayName
    }

    private func getSubscriptionTitle() -> String {
        let status = SubscriptionStatus(rawValue: subscriptionStatusRaw) ?? .free
        return status.displayName
    }

    private func getSubscriptionColor() -> Color {
        let status = SubscriptionStatus(rawValue: subscriptionStatusRaw) ?? .free
        return status.badgeColor
    }
}

#Preview {
    NavigationStack {
        SettingsView(favoritesManager: FavoritesManager())
    }
}
