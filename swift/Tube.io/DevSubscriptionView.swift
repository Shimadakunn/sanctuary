//
//  DevSubscriptionView.swift
//
//  Created by Léo Combaret on 05/12/2025.
//

internal import SwiftUI
internal import StoreKit

struct DevSubscriptionView: View {
    @AppStorage("subscriptionStatus") private var subscriptionStatusRaw: String = SubscriptionStatus.free.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var transactionsCleared = false

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

            Section(header: Text("Free Trial".localized)) {
                Button(action: {
                    #if DEBUG
                    FreeTrialManager.shared.resetTrialForTesting()
                    #endif
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 40, height: 40)

                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18))
                                .foregroundColor(.red)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reset Free Trial")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Text("Clears Keychain data, allows new trial")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("StoreKit Transactions")) {
                Button(action: {
                    Task {
                        await clearAllTransactions()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 40, height: 40)

                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(.orange)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Clear All Transactions")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Text("Resets all StoreKit test purchases")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if transactionsCleared {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 22))
                        }
                    }
                    .padding(.vertical, 4)
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

    private func clearAllTransactions() async {
        // Finish all current entitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
        }

        // Also finish any unfinished transactions
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
        }

        // Reset StoreKitManager's local state (clears purchasedProductIDs)
        #if DEBUG
        await MainActor.run {
            StoreKitManager.shared.resetForTesting()
        }
        #endif

        // Reset local subscription status to free
        subscriptionStatusRaw = SubscriptionStatus.free.rawValue

        // Show confirmation
        await MainActor.run {
            transactionsCleared = true
        }

        // Hide confirmation after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            transactionsCleared = false
        }
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
