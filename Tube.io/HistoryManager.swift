//
//  HistoryManager.swift
//
//  Created by Léo Combaret on 26/11/2025.
//

import Foundation
import Combine
internal import SwiftUI

struct HistoryItem: Codable, Identifiable {
    let id: UUID
    var title: String
    var url: String
    var faviconURL: String
    let visitDate: Date

    init(title: String, url: String, faviconURL: String) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.faviconURL = faviconURL
        self.visitDate = Date()
    }
}

class HistoryManager: ObservableObject {
    @Published var history: [HistoryItem] = []

    private let userDefaultsKey = "savedHistory"
    private let maxHistoryItems = 1000

    init() {
        loadHistory()
    }

    func addHistoryItem(title: String, url: String) {
        // Don't add empty URLs or local pages
        guard !url.isEmpty,
              !url.hasPrefix("about:"),
              !url.hasPrefix("file:") else {
            return
        }

        // Don't add duplicate consecutive entries
        if let lastItem = history.first, lastItem.url == url {
            print("📜 [History] Skipped duplicate: \(title) - \(url)")
            return
        }

        let faviconURL = getFaviconURL(from: url)
        let historyItem = HistoryItem(title: title, url: url, faviconURL: faviconURL)

        // Add to the beginning of the list (most recent first)
        history.insert(historyItem, at: 0)

        // Limit history size
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }

        saveHistory()
        print("📜 [History] Added: \(title) - \(url)")
    }

    private func getFaviconURL(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return ""
        }
        return "https://www.google.com/s2/favicons?domain=\(host)&sz=64"
    }

    func removeHistoryItem(id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
        print("❌ [History] Removed item")
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
        print("🗑️ [History] Cleared all history")
    }

    func groupedHistory() -> [(String, [HistoryItem])] {
        let calendar = Calendar.current
        let now = Date()

        var grouped: [String: [HistoryItem]] = [:]

        for item in history {
            let key: String
            if calendar.isDateInToday(item.visitDate) {
                key = "Today"
            } else if calendar.isDateInYesterday(item.visitDate) {
                key = "Yesterday"
            } else if calendar.isDate(item.visitDate, equalTo: now, toGranularity: .weekOfYear) {
                key = "This Week"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                key = formatter.string(from: item.visitDate)
            }

            if grouped[key] == nil {
                grouped[key] = []
            }
            grouped[key]?.append(item)
        }

        // Sort sections
        let order = ["Today", "Yesterday", "This Week"]
        return grouped.sorted { first, second in
            if let firstIndex = order.firstIndex(of: first.key),
               let secondIndex = order.firstIndex(of: second.key) {
                return firstIndex < secondIndex
            }
            if order.contains(first.key) {
                return true
            }
            if order.contains(second.key) {
                return false
            }
            return first.key > second.key
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = decoded
            print("📚 [History] Loaded \(history.count) items")
        }
    }
}
