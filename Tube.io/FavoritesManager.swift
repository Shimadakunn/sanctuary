//
//  FavoritesManager.swift
//
//  Created by Léo Combaret on 26/11/2025.
//

import Foundation
import Combine
internal import SwiftUI

struct FavoriteWebsite: Codable, Identifiable {
    let id: UUID
    var title: String
    var url: String
    var faviconURL: String
    let dateAdded: Date

    init(title: String, url: String, faviconURL: String) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.faviconURL = faviconURL
        self.dateAdded = Date()
    }
}

class FavoritesManager: ObservableObject {
    @Published var favorites: [FavoriteWebsite] = []

    private let userDefaultsKey = "savedFavorites"

    init() {
        loadFavorites()
        if favorites.isEmpty {
            initializeDefaultFavorites()
        } else {
            // Migrate existing favorites to use localized titles
            migrateToLocalizedTitles()
        }
    }

    private func initializeDefaultFavorites() {
        let defaults: [(title: String, url: String, icon: String, color: String)] = [
            ("YouTube".localized, "https://m.youtube.com", "play.rectangle.fill", "red"),
            ("Movies/Shows".localized, "https://www.cineby.gd/", "film.fill", "purple"),
            ("Anime".localized, "https://9animetv.to/home", "sparkles.tv.fill", "pink"),
            ("Manga".localized, "https://mangafire.to/home", "book.fill", "orange"),
            ("Live Sports".localized, "https://sportyhunter.com/", "sportscourt.fill", "green"),
            ("Live TV".localized, "https://tv.garden/", "tv.fill", "blue"),
            ("eBooks".localized, "https://z-lib.gd/", "books.vertical.fill", "indigo"),
            ("Comics".localized, "https://readcomiconline.li/", "text.book.closed.fill", "yellow"),
        ]

        for (title, url, icon, color) in defaults {
            addDefaultFavorite(title: title, url: url, icon: icon, color: color)
        }
    }

    private func addDefaultFavorite(title: String, url: String, icon: String, color: String) {
        let faviconURL = "sf:\(icon):\(color)"
        let favorite = FavoriteWebsite(title: title, url: url, faviconURL: faviconURL)
        favorites.append(favorite)
        saveFavorites()
        print("⭐ [Favorites] Added default: \(title) - Icon: \(icon) Color: \(color)")
    }

    func addFavorite(title: String, url: String) {
        let faviconURL = getFaviconURL(from: url)
        let favorite = FavoriteWebsite(title: title, url: url, faviconURL: faviconURL)
        favorites.append(favorite)
        saveFavorites()
        print("⭐ [Favorites] Added: \(title) - \(url) - Favicon: \(faviconURL)")
    }

    private func getFaviconURL(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return ""
        }
        return "https://www.google.com/s2/favicons?domain=\(host)&sz=64"
    }

    func removeFavorite(url: String) {
        favorites.removeAll { $0.url == url }
        saveFavorites()
        print("❌ [Favorites] Removed: \(url)")
    }

    func updateFavorite(id: UUID, newTitle: String, newURL: String? = nil) {
        if let index = favorites.firstIndex(where: { $0.id == id }) {
            favorites[index].title = newTitle
            if let newURL = newURL {
                favorites[index].url = newURL
                favorites[index].faviconURL = getFaviconURL(from: newURL)
            }
            saveFavorites()
            print("✏️ [Favorites] Updated: \(newTitle)")
        }
    }

    func removeFavoriteById(id: UUID) {
        favorites.removeAll { $0.id == id }
        saveFavorites()
        print("❌ [Favorites] Removed by ID")
    }

    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
        print("🔄 [Favorites] Reordered")
    }

    func isFavorite(url: String?) -> Bool {
        guard let url = url else { return false }
        return favorites.contains { $0.url == url }
    }

    func toggleFavorite(title: String, url: String) {
        if isFavorite(url: url) {
            removeFavorite(url: url)
        } else {
            addFavorite(title: title, url: url)
        }
    }

    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([FavoriteWebsite].self, from: data) {
            favorites = decoded
            print("📚 [Favorites] Loaded \(favorites.count) favorites")
        }
    }

    private func migrateToLocalizedTitles() {
        // Map of URLs to their localization keys
        let urlToKeyMap: [String: String] = [
            "https://m.youtube.com": "YouTube",
            "https://www.cineby.gd/": "Movies/Shows",
            "https://9animetv.to/home": "Anime",
            "https://mangafire.to/home": "Manga",
            "https://sportyhunter.com/": "Live Sports",
            "https://tv.garden/": "Live TV",
            "https://z-lib.gd/": "eBooks",
            "https://readcomiconline.li/": "Comics"
        ]

        var needsUpdate = false

        for index in favorites.indices {
            if let localizedKey = urlToKeyMap[favorites[index].url] {
                let localizedTitle = localizedKey.localized
                // Only update if the title has changed
                if favorites[index].title != localizedTitle {
                    print("🔄 [Migration] Updating '\(favorites[index].title)' to '\(localizedTitle)'")
                    favorites[index].title = localizedTitle
                    needsUpdate = true
                }
            }
        }

        if needsUpdate {
            saveFavorites()
            print("✅ [Migration] Favorites titles updated to localized versions")
        }
    }
}
