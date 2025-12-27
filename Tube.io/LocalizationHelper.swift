//
//  LocalizationHelper.swift
//
//  Created for localization support
//

import Foundation

extension String {
    /// Returns a localized version of the string
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    /// Returns a localized version of the string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}
