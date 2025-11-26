//
//  FavoritesManager.swift
//  Sanctuary
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
        }
    }

    private func initializeDefaultFavorites() {
        let defaults = [
            ("YouTube", "https://m.youtube.com"),
            ("Anime", "https://9animetv.to/home")
        ]

        for (title, url) in defaults {
            addFavorite(title: title, url: url)
        }
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
}
