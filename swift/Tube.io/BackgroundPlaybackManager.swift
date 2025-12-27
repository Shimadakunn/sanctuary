//
//  BackgroundPlaybackManager.swift
//
//  Created by Léo Combaret on 24/12/2025.
//

import Foundation
import WebKit
import AVFoundation
import UIKit
import MediaPlayer

class BackgroundPlaybackManager {
    static let shared = BackgroundPlaybackManager()

    /// Flag to indicate app is in background - used to block navigations
    var isInBackground = false

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
        setupRemoteCommandCenter()
        print("🎬 [Background] BackgroundPlaybackManager initialized")
    }

    /// Configure remote command center for next/previous track controls
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Disable skip forward/backward commands (the 10 sec buttons)
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        // Enable next/previous track commands
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipToNext()
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipToPrevious()
            return .success
        }

        // Enable play/pause commands
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resumePlayback()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pausePlayback()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        // Disable seek bar dragging (optional - prevents interference)
        commandCenter.changePlaybackPositionCommand.isEnabled = false

        print("🎛️ [Remote] Command center configured with next/previous track controls")
    }

    /// Update Now Playing info to claim control of the remote session
    func updateNowPlayingInfo() {
        // Get current media info from the web page
        let mediaInfoScript = """
        (function() {
            var video = document.querySelector('video');
            var info = {
                title: document.title || 'Unknown',
                duration: video ? video.duration : 0,
                currentTime: video ? video.currentTime : 0,
                isPlaying: video ? !video.paused : false
            };

            // Try to get YouTube Music specific metadata
            var titleEl = document.querySelector('.title.ytmusic-player-bar') ||
                          document.querySelector('.ytp-title-link') ||
                          document.querySelector('[class*="title"]');
            var artistEl = document.querySelector('.byline.ytmusic-player-bar') ||
                           document.querySelector('.ytp-title-channel');

            if (titleEl) info.title = titleEl.textContent.trim();
            if (artistEl) info.artist = artistEl.textContent.trim();

            return info;
        })();
        """

        webView?.evaluateJavaScript(mediaInfoScript) { [weak self] result, error in
            guard let info = result as? [String: Any] else { return }

            var nowPlayingInfo = [String: Any]()

            if let title = info["title"] as? String {
                nowPlayingInfo[MPMediaItemPropertyTitle] = title
            }
            if let artist = info["artist"] as? String {
                nowPlayingInfo[MPMediaItemPropertyArtist] = artist
            }
            if let duration = info["duration"] as? Double, duration > 0 {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            }
            if let currentTime = info["currentTime"] as? Double {
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            }
            if let isPlaying = info["isPlaying"] as? Bool {
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            }

            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

            // Re-apply command center settings after updating now playing info
            self?.reapplyRemoteCommands()

            print("🎵 [NowPlaying] Updated: \(info["title"] ?? "unknown")")
        }
    }

    /// Re-apply remote command settings (call after WKWebView might have changed them)
    private func reapplyRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Force disable skip commands
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        // Force enable track commands
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
    }

    /// Skip to next track on YouTube Music
    func skipToNext() {
        let nextScript = """
        (function() {
            // YouTube Music next button
            var nextBtn = document.querySelector('.next-button') ||
                          document.querySelector('[aria-label="Next"]') ||
                          document.querySelector('[data-tooltip="Next"]') ||
                          document.querySelector('button[aria-label*="Next"]') ||
                          document.querySelector('.ytp-next-button');

            if (nextBtn) {
                nextBtn.click();
                console.log('[Tube.io] Next track clicked');
                return true;
            }

            // Fallback: try to find any next button
            var buttons = document.querySelectorAll('button');
            for (var i = 0; i < buttons.length; i++) {
                var btn = buttons[i];
                var ariaLabel = btn.getAttribute('aria-label') || '';
                var title = btn.getAttribute('title') || '';
                if (ariaLabel.toLowerCase().includes('next') ||
                    title.toLowerCase().includes('next')) {
                    btn.click();
                    console.log('[Tube.io] Next button found and clicked');
                    return true;
                }
            }

            console.log('[Tube.io] No next button found');
            return false;
        })();
        """

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(nextScript) { result, error in
                if let error = error {
                    print("❌ [Remote] Next track error: \(error.localizedDescription)")
                } else if let success = result as? Bool {
                    print("🎵 [Remote] Next track: \(success ? "success" : "no button found")")
                }
            }
        }
    }

    /// Skip to previous track on YouTube Music
    func skipToPrevious() {
        let prevScript = """
        (function() {
            // YouTube Music previous button
            var prevBtn = document.querySelector('.previous-button') ||
                          document.querySelector('[aria-label="Previous"]') ||
                          document.querySelector('[data-tooltip="Previous"]') ||
                          document.querySelector('button[aria-label*="Previous"]') ||
                          document.querySelector('.ytp-prev-button');

            if (prevBtn) {
                prevBtn.click();
                console.log('[Tube.io] Previous track clicked');
                return true;
            }

            // Fallback: try to find any previous button
            var buttons = document.querySelectorAll('button');
            for (var i = 0; i < buttons.length; i++) {
                var btn = buttons[i];
                var ariaLabel = btn.getAttribute('aria-label') || '';
                var title = btn.getAttribute('title') || '';
                if (ariaLabel.toLowerCase().includes('previous') ||
                    title.toLowerCase().includes('previous')) {
                    btn.click();
                    console.log('[Tube.io] Previous button found and clicked');
                    return true;
                }
            }

            console.log('[Tube.io] No previous button found');
            return false;
        })();
        """

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(prevScript) { result, error in
                if let error = error {
                    print("❌ [Remote] Previous track error: \(error.localizedDescription)")
                } else if let success = result as? Bool {
                    print("🎵 [Remote] Previous track: \(success ? "success" : "no button found")")
                }
            }
        }
    }

    /// Pause playback
    func pausePlayback() {
        let pauseScript = """
        (function() {
            var mediaElements = document.querySelectorAll('video, audio');
            mediaElements.forEach(function(el) {
                if (!el.paused) {
                    el.pause();
                }
            });
            return true;
        })();
        """

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(pauseScript) { _, error in
                if let error = error {
                    print("❌ [Remote] Pause error: \(error.localizedDescription)")
                } else {
                    print("⏸️ [Remote] Playback paused")
                }
            }
        }
    }

    /// Toggle play/pause
    func togglePlayPause() {
        let toggleScript = """
        (function() {
            var mediaElements = document.querySelectorAll('video, audio');
            var toggled = false;
            mediaElements.forEach(function(el) {
                if (el.paused) {
                    el.play();
                } else {
                    el.pause();
                }
                toggled = true;
            });
            return toggled;
        })();
        """

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(toggleScript) { _, error in
                if let error = error {
                    print("❌ [Remote] Toggle error: \(error.localizedDescription)")
                } else {
                    print("⏯️ [Remote] Playback toggled")
                }
            }
        }
    }

    /// JavaScript that tricks websites into thinking the page is always visible
    /// This prevents sites from pausing video when app goes to background
    static let visibilityOverrideScript = """
    (function() {
        // Already injected check
        if (window.__visibilityOverrideInjected) return;
        window.__visibilityOverrideInjected = true;

        // Events to block that websites use to detect background state
        var blockedEvents = [
            'visibilitychange',
            'blur',
            'pagehide',
            'freeze',
            'webkitvisibilitychange'
        ];

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

        // Override webkitHidden (older browsers)
        Object.defineProperty(document, 'webkitHidden', {
            get: function() { return false; },
            configurable: true
        });

        // Block events on document
        var originalAddEventListener = document.addEventListener;
        document.addEventListener = function(type, listener, options) {
            if (blockedEvents.includes(type)) {
                console.log('[Tube.io] Blocked document.' + type + ' listener');
                return;
            }
            return originalAddEventListener.call(this, type, listener, options);
        };

        // Block events on window
        var originalWindowAddEventListener = window.addEventListener;
        window.addEventListener = function(type, listener, options) {
            if (blockedEvents.includes(type)) {
                console.log('[Tube.io] Blocked window.' + type + ' listener');
                return;
            }
            return originalWindowAddEventListener.call(this, type, listener, options);
        };

        // Override document.hasFocus to always return true
        Object.defineProperty(document, 'hasFocus', {
            value: function() { return true; },
            configurable: true,
            writable: true
        });

        // Override window.focus state
        Object.defineProperty(window, 'onfocus', { value: null, writable: true });
        Object.defineProperty(window, 'onblur', { value: null, writable: true });
        Object.defineProperty(document, 'onfocus', { value: null, writable: true });
        Object.defineProperty(document, 'onblur', { value: null, writable: true });

        // Block history-based navigation detection
        var originalPushState = history.pushState;
        var originalReplaceState = history.replaceState;
        window.__tubeioAllowNavigation = true;

        // Intercept location changes during background
        var originalLocationAssign = window.location.assign;
        var originalLocationReplace = window.location.replace;

        // ============================================
        // MEDIA SESSION OVERRIDE - Force next/previous track buttons
        // ============================================
        if ('mediaSession' in navigator) {
            var originalSetActionHandler = navigator.mediaSession.setActionHandler.bind(navigator.mediaSession);
            var storedHandlers = {};

            navigator.mediaSession.setActionHandler = function(action, handler) {
                console.log('[Tube.io] MediaSession action intercepted: ' + action);

                // Store the original handler
                storedHandlers[action] = handler;

                // Block seekforward/seekbackward (the 10 sec skip buttons)
                if (action === 'seekforward' || action === 'seekbackward') {
                    console.log('[Tube.io] Blocking ' + action + ' to show next/previous instead');
                    // Don't register these - this removes the 10 sec skip buttons
                    return;
                }

                // Pass through other actions (play, pause, etc.)
                originalSetActionHandler(action, handler);
            };

            // Register next/previous track handlers that click the YouTube buttons
            function setupTrackControls() {
                // Find and click next button
                var nextHandler = function() {
                    console.log('[Tube.io] Next track triggered from MediaSession');
                    var nextBtn = document.querySelector('.next-button') ||
                                  document.querySelector('[aria-label="Next"]') ||
                                  document.querySelector('[data-tooltip="Next"]') ||
                                  document.querySelector('button[aria-label*="Next"]') ||
                                  document.querySelector('.ytp-next-button');
                    if (nextBtn) {
                        nextBtn.click();
                        console.log('[Tube.io] Next button clicked');
                    }
                };

                // Find and click previous button
                var prevHandler = function() {
                    console.log('[Tube.io] Previous track triggered from MediaSession');
                    var prevBtn = document.querySelector('.previous-button') ||
                                  document.querySelector('[aria-label="Previous"]') ||
                                  document.querySelector('[data-tooltip="Previous"]') ||
                                  document.querySelector('button[aria-label*="Previous"]') ||
                                  document.querySelector('.ytp-prev-button');
                    if (prevBtn) {
                        prevBtn.click();
                        console.log('[Tube.io] Previous button clicked');
                    }
                };

                // Register the track controls
                try {
                    originalSetActionHandler('nexttrack', nextHandler);
                    originalSetActionHandler('previoustrack', prevHandler);
                    console.log('[Tube.io] Next/Previous track handlers registered');
                } catch(e) {
                    console.log('[Tube.io] Error registering track handlers: ' + e);
                }
            }

            // Setup immediately and also after a delay (for dynamic pages)
            setupTrackControls();
            setTimeout(setupTrackControls, 2000);
            setTimeout(setupTrackControls, 5000);
        }

        console.log('[Tube.io] Visibility override injected - background playback enabled');
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

        // App returning to foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // App became active (fully in foreground)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
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
        isInBackground = true
        // Ensure audio session is active
        activateAudioSession()

        // Update Now Playing info and reclaim remote command center
        updateNowPlayingInfo()

        // Start resume loop immediately to catch pauses from Control Center/Notification Center
        resumeAttempts = 0
        startResumeLoop()
    }

    @objc private func appWillEnterForeground() {
        print("🎬 [Background] App will enter foreground")
        isInBackground = false
    }

    @objc private func appDidBecomeActive() {
        print("🎬 [Background] App did become active")
        isInBackground = false
    }

    private var resumeAttempts = 0
    private let maxResumeAttempts = 20  // Max 2 seconds (20 * 0.1s)

    @objc private func appDidEnterBackground() {
        print("🎬 [Background] App did enter background - resuming playback")
        isInBackground = true
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

    /// Start Picture-in-Picture mode for the current video
    func startPictureInPicture() {
        print("🎬 [PiP] Starting Picture-in-Picture mode...")

        let pipScript = """
        (function() {
            // Find all video elements
            var videos = document.querySelectorAll('video');
            var pipStarted = false;

            // Try main document videos first
            for (var i = 0; i < videos.length; i++) {
                var video = videos[i];
                // Check if video has content and is visible
                if (video.readyState >= 2 && video.videoWidth > 0) {
                    // Make sure video is playing
                    if (video.paused) {
                        video.play();
                    }
                    // Request PiP
                    if (document.pictureInPictureEnabled && !document.pictureInPictureElement) {
                        video.requestPictureInPicture().then(function() {
                            console.log('[Tube.io] PiP started successfully');
                        }).catch(function(e) {
                            console.log('[Tube.io] PiP failed: ' + e.message);
                        });
                        pipStarted = true;
                        break;
                    }
                }
            }

            // Try iframes if no video found in main document
            if (!pipStarted) {
                var iframes = document.querySelectorAll('iframe');
                for (var j = 0; j < iframes.length; j++) {
                    try {
                        var iframeDoc = iframes[j].contentDocument || iframes[j].contentWindow.document;
                        var iframeVideos = iframeDoc.querySelectorAll('video');
                        for (var k = 0; k < iframeVideos.length; k++) {
                            var iframeVideo = iframeVideos[k];
                            if (iframeVideo.readyState >= 2 && iframeVideo.videoWidth > 0) {
                                if (iframeVideo.paused) {
                                    iframeVideo.play();
                                }
                                if (iframeDoc.pictureInPictureEnabled && !iframeDoc.pictureInPictureElement) {
                                    iframeVideo.requestPictureInPicture();
                                    pipStarted = true;
                                    break;
                                }
                            }
                        }
                    } catch(e) {
                        // Cross-origin iframe
                    }
                    if (pipStarted) break;
                }
            }

            return pipStarted;
        })();
        """

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(pipScript) { result, error in
                if let error = error {
                    print("❌ [PiP] JavaScript error: \(error.localizedDescription)")
                } else if let started = result as? Bool {
                    print("🎬 [PiP] Picture-in-Picture \(started ? "started" : "failed - no video found")")
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
