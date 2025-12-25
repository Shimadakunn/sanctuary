//
//  DownloadOptionsView.swift
//  Sanctuary
//
//  Created by Léo Combaret on 30/11/2025.
//

internal import SwiftUI

struct DownloadOptionsView: View {
    let url: URL
    @Binding var isPresented: Bool

    @StateObject private var downloadManager = DownloadManager.shared
    @State private var filename: String = ""
    @State private var format: String = "mp4"
    @State private var quality: String = "high"
    @State private var isDownloading = false
    @State private var errorMessage: String?
    @State private var downloadSuccess = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Video Details".localized)) {
                    TextField("Filename".localized, text: $filename)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(isDownloading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Format".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Format".localized, selection: $format) {
                            Text("MP4 (Video)").tag("mp4")
                            Text("MP3 (Audio)").tag("mp3")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .labelsHidden()
                        .padding(8)
                        .background(Color.adaptiveSecondaryBackground)
                        .cornerRadius(8)
                        .disabled(isDownloading)
                    }
                    .listRowBackground(Color.clear)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quality".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Quality".localized, selection: $quality) {
                            Text("Best").tag("high")
                            Text("Medium").tag("mid")
                            Text("Low").tag("low")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .labelsHidden()
                        .padding(8)
                        .background(Color.adaptiveSecondaryBackground)
                        .cornerRadius(8)
                        .disabled(isDownloading)
                    }
                    .listRowBackground(Color.clear)
                }

                if isDownloading {
                    Section(header: Text("Progress".localized)) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(downloadManager.currentStatus)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(downloadManager.currentProgress * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }

                            ProgressView(value: downloadManager.currentProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                                .tint(.blue)
                        }
                        .padding(.vertical, 8)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                if downloadSuccess {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Download Complete".localized)
                                .foregroundColor(.green)
                        }
                    }
                }

                Button(action: startDownload) {
                    HStack {
                        Spacer()
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 8)
                            Text("Downloading...".localized)
                                .font(.headline)
                        } else {
                            Text("Download".localized)
                                .font(.headline)
                        }
                        Spacer()
                    }
                }
                .disabled(filename.isEmpty || isDownloading)
            }
            .navigationTitle("Download Video".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized) {
                        isPresented = false
                    }
                    .disabled(isDownloading)
                }
            }
            .onAppear {
                // Set default filename
                let timestamp = Int(Date().timeIntervalSince1970)
                filename = "video_\(timestamp)"
            }
            .interactiveDismissDisabled(isDownloading)
        }
    }

    private func startDownload() {
        guard !filename.isEmpty else { return }

        withAnimation {
            isDownloading = true
            errorMessage = nil
            downloadSuccess = false
        }

        Task {
            do {
                try await DownloadManager.shared.downloadVideo(
                    url: url,
                    filename: filename,
                    format: format,
                    quality: quality
                )
                await MainActor.run {
                    withAnimation {
                        isDownloading = false
                        downloadSuccess = true
                    }
                    // Close after a short delay to show success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isPresented = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        isDownloading = false
                        errorMessage = "Download failed. Please check your internet connection and try again."
                    }
                }
            }
        }
    }
}
