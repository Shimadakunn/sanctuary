//
//  HomePage.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

import SwiftUI

struct HomePage: View {
    @Binding var searchText: String
    let onSubmit: () -> Void
    let onQuickAccess: (String) -> Void

    private let quickAccessSites = [
        ("YouTube", "youtube.com", "play.rectangle.fill", Color.red),
        ("Forbes", "forbes.com", "newspaper.fill", Color.blue),
        ("Twitter", "twitter.com", "bird.fill", Color.cyan)
    ]

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 30) {
                    Text("Sanctuary")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(quickAccessSites, id: \.1) { site in
                            QuickAccessTile(
                                title: site.0,
                                url: site.1,
                                icon: site.2,
                                color: site.3
                            ) {
                                onQuickAccess(site.1)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                SearchBar(text: $searchText, onSubmit: onSubmit)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }
}

struct QuickAccessTile: View {
    let title: String
    let url: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(color.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 18))

            TextField("Search or enter website", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}
