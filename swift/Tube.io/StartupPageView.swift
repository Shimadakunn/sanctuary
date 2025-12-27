//
//  StartupPageView.swift
//
//  Created by Léo Combaret on 29/11/2025.
//

internal import SwiftUI

struct StartupPageView: View {
    @ObservedObject var favoritesManager: FavoritesManager
    @AppStorage("startupPageURL") private var startupPageURL: String = ""
    @AppStorage("subscriptionStatus") private var subscriptionStatusRaw: String = SubscriptionStatus.free.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var showPremiumModal = false

    private var subscriptionStatus: SubscriptionStatus {
        SubscriptionStatus(rawValue: subscriptionStatusRaw) ?? .free
    }

    private var isPremium: Bool {
        subscriptionStatus == .premium || subscriptionStatus == .freeTrial
    }

    var body: some View {
        List {
            Button(action: {
                startupPageURL = ""
                dismiss()
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: "house.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                    }

                    Text("Home".localized)
                        .foregroundColor(.primary)

                    Spacer()

                    if startupPageURL.isEmpty {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }

            if isPremium {
                Button(action: {
                    startupPageURL = "LAST_APP"
                    dismiss()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 40, height: 40)

                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 18))
                                .foregroundColor(.purple)
                        }

                        Text("Open Last App".localized)
                            .foregroundColor(.primary)

                        Spacer()

                        if startupPageURL == "LAST_APP" {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }

                ForEach(favoritesManager.favorites) { favorite in
                    Button(action: {
                        startupPageURL = favorite.url
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            FaviconView(faviconURL: favorite.faviconURL)

                            Text(favorite.title)
                                .foregroundColor(.primary)

                            Spacer()

                            if startupPageURL == favorite.url {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } else {
                // Premium feature locked for free users
                Button(action: {
                    showPremiumModal = true
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 40, height: 40)

                            Image(systemName: "crown.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Choose Launching App".localized)
                                .foregroundColor(.primary)
                                .font(.system(size: 16))
                            Text("Premium Feature".localized)
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                    }
                }
            }
        }
        .navigationTitle("Launching App".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPremiumModal) {
            PremiumModalView()
        }
    }
}

struct FaviconView: View {
    let faviconURL: String
    @State private var dominantColor: Color = Color.gray.opacity(0.15)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(dominantColor)
                .frame(width: 40, height: 40)

            if faviconURL.hasPrefix("sf:") {
                // SF Symbol with color
                let components = faviconURL.dropFirst(3).split(separator: ":")
                if components.count == 2 {
                    let iconName = String(components[0])
                    let colorName = String(components[1])
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundColor(getColor(from: colorName))
                        .onAppear {
                            dominantColor = getColor(from: colorName).opacity(0.2)
                        }
                }
            } else if !faviconURL.isEmpty {
                // Regular favicon
                AsyncImage(url: URL(string: faviconURL)) { phase in
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
            } else {
                // Fallback
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
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

    private func getColor(from name: String) -> Color {
        switch name.lowercased() {
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
        case "brown": return .brown
        default: return .blue
        }
    }
}

#Preview {
    NavigationStack {
        StartupPageView(favoritesManager: FavoritesManager())
    }
}
