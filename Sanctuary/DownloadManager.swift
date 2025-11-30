//
//  DownloadManager.swift
//  Sanctuary
//
//  Created by Léo Combaret on 30/11/2025.
//

import Foundation
import Combine

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    private init() {}
    
    func downloadVideo(url: URL, filename: String, format: String) async throws {
        print("⬇️ [iOS] Starting download for: \(url.absoluteString)")
        print("📋 [iOS] Requested format: \(format)")
        print("📋 [iOS] Filename: \(filename)")

        // Use the production server URL
        guard let apiUrl = URL(string: "http://localhost:3000/download") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 minutes timeout for large files

        let body: [String: Any] = [
            "url": url.absoluteString,
            "format": format,
            "quality": "best",
            "title": filename
        ]

        print("📤 [iOS] Sending request to backend:")
        print("   URL: \(url.absoluteString)")
        print("   Format: \(format)")
        print("   Quality: best")
        print("   Title: \(filename)")

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (downloadedURL, response) = try await URLSession.shared.download(for: request)

        // Log response details
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 [iOS] Received response:")
            print("   Status code: \(httpResponse.statusCode)")
            print("   Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
            print("   Content-Disposition: \(httpResponse.value(forHTTPHeaderField: "Content-Disposition") ?? "unknown")")
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ [iOS] Server returned error: \(statusCode)")
            throw URLError(.badServerResponse)
        }

        // Move file to Documents directory
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw URLError(.fileDoesNotExist)
        }

        // Ensure filename has correct extension
        let safeFilename = filename.replacingOccurrences(of: "/", with: "_")
        let finalFilename = safeFilename.hasSuffix(".\(format)") ? safeFilename : "\(safeFilename).\(format)"
        let destinationURL = documentsURL.appendingPathComponent(finalFilename)

        // Log temporary file info
        if let fileAttributes = try? fileManager.attributesOfItem(atPath: downloadedURL.path),
           let fileSize = fileAttributes[.size] as? Int64 {
            print("📦 [iOS] Downloaded file info:")
            print("   Temp path: \(downloadedURL.path)")
            print("   File size: \(fileSize) bytes (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
        }

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
            print("   Requested format: \(format)")
            print("   Final filename: \(finalFilename)")
            print("   File size: \(fileSize) bytes (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
        }
    }
}
