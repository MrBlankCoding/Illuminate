//
//  DownloadsView.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//

import SwiftUI

struct DownloadsView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Downloads")
                    .font(.webH2)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            if downloadManager.downloads.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.textSecondary.opacity(0.5))
                    Text("No active downloads")
                        .font(.webMicro)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(downloadManager.downloads) { task in
                            DownloadRow(task: task)
                        }
                    }
                }
            }
        }
        .frame(width: 350, height: 450)
        .glassBackground()
    }
}

struct DownloadRow: View {
    let task: DownloadTask
    @EnvironmentObject private var tabManager: TabManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon(for: task.filename))
                .font(.system(size: 24))
                .foregroundStyle(tabManager.windowThemeColor)
                .frame(width: 40, height: 40)
                .background(tabManager.windowThemeColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.filename)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                if task.isCompleted {
                    Text("Completed")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.green)
                } else if task.isFailed {
                    Text("Failed: \(task.error?.localizedDescription ?? "Unknown error")")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.red)
                } else {
                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                        .tint(tabManager.windowThemeColor)
                }
            }
            
            Spacer()
            
            if task.isCompleted {
                Button {
                    showInFinder()
                } label: {
                    Image(systemName: "folder")
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.bgSurface.opacity(0.3))
    }
    
    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "zip", "gz", "rar": return "archivebox"
        case "dmg", "pkg": return "shippingbox"
        case "jpg", "png", "gif", "webp": return "photo"
        case "mp4", "mov", "avi": return "video"
        case "mp3", "wav", "m4a": return "music.note"
        default: return "doc"
        }
    }
    
    private func showInFinder() {
        let downloadsFolder = FileManager.default.illuminateDownloadsDirectory()
        let fileURL = task.destinationURL ?? downloadsFolder.appendingPathComponent(task.filename)
        NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: downloadsFolder.path)
    }
}
