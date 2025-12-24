//
//  DevModeCodeInputView.swift
//  Sanctuary
//
//  Created by Claude Code on 24/12/2025.
//

internal import SwiftUI

struct DevModeCodeInputView: View {
    @Binding var code: String
    @Binding var isPresented: Bool
    @Binding var devModeEnabled: Bool
    @Binding var showInvalidCodeAlert: Bool
    @FocusState private var isCodeFieldFocused: Bool

    private let correctCode = "251122"

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(devModeEnabled ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: devModeEnabled ? "lock.open.fill" : "lock.shield.fill")
                        .font(.system(size: 36))
                        .foregroundColor(devModeEnabled ? .green : .blue)
                }

                VStack(spacing: 8) {
                    Text("Dev Mode".localized)
                        .font(.system(size: 24, weight: .bold))

                    if devModeEnabled {
                        Text("Dev Mode is currently enabled".localized)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Enter the developer code to enable advanced features".localized)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                if devModeEnabled {
                    // Disable button when dev mode is enabled
                    Button(action: {
                        devModeEnabled = false
                        isPresented = false
                    }) {
                        Text("Disable Dev Mode".localized)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                } else {
                    // Code input when dev mode is disabled
                    VStack(spacing: 16) {
                        SecureField("Enter code".localized, text: $code)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 24, weight: .medium))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .keyboardType(.numberPad)
                            .focused($isCodeFieldFocused)
                            .padding(.horizontal, 32)

                        Button(action: validateCode) {
                            Text("Activate".localized)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(code.isEmpty ? Color.gray : Color.blue)
                                .cornerRadius(12)
                        }
                        .disabled(code.isEmpty)
                        .padding(.horizontal, 32)
                    }
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                if !devModeEnabled {
                    isCodeFieldFocused = true
                }
            }
        }
    }

    private func validateCode() {
        if code == correctCode {
            devModeEnabled = true
            isPresented = false
        } else {
            showInvalidCodeAlert = true
            code = ""
        }
    }
}

#Preview {
    DevModeCodeInputView(
        code: .constant(""),
        isPresented: .constant(true),
        devModeEnabled: .constant(false),
        showInvalidCodeAlert: .constant(false)
    )
}
