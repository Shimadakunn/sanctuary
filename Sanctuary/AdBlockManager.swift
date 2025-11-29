//
//  AdBlockManager.swift
//  Sanctuary
//
//  Manages ad blocking filter lists with fetching and caching
//

import Foundation
import Combine

class AdBlockManager: ObservableObject {
    static let shared = AdBlockManager()

    @Published var isLoading = false
    @Published var lastUpdated: Date?

    private var blockedDomains: Set<String> = []
    private var blockedPatterns: [String] = []
    private let cacheKey = "cachedAdDomains"
    private let lastUpdateKey = "lastAdBlockUpdate"
    private let updateInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    // Fallback hardcoded domains (used if fetching fails)
    private let fallbackDomains: Set<String> = [
        "freedomnetvpn.com",
        "vpn-site.com",
        "click.vpn-site.com",
        "doubleclick.net",
        "googlesyndication.com",
        "googleadservices.com",
        "adservice.google.com",
        "advertising.com",
        "ad.doubleclick.net",
        "ads.google.com",
        "clickadu.com",
        "propellerads.com",
        "popads.net",
        "popcash.net",
        "adsterra.com",
        "exoclick.com",
        "juicyads.com",
        "trafficjunky.com",
        "outbrain.com",
        "taboola.com",
        "infolinks.com",
        "router.infolinks.com",
        "resources.infolinks.com",
        "a-ads.com",
        "ad.a-ads.com",
        "adskeeper.com",
        "clck.adskeeper.com",
        "jads.co",
        "mgid.com",
        "adnium.com",
        "revenuehits.com",
        "hilltopads.com",
        "adcolony.com",
        "bidvertiser.com",
        "chitika.com",
        "adversal.com",
        "adf.ly",
        "adfly.com",
        "linkbucks.com",
        "bc.vc",
        "adfoc.us",
        "shorte.st",
        "ouo.io",
        "adsco.re",
        "adserver.com",
        "adtech.de",
        "serving-sys.com",
        "mathtag.com",
        "media.net",
        "revcontent.com",
        "contentabc.com",
        "monetag.com",
        "adstyle.com",
        "adserverpub.com",
        "prebid.org",
        "casalemedia.com",
        "criteo.com",
        "pubmatic.com",
        "rubiconproject.com",
        "openx.net",
        "indexww.com",
        "adsafeprotected.com",
        "moatads.com",
        "smartadserver.com"
    ]

    private init() {
        loadCachedDomains()

        // Fetch new filters if cache is old or doesn't exist
        if shouldUpdateFilters() {
            Task {
                await fetchAndUpdateFilters()
            }
        }
    }

    // MARK: - Public Methods

    func isBlocked(domain: String) -> Bool {
        let lowercaseDomain = domain.lowercased()

        // Check direct domain match
        if blockedDomains.contains(lowercaseDomain) {
            return true
        }

        // Check if domain ends with any blocked domain (subdomain matching)
        for blockedDomain in blockedDomains {
            if lowercaseDomain == blockedDomain || lowercaseDomain.hasSuffix("." + blockedDomain) {
                return true
            }
        }

        return false
    }

    func isBlocked(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return isBlocked(domain: host)
    }

    func forceUpdate() async {
        await fetchAndUpdateFilters()
    }

    // MARK: - Private Methods

    private func shouldUpdateFilters() -> Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastUpdate) > updateInterval
    }

    private func loadCachedDomains() {
        if let cached = UserDefaults.standard.array(forKey: cacheKey) as? [String] {
            blockedDomains = Set(cached)
            lastUpdated = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date
            print("📋 [AdBlockManager] Loaded \(blockedDomains.count) cached domains")
        } else {
            // Use fallback if no cache exists
            blockedDomains = fallbackDomains
            print("📋 [AdBlockManager] Using fallback domains (\(fallbackDomains.count))")
        }
    }

    private func saveCachedDomains() {
        UserDefaults.standard.set(Array(blockedDomains), forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
        lastUpdated = Date()
        print("💾 [AdBlockManager] Saved \(blockedDomains.count) domains to cache")
    }

    private func fetchAndUpdateFilters() async {
        await MainActor.run {
            isLoading = true
        }

        print("🔄 [AdBlockManager] Fetching filter lists...")

        var newDomains = Set<String>()

        // Load assets.json
        guard let assetsURL = Bundle.main.url(forResource: "assets", withExtension: "json"),
              let assetsData = try? Data(contentsOf: assetsURL),
              let assetsJSON = try? JSONSerialization.jsonObject(with: assetsData) as? [String: [String: Any]] else {
            print("❌ [AdBlockManager] Failed to load assets.json")
            await MainActor.run {
                isLoading = false
            }
            return
        }

        // Extract filter lists we want to use (ads, malware, privacy)
        let filterKeys = ["ublock-filters", "easylist", "plowe-0", "urlhaus-1"]

        for key in filterKeys {
            guard let filterInfo = assetsJSON[key],
                  let contentURLs = filterInfo["contentURL"] as? [String] else {
                continue
            }

            // Try each URL until one works
            for urlString in contentURLs {
                if let domains = await fetchFilterList(urlString: urlString) {
                    newDomains.formUnion(domains)
                    print("✅ [AdBlockManager] Fetched \(domains.count) domains from \(key)")
                    break
                }
            }
        }

        // If we got new domains, update the cache
        if !newDomains.isEmpty {
            await MainActor.run {
                blockedDomains = newDomains.union(fallbackDomains)
                saveCachedDomains()
                isLoading = false
            }
            print("✅ [AdBlockManager] Updated with \(blockedDomains.count) total domains")
        } else {
            // If fetching failed, keep existing cache or use fallback
            await MainActor.run {
                if blockedDomains.isEmpty {
                    blockedDomains = fallbackDomains
                }
                isLoading = false
            }
            print("⚠️ [AdBlockManager] Failed to fetch filters, using cached/fallback domains")
        }
    }

    private func fetchFilterList(urlString: String) async -> Set<String>? {
        // Handle both remote URLs and local bundle files
        var data: Data?

        if urlString.hasPrefix("http") {
            // Fetch from remote URL
            guard let url = URL(string: urlString) else { return nil }

            do {
                let (fetchedData, _) = try await URLSession.shared.data(from: url)
                data = fetchedData
            } catch {
                print("⚠️ [AdBlockManager] Failed to fetch \(urlString): \(error)")
                return nil
            }
        } else {
            // Load from bundle
            let fileName = urlString.replacingOccurrences(of: "assets/", with: "")
            let components = fileName.split(separator: "/")

            if components.count >= 2 {
                let directory = String(components[0])
                let fileNameWithExt = String(components[1])
                let fileComponents = fileNameWithExt.split(separator: ".")

                if fileComponents.count >= 2 {
                    let name = fileComponents.dropLast().joined(separator: ".")
                    let ext = String(fileComponents.last!)

                    if let bundleURL = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: directory) {
                        data = try? Data(contentsOf: bundleURL)
                    }
                }
            }
        }

        guard let filterData = data,
              let content = String(data: filterData, encoding: .utf8) else {
            return nil
        }

        return parseFilterList(content: content)
    }

    private func parseFilterList(content: String) -> Set<String> {
        var domains = Set<String>()
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("!") || trimmed.hasPrefix("#") {
                continue
            }

            // Parse hosts file format (e.g., "0.0.0.0 ad.domain.com" or "127.0.0.1 ad.domain.com")
            if trimmed.hasPrefix("0.0.0.0 ") || trimmed.hasPrefix("127.0.0.1 ") {
                let components = trimmed.components(separatedBy: .whitespaces)
                if components.count >= 2 {
                    let domain = components[1].lowercased()
                    if !domain.isEmpty && domain != "localhost" {
                        domains.insert(domain)
                    }
                }
                continue
            }

            // Parse adblock filter format (e.g., "||domain.com^")
            if trimmed.hasPrefix("||") && trimmed.contains("^") {
                var domain = trimmed.replacingOccurrences(of: "||", with: "")
                if let caretIndex = domain.firstIndex(of: "^") {
                    domain = String(domain[..<caretIndex])
                }
                domain = domain.lowercased()

                // Only add if it looks like a domain (contains a dot, no slashes)
                if domain.contains(".") && !domain.contains("/") {
                    domains.insert(domain)
                }
                continue
            }
        }

        return domains
    }
}
