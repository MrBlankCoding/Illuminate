//
//  FilePanels.swift
//  Illuminate
//
//  Created by MrBlankCoding on 8/20/26.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
enum FilePanels {

    static func chooseDirectory(
        initialDirectory: URL? = nil,
        message: String? = nil,
        prompt: String? = nil
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = initialDirectory
        apply(message: message, prompt: prompt, to: panel)

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func chooseFiles(
        allowedContentTypes: [UTType]? = nil,
        allowsMultipleSelection: Bool = false,
        canChooseDirectories: Bool = false,
        initialDirectory: URL? = nil,
        message: String? = nil,
        prompt: String? = nil
    ) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = canChooseDirectories
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.showsHiddenFiles = false
        if let allowedContentTypes {
            panel.allowedContentTypes = allowedContentTypes
        }
        panel.directoryURL = initialDirectory
        apply(message: message, prompt: prompt, to: panel)

        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    static func saveFile(
        suggestedFilename: String,
        defaultDirectory: URL?
    ) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFilename
        panel.directoryURL = defaultDirectory

        let ext = (suggestedFilename as NSString).pathExtension
        if !ext.isEmpty, let contentType = UTType(filenameExtension: ext) {
            panel.allowedContentTypes = [contentType]
        }

        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func apply(message: String?, prompt: String?, to panel: NSOpenPanel) {
        if let message { panel.message = message }
        if let prompt { panel.prompt = prompt }
    }

}
