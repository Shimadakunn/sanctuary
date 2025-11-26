//
//  BrowserTab.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

import Foundation

struct BrowserTab: Identifiable, Equatable {
    let id = UUID()
    var url: URL?
    var title: String

    init(url: URL? = nil, title: String = "New Tab") {
        self.url = url
        self.title = title
    }
}
