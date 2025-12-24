//
//  AudioPlayer.swift
//  Sanctuary
//
//  Created by Léo Combaret on 30/11/2025.
//

internal import SwiftUI
import AVKit
import AVFoundation

struct AudioPlayer: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // Ensure audio session is active for background playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true)
        } catch {
            print("❌ [Audio] Failed to activate audio session: \(error.localizedDescription)")
        }

        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = false
        controller.updatesNowPlayingInfoCenter = true
        controller.entersFullScreenWhenPlaybackBegins = false

        // Auto-play
        player.play()

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
