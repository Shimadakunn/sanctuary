//
//  BrowserView.swift
//  Sanctuary
//
//  Created by Léo Combaret on 26/11/2025.
//

internal import SwiftUI
import WebKit
import Combine

struct BrowserView: View {
    let url: URL?
    @Binding var canGoBack: Bool
    @Binding var title: String
    let onBack: () -> Void
    let onGoHome: () -> Void
    let webViewStore: WebViewStore
    @ObservedObject var favoritesManager: FavoritesManager
    @ObservedObject var historyManager: HistoryManager

    @State private var showAddFavoriteSheet = false

    var body: some View {
        ZStack {
            WebViewWrapper(url: url, canGoBack: $canGoBack, title: $title, webViewStore: webViewStore, historyManager: historyManager)
                .ignoresSafeArea(edges: .bottom)

            VStack {
                Spacer()

                HStack {
                    Button(action: {
                        print("⬅️ [Back Button Pressed] CanGoBack: \(canGoBack)")
                        if canGoBack {
                            print("⬅️ [Back Button] Calling webView.goBack()")
                            webViewStore.webView?.goBack()
                        } else {
                            print("⬅️ [Back Button] Calling onBack() - returning to home")
                            onBack()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 50, height: 50)

                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 20)

                    Spacer()

                    Button(action: {
                        let currentURL = webViewStore.webView?.url?.absoluteString ?? ""
                        if favoritesManager.isFavorite(url: currentURL) {
                            favoritesManager.removeFavorite(url: currentURL)
                        } else {
                            showAddFavoriteSheet = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 50, height: 50)

                            Image(systemName: favoritesManager.isFavorite(url: webViewStore.webView?.url?.absoluteString) ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(favoritesManager.isFavorite(url: webViewStore.webView?.url?.absoluteString) ? .red : .white)
                        }
                    }
                    .sheet(isPresented: $showAddFavoriteSheet) {
                        AddFavoriteView(
                            initialTitle: title,
                            url: webViewStore.webView?.url?.absoluteString ?? "",
                            favoritesManager: favoritesManager,
                            isPresented: $showAddFavoriteSheet
                        )
                    }

                    Button(action: {
                        print("🏠 [Home Button Pressed]")
                        onGoHome()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 50, height: 50)

                            Image(systemName: "house.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

class WebViewStore: ObservableObject {
    @Published var webView: WKWebView?
}

struct WebViewWrapper: UIViewRepresentable {
    let url: URL?
    @Binding var canGoBack: Bool
    @Binding var title: String
    @ObservedObject var webViewStore: WebViewStore
    @ObservedObject var historyManager: HistoryManager

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        DispatchQueue.main.async {
            webViewStore.webView = webView
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = url, webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        var currentURL: URL?

        // Whitelist for bypassing ad blocking (user can add sites here)
        private var whitelist: Set<String> = []

        // Timing tracking to detect rapid redirects (common ad pattern)
        private var lastNavigationTime: Date?
        private var rapidRedirectCount: Int = 0

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        // MARK: - Base Domain Detection (uBlock-style first-party/third-party detection)

        /// Extract base domain using Public Suffix List logic
        /// For example: "www.example.com" -> "example.com", "blog.github.io" -> "blog.github.io"
        private func getBaseDomain(from url: URL) -> String? {
            guard let host = url.host else { return nil }

            // Simple implementation - iOS doesn't have built-in PSL, so we use basic heuristics
            // For production, consider using a proper Public Suffix List library
            let components = host.split(separator: ".")
            guard components.count >= 2 else { return host }

            // Handle common multi-part TLDs (.co.uk, .com.au, etc.)
            let multiPartTLDs = ["co.uk", "com.au", "co.jp", "co.nz", "com.br", "co.za"]
            let lastTwo = components.suffix(2).joined(separator: ".")

            if multiPartTLDs.contains(lastTwo) {
                // Need at least 3 components for multi-part TLD
                guard components.count >= 3 else { return host }
                return components.suffix(3).joined(separator: ".")
            } else {
                // Standard TLD - return last two components
                return lastTwo
            }
        }

        /// Check if request is third-party relative to document (uBlock-style)
        private func isThirdParty(requestURL: URL, documentURL: URL) -> Bool {
            guard let requestDomain = getBaseDomain(from: requestURL),
                  let documentDomain = getBaseDomain(from: documentURL) else {
                return true // Assume third-party if we can't determine
            }
            return requestDomain != documentDomain
        }

        // MARK: - Improved Ad Blocking Logic

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let targetURL = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let sourceURL = navigationAction.sourceFrame.request.url
            let navigationType = navigationAction.navigationType
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false

            print("🔍 [Navigation Policy] Type: \(navigationType.rawValue), MainFrame: \(isMainFrame), Target: \(targetURL.absoluteString), Source: \(sourceURL?.absoluteString ?? "nil")")

            // RULE 1: Always allow about:blank and data: URLs (used by legitimate sites)
            if targetURL.scheme == "about" || targetURL.scheme == "data" {
                decisionHandler(.allow)
                return
            }

            // RULE 2: Check whitelist (highest priority - like uBlock's trusted sites)
            if let targetHost = targetURL.host, whitelist.contains(targetHost) {
                print("✅ [Whitelist] Allowing navigation to whitelisted domain: \(targetHost)")
                decisionHandler(.allow)
                return
            }

            // RULE 3: Always allow user-initiated navigation (uBlock principle)
            // These are explicit user actions that should never be blocked
            switch navigationType {
            case .linkActivated:  // User clicked a link
                print("✅ [User Action] Link click - allowing")
                resetRedirectTracking()
                decisionHandler(.allow)
                return

            case .formSubmitted:  // User submitted a form
                print("✅ [User Action] Form submission - allowing")
                resetRedirectTracking()
                decisionHandler(.allow)
                return

            case .backForward:    // User navigated via back/forward buttons
                print("✅ [User Action] Back/forward navigation - allowing")
                resetRedirectTracking()
                decisionHandler(.allow)
                return

            case .reload:         // User reloaded the page
                print("✅ [User Action] Page reload - allowing")
                resetRedirectTracking()
                decisionHandler(.allow)
                return

            case .formResubmitted: // User resubmitted a form
                print("✅ [User Action] Form resubmission - allowing")
                resetRedirectTracking()
                decisionHandler(.allow)
                return

            case .other:
                // Programmatic navigation - apply strict filtering
                break

            @unknown default:
                // Future navigation types - be conservative and allow
                print("⚠️ [Unknown Navigation Type] Allowing")
                decisionHandler(.allow)
                return
            }

            // Beyond this point: We're dealing with .other (programmatic) navigation
            // Apply uBlock-inspired heuristics to detect ads/trackers

            guard let sourceURL = sourceURL else {
                // No source URL - likely initial page load, allow
                decisionHandler(.allow)
                return
            }

            // RULE 4: Same-page navigation (anchors, hash changes) - always allow
            if sourceURL.absoluteString == targetURL.absoluteString {
                decisionHandler(.allow)
                return
            }

            // RULE 5: Detect rapid redirect chains (common ad pattern)
            let now = Date()
            if let lastTime = lastNavigationTime, now.timeIntervalSince(lastTime) < 0.5 {
                rapidRedirectCount += 1
                if rapidRedirectCount > 2 {
                    print("🚫 [Blocked] Rapid redirect chain detected (\(rapidRedirectCount) redirects in <500ms)")
                    decisionHandler(.cancel)
                    return
                }
            } else {
                rapidRedirectCount = 0
            }
            lastNavigationTime = now

            // RULE 6: Third-party detection using base domain comparison (uBlock-style)
            let isThirdPartyNav = isThirdParty(requestURL: targetURL, documentURL: sourceURL)

            if isThirdPartyNav {
                // Third-party programmatic navigation

                // RULE 6a: Block third-party backwards navigation in history (ad redirect pattern)
                if webView.backForwardList.backList.contains(where: { $0.url == targetURL }) {
                    print("🚫 [Blocked] Third-party backwards redirect: \(sourceURL.host ?? "unknown") -> \(targetURL.host ?? "unknown")")
                    decisionHandler(.cancel)
                    return
                }

                // RULE 6b: Block third-party navigation in subframes (common for ad iframes)
                // BUT allow legitimate video/media embeds
                if !isMainFrame {
                    // Allow legitimate video/media domains
                    let legitimateDomains = [
                        "youtube.com", "youtu.be", "youtube-nocookie.com",
                        "vimeo.com", "player.vimeo.com",
                        "dailymotion.com", "dai.ly",
                        "twitch.tv", "player.twitch.tv",
                        "facebook.com", "fb.com",
                        "instagram.com",
                        "twitter.com", "x.com",
                        "tiktok.com",
                        "soundcloud.com",
                        "spotify.com",
                        "reddit.com",
                        "streamable.com",
                        "wistia.com", "fast.wistia.com",
                        "vidyard.com",
                        "brightcove.com",
                        "jwplatform.com", "jwplayer.com",
                        "flowplayer.com",
                        "cloudflare.com", "cloudflarestream.com",
                        "videojs.com",
                        "9animetv.to"
                    ]

                    let targetHost = targetURL.host?.lowercased() ?? ""
                    let isLegitimate = legitimateDomains.contains { domain in
                        targetHost == domain || targetHost.hasSuffix(".\(domain)")
                    }

                    // Also check for known ad patterns in URL
                    let urlString = targetURL.absoluteString.lowercased()
                    let adPatterns = [
                        "/ads/", "/ad/", "/advert", "doubleclick", "googlesyndication",
                        "advertising", "/banner", "/popup", "adserver", "adservice",
                        "/sponsor", "pagead", "adsystem", "adtech"
                    ]
                    let hasAdPattern = adPatterns.contains { urlString.contains($0) }

                    if !isLegitimate || hasAdPattern {
                        print("🚫 [Blocked] Third-party subframe navigation: \(sourceURL.host ?? "unknown") -> \(targetURL.host ?? "unknown")")
                        decisionHandler(.cancel)
                        return
                    } else {
                        print("✅ [Legitimate iframe] Allowing third-party media/video embed: \(targetHost)")
                    }
                }

                // RULE 6c: Allow third-party main frame navigation (might be legitimate oauth/payment)
                // But log it for visibility
                print("⚠️ [Third-party] Allowing main frame third-party navigation: \(sourceURL.host ?? "unknown") -> \(targetURL.host ?? "unknown")")
            } else {
                // First-party programmatic navigation - be more lenient

                // RULE 7: Block backwards programmatic navigation in main frame
                // This prevents pages from redirecting users back to homepage/shallower paths
                if isMainFrame {
                    let sourcePathComponents = sourceURL.pathComponents
                    let targetPathComponents = targetURL.pathComponents

                    // Check if this is backwards navigation (to a shallower path)
                    if targetPathComponents.count < sourcePathComponents.count {
                        print("🚫 [Blocked] Programmatic backwards navigation: \(sourceURL.path) -> \(targetURL.path)")
                        decisionHandler(.cancel)
                        return
                    }

                    // Forward or same-level navigation is OK
                    print("✅ [First-party] Allowing first-party main frame forward navigation")
                    decisionHandler(.allow)
                    return
                }

                // RULE 8: Check suspicious patterns in first-party subframe navigation
                let sourcePathComponents = sourceURL.pathComponents
                let targetPathComponents = targetURL.pathComponents

                // Only block if going backwards AND has suspicious query parameters (tracking)
                if targetPathComponents.count < sourcePathComponents.count {
                    let suspiciousParams = ["ad", "ads", "click", "track", "utm_", "ref=", "affiliate"]
                    let queryString = targetURL.query?.lowercased() ?? ""

                    if suspiciousParams.contains(where: { queryString.contains($0) }) {
                        print("🚫 [Blocked] First-party backwards navigation with tracking params: \(sourceURL.path) -> \(targetURL.path)")
                        decisionHandler(.cancel)
                        return
                    }
                }
            }

            // Default: Allow
            decisionHandler(.allow)
        }

        private func resetRedirectTracking() {
            rapidRedirectCount = 0
            lastNavigationTime = nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🚀 [Navigation Start] URL: \(webView.url?.absoluteString ?? "nil")")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.canGoBack = webView.canGoBack
            parent.title = webView.title ?? webView.url?.host ?? "Sanctuary"
            currentURL = webView.url

            // Add to history
            if let url = webView.url?.absoluteString,
               let title = webView.title ?? webView.url?.host {
                parent.historyManager.addHistoryItem(title: title, url: url)
            }

            print("✅ [Navigation Finish] URL: \(webView.url?.absoluteString ?? "nil"), CanGoBack: \(webView.canGoBack)")
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.canGoBack = webView.canGoBack

            // Also track in didCommit to catch client-side navigation (like YouTube videos)
            if let url = webView.url?.absoluteString,
               let title = webView.title ?? webView.url?.host {
                parent.historyManager.addHistoryItem(title: title, url: url)
            }

            print("📝 [Navigation Commit] URL: \(webView.url?.absoluteString ?? "nil"), CanGoBack: \(webView.canGoBack)")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ [Navigation Fail] Error: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ [Navigation Provisional Fail] Error: \(error.localizedDescription)")
        }
    }
}

struct AddFavoriteView: View {
    @State var initialTitle: String
    @State var initialURL: String
    @ObservedObject var favoritesManager: FavoritesManager
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var dominantColor: Color = Color.gray.opacity(0.15)

    init(initialTitle: String, url: String, favoritesManager: FavoritesManager, isPresented: Binding<Bool>) {
        _initialTitle = State(initialValue: initialTitle)
        _initialURL = State(initialValue: url)
        self.favoritesManager = favoritesManager
        _isPresented = isPresented
    }

    private var faviconURL: String {
        guard let urlObj = URL(string: initialURL),
              let host = urlObj.host else {
            return ""
        }
        return "https://www.google.com/s2/favicons?domain=\(host)&sz=64"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(dominantColor)
                        .frame(width: 80, height: 80)

                    AsyncImage(url: URL(string: faviconURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                                .onAppear {
                                    extractColor(from: image)
                                }
                        default:
                            Image(systemName: "globe")
                                .font(.system(size: 36))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .frame(height: 200)

                VStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("Title", text: $initialTitle)
                                .font(.system(size: 16))

                            if !initialTitle.isEmpty {
                                Button(action: {
                                    initialTitle = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 18))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("URL")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("URL", text: $initialURL)
                                .font(.system(size: 16))
                                .autocapitalization(.none)
                                .keyboardType(.URL)

                            if !initialURL.isEmpty {
                                Button(action: {
                                    initialURL = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 18))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                Button(action: {
                    favoritesManager.addFavorite(title: initialTitle, url: initialURL)
                    dismiss()
                }) {
                    Text("Save")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("Add Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func extractColor(from image: Image) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = URL(string: faviconURL),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data),
               let significantColor = uiImage.dominantColor() {
                DispatchQueue.main.async {
                    var r: CGFloat = 0
                    var g: CGFloat = 0
                    var b: CGFloat = 0
                    var a: CGFloat = 0

                    significantColor.getRed(&r, green: &g, blue: &b, alpha: &a)

                    let pastelR = r + (1.0 - r) * 0.7
                    let pastelG = g + (1.0 - g) * 0.7
                    let pastelB = b + (1.0 - b) * 0.7

                    dominantColor = Color(red: pastelR, green: pastelG, blue: pastelB)
                }
            }
        }
    }
}
