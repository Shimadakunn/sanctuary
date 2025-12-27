//
//  ThemeView.swift
//
//  Created by Léo Combaret on 05/12/2025.
//

internal import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var displayName: String {
        switch self {
        case .system:
            return "System".localized
        case .light:
            return "Light".localized
        case .dark:
            return "Dark".localized
        }
    }

    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct ThemeView: View {
    @AppStorage("selectedTheme") private var selectedThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.dismiss) private var dismiss

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: selectedThemeRaw) ?? .system
    }

    var body: some View {
        List {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Button(action: {
                    selectedThemeRaw = theme.rawValue
                    dismiss()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeColor(for: theme).opacity(0.2))
                                .frame(width: 40, height: 40)

                            Image(systemName: theme.iconName)
                                .font(.system(size: 18))
                                .foregroundColor(themeColor(for: theme))
                        }

                        Text(theme.displayName)
                            .foregroundColor(.primary)

                        Spacer()

                        if selectedTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Theme".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return .blue
        case .light:
            return .orange
        case .dark:
            return .indigo
        }
    }
}

#Preview {
    NavigationStack {
        ThemeView()
    }
}
