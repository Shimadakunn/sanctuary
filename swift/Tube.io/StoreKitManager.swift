//
//  StoreKitManager.swift
//  Tube.io
//
//  Created by Léo Combaret on 27/12/2025.
//

internal import StoreKit
internal import SwiftUI
import Combine

/// Typealias to avoid ambiguity with other Transaction types (e.g., SwiftData)
typealias StoreTransaction = StoreKit.Transaction

/// Product identifiers for your in-app purchases
/// These must match exactly with App Store Connect
enum ProductID: String, CaseIterable {
    case monthlyPremium = "com.tubeio.premium.monthly"
}

/// Main manager for handling StoreKit 2 subscriptions
@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    // MARK: - Published Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var subscriptionExpirationDate: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // MARK: - Computed Properties
    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
    }

    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthlyPremium.rawValue }
    }

    // MARK: - Private Properties
    private var transactionListener: Task<Void, Error>?

    // MARK: - Initialization
    private init() {
        // Start listening for transactions
        transactionListener = listenForTransactions()

        // Load products and check subscription status
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    /// Fetches available products from App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            print("StoreKit: Loading products with IDs: \(productIDs)")

            products = try await Product.products(for: productIDs)

            if products.isEmpty {
                errorMessage = "No products found. Check your App Store Connect configuration."
                print("StoreKit Warning: No products returned from App Store")
            } else {
                print("StoreKit: Successfully loaded \(products.count) product(s)")
                for product in products {
                    print("  - \(product.id): \(product.displayName) - \(product.displayPrice)")
                }
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("StoreKit Error: Failed to load products - \(error)")
        }

        isLoading = false
    }

    // MARK: - Purchasing

    /// Initiates a purchase for the given product
    func purchase(_ product: Product) async throws -> StoreTransaction? {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updatePurchasedProducts()

                // Finish the transaction
                await transaction.finish()

                return transaction

            case .pending:
                // Transaction is pending (e.g., parental approval required)
                errorMessage = "Purchase is pending approval"
                return nil

            case .userCancelled:
                // User cancelled the purchase
                return nil

            @unknown default:
                errorMessage = "Unknown purchase result"
                return nil
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("StoreKit Error: Purchase failed - \(error)")
            throw error
        }
    }

    /// Convenience method to purchase the monthly premium subscription
    func purchaseMonthlyPremium() async throws -> StoreTransaction? {
        guard let product = monthlyProduct else {
            errorMessage = "Monthly premium product not available"
            print("StoreKit Error: monthlyProduct is nil. Available products: \(products.map { $0.id })")
            return nil
        }
        print("StoreKit: Initiating purchase for \(product.id)")
        return try await purchase(product)
    }

    // MARK: - Restore Purchases

    /// Restores previous purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // This syncs with App Store and updates Transaction.currentEntitlements
            try await AppStore.sync()
            await updatePurchasedProducts()

            if purchasedProductIDs.isEmpty {
                errorMessage = "No purchases to restore"
            }
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("StoreKit Error: Restore failed - \(error)")
        }
    }

    // MARK: - Subscription Status

    /// Updates the set of currently purchased product IDs
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var latestExpirationDate: Date?

        // Iterate through all current entitlements
        for await result in StoreTransaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if subscription is still active
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)

                    // Get expiration date for subscriptions
                    if let expirationDate = transaction.expirationDate {
                        if latestExpirationDate == nil || expirationDate > latestExpirationDate! {
                            latestExpirationDate = expirationDate
                        }
                    }
                }
            } catch {
                print("StoreKit Error: Failed to verify transaction - \(error)")
            }
        }

        self.purchasedProductIDs = purchased
        self.subscriptionExpirationDate = latestExpirationDate

        // Sync with local storage for offline access
        syncSubscriptionStatus()
    }

    /// Syncs the subscription status with UserDefaults
    private func syncSubscriptionStatus() {
        if hasActiveSubscription {
            UserDefaults.standard.set(SubscriptionStatus.premium.rawValue, forKey: "subscriptionStatus")
        } else {
            // Don't override free trial - let FreeTrialManager handle .freeTrial vs .free
            let currentStatus = UserDefaults.standard.string(forKey: "subscriptionStatus")
            if currentStatus != SubscriptionStatus.freeTrial.rawValue {
                UserDefaults.standard.set(SubscriptionStatus.free.rawValue, forKey: "subscriptionStatus")
            }
        }
    }

    // MARK: - Transaction Listener

    /// Listens for transactions that occur outside the app (e.g., renewals, revocations)
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreTransaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    // Update purchased products
                    await self.updatePurchasedProducts()

                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    print("StoreKit Error: Transaction listener error - \(error)")
                }
            }
        }
    }

    // MARK: - Transaction Verification

    /// Verifies that a transaction is valid
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Subscription Management

    /// Opens the subscription management page in the App Store
    func openSubscriptionManagement() async {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene)
            } catch {
                // Fallback to opening Settings
                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                    await UIApplication.shared.open(url)
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Returns a formatted price string for the monthly product
    var monthlyPriceString: String {
        guard let product = monthlyProduct else {
            return "$1.99/month" // Fallback
        }
        return "\(product.displayPrice)/month"
    }

    /// Returns a formatted renewal date string
    var formattedRenewalDate: String? {
        guard let date = subscriptionExpirationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Clears any error message
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Preview Helpers
#if DEBUG
extension StoreKitManager {
    /// Creates a mock manager for previews and testing
    static var preview: StoreKitManager {
        let manager = StoreKitManager.shared
        // In preview mode, the manager will use StoreKit Testing configuration
        return manager
    }

    /// Resets subscription state for testing (clears local state, not actual StoreKit transactions)
    func resetForTesting() {
        purchasedProductIDs = []
        subscriptionExpirationDate = nil
        print("StoreKitManager: Reset local subscription state for testing")
    }
}
#endif
