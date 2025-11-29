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
                            .padding(.bottom, 12)

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

                                Text("Share")
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

                                Text("Reload")
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

                                Text(favoritesManager.isFavorite(url: webViewStore.webView?.url?.absoluteString) ? "Remove from Favorites" : "Add to Favorites")
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

                                Text("Home")
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

                                Text("Hide")
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

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            print("🔍 [Navigation Policy] Type: \(navigationAction.navigationType.rawValue), URL: \(navigationAction.request.url?.absoluteString ?? "nil"), SourceFrame: \(navigationAction.sourceFrame.request.url?.absoluteString ?? "nil")")

            // Always allow about:blank (used by many sites for internal operations)
            if let targetURL = navigationAction.request.url,
               targetURL.absoluteString == "about:blank" {
                decisionHandler(.allow)
                return
            }

            // Block "other" type navigation that appears to be going backwards
            if navigationAction.navigationType == .other {
                if let sourceURL = navigationAction.sourceFrame.request.url,
                   let targetURL = navigationAction.request.url {

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
