//
//  DevSubscriptionView.swift
//
//  Created by Léo Combaret on 05/12/2025.
//

internal import SwiftUI

struct DevSubscriptionView: View {
    @AppStorage("subscriptionStatus") private var subscriptionStatusRaw: String = SubscriptionStatus.free.rawValue
    @Environment(\.dismiss) private var dismiss

    private var selectedStatus: SubscriptionStatus {
        SubscriptionStatus(rawValue: subscriptionStatusRaw) ?? .free
    }

    var body: some View {
        List {
            Section(header: Text("Development Testing".localized)) {
                ForEach(SubscriptionStatus.allCases, id: \.self) { status in
                    Button(action: {
                        subscriptionStatusRaw = status.rawValue
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            // Status icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(status.badgeColor.opacity(0.2))
                                    .frame(width: 40, height: 40)

                                Image(systemName: getIconName(for: status))
                                    .font(.system(size: 18))
                                    .foregroundColor(status.badgeColor)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(status.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)

                                Text(getDescription(for: status))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedStatus == status {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 22))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Text("This is a development tool to test different subscription states. Changes take effect immediately.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Dev Subscript".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func getIconName(for status: SubscriptionStatus) -> String {
        switch status {
        case .freeTrial:
            return "timer"
        case .free:
            return "gift"
        case .premium:
            return "crown.fill"
        }
    }

    private func getDescription(for status: SubscriptionStatus) -> String {
        switch status {
        case .freeTrial:
            return "Test trial period features"
        case .free:
            return "Test basic features with ads"
        case .premium:
            return "Test full premium features"
        }
    }
}

#Preview {
    NavigationStack {
        DevSubscriptionView()
    }
}
