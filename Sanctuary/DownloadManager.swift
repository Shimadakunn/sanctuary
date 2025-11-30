//
//  DownloadManager.swift
//  Sanctuary
//
//  Created by Léo Combaret on 30/11/2025.
//

import Foundation
import Combine

struct VideoInfoResponse: Codable {
    let title: String?
    let url: String
    let thumbnail: String?
}

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    private init() {}
    
    func downloadVideo(url: URL, filename: String, format: String) async throws {
        print("⬇️ [iOS] Starting download process for: \(url.absoluteString)")
        
        // 1. Request the direct download link from the backend
        guard let apiUrl = URL(string: "https://sanctuary-378h.vercel.app/download") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Timeout for obtaining the link

        // We send the format preferences, though actual result depends on backend capabilities
        let body: [String: Any] = [
            "url": url.absoluteString,
            "format": format,
            "quality": "best"
        ]

        print("📤 [iOS] Requesting video info from backend...")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode != 200 {
            print("❌ [iOS] Backend error: \(httpResponse.statusCode)")
            // Try to parse error message if available
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? String {
                print("❌ [iOS] Error details: \(errorMessage)")
            }
            throw URLError(.badServerResponse)
        }

        // Parse the JSON response to get the direct URL
        let videoInfo = try JSONDecoder().decode(VideoInfoResponse.self, from: data)
        
        guard let directDownloadURL = URL(string: videoInfo.url) else {
            print("❌ [iOS] Invalid direct URL returned")
            throw URLError(.badURL)
        }

        print("✅ [iOS] Received direct link: \(directDownloadURL.host ?? "unknown")")

        // 2. Download the actual file from the direct link
        print("⬇️ [iOS] Starting file download...")
        var downloadRequest = URLRequest(url: directDownloadURL)
        downloadRequest.timeoutInterval = 300 // 5 minutes for large files
        
        let (downloadedURL, downloadResponse) = try await URLSession.shared.download(for: downloadRequest)

        if let httpDownloadResponse = downloadResponse as? HTTPURLResponse {
            print("📥 [iOS] File download status: \(httpDownloadResponse.statusCode)")
            print("   Content-Type: \(httpDownloadResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
            print("   Size: \(httpDownloadResponse.expectedContentLength) bytes")
            
            guard httpDownloadResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        }

        // 3. Move file to Documents directory
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw URLError(.fileDoesNotExist)
        }

        // Ensure filename has correct extension
        let safeFilename = filename.replacingOccurrences(of: "/", with: "_")
        let finalFilename = safeFilename.hasSuffix(".\(format)") ? safeFilename : "\(safeFilename).\(format)"
        let destinationURL = documentsURL.appendingPathComponent(finalFilename)

        // Remove existing file if needed
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: downloadedURL, to: destinationURL)

        // Log final file info
        if let fileAttributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
           let fileSize = fileAttributes[.size] as? Int64 {
            print("✅ [iOS] File saved successfully:")
            print("   Path: \(destinationURL.path)")
            print("   File size: \(fileSize) bytes (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
        }
    }
}
