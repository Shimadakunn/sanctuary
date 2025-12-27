//
//  SubscriptionView.swift
//
//  Created by Léo Combaret on 05/12/2025.
//

internal import SwiftUI

enum SubscriptionStatus: String, CaseIterable {
    case freeTrial = "Free Trial"
    case free = "Free"
    case premium = "Premium"

    var displayName: String {
        switch self {
        case .freeTrial:
            return "Free Trial".localized
        case .free:
            return "Free".localized
        case .premium:
            return "Premium".localized
        }
    }

    var badgeColor: Color {
        switch self {
        case .freeTrial:
            return .blue
        case .free:
            return .gray
        case .premium:
            return .orange
        }
    }
}

struct SubscriptionView: View {
    @AppStorage("subscriptionStatus") private var subscriptionStatusRaw: String = SubscriptionStatus.free.rawValue

    private var subscriptionStatus: SubscriptionStatus {
        SubscriptionStatus(rawValue: subscriptionStatusRaw) ?? .free
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Current subscription status card
                VStack(spacing: 16) {
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
                            .frame(width: 80, height: 80)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)

                    Text("Your Subscription".localized)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)

                    // Status badge
                    HStack(spacing: 8) {
                        Circle()
                            .fill(subscriptionStatus.badgeColor)
                            .frame(width: 8, height: 8)

                        Text(subscriptionStatus.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(subscriptionStatus.badgeColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(subscriptionStatus.badgeColor.opacity(0.15))
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.adaptiveCardBackground)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Premium benefits section
                if subscriptionStatus != .premium {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Premium Benefits".localized)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)

                        VStack(spacing: 8) {
                            SubscriptionBenefitRow(
                                icon: "sparkles",
                                iconColor: .yellow,
                                title: "Ad-Free Experience".localized,
                                description: "Browse without interruptions".localized
                            )

                            SubscriptionBenefitRow(
                                icon: "arrow.down.circle.fill",
                                iconColor: .blue,
                                title: "Download Videos".localized,
                                description: "Save videos for offline viewing".localized
                            )

                            SubscriptionBenefitRow(
                                icon: "app.badge",
                                iconColor: .purple,
                                title: "Choose Launching App".localized,
                                description: "Set your favorite page as startup".localized
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Subscription info for premium users
                if subscriptionStatus == .premium {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("You're a Premium member!".localized)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Thank you for your support".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green.opacity(0.1))
                    )
                    .padding(.horizontal, 20)
                }

                Spacer()
                Spacer()

                // Subscribe button (only for non-premium users)
                if subscriptionStatus != .premium {
                    VStack(spacing: 12) {
                        Button(action: {
                            // TODO: Implement subscription logic
                            print("Subscribe tapped")
                        }) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 18))

                                Text("Subscribe for $1.99/month".localized)
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
                }

                // Manage subscription button for premium users
                if subscriptionStatus == .premium {
                    Button(action: {
                        // TODO: Open manage subscription
                        print("Manage subscription tapped")
                    }) {
                        Text("Manage Subscription".localized)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .background(Color.adaptiveGroupedBackground)
        .navigationTitle("Subscription".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subscription Benefit Row
struct SubscriptionBenefitRow: View {
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

#Preview("Subscription - Free") {
    NavigationStack {
        SubscriptionView()
    }
}

#Preview("Subscription - Premium") {
    NavigationStack {
        SubscriptionView()
    }
    .onAppear {
        UserDefaults.standard.set(SubscriptionStatus.premium.rawValue, forKey: "subscriptionStatus")
    }
}
