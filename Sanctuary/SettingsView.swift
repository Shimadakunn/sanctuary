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

    var body: some View {
        List {
            // Preferences Section
            Section(header: Text("Preferences")) {
                NavigationLink(destination: StartupPageView(favoritesManager: favoritesManager)) {
                    HStack {
                        Text("Launching App")
                        Spacer()
                        Text(getStartupPageTitle())
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // Privacy Section
            Section(header: Text("Privacy")) {
                Toggle(isOn: $appLockEnabled) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("App Lock")
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
                        Text("Clear Cache")
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
                        Text("Clear Cookies")
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
                        Text("Clear All Website Data")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }

            // About Section
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(getAppVersion())
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build")
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
                        Text("About Sanctuary")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will clear all cached images and files. This may improve privacy and free up storage space.")
        }
        .alert("Clear Cookies", isPresented: $showClearCookiesAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCookies()
            }
        } message: {
            Text("This will clear all cookies. You will be logged out of websites.")
        }
        .alert("Clear All Website Data", isPresented: $showClearAllDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllWebsiteData()
            }
        } message: {
            Text("This will clear all website data including cache, cookies, and local storage. You will be logged out of all websites.")
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
            return "Home"
        }

        // Find the favorite with matching URL
        if let favorite = favoritesManager.favorites.first(where: { $0.url == startupPageURL }) {
            return favorite.title
        }

        return "Home"
    }
}

#Preview {
    NavigationStack {
        SettingsView(favoritesManager: FavoritesManager())
    }
}
