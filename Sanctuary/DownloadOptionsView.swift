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
    
    @State private var filename: String = ""
    @State private var format: String = "mp4"
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
                    }
                    .listRowBackground(Color.clear)
                }
                
                if isDownloading {
                    Section {
                        HStack {
                            Text("Downloading...".localized)
                            Spacer()
                            ProgressView()
                        }
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
                        Text("Download".localized)
                            .font(.headline)
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
                try await DownloadManager.shared.downloadVideo(url: url, filename: filename, format: format)
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
                        errorMessage = "Download failed. Please ensure backend is running on localhost:3000."
                    }
                }
            }
        }
    }
}
