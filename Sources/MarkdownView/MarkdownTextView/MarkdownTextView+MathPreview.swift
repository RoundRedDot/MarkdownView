//
//  MarkdownTextView+MathPreview.swift
//  MarkdownView
//
//  Created by Willow Zhang on 11/13/25
//

import QuickLook
import UIKit

extension MarkdownTextView {
    internal func presentMathPreview(for latexContent: String, theme: MarkdownTheme) {
        // Render at higher resolution for preview (2x)
        let previewFontSize = theme.fonts.body.pointSize * 2
        
        guard let image = MathRenderer.renderToImage(
            latex: latexContent,
            fontSize: previewFontSize,
            textColor: theme.colors.body
        ) else {
            print("[MarkdownView] Failed to render LaTeX for preview: \(latexContent)")
            return
        }
        
        guard let pngData = image.pngData() else { return }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        
        do {
            try pngData.write(to: tempURL)
            
            let previewItem = MathPreviewItem(url: tempURL, title: "Math Equation")
            let dataSource = MathPreviewDataSource(item: previewItem) {
                try? FileManager.default.removeItem(at: tempURL)
            }
            
            let controller = QLPreviewController()
            controller.dataSource = dataSource
            objc_setAssociatedObject(controller, "dataSource", dataSource, .OBJC_ASSOCIATION_RETAIN)
            
            window?.rootViewController?.present(controller, animated: true)
        } catch {
            print("[MarkdownView] Failed to create temp file for math preview: \(error)")
        }
    }
}

// MARK: - QuickLook Support

private class MathPreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?
    
    init(url: URL, title: String) {
        self.previewItemURL = url
        self.previewItemTitle = title
    }
}

private class MathPreviewDataSource: NSObject, QLPreviewControllerDataSource {
    let item: MathPreviewItem
    let cleanup: () -> Void
    
    init(item: MathPreviewItem, cleanup: @escaping () -> Void) {
        self.item = item
        self.cleanup = cleanup
    }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
        item
    }
    
    deinit {
        cleanup()
    }
}

