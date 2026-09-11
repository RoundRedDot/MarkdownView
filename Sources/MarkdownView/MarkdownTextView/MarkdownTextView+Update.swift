//
//  MarkdownTextView+Update.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import CoreText
import Litext
import UIKit

extension MarkdownTextView {
    func updateTextExecute() {
        assert(Thread.isMainThread)

        viewProvider.lockPool()
        defer { viewProvider.unlockPool() }

        var oldViews: Set<UIView> = .init()
        for view in contextViews {
            oldViews.insert(view)
            if let view = view as? CodeView {
                viewProvider.stashCodeView(view)
                continue
            }
            if let view = view as? TableView {
                viewProvider.stashTableView(view)
                continue
            }
            assertionFailure()
        }

        viewProvider.reorderViews(matching: contextViews)
        contextViews.removeAll()

        // 行内代码胶囊、脚注等会在这里被烘焙成图片，动态色必须按本视图的 trait 解析，
        // 否则宿主用 overrideUserInterfaceStyle（如导出黑色模板强制 light）时会拿到系统当前深浅色的值
        var artifacts: TextBuilder.BuildResult!
        traitCollection.performAsCurrent {
            artifacts = TextBuilder.build(view: self, viewProvider: viewProvider)
        }
        textView.attributedText = artifacts.document
        contextViews = artifacts.subviews

        for view in artifacts.subviews {
            if let view = view as? CodeView {
                view.textView.delegate = self
            }
        }

        for goneView in oldViews where !artifacts.subviews.contains(goneView) {
            goneView.removeFromSuperview()
        }

        textView.setNeedsLayout()
        setNeedsLayout()

        textView.setNeedsDisplay()
        setNeedsDisplay()
    }
}
