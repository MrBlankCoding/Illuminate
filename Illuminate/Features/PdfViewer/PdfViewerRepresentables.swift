//
//  PdfViewerRepresentables.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/8/26.
//

import AppKit
import PDFKit
import SwiftUI

struct OutlineRowView: View {
    let outline: PDFOutline
    let depth: Int
    let onSelect: (PDFDestination) -> Void

    var body: some View {
        if outline.numberOfChildren > 0 {
            DisclosureGroup {
                ForEach(0..<outline.numberOfChildren, id: \.self) { i in
                    if let child = outline.child(at: i) {
                        OutlineRowView(outline: child, depth: depth + 1, onSelect: onSelect)
                    }
                }
            } label: {
                rowLabel
            }
        } else {
            rowLabel
        }
    }

    private var rowLabel: some View {
        Text(outline.label ?? "Untitled")
            .font(.system(size: 12))
            .lineLimit(1)
            .contentShape(Rectangle())
            .onTapGesture {
                if let destination = outline.destination {
                    onSelect(destination)
                }
            }
            .hoverCursor(.pointingHand)
            .padding(.leading, CGFloat(depth) * 10)
    }
}


struct PDFKitView: NSViewRepresentable {
    let controller: PDFViewerController

    func makeNSView(context: Context) -> PDFView {
        let view = controller.pdfView
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {}
}
