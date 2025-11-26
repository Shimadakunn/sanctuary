//
//  OrientationManager.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

import UIKit
import SwiftUI
import Combine

class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    @Published var orientation: UIInterfaceOrientationMask = .portrait

    func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        self.orientation = orientation
    }

    func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation: UIInterfaceOrientation) {
        self.orientation = orientation

        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
            windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }

    func unlockOrientation() {
        self.orientation = .all
    }
}
