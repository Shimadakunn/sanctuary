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
    @State private var showMenuSheet = false

    var body: some View {
        ZStack {
            WebViewWrapper(url: url, canGoBack: $canGoBack, title: $title, webViewStore: webViewStore, historyManager: historyManager)
                .ignoresSafeArea(edges: .bottom)

            VStack {
                Spacer()

                HStack {
                    Button(action: {
                        // Check the WebView's actual canGoBack state directly (more reliable than binding)
                        let webViewCanGoBack = webViewStore.webView?.canGoBack ?? false
                        print("⬅️ [Back Button Pressed] CanGoBack Binding: \(canGoBack), WebView CanGoBack: \(webViewCanGoBack)")

                        if webViewCanGoBack {
                            print("⬅️ [Back Button] Calling webView.goBack()")
                            webViewStore.webView?.goBack()
                        } else {
                            print("⬅️ [Back Button] Calling onBack() - returning to home")
                            onBack()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.buttonOverlay)
                                .frame(width: 50, height: 50)

                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 20)

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showMenuSheet = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.buttonOverlay)
                                .frame(width: 50, height: 50)

                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 100)
            }

            if showMenuSheet {
                Color.overlayDim
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showMenuSheet = false
                        }
                    }
                    .transition(.opacity)
            }

            if showMenuSheet {
                VStack {
                    Spacer()

                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.adaptiveSecondaryLabel.opacity(0.4))
                            .frame(width: 40, height: 4)
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showMenuSheet = false
                            }
                            if let url = webViewStore.webView?.url {
                                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootVC = windowScene.windows.first?.rootViewController {
                                    rootVC.present(activityVC, animated: true)
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                    .frame(width: 24)

                                Text("Share".localized)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                        }

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showMenuSheet = false
                            }
                            webViewStore.webView?.reload()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                    .frame(width: 24)

                                Text("Reload".localized)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                        }

                        Button(action: {
                            let currentURL = webViewStore.webView?.url?.absoluteString ?? ""
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if favoritesManager.isFavorite(url: currentURL) {
                                    favoritesManager.removeFavorite(url: currentURL)
                                    showMenuSheet = false
                                } else {
                                    showMenuSheet = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showAddFavoriteSheet = true
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: favoritesManager.isFavorite(url: webViewStore.webView?.url?.absoluteString) ? "heart.fill" : "heart")
                                    .font(.system(size: 18))
                                    .foregroundColor(favoritesManager.isFavorite(url: webViewStore.webView?.url?.absoluteString) ? .red : .primary)
                                    .frame(width: 24)

                                Text(favoritesManager.isFavorite(url: webViewStore.webView?.url?.absoluteString) ? "Remove from Favorites".localized : "Add to Favorites".localized)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                        }

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showMenuSheet = false
                            }
                            onGoHome()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                    .frame(width: 24)

                                Text("Home".localized)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                        }

                        Divider()
                            .background(Color.secondary.opacity(0.3))
                            .padding(.vertical, 8)

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showMenuSheet = false
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                    .frame(width: 24)

                                Text("Hide".localized)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                        }
                        .padding(.bottom, 20)
                    }
                    .background(Color.sheetBackground)
                    .cornerRadius(topRadius: 40, bottomRadius: 60)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
                .transition(.move(edge: .bottom))
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
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    func cornerRadius(topRadius: CGFloat, bottomRadius: CGFloat) -> some View {
        clipShape(DifferentCornerRadius(topRadius: topRadius, bottomRadius: bottomRadius))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct DifferentCornerRadius: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let topLeft = CGPoint(x: rect.minX, y: rect.minY + topRadius)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY + topRadius)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY - bottomRadius)

        path.move(to: topLeft)
        path.addArc(center: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
                    radius: topRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius),
                    radius: topRadius,
                    startAngle: .degrees(270),
                    endAngle: .degrees(0),
                    clockwise: false)
        path.addLine(to: bottomRight)
        path.addArc(center: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY - bottomRadius),
                    radius: bottomRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomRadius),
                    radius: bottomRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false)
        path.closeSubpath()

        return path
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

        // Add message handler for click tracking
        configuration.userContentController.add(context.coordinator, name: "clickHandler")

        // Inject JavaScript to track clicks and handle link navigation
        let clickTrackerScript = """
        document.addEventListener('click', function(event) {
            const element = event.target;
            const link = element.tagName === 'A' ? element : element.closest('a');

            const clickInfo = {
                tagName: element.tagName,
                id: element.id || 'none',
                className: element.className || 'none',
                text: element.textContent?.substring(0, 50) || 'none',
                href: element.href || link?.href || 'none',
                x: event.clientX,
                y: event.clientY,
                isLink: !!link,
                linkTarget: link?.target || 'none',
                hasOnClick: !!(element.onclick || link?.onclick),
                defaultPrevented: event.defaultPrevented
            };

            window.webkit.messageHandlers.clickHandler.postMessage(clickInfo);

            // If it's a link with target="_blank" or similar, load it in the current window
            if (link && link.href && link.target === '_blank') {
                console.log('📎 Intercepting target="_blank" link:', link.href);
                event.preventDefault();
                window.location.href = link.href;
            }
        }, true);
        """

        let clickScript = WKUserScript(source: clickTrackerScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(clickScript)

        // Inject JavaScript to block pop-ups and ads
        let popupBlockerScript = """
        // Block window.open pop-ups
        window.open = function() {
            console.log('🚫 Pop-up blocked by JavaScript');
            return null;
        };

        // Inject CSS to hide common ad elements
        (function() {
            const style = document.createElement('style');
            style.textContent = `
                iframe[src*="infolinks"],
                iframe[src*="a-ads"],
                iframe[src*="ad."],
                iframe[src*="/ad/"],
                iframe[src*="/Ads/"],
                iframe[src*="ads."],
                iframe[src*="doubleclick"],
                iframe[src*="googlesyndication"],
                iframe[src*="advertising"],
                iframe[src*="adskeeper"],
                iframe[src*="mgid"],
                iframe[src*="taboola"],
                iframe[src*="outbrain"],
                iframe[src*="revcontent"],
                iframe[src*="contentabc"],
                iframe[src*="propeller"],
                iframe[src*="clickadu"],
                iframe[src*="bid"],
                iframe[src*="/banner"],
                iframe[src*="adserver"],
                iframe[sandbox*="allow-scripts"][src*="/"],
                div[id*="ad-"],
                div[class*="ad-"],
                div[id*="_ad_"],
                div[class*="_ad_"],
                div[class*="mg-"],
                div[id*="mg-"],
                div[class*="mgline"],
                div[id*="mgline"],
                div[class*="adskeeper"],
                div[id*="adskeeper"],
                div[class*="taboola"],
                div[id*="taboola"],
                div[class*="outbrain"],
                div[id*="outbrain"],
                div[class*="sponsored"],
                div[id*="sponsored"],
                .advertisement,
                .ad-container,
                .ad-banner,
                .ad-widget,
                .ad-content,
                .ads-wrapper,
                .mgbox,
                .mg-box,
                .mgline,
                .mg-line,
                .adsbox,
                .ad-placement,
                .sponsored-content,
                .native-ad,
                [class*="AdSpace"],
                [id*="AdSpace"],
                [class*="ad_wrapper"],
                [id*="ad_wrapper"],
                [data-ad],
                [data-ad-slot],
                ins.adsbygoogle,
                .IL_AD,
                .IL_INSEARCH,
                .IL_RELATED,
                .il_container,
                .inlinks_container,
                .infolinks-container,
                span[class*="IL_"],
                div[class*="IL_"],
                a[href*="infolinks"],
                a[href*="clk.htm"],
                script[src*="infolinks"],
                [data-il-target],
                [data-infolinks],
                .yrt-related,
                .txt-lnk-ad,
                .ilframe,
                .il-ad-container {
                    display: none !important;
                    visibility: hidden !important;
                    width: 0 !important;
                    height: 0 !important;
                    opacity: 0 !important;
                    pointer-events: none !important;
                }
            `;
            document.head.appendChild(style);

            // Aggressively remove ad elements from the DOM
            function removeAdElements() {
                // Remove ad iframes
                const adPatterns = ['/ads/', '/Ads/', 'bid', 'banner', 'adserver',
                                   'adskeeper', 'mgid', 'taboola', 'outbrain',
                                   'googlesyndication', 'doubleclick', 'advertising'];

                const iframes = document.querySelectorAll('iframe');
                iframes.forEach(iframe => {
                    const src = iframe.getAttribute('src') || '';
                    const lowerSrc = src.toLowerCase();

                    for (const pattern of adPatterns) {
                        if (lowerSrc.includes(pattern.toLowerCase())) {
                            console.log('🗑️ Removing ad iframe:', src);
                            iframe.remove();
                            break;
                        }
                    }

                    // Also remove iframes with sandbox attribute (common for ads)
                    if (iframe.hasAttribute('sandbox') && src.includes('/')) {
                        const sandbox = iframe.getAttribute('sandbox');
                        if (sandbox.includes('allow-scripts')) {
                            console.log('🗑️ Removing sandboxed iframe:', src);
                            iframe.remove();
                        }
                    }
                });

                // Remove Infolinks elements
                const infolinksSelectors = [
                    '.IL_AD', '.IL_INSEARCH', '.IL_RELATED', '.il_container',
                    '.inlinks_container', '.infolinks-container', 'span[class*="IL_"]',
                    'div[class*="IL_"]', 'a[href*="infolinks"]', 'a[href*="clk.htm"]',
                    '[data-il-target]', '[data-infolinks]', '.txt-lnk-ad', '.ilframe'
                ];

                infolinksSelectors.forEach(selector => {
                    document.querySelectorAll(selector).forEach(el => {
                        console.log('🗑️ Removing Infolinks element:', selector);
                        el.remove();
                    });
                });

                // Remove Infolinks scripts
                document.querySelectorAll('script[src*="infolinks"]').forEach(script => {
                    console.log('🗑️ Removing Infolinks script');
                    script.remove();
                });

                // Remove any links with ad tracking patterns
                document.querySelectorAll('a').forEach(link => {
                    const href = link.getAttribute('href') || '';
                    if (href.includes('clk.htm') || href.includes('infolinks.com') ||
                        href.includes('adskeeper') || href.includes('mgid.com')) {
                        console.log('🗑️ Removing ad link:', href);
                        link.remove();
                    }
                });
            }

            // Run immediately and on DOM changes
            removeAdElements();
            setInterval(removeAdElements, 500);

            const observer = new MutationObserver(() => {
                removeAdElements();
            });
            observer.observe(document.documentElement, { childList: true, subtree: true });
        })();

        // Block ad scripts from loading
        (function() {
            const originalAppendChild = Node.prototype.appendChild;
            const originalInsertBefore = Node.prototype.insertBefore;

            function shouldBlockElement(element) {
                if (element.tagName === 'SCRIPT') {
                    const src = element.src || element.getAttribute('src') || '';
                    const adScriptPatterns = ['infolinks', 'adskeeper', 'mgid', 'taboola',
                                             'outbrain', 'googlesyndication', 'doubleclick',
                                             'advertising', 'adserver', 'propeller', 'clickadu'];

                    for (const pattern of adScriptPatterns) {
                        if (src.toLowerCase().includes(pattern)) {
                            console.log('🚫 Blocked ad script:', src);
                            return true;
                        }
                    }
                }
                return false;
            }

            Node.prototype.appendChild = function(element) {
                if (shouldBlockElement(element)) {
                    return element;
                }
                return originalAppendChild.call(this, element);
            };

            Node.prototype.insertBefore = function(element, reference) {
                if (shouldBlockElement(element)) {
                    return element;
                }
                return originalInsertBefore.call(this, element, reference);
            };
        })();

        // Block common ad insertion methods
        (function() {
            // Store original methods
            const originalCreateElement = document.createElement;

            // Override createElement to block ad iframes and scripts
            document.createElement = function(tagName) {
                const element = originalCreateElement.call(document, tagName);

                if (tagName.toLowerCase() === 'iframe') {
                    // Monitor iframe src changes
                    const originalSetAttribute = element.setAttribute;
                    element.setAttribute = function(name, value) {
                        if (name === 'src' && value) {
                            const adPatterns = [
                                'ad', 'banner', 'popup', 'tracker',
                                'doubleclick', 'googlesyndication',
                                'infolinks', 'a-ads', '/ads/', '/Ads/',
                                'advertising', 'adservice', 'adskeeper',
                                'mgid', 'taboola', 'outbrain',
                                'revcontent', 'propeller', 'clickadu',
                                'adsterra', 'exoclick', 'popads',
                                'popcash', 'criteo', 'pubmatic',
                                'rubiconproject', 'openx', 'sponsored',
                                'native-ad', 'mgline', 'mgbox', 'bid',
                                'adserver', 'advert', '/banner'
                            ];
                            const lowerValue = value.toLowerCase();

                            for (const pattern of adPatterns) {
                                if (lowerValue.includes(pattern)) {
                                    console.log('🚫 Ad iframe blocked:', value);
                                    return;
                                }
                            }
                        }
                        return originalSetAttribute.call(this, name, value);
                    };
                }

                return element;
            };
        })();

        // Block common redirect techniques
        let isRedirecting = false;
        const originalPushState = history.pushState;
        const originalReplaceState = history.replaceState;

        history.pushState = function() {
            if (!isRedirecting) {
                return originalPushState.apply(this, arguments);
            }
        };

        history.replaceState = function() {
            if (!isRedirecting) {
                return originalReplaceState.apply(this, arguments);
            }
        };
        """

        let userScript = WKUserScript(source: popupBlockerScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)

        // Suppress JavaScript dialogs (alert, confirm, prompt) to prevent ad pop-ups
        configuration.suppressesIncrementalRendering = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
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

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: WebViewWrapper
        var currentURL: URL?

        // Reference to the shared AdBlockManager
        private let adBlockManager = AdBlockManager.shared

        // Suspicious URL patterns (for tracking/ad redirects)
        private let suspiciousPatterns = [
            "preland",
            "tracker",
            "redirect",
            "aff_",
            "click",
            "track",
            "zoneid",
            "bannerid",
            "campaignid",
            "clk.htm",
            "usync",
            "/action/clk",
            "ad-click",
            "adclick",
            "ghits",
            "clck.",
            "adskeeper",
            "mgline",
            "ads-click",
            "adserve",
            "adserver",
            "/ads/",
            "outbrain",
            "taboola",
            "sponsored",
            "popup",
            "popunder",
            "interstitial"
        ]

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        private func isAdDomain(_ url: URL) -> Bool {
            return adBlockManager.isBlocked(url: url)
        }

        private func hasSuspiciousPattern(_ url: URL) -> Bool {
            let urlString = url.absoluteString.lowercased()

            // Check for suspicious patterns in URL
            for pattern in suspiciousPatterns {
                if urlString.contains(pattern) {
                    return true
                }
            }

            return false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            print("🔍 [Navigation Policy] Type: \(navigationAction.navigationType.rawValue), URL: \(navigationAction.request.url?.absoluteString ?? "nil"), TargetFrame: \(navigationAction.targetFrame != nil ? "present" : "nil"), SourceFrame: \(navigationAction.sourceFrame.request.url?.absoluteString ?? "nil")")

            // Always allow user-initiated back/forward navigation
            if navigationAction.navigationType == .backForward {
                print("✅ [Back/Forward Navigation] Allowing user navigation")
                decisionHandler(.allow)
                return
            }

            // Always allow about:blank (used by many sites for internal operations)
            if let targetURL = navigationAction.request.url,
               targetURL.absoluteString == "about:blank" {
                print("✅ [Navigation Allowed] about:blank")
                decisionHandler(.allow)
                return
            }

            guard let targetURL = navigationAction.request.url else {
                print("🚫 [Navigation Blocked] No target URL")
                decisionHandler(.cancel)
                return
            }

            // HANDLE NEW WINDOW/TAB REQUESTS: Instead of blocking, load in current frame
            if navigationAction.targetFrame == nil {
                // Check if this is likely an ad/malicious pop-up or a legitimate link
                let isLikelyAd = isAdDomain(targetURL) || hasSuspiciousPattern(targetURL)

                if isLikelyAd {
                    print("🚫 [Pop-up Blocked] Ad/malicious pop-up blocked: \(targetURL.absoluteString)")
                    decisionHandler(.cancel)
                    return
                } else {
                    // Load legitimate links in the current frame instead of blocking
                    print("🔄 [Pop-up Redirected] Loading in current frame: \(targetURL.absoluteString)")
                    webView.load(URLRequest(url: targetURL))
                    decisionHandler(.cancel)
                    return
                }
            }

            // BLOCK AD DOMAINS: Block known ad/tracking domains
            if isAdDomain(targetURL) {
                print("🚫 [Ad Blocked] Blocked ad domain: \(targetURL.host ?? "unknown")")
                decisionHandler(.cancel)
                return
            }

            // BLOCK SUSPICIOUS REDIRECTS: If navigating from a legitimate source to a URL with suspicious patterns
            if let sourceURL = navigationAction.sourceFrame.request.url,
               sourceURL.host != targetURL.host,
               hasSuspiciousPattern(targetURL) {
                print("🚫 [Suspicious URL Blocked] Blocked suspicious redirect: \(targetURL.absoluteString)")
                decisionHandler(.cancel)
                return
            }

            // Block "other" type navigation that appears to be going backwards
            if navigationAction.navigationType == .other {
                if let sourceURL = navigationAction.sourceFrame.request.url {

                    // Allow same-page navigation (anchors, hash changes)
                    if sourceURL.absoluteString == targetURL.absoluteString {
                        decisionHandler(.allow)
                        return
                    }

                    // Block cross-origin backwards navigation (e.g., site redirecting back to Google)
                    if sourceURL.host != targetURL.host,
                       webView.backForwardList.backList.contains(where: { $0.url == targetURL }) {
                        print("🚫 [Navigation Blocked] Cross-origin backwards redirect from \(sourceURL.host ?? "unknown") to \(targetURL.host ?? "unknown")")
                        decisionHandler(.cancel)
                        return
                    }

                    // Check if this is a suspicious same-host backwards navigation
                    // (navigating to a simpler/parent URL from a more complex one)
                    let sourcePathComponents = sourceURL.pathComponents
                    let targetPathComponents = targetURL.pathComponents

                    // If target has fewer path components and same host, it's likely unwanted back navigation
                    if sourceURL.host == targetURL.host,
                       targetPathComponents.count < sourcePathComponents.count,
                       sourceURL.absoluteString != targetURL.absoluteString {
                        print("🚫 [Navigation Blocked] Suspicious backwards navigation from \(sourceURL.path) to \(targetURL.path)")
                        decisionHandler(.cancel)
                        return
                    }
                }
            }

            print("✅ [Navigation Allowed] URL: \(targetURL.absoluteString)")
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🚀 [Navigation Start] URL: \(webView.url?.absoluteString ?? "nil")")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.canGoBack = webView.canGoBack
            parent.title = webView.title ?? webView.url?.host ?? "Sanctuary"
            currentURL = webView.url

            // Add to history
            if let url = webView.url?.absoluteString {
                let pageTitle = webView.title?.isEmpty == false ? webView.title : webView.url?.host
                let finalTitle = pageTitle ?? url
                parent.historyManager.addHistoryItem(title: finalTitle, url: url)
            }

            print("✅ [Navigation Finish] URL: \(webView.url?.absoluteString ?? "nil"), CanGoBack: \(webView.canGoBack)")
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.canGoBack = webView.canGoBack

            // Also track in didCommit to catch client-side navigation (like YouTube videos)
            if let url = webView.url?.absoluteString {
                let pageTitle = webView.title?.isEmpty == false ? webView.title : webView.url?.host
                let finalTitle = pageTitle ?? url
                parent.historyManager.addHistoryItem(title: finalTitle, url: url)
            }

            print("📝 [Navigation Commit] URL: \(webView.url?.absoluteString ?? "nil"), CanGoBack: \(webView.canGoBack)")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ [Navigation Fail] Error: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ [Navigation Provisional Fail] Error: \(error.localizedDescription)")
        }

        // MARK: - WKUIDelegate (Pop-up blocking)

        // Block new window creation (pop-ups)
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            print("🚫 [Pop-up Blocked] Prevented new window creation: \(navigationAction.request.url?.absoluteString ?? "unknown")")
            // Return nil to prevent the pop-up from opening
            return nil
        }

        // Block JavaScript alert dialogs (often used for ads)
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            // Check if this looks like an ad alert
            let adKeywords = ["winner", "prize", "click here", "congratulations", "virus", "infected"]
            let lowercaseMessage = message.lowercased()

            for keyword in adKeywords {
                if lowercaseMessage.contains(keyword) {
                    print("🚫 [Ad Alert Blocked] Message: \(message)")
                    completionHandler()
                    return
                }
            }

            // For legitimate alerts, you can choose to show them or block all
            // For now, blocking all to prevent ad interruptions
            print("⚠️ [Alert Blocked] Message: \(message)")
            completionHandler()
        }

        // Block JavaScript confirm dialogs
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            print("🚫 [Confirm Dialog Blocked] Message: \(message)")
            // Always return false to decline
            completionHandler(false)
        }

        // Block JavaScript text input dialogs
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            print("🚫 [Text Input Dialog Blocked] Prompt: \(prompt)")
            completionHandler(nil)
        }

        // MARK: - WKScriptMessageHandler (Click tracking)

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "clickHandler", let clickInfo = message.body as? [String: Any] {
                let tagName = clickInfo["tagName"] as? String ?? "unknown"
                let id = clickInfo["id"] as? String ?? "none"
                let className = clickInfo["className"] as? String ?? "none"
                let text = clickInfo["text"] as? String ?? "none"
                let href = clickInfo["href"] as? String ?? "none"
                let x = clickInfo["x"] as? Double ?? 0
                let y = clickInfo["y"] as? Double ?? 0
                let isLink = clickInfo["isLink"] as? Bool ?? false
                let linkTarget = clickInfo["linkTarget"] as? String ?? "none"
                let hasOnClick = clickInfo["hasOnClick"] as? Bool ?? false
                let defaultPrevented = clickInfo["defaultPrevented"] as? Bool ?? false

                print("👆 [User Click] Tag: <\(tagName)>, Link: \(isLink ? "YES" : "NO"), Target: \(linkTarget), OnClick: \(hasOnClick ? "YES" : "NO"), DefaultPrevented: \(defaultPrevented ? "YES" : "NO")")
                print("   ↳ ID: \(id), Class: \(className), Text: \"\(text)\"")
                print("   ↳ URL: \(href), Position: (\(Int(x)), \(Int(y)))")
            }
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
                        Text("Title".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("Title".localized, text: $initialTitle)
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
                        Text("URL".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("URL".localized, text: $initialURL)
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
                    Text("Save".localized)
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
            .navigationTitle("Add Favorite".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) {
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
