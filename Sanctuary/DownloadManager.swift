//
//  DownloadManager.swift
//  Sanctuary
//
//  Created by Léo Combaret on 30/11/2025.
//

import Foundation
import Combine

struct StartDownloadResponse: Codable {
    let sessionId: String
    let filename: String
}

struct ProgressResponse: Codable {
    let status: String
    let progress: Double
    let filename: String
    let error: String?
}

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    // Configure your backend URL here
    private let backendURL = "http://192.168.1.124:3000"

    @Published var currentProgress: Double = 0
    @Published var currentStatus: String = ""
    @Published var isDownloading: Bool = false

    private init() {}

    func downloadVideo(url: URL, filename: String, format: String, quality: String) async throws {
        await MainActor.run {
            self.isDownloading = true
            self.currentProgress = 0
            self.currentStatus = "Starting..."
        }

        print("⬇️ [iOS] Starting download process for: \(url.absoluteString)")

        // 1. Start the download and get session ID
        guard let startUrl = URL(string: "\(backendURL)/start") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: startUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let backendFormat = format == "mp3" ? "audio" : "video"

        let body: [String: Any] = [
            "url": url.absoluteString,
            "format": backendFormat,
            "quality": quality,
            "title": filename
        ]

        print("📤 [iOS] Sending start request to backend...")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (startData, startResponse) = try await URLSession.shared.data(for: request)

        guard let httpResponse = startResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            await MainActor.run {
                self.isDownloading = false
            }
            throw URLError(.badServerResponse)
        }

        let startResult = try JSONDecoder().decode(StartDownloadResponse.self, from: startData)
        print("✅ [iOS] Download started with session ID: \(startResult.sessionId)")

        // 2. Poll for progress
        let sessionId = startResult.sessionId
        var completed = false
        var lastProgress: Double = 0

        while !completed {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            guard let progressUrl = URL(string: "\(backendURL)/progress/\(sessionId)") else {
                continue
            }

            let (progressData, _) = try await URLSession.shared.data(from: progressUrl)
            let progressResult = try JSONDecoder().decode(ProgressResponse.self, from: progressData)

            await MainActor.run {
                self.currentProgress = progressResult.progress / 100.0
                switch progressResult.status {
                case "pending":
                    self.currentStatus = "Preparing..."
                case "downloading":
                    self.currentStatus = "Downloading..."
                case "processing":
                    self.currentStatus = "Processing..."
                case "completed":
                    self.currentStatus = "Completed!"
                case "error":
                    self.currentStatus = "Error"
                default:
                    self.currentStatus = progressResult.status
                }
            }

            if progressResult.progress != lastProgress {
                print("📊 [iOS] Progress: \(String(format: "%.1f", progressResult.progress))% - \(progressResult.status)")
                lastProgress = progressResult.progress
            }

            if progressResult.status == "completed" {
                completed = true
            } else if progressResult.status == "error" {
                await MainActor.run {
                    self.isDownloading = false
                }
                throw NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: progressResult.error ?? "Unknown error"])
            }
        }

        // 3. Download the file
        await MainActor.run {
            self.currentStatus = "Saving file..."
        }

        guard let fileUrl = URL(string: "\(backendURL)/file/\(sessionId)") else {
            await MainActor.run {
                self.isDownloading = false
            }
            throw URLError(.badURL)
        }

        print("📥 [iOS] Downloading file...")
        let (downloadedURL, downloadResponse) = try await URLSession.shared.download(from: fileUrl)

        guard let httpDownloadResponse = downloadResponse as? HTTPURLResponse,
              httpDownloadResponse.statusCode == 200 else {
            await MainActor.run {
                self.isDownloading = false
            }
            throw URLError(.badServerResponse)
        }

        // 4. Move file to Documents directory
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            await MainActor.run {
                self.isDownloading = false
            }
            throw URLError(.fileDoesNotExist)
        }

        let contentType = httpDownloadResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        let actualExtension: String
        if contentType.contains("audio/mpeg") {
            actualExtension = "mp3"
        } else if contentType.contains("video/mp4") {
            actualExtension = "mp4"
        } else {
            actualExtension = format
        }

        let safeFilename = filename.replacingOccurrences(of: "/", with: "_")
        let finalFilename = safeFilename.hasSuffix(".\(actualExtension)") ? safeFilename : "\(safeFilename).\(actualExtension)"
        let destinationURL = documentsURL.appendingPathComponent(finalFilename)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: downloadedURL, to: destinationURL)

        if let fileAttributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
           let fileSize = fileAttributes[.size] as? Int64 {
            print("✅ [iOS] File saved successfully:")
            print("   Path: \(destinationURL.path)")
            print("   File size: \(fileSize) bytes (\(String(format: "%.2f", Double(fileSize) / 1024.0 / 1024.0)) MB)")
        }

        await MainActor.run {
            self.isDownloading = false
            self.currentProgress = 1.0
            self.currentStatus = "Completed!"
        }
    }
}
