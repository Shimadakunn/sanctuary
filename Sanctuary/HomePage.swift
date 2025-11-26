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

    @State private var showManageView = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: {
                        showManageView = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }

                Spacer()

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                        ForEach(favoritesManager.favorites) { favorite in
                            FavoriteTile(
                                title: favorite.title,
                                url: favorite.url,
                                faviconURL: favorite.faviconURL
                            ) {
                                onQuickAccess(favorite.url)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }

                SearchBar(text: $searchText, onSubmit: onSubmit)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
            .sheet(isPresented: $showManageView) {
                ManageFavoritesView(favoritesManager: favoritesManager, isPresented: $showManageView)
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

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
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
    @Environment(\.editMode) private var editMode
    @State private var editingFavorite: FavoriteWebsite? = nil

    var body: some View {
        NavigationView {
            List {
                ForEach(favoritesManager.favorites) { favorite in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: favorite.faviconURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                            default:
                                Image(systemName: "globe")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(favorite.title)
                                .font(.system(size: 16, weight: .medium))
                            Text(favorite.url)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: {
                            editingFavorite = favorite
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 24))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .onMove { source, destination in
                    favoritesManager.moveFavorite(from: source, to: destination)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let favorite = favoritesManager.favorites[index]
                        favoritesManager.removeFavoriteById(id: favorite.id)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Manage Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
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
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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

struct SearchBar: View {
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 18))

            TextField("Search or enter website", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}
