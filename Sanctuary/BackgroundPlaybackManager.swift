//
//  BackgroundPlaybackManager.swift
//  Sanctuary
//
//  Created by Léo Combaret on 24/12/2025.
//

import Foundation
import WebKit
import AVFoundation
import UIKit

class BackgroundPlaybackManager {
    static let shared = BackgroundPlaybackManager()

    weak var webView: WKWebView? {
        didSet {
            // Inject visibility override script when webview is set
            if webView != nil {
                injectVisibilityOverride()
            }
        }
    }

    private init() {
        setupBackgroundObservers()
        print("🎬 [Background] BackgroundPlaybackManager initialized")
    }

    /// JavaScript that tricks websites into thinking the page is always visible
    /// This prevents sites from pausing video when app goes to background
    static let visibilityOverrideScript = """
    (function() {
        // Already injected check
        if (window.__visibilityOverrideInjected) return;
        window.__visibilityOverrideInjected = true;

        // Override document.hidden
        Object.defineProperty(document, 'hidden', {
            get: function() { return false; },
            configurable: true
        });

        // Override document.visibilityState
        Object.defineProperty(document, 'visibilityState', {
            get: function() { return 'visible'; },
            configurable: true
        });

        // Block visibilitychange events
        var originalAddEventListener = document.addEventListener;
        document.addEventListener = function(type, listener, options) {
            if (type === 'visibilitychange') {
                console.log('[Sanctuary] Blocked visibilitychange listener');
                return;
            }
            return originalAddEventListener.call(this, type, listener, options);
        };

        // Also override on window
        var originalWindowAddEventListener = window.addEventListener;
        window.addEventListener = function(type, listener, options) {
            if (type === 'visibilitychange') {
                console.log('[Sanctuary] Blocked window visibilitychange listener');
                return;
            }
            return originalWindowAddEventListener.call(this, type, listener, options);
        };

        // Prevent pagehide/pageshow from being used to detect background
        Object.defineProperty(document, 'hasFocus', {
            value: function() { return true; },
            configurable: true
        });

        console.log('[Sanctuary] Visibility override injected - background playback enabled');
    })();
    """

    func injectVisibilityOverride() {
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(BackgroundPlaybackManager.visibilityOverrideScript) { _, error in
                if let error = error {
                    print("❌ [Background] Failed to inject visibility override: \(error.localizedDescription)")
                } else {
                    print("🎬 [Background] Visibility override injected")
                }
            }
        }
    }

    private func setupBackgroundObservers() {
        // App entering background (home button, app switch, lock screen)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // App resigning active (about to go to background)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        // Audio interruption handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func appWillResignActive() {
        print("🎬 [Background] App will resign active - preparing for background playback")
        // Ensure audio session is active
        activateAudioSession()
    }

    private var resumeAttempts = 0
    private let maxResumeAttempts = 20  // Max 2 seconds (20 * 0.1s)

    @objc private func appDidEnterBackground() {
        print("🎬 [Background] App did enter background - resuming playback")
        resumeAttempts = 0
        startResumeLoop()
    }

    private func startResumeLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.tryResumePlayback()
        }
    }

    private func tryResumePlayback() {
        guard resumeAttempts < maxResumeAttempts else {
            print("🎬 [Background] Max resume attempts reached")
            return
        }

        resumeAttempts += 1
        resumePlayback { [weak self] resumed in
            guard let self = self else { return }
            if resumed {
                print("🎬 [Background] Playback resumed after \(self.resumeAttempts) attempt(s)")
            } else {
                // Try again after 0.1s
                self.startResumeLoop()
            }
        }
    }

    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("🎬 [Background] Audio interruption began")
        case .ended:
            print("🎬 [Background] Audio interruption ended - resuming")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    activateAudioSession()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.resumePlayback()
                    }
                }
            }
        @unknown default:
            break
        }
    }

    private func activateAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            try audioSession.setActive(true)
            print("🎬 [Background] Audio session activated")
        } catch {
            print("❌ [Background] Failed to activate audio session: \(error.localizedDescription)")
        }
    }

    func resumePlayback(completion: ((Bool) -> Void)? = nil) {
        // Resume video/audio in WKWebView
        let resumeScript = """
        (function() {
            var mediaElements = document.querySelectorAll('video, audio');
            var resumed = 0;
            var playing = 0;
            mediaElements.forEach(function(el) {
                if (!el.paused) {
                    playing++;
                } else if (el.readyState >= 2) {
                    el.play().then(function() {
                        console.log('Media resumed successfully');
                    }).catch(function(e) {
                        console.log('Failed to resume: ' + e.message);
                    });
                    resumed++;
                }
            });

            // Also try to find video in iframes (for embedded players)
            var iframes = document.querySelectorAll('iframe');
            iframes.forEach(function(iframe) {
                try {
                    var iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
                    var iframeMedia = iframeDoc.querySelectorAll('video, audio');
                    iframeMedia.forEach(function(el) {
                        if (!el.paused) {
                            playing++;
                        } else {
                            el.play();
                            resumed++;
                        }
                    });
                } catch(e) {
                    // Cross-origin iframe, can't access
                }
            });

            // Return: already playing OR just resumed something
            return (playing > 0 || resumed > 0);
        })();
        """

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(resumeScript) { result, error in
                if let error = error {
                    print("❌ [Background] JavaScript error: \(error.localizedDescription)")
                    completion?(false)
                } else if let isPlaying = result as? Bool {
                    completion?(isPlaying)
                } else {
                    completion?(false)
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
