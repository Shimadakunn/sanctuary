//
//  FilesView.swift
//  Sanctuary
//
//  Created by Léo Combaret on 29/11/2025.
//

internal import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @State private var currentPath: URL
    @State private var items: [FileItem] = []
    @State private var isLoading = false
    @State private var selectedFile: FileItem?

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        _currentPath = State(initialValue: documentsPath)
    }

    var body: some View {
        List {
            if items.isEmpty && !isLoading {
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
                    FileRow(item: item) {
                        if item.isDirectory {
                            navigateToFolder(item.url)
                        } else {
                            selectedFile = item
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
        }
        .onAppear {
            loadFiles()
        }
        .sheet(item: $selectedFile) { file in
            FilePreviewView(file: file)
        }
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
        .buttonStyle(PlainButtonStyle())
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
        case "mp4", "mov", "avi":
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
        case "mp4", "mov", "avi":
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
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
            .navigationTitle("File Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var iconName: String {
        let ext = file.url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "heic":
            return "photo.fill"
        case "mp4", "mov", "avi":
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
        case "mp4", "mov", "avi":
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
