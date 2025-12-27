//
//  PremiumViews.swift
//
//  Created by Léo Combaret on 05/12/2025.
//

internal import SwiftUI

// MARK: - Premium Banner View
struct PremiumBannerView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Crown icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade to Premium".localized)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Ad-free, downloads & more")
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.7))
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(0.25),
                                Color.yellow.opacity(0.15)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.yellow.opacity(0.6))
                                .frame(height: 1)
                            Spacer()
                            Rectangle()
                                .fill(Color.yellow.opacity(0.6))
                                .frame(height: 1)
                        }
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Premium Modal View
struct PremiumModalView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.yellow.opacity(0.15),
                        Color.orange.opacity(0.1),
                        Color.adaptiveGroupedBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header with crown icon
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.yellow, Color.orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)

                                Image(systemName: "crown.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }

                            Text("Tube.io Premium".localized)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)

                            Text("Unlock the full experience".localized)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 32)

                        // Features list
                        VStack(spacing: 16) {
                            PremiumFeatureRow(
                                icon: "sparkles",
                                iconColor: .yellow,
                                title: "Ad-Free Experience".localized,
                                description: "Browse without interruptions".localized
                            )

                            PremiumFeatureRow(
                                icon: "arrow.down.circle.fill",
                                iconColor: .blue,
                                title: "Download Videos".localized,
                                description: "Save videos for offline viewing".localized
                            )

                            PremiumFeatureRow(
                                icon: "app.badge",
                                iconColor: .purple,
                                title: "Choose Launching App".localized,
                                description: "Set your favorite page as startup".localized
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                        Spacer()

                        // Purchase button
                        VStack(spacing: 12) {
                            Button(action: {
                                // TODO: Implement purchase logic
                                print("Purchase premium tapped")
                            }) {
                                HStack {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 18))

                                    Text("Get Premium".localized)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.yellow, Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(14)
                                .shadow(color: Color.orange.opacity(0.3), radius: 12, x: 0, y: 4)
                            }

                            // Terms and restore
                            HStack(spacing: 16) {
                                Button(action: {
                                    // TODO: Implement restore purchases
                                    print("Restore purchases tapped")
                                }) {
                                    Text("Restore Purchases".localized)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }

                                Text("•")
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    // TODO: Open terms
                                    print("Terms tapped")
                                }) {
                                    Text("Terms".localized)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
    }
}

// MARK: - Premium Feature Row
struct PremiumFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
            }

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.adaptiveCardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Color Extensions
extension Color {
    static var adaptivePremiumBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.15, alpha: 1.0)
                : UIColor.white
        })
    }

    static var adaptiveCardBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.2, alpha: 1.0)
                : UIColor.white
        })
    }

    static var adaptiveCrownBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.2, alpha: 0.6)
                : UIColor.white.withAlphaComponent(0.8)
        })
    }

    static var adaptiveCrownIcon: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.systemYellow
                : UIColor.systemOrange
        })
    }
}

// MARK: - Previews
#Preview("Premium Banner") {
    PremiumBannerView(onTap: {})
        .padding()
}

#Preview("Premium Modal") {
    PremiumModalView()
}
