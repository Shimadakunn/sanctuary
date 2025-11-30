//
//  FilesView.swift
//  Sanctuary
//
//  Created by Léo Combaret on 29/11/2025.
//

internal import SwiftUI
import UniformTypeIdentifiers
import AVKit

struct FilesView: View {
    @State private var currentPath: URL
    @State private var items: [FileItem] = []
    @State private var isLoading = false
    @State private var selectedFile: FileItem?
    @State private var videoToPlay: FileItem?
    @State private var audioToPlay: FileItem?
    @State private var isEditMode = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showRenameAlert = false
    @State private var itemToRename: FileItem?
    @State private var newFileName = ""

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        _currentPath = State(initialValue: documentsPath)
    }

    var body: some View {
        List {
            if items.isEmpty && !isLoading {
                // ... existing empty state ...
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Files")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Your documents will appear here")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
                .listRowBackground(Color.clear)
            } else {
                ForEach(items) { item in
                    if isEditMode {
                        HStack {
                            Button(action: { toggleSelection(item) }) {
                                Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedItems.contains(item.id) ? .blue : .gray)
                                    .font(.system(size: 24))
                            }
                            .buttonStyle(PlainButtonStyle())

                            FileRow(item: item)

                            Spacer()

                            Button(action: {
                                itemToRename = item
                                newFileName = item.url.deletingPathExtension().lastPathComponent
                                showRenameAlert = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else {
                        if item.isDirectory {
                            Button(action: { navigateToFolder(item.url) }) {
                                FileRow(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else if isVideo(file: item) {
                            Button(action: { videoToPlay = item }) {
                                FileRow(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else if isAudio(file: item) {
                            Button(action: { audioToPlay = item }) {
                                FileRow(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            NavigationLink(destination: FilePreviewView(file: item)) {
                                FileRow(item: item)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(currentPath.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if currentPath.path != FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: navigateUp) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditMode {
                    HStack(spacing: 16) {
                        if !selectedItems.isEmpty {
                            Button(action: deleteSelectedItems) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        Button("Done") {
                            isEditMode = false
                            selectedItems.removeAll()
                        }
                    }
                } else {
                    Button("Edit") {
                        isEditMode = true
                    }
                    .disabled(items.isEmpty)
                }
            }
        }
        .onAppear {
            loadFiles()
        }
        .fullScreenCover(item: $videoToPlay) { item in
            LandscapeVideoPlayer(url: item.url)
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $audioToPlay) { item in
            AudioPlayer(url: item.url)
                .ignoresSafeArea()
        }
        .alert("Rename File", isPresented: $showRenameAlert) {
            TextField("File name", text: $newFileName)
            Button("Cancel", role: .cancel) {
                itemToRename = nil
                newFileName = ""
            }
            Button("Rename") {
                if let item = itemToRename {
                    renameFile(item)
                }
            }
        } message: {
            Text("Enter a new name for the file")
        }
    }
    
    private func isVideo(file: FileItem) -> Bool {
        let ext = file.url.pathExtension.lowercased()
        return ["mp4", "mov", "avi", "m4v", "m3u8"].contains(ext)
    }

    private func isAudio(file: FileItem) -> Bool {
        let ext = file.url.pathExtension.lowercased()
        return ["mp3", "wav", "m4a", "aac"].contains(ext)
    }

    private func toggleSelection(_ item: FileItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func deleteSelectedItems() {
        let itemsToDelete = items.filter { selectedItems.contains($0.id) }

        for item in itemsToDelete {
            do {
                try FileManager.default.removeItem(at: item.url)
                print("✅ Deleted: \(item.name)")
            } catch {
                print("❌ Error deleting \(item.name): \(error)")
            }
        }

        selectedItems.removeAll()
        isEditMode = false
        loadFiles()
    }

    private func renameFile(_ item: FileItem) {
        guard !newFileName.isEmpty else {
            itemToRename = nil
            newFileName = ""
            return
        }

        let fileExtension = item.url.pathExtension
        let newName = newFileName + (fileExtension.isEmpty ? "" : ".\(fileExtension)")
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)

        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            print("✅ Renamed: \(item.name) → \(newName)")
            loadFiles()
        } catch {
            print("❌ Error renaming file: \(error)")
        }

        itemToRename = nil
        newFileName = ""
    }

    private func loadFiles() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                let urls = try fileManager.contentsOfDirectory(
                    at: currentPath,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )

                var fileItems: [FileItem] = []

                for url in urls {
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                    let isDirectory = resourceValues.isDirectory ?? false
                    let size = resourceValues.fileSize ?? 0
                    let modificationDate = resourceValues.contentModificationDate ?? Date()

                    fileItems.append(FileItem(
                        url: url,
                        name: url.lastPathComponent,
                        isDirectory: isDirectory,
                        size: size,
                        modificationDate: modificationDate
                    ))
                }

                // Sort: directories first, then by name
                fileItems.sort { first, second in
                    if first.isDirectory != second.isDirectory {
                        return first.isDirectory
                    }
                    return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
                }

                DispatchQueue.main.async {
                    self.items = fileItems
                    self.isLoading = false
                }
            } catch {
                print("Error loading files: \(error)")
                DispatchQueue.main.async {
                    self.items = []
                    self.isLoading = false
                }
            }
        }
    }

    private func navigateToFolder(_ url: URL) {
        currentPath = url
        loadFiles()
    }

    private func navigateUp() {
        currentPath = currentPath.deletingLastPathComponent()
        loadFiles()
    }
}

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int
    let modificationDate: Date
}

struct FileRow: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !item.isDirectory {
                        Text(formatFileSize(item.size))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Text(formatDate(item.modificationDate))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        if item.isDirectory {
            return "folder.fill"
        }

        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "heic":
            return "photo.fill"
        case "mp4", "mov", "avi", "m3u8":
            return "play.rectangle.fill"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "zip", "rar", "7z":
            return "archivebox.fill"
        case "txt", "md":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }

    private var iconColor: Color {
        if item.isDirectory {
            return .blue
        }

        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return .red
        case "jpg", "jpeg", "png", "gif", "heic":
            return .green
        case "mp4", "mov", "avi", "m3u8":
            return .purple
        case "mp3", "wav", "m4a":
            return .pink
        case "zip", "rar", "7z":
            return .orange
        case "txt", "md":
            return .blue
        default:
            return .gray
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct FilePreviewView: View {
    let file: FileItem

    var body: some View {
        Group {
            if isVideo {
                VideoPlayer(player: AVPlayer(url: file.url))
            } else if isAudio {
                VideoPlayer(player: AVPlayer(url: file.url))
            } else if isImage {
                AsyncImage(url: file.url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: iconName)
                            .font(.system(size: 64))
                            .foregroundColor(iconColor)
                            .padding(.top, 40)

                        Text(file.name)
                            .font(.system(size: 18, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "Size", value: formatFileSize(file.size))
                            InfoRow(label: "Modified", value: formatDate(file.modificationDate))
                            InfoRow(label: "Location", value: file.url.deletingLastPathComponent().path)
                        }
                        .padding()
                        .background(Color.adaptiveSecondaryBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)

                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isVideo: Bool {
        let ext = file.url.pathExtension.lowercased()
        return ["mp4", "mov", "avi", "m4v", "m3u8"].contains(ext)
    }

    private var isAudio: Bool {
        let ext = file.url.pathExtension.lowercased()
        return ["mp3", "wav", "m4a", "aac"].contains(ext)
    }

    private var isImage: Bool {
        let ext = file.url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "heic"].contains(ext)
    }

    private var iconName: String {
        let ext = file.url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "heic":
            return "photo.fill"
        case "mp4", "mov", "avi", "m3u8":
            return "play.rectangle.fill"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "zip", "rar", "7z":
            return "archivebox.fill"
        case "txt", "md":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }

    private var iconColor: Color {
        let ext = file.url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return .red
        case "jpg", "jpeg", "png", "gif", "heic":
            return .green
        case "mp4", "mov", "avi", "m3u8":
            return .purple
        case "mp3", "wav", "m4a":
            return .pink
        case "zip", "rar", "7z":
            return .orange
        case "txt", "md":
            return .blue
        default:
            return .gray
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }
}
