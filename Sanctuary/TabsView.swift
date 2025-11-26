//
//  TabsView.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

import SwiftUI

struct TabsView: View {
    @Binding var tabs: [BrowserTab]
    @Binding var selectedTabIndex: Int
    @Binding var searchText: String
    let onSelectTab: (Int) -> Void
    let onNewTab: () -> Void
    let onCloseTab: (Int) -> Void
    let onSubmit: () -> Void

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 30) {
                    HStack {
                        Text("Tabs")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Spacer()

                        Text("\(tabs.count)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 30)

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                                TabTile(
                                    tab: tab,
                                    isSelected: index == selectedTabIndex,
                                    onSelect: { onSelectTab(index) },
                                    onClose: { onCloseTab(index) }
                                )
                            }

                            Button(action: onNewTab) {
                                VStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                                            .frame(height: 160)

                                        Image(systemName: "plus")
                                            .font(.system(size: 40, weight: .light))
                                            .foregroundColor(.secondary)
                                    }

                                    Text("New Tab")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer()

                SearchBar(text: $searchText, onSubmit: onSubmit)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }
}

struct TabTile: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .frame(height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                        )

                    VStack {
                        Spacer()
                        Image(systemName: "globe")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)

                    Button(action: onClose) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 28, height: 28)

                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(8)
                }

                Text(tab.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .padding(.top, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
