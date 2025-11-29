//
//  HomePage.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

internal import SwiftUI
import UIKit

extension UIImage {
    func dominantColor() -> UIColor? {
        guard let cgImage = self.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var colorCounts: [UIColor: Int] = [:]

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = CGFloat(pixelData[offset]) / 255.0
                let g = CGFloat(pixelData[offset + 1]) / 255.0
                let b = CGFloat(pixelData[offset + 2]) / 255.0
                let a = CGFloat(pixelData[offset + 3]) / 255.0

                // Skip transparent pixels
                if a < 0.5 { continue }

                // Skip white, black, and gray colors
                let isWhite = r > 0.9 && g > 0.9 && b > 0.9
                let isBlack = r < 0.1 && g < 0.1 && b < 0.1
                let isGray = abs(r - g) < 0.1 && abs(g - b) < 0.1 && abs(r - b) < 0.1

                if isWhite || isBlack || isGray { continue }

                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                colorCounts[color, default: 0] += 1
            }
        }

        // Return the most common non-neutral color
        return colorCounts.max(by: { $0.value < $1.value })?.key
    }
}

struct HomePage: View {
    @Binding var searchText: String
    let onSubmit: () -> Void
    let onQuickAccess: (String) -> Void
    @ObservedObject var favoritesManager: FavoritesManager
    @ObservedObject var historyManager: HistoryManager

    @State private var showManageView = false
    @State private var showHistoryView = false
    @State private var showFilesView = false
    @State private var showSettingsView = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveGroupedBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Favorites Grid
                    HStack {
                        Spacer()
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                            ForEach(Array(favoritesManager.favorites.prefix(8))) { favorite in
                                FavoriteTile(
                                    title: favorite.title,
                                    url: favorite.url,
                                    faviconURL: favorite.faviconURL
                                ) {
                                    onQuickAccess(favorite.url)
                                }
                            }
                        }
                        .frame(maxWidth: 400)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)

                    // Action Buttons
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                        ActionButton(icon: "heart.fill", title: "Favorites") {
                            showManageView = true
                        }

                        ActionButton(icon: "clock.fill", title: "History") {
                            showHistoryView = true
                        }

                        ActionButton(icon: "folder.fill", title: "Files") {
                            showFilesView = true
                        }

                        ActionButton(icon: "gearshape.fill", title: "Settings") {
                            showSettingsView = true
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)

                    SearchBar(text: $searchText, onSubmit: onSubmit)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                .navigationDestination(isPresented: $showManageView) {
                    ManageFavoritesView(favoritesManager: favoritesManager, isPresented: $showManageView) { url in
                        showManageView = false
                        onQuickAccess(url)
                    }
                }
                .navigationDestination(isPresented: $showHistoryView) {
                    HistoryView(historyManager: historyManager) { url in
                        showHistoryView = false
                        onQuickAccess(url)
                    }
                }
                .navigationDestination(isPresented: $showFilesView) {
                    FilesView()
                }
                .navigationDestination(isPresented: $showSettingsView) {
                    SettingsView(favoritesManager: favoritesManager)
                }
            }
        }
    }
}

struct FavoriteTile: View {
    let title: String
    let url: String
    let faviconURL: String
    let action: () -> Void

    @State private var dominantColor: Color = Color.gray.opacity(0.15)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(dominantColor)
                        .frame(width: 60, height: 60)

                    if faviconURL.hasPrefix("sf:") {
                        let components = faviconURL.dropFirst(3).split(separator: ":")
                        if components.count == 2 {
                            let iconName = String(components[0])
                            let colorName = String(components[1])
                            Image(systemName: iconName)
                                .font(.system(size: 28))
                                .foregroundColor(colorFromString(colorName))
                                .onAppear {
                                    dominantColor = colorFromString(colorName).opacity(0.2)
                                }
                        }
                    } else {
                        AsyncImage(url: URL(string: faviconURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                    .onAppear {
                                        extractColor(from: image)
                                    }
                            case .failure:
                                Image(systemName: "globe")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                            @unknown default:
                                Image(systemName: "globe")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        case "mint": return .mint
        case "cyan": return .cyan
        default: return .blue
        }
    }

    private func extractColor(from image: Image) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = URL(string: faviconURL),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data),
               let significantColor = uiImage.dominantColor() {
                DispatchQueue.main.async {
                    var r: CGFloat = 0
                    var g: CGFloat = 0
                    var b: CGFloat = 0
                    var a: CGFloat = 0

                    significantColor.getRed(&r, green: &g, blue: &b, alpha: &a)

                    // Blend with white for a pastel effect
                    let pastelR = r + (1.0 - r) * 0.7
                    let pastelG = g + (1.0 - g) * 0.7
                    let pastelB = b + (1.0 - b) * 0.7

                    dominantColor = Color(red: pastelR, green: pastelG, blue: pastelB)
                }
            }
        }
    }
}

struct ManageFavoritesView: View {
    @ObservedObject var favoritesManager: FavoritesManager
    @Binding var isPresented: Bool
    let onNavigate: (String) -> Void
    @State private var editMode: EditMode = .inactive
    @State private var editingFavorite: FavoriteWebsite? = nil

    var body: some View {
        List {
            Section {
                ForEach(favoritesManager.favorites) { favorite in
                    let index = favoritesManager.favorites.firstIndex(where: { $0.id == favorite.id }) ?? 0

                    FavoriteListRowWithHeader(
                        favorite: favorite,
                        index: index,
                        isEditMode: editMode.isEditing,
                        onEdit: {
                            editingFavorite = favorite
                        },
                        onTap: {
                            if !editMode.isEditing {
                                onNavigate(favorite.url)
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
                }
                .onMove(perform: moveFavorite)
                .onDelete(perform: deleteFavorite)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(editMode.isEditing ? "Done" : "Edit") {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                }
            }
        }
        .sheet(item: $editingFavorite) { favorite in
            EditFavoriteDetailView(
                favorite: favorite,
                favoritesManager: favoritesManager
            )
        }
    }

    private func moveFavorite(from source: IndexSet, to destination: Int) {
        favoritesManager.moveFavorite(from: source, to: destination)
    }

    private func deleteFavorite(at indexSet: IndexSet) {
        indexSet.forEach { index in
            let favorite = favoritesManager.favorites[index]
            favoritesManager.removeFavoriteById(id: favorite.id)
        }
    }
}

struct FavoriteListRowWithHeader: View {
    let favorite: FavoriteWebsite
    let index: Int
    let isEditMode: Bool
    let onEdit: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if index == 0 {
                Text("SHOWN ON HOME")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }

            if index == 8 {
                Text("HIDDEN")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
            }

            FavoriteListRow(
                favorite: favorite,
                isEditMode: isEditMode,
                onEdit: onEdit,
                onTap: onTap
            )
        }
    }
}

struct FavoriteListRow: View {
    let favorite: FavoriteWebsite
    let isEditMode: Bool
    let onEdit: () -> Void
    let onTap: () -> Void
    @State private var dominantColor: Color = Color.gray.opacity(0.15)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(dominantColor)
                        .frame(width: 40, height: 40)

                    if favorite.faviconURL.hasPrefix("sf:") {
                        let components = favorite.faviconURL.dropFirst(3).split(separator: ":")
                        if components.count == 2 {
                            let iconName = String(components[0])
                            let colorName = String(components[1])
                            Image(systemName: iconName)
                                .font(.system(size: 18))
                                .foregroundColor(colorFromString(colorName))
                                .onAppear {
                                    dominantColor = colorFromString(colorName).opacity(0.2)
                                }
                        }
                    } else {
                        AsyncImage(url: URL(string: favorite.faviconURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                                    .onAppear {
                                        extractColor(from: image)
                                    }
                            default:
                                Image(systemName: "globe")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(favorite.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(favorite.url)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isEditMode {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 22))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        case "mint": return .mint
        case "cyan": return .cyan
        default: return .blue
        }
    }

    private func extractColor(from image: Image) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = URL(string: favorite.faviconURL),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data),
               let significantColor = uiImage.dominantColor() {
                DispatchQueue.main.async {
                    var r: CGFloat = 0
                    var g: CGFloat = 0
                    var b: CGFloat = 0
                    var a: CGFloat = 0

                    significantColor.getRed(&r, green: &g, blue: &b, alpha: &a)

                    // Blend with white for a pastel effect
                    let pastelR = r + (1.0 - r) * 0.7
                    let pastelG = g + (1.0 - g) * 0.7
                    let pastelB = b + (1.0 - b) * 0.7

                    dominantColor = Color(red: pastelR, green: pastelG, blue: pastelB)
                }
            }
        }
    }
}

struct EditFavoriteDetailView: View {
    let favorite: FavoriteWebsite
    @ObservedObject var favoritesManager: FavoritesManager
    @Environment(\.dismiss) private var dismiss
    @State private var editedTitle: String
    @State private var editedURL: String
    @State private var dominantColor: Color = Color.gray.opacity(0.15)

    init(favorite: FavoriteWebsite, favoritesManager: FavoritesManager) {
        self.favorite = favorite
        self.favoritesManager = favoritesManager
        _editedTitle = State(initialValue: favorite.title)
        _editedURL = State(initialValue: favorite.url)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(dominantColor)
                        .frame(width: 80, height: 80)

                    if favorite.faviconURL.hasPrefix("sf:") {
                        let components = favorite.faviconURL.dropFirst(3).split(separator: ":")
                        if components.count == 2 {
                            let iconName = String(components[0])
                            let colorName = String(components[1])
                            Image(systemName: iconName)
                                .font(.system(size: 40))
                                .foregroundColor(colorFromString(colorName))
                                .onAppear {
                                    dominantColor = colorFromString(colorName).opacity(0.2)
                                }
                        }
                    } else {
                        AsyncImage(url: URL(string: favorite.faviconURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                                    .onAppear {
                                        extractColor(from: image)
                                    }
                            default:
                                Image(systemName: "globe")
                                    .font(.system(size: 36))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .frame(height: 200)

                VStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("Title", text: $editedTitle)
                                .font(.system(size: 16))

                            if !editedTitle.isEmpty {
                                Button(action: {
                                    editedTitle = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 18))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.border, lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("URL")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("URL", text: $editedURL)
                                .font(.system(size: 16))
                                .autocapitalization(.none)
                                .keyboardType(.URL)

                            if !editedURL.isEmpty {
                                Button(action: {
                                    editedURL = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 18))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.border, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                Button(action: {
                    favoritesManager.updateFavorite(id: favorite.id, newTitle: editedTitle, newURL: editedURL)
                    dismiss()
                }) {
                    Text("Save")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("Edit Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        case "mint": return .mint
        case "cyan": return .cyan
        default: return .blue
        }
    }

    private func extractColor(from image: Image) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = URL(string: favorite.faviconURL),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data),
               let significantColor = uiImage.dominantColor() {
                DispatchQueue.main.async {
                    var r: CGFloat = 0
                    var g: CGFloat = 0
                    var b: CGFloat = 0
                    var a: CGFloat = 0

                    significantColor.getRed(&r, green: &g, blue: &b, alpha: &a)

                    let pastelR = r + (1.0 - r) * 0.7
                    let pastelG = g + (1.0 - g) * 0.7
                    let pastelB = b + (1.0 - b) * 0.7

                    dominantColor = Color(red: pastelR, green: pastelG, blue: pastelB)
                }
            }
        }
    }
}

struct QuickAccessTile: View {
    let title: String
    let url: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(color.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = "Search or enter website"
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.keyboardType = .webSearch
        searchBar.returnKeyType = .go
        searchBar.searchBarStyle = .minimal
        searchBar.enablesReturnKeyAutomatically = false
        searchBar.showsCancelButton = false
        return searchBar
    }

    func updateUIView(_ searchBar: UISearchBar, context: Context) {
        searchBar.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UISearchBarDelegate {
        let parent: SearchBar

        init(_ parent: SearchBar) {
            self.parent = parent
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            searchBar.setShowsCancelButton(true, animated: true)
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            parent.onSubmit()
            searchBar.setShowsCancelButton(false, animated: true)
            searchBar.resignFirstResponder()
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            searchBar.setShowsCancelButton(false, animated: true)
            searchBar.resignFirstResponder()
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.border, lineWidth: 2)
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HistoryView: View {
    @ObservedObject var historyManager: HistoryManager
    let onVisit: (String) -> Void
    @State private var searchText: String = ""

    private var filteredHistory: [(String, [HistoryItem])] {
        let grouped = historyManager.groupedHistory()

        if searchText.isEmpty {
            return grouped
        }

        return grouped.compactMap { section in
            let filteredItems = section.1.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.url.localizedCaseInsensitiveContains(searchText)
            }
            return filteredItems.isEmpty ? nil : (section.0, filteredItems)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                if filteredHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "clock" : "magnifyingglass")
                            .font(.system(size: 64))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(searchText.isEmpty ? "No History Yet" : "No Results")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "Sites you visit will appear here" : "Try a different search term")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredHistory, id: \.0) { section in
                        Section(header: Text(section.0)) {
                            ForEach(section.1) { item in
                                HistoryRow(item: item) {
                                    onVisit(item.url)
                                }
                            }
                            .onDelete { indexSet in
                                indexSet.forEach { index in
                                    let item = section.1[index]
                                    historyManager.removeHistoryItem(id: item.id)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            SearchBar(text: $searchText, onSubmit: {})
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !historyManager.history.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        historyManager.clearHistory()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    let onTap: () -> Void
    @State private var dominantColor: Color = Color.gray.opacity(0.15)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(dominantColor)
                        .frame(width: 48, height: 48)

                    AsyncImage(url: URL(string: item.faviconURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .onAppear {
                                    extractColor(from: image)
                                }
                        default:
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title.isEmpty ? (URL(string: item.url)?.host ?? item.url) : item.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(item.url)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(timeAgo(from: item.visitDate))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func extractColor(from image: Image) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = URL(string: item.faviconURL),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data),
               let significantColor = uiImage.dominantColor() {
                DispatchQueue.main.async {
                    var r: CGFloat = 0
                    var g: CGFloat = 0
                    var b: CGFloat = 0
                    var a: CGFloat = 0

                    significantColor.getRed(&r, green: &g, blue: &b, alpha: &a)

                    let pastelR = r + (1.0 - r) * 0.7
                    let pastelG = g + (1.0 - g) * 0.7
                    let pastelB = b + (1.0 - b) * 0.7

                    dominantColor = Color(red: pastelR, green: pastelG, blue: pastelB)
                }
            }
        }
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else if hours < 24 {
            return "\(hours)h"
        } else if days < 7 {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}
