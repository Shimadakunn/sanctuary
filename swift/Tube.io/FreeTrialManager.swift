//
//  FreeTrialManager.swift
//  Tube.io
//
//  Created by Léo Combaret on 27/12/2025.
//

import Foundation
internal import SwiftUI
import Combine

/// Manages the 14-day free trial for new users
/// Uses Keychain to persist trial data across app reinstalls
@MainActor
final class FreeTrialManager: ObservableObject {
    static let shared = FreeTrialManager()

    private let keychain = KeychainManager.shared
    private let trialDuration: TimeInterval = 14 * 24 * 60 * 60 // 14 days in seconds

    // MARK: - Published Properties
    @Published private(set) var trialStartDate: Date?
    @Published private(set) var trialEndDate: Date?
    @Published private(set) var daysRemaining: Int = 0
    @Published private(set) var hasUsedTrial: Bool = false
    @Published private(set) var isTrialActive: Bool = false

    // MARK: - Initialization
    private init() {
        loadTrialStatus()
    }

    // MARK: - Public Methods

    /// Call this on app launch to initialize or check trial status
    func checkAndActivateTrial() {
        loadTrialStatus()

        // If user has never used trial and no start date exists, start the trial
        if !hasUsedTrial && trialStartDate == nil {
            startTrial()
        } else {
            // Check if trial is still active
            updateTrialActiveStatus()
        }

        syncWithSubscriptionStatus()
    }

    /// Manually refresh trial status
    func refreshTrialStatus() {
        loadTrialStatus()
        updateTrialActiveStatus()
        syncWithSubscriptionStatus()
    }

    // MARK: - Private Methods

    private func loadTrialStatus() {
        hasUsedTrial = keychain.getBool(forKey: .hasUsedTrial)
        trialStartDate = keychain.getDate(forKey: .trialStartDate)

        if let startDate = trialStartDate {
            trialEndDate = startDate.addingTimeInterval(trialDuration)
        }

        updateTrialActiveStatus()
    }

    private func startTrial() {
        let now = Date()
        trialStartDate = now
        trialEndDate = now.addingTimeInterval(trialDuration)

        // Save to Keychain (persists across reinstalls)
        keychain.save(now, forKey: .trialStartDate)
        keychain.save(true, forKey: .hasUsedTrial)

        hasUsedTrial = true
        isTrialActive = true
        updateDaysRemaining()

        print("FreeTrialManager: Started 14-day free trial")
        print("  Start: \(now)")
        print("  End: \(trialEndDate!)")
    }

    private func updateTrialActiveStatus() {
        guard let endDate = trialEndDate else {
            isTrialActive = false
            daysRemaining = 0
            return
        }

        let now = Date()
        isTrialActive = now < endDate
        updateDaysRemaining()

        if !isTrialActive {
            print("FreeTrialManager: Trial has expired")
        }
    }

    private func updateDaysRemaining() {
        guard let endDate = trialEndDate else {
            daysRemaining = 0
            return
        }

        let now = Date()
        let remaining = endDate.timeIntervalSince(now)

        if remaining > 0 {
            // Round up to show "1 day" even if less than 24 hours remain
            daysRemaining = Int(ceil(remaining / (24 * 60 * 60)))
        } else {
            daysRemaining = 0
        }
    }

    private func syncWithSubscriptionStatus() {
        // Don't override if user has paid premium subscription
        let storeManager = StoreKitManager.shared
        if storeManager.hasActiveSubscription {
            // User has paid subscription, don't change status
            return
        }

        // Update subscription status based on trial
        let newStatus: SubscriptionStatus = isTrialActive ? .freeTrial : .free
        UserDefaults.standard.set(newStatus.rawValue, forKey: "subscriptionStatus")
    }

    // MARK: - Computed Properties

    /// Returns formatted trial end date
    var formattedTrialEndDate: String? {
        guard let endDate = trialEndDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: endDate)
    }

    /// Returns a user-friendly string describing trial status
    var trialStatusDescription: String {
        if isTrialActive {
            if daysRemaining == 1 {
                return "1 day remaining"
            } else {
                return "\(daysRemaining) days remaining"
            }
        } else if hasUsedTrial {
            return "Trial ended"
        } else {
            return "No trial"
        }
    }

    // MARK: - Debug/Testing Methods
    #if DEBUG
    /// Resets trial for testing purposes (only available in debug builds)
    func resetTrialForTesting() {
        keychain.delete(forKey: .trialStartDate)
        keychain.delete(forKey: .hasUsedTrial)
        trialStartDate = nil
        trialEndDate = nil
        hasUsedTrial = false
        isTrialActive = false
        daysRemaining = 0
        UserDefaults.standard.set(SubscriptionStatus.free.rawValue, forKey: "subscriptionStatus")
        print("FreeTrialManager: Trial reset for testing")

        // Immediately start a new trial after reset
        checkAndActivateTrial()
    }
    #endif
}
