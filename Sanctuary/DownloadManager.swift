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
        print("⬇️ [DownloadManager] Starting download for: \(url.absoluteString)")
        
        // Assuming the backend is running on localhost:3000
        // Use localhost directly. Ensure NSAppTransportSecurity allows it.
        guard let apiUrl = URL(string: "http://localhost:3000/api/download") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 minutes timeout for large files
        
        let body: [String: Any] = [
            "url": url.absoluteString,
            "format": format,
            "quality": "best"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (downloadedURL, response) = try await URLSession.shared.download(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ [DownloadManager] Server returned error: \(statusCode)")
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
        
        // Remove existing file if needed
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.moveItem(at: downloadedURL, to: destinationURL)
        print("✅ [DownloadManager] File saved to: \(destinationURL.path)")
    }
}
