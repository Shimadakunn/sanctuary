//
//  AppLockView.swift
//
//  Created by Léo Combaret on 29/11/2025.
//

internal import SwiftUI
import LocalAuthentication

struct AppLockView: View {
    @Binding var isUnlocked: Bool
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            Color.overlayDim
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .shadow(radius: 10)

                    if showError {
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .font(.caption)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            authenticate()
        }
    }

    private func biometricIcon() -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)

        switch context.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.fill"
        }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        // Use .deviceOwnerAuthentication instead of .deviceOwnerAuthenticationWithBiometrics
        // This allows fallback to device passcode if biometrics fail
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock"

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation {
                            isUnlocked = true
                        }
                    } else {
                        if let error = authenticationError {
                            errorMessage = "Authentication failed: \(error.localizedDescription)"
                        } else {
                            errorMessage = "Authentication failed"
                        }
                        showError = true
                    }
                }
            }
        } else {
            // Device doesn't support biometrics or passcode is not set
            if let error = error {
                errorMessage = "Authentication not available: \(error.localizedDescription)"
            } else {
                errorMessage = "Please set up Face ID, Touch ID, or a passcode in Settings"
            }
            showError = true
        }
    }
}

#Preview {
    AppLockView(isUnlocked: .constant(false))
}
