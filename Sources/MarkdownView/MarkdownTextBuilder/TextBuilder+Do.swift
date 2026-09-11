//
//  TextBuilder+Do.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import CoreText
import Foundation
import UIKit

private func builtinSystemImage(_ name: String, size: CGFloat = 16) -> UIImage {
    guard let image = UIImage(
        systemName: name,
        withConfiguration: UIImage.SymbolConfiguration(scale: .small)
    ) else { return .init() }
    let templateImage = image.withTintColor(.label, renderingMode: .alwaysTemplate)
    return templateImage.resized(to: .init(width: size, height: size))
}

private let kCheckedBoxImage = builtinSystemImage("checkmark.square.fill")
private let kUncheckedBoxImage = builtinSystemImage("square")

private func kNumberCircleImage(_ number: Int) -> UIImage {
    builtinSystemImage("\(number).circle.fill")
}

private func kNumberTextImage(_ number: Int, theme: MarkdownTheme) -> UIImage {
    let font = theme.fonts.listNumber ?? theme.fonts.body
    let numberText = "\(number)."
    
    // 计算文本宽度
    let textAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.label
    ]
    let textSize = numberText.size(withAttributes: textAttributes)
    
    // TODO: 宽度不够会被截断
    let height = font.pointSize
    let maxWidth: CGFloat = theme.sizes.listIndent
    let x: CGFloat = maxWidth - textSize.width - theme.sizes.listNumberGap // 右对齐，右缘留 gap
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: maxWidth, height: height))
    let image = renderer.image { context in
        let textRect = CGRect(
            x: x,
            y: (height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        numberText.draw(in: textRect, withAttributes: textAttributes)
    }
    return image.withRenderingMode(.alwaysTemplate)
}

extension TextBuilder {
    @inline(__always)
    static func lineBoundingBox(_ line: CTLine, lineOrigin: CGPoint) -> CGRect {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        return .init(x: lineOrigin.x, y: lineOrigin.y - descent, width: width, height: ascent + descent)
    }

    static func build(view: MarkdownTextView, viewProvider: ReusableViewProvider) -> BuildResult {
        let context: MarkdownTextView.PreprocessedContent = view.document
        let theme: MarkdownTheme = view.theme

        var blockquoteMarkingStorage: CGFloat? = nil

        @discardableResult
        func populateContextColorFromFirstRun(context: CGContext, line: CTLine) -> UIColor {
            var textColor = theme.colors.body
            if let firstRun = line.glyphRuns().first,
               let attributes = CTRunGetAttributes(firstRun) as? [NSAttributedString.Key: Any],
               let color = attributes[.foregroundColor] as? UIColor
            {
                textColor = color
            }
            context.setStrokeColor(textColor.cgColor)
            context.setFillColor(textColor.cgColor)
            return textColor
        }

        return TextBuilder(nodes: context.blocks, context: context, viewProvider: viewProvider)
            .withTheme(theme)
            .withBulletDrawing { context, line, lineOrigin, depth in
                let radius: CGFloat = 3
                let boundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)
                populateContextColorFromFirstRun(context: context, line: line)
                let rect = CGRect(
                    x: boundingBox.minX - 16,
                    y: boundingBox.midY - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                if depth == 0 {
                    context.fillEllipse(in: rect)
                } else if depth == 1 {
                    context.strokeEllipse(in: rect)
                } else {
                    context.fill(rect)
                }
            }
            .withNumberedDrawing { context, line, lineOrigin, num in
                let rect = lineBoundingBox(line, lineOrigin: lineOrigin)
                    .offsetBy(dx: -theme.sizes.listIndent, dy: 0)
                // let image = kNumberCircleImage(num)
                let image = kNumberTextImage(num, theme: theme)
                guard let cgImage = image.cgImage else { return }
                let imageSize = image.size
                let targetRect: CGRect = .init(
                    x: rect.minX,
                    y: rect.midY - imageSize.height / 2,
                    width: imageSize.width,
                    height: imageSize.height
                )
                let textColor = populateContextColorFromFirstRun(context: context, line: line)
                context.clip(to: targetRect, mask: cgImage)
                context.setFillColor(textColor.cgColor)
                context.fill(targetRect)
            }
            .withCheckboxDrawing { context, line, lineOrigin, isChecked in
                let rect = lineBoundingBox(line, lineOrigin: lineOrigin)
                    .offsetBy(dx: -16, dy: 0)
                    .offsetBy(dx: -8, dy: 0)
                if let borderColor = theme.colors.checkboxBorder {
                    // 自绘样式：圆角方框 + 勾选填充（与编辑器网页一致）
                    let side = theme.sizes.checkbox
                    let borderWidth = theme.sizes.checkboxBorderWidth
                    let box = CGRect(x: rect.minX, y: rect.midY - side / 2, width: side, height: side)
                    let path = CGPath(
                        roundedRect: box.insetBy(dx: borderWidth / 2, dy: borderWidth / 2),
                        cornerWidth: theme.sizes.checkboxCornerRadius,
                        cornerHeight: theme.sizes.checkboxCornerRadius,
                        transform: nil
                    )
                    context.saveGState()
                    if isChecked {
                        let fill = theme.colors.checkboxFill ?? borderColor
                        context.setFillColor(fill.cgColor)
                        context.addPath(CGPath(
                            roundedRect: box,
                            cornerWidth: theme.sizes.checkboxCornerRadius,
                            cornerHeight: theme.sizes.checkboxCornerRadius,
                            transform: nil
                        ))
                        context.fillPath()
                        // 勾：CoreText 坐标系 y 向上
                        context.setStrokeColor(theme.colors.checkboxCheck.cgColor)
                        context.setLineWidth(borderWidth)
                        context.setLineCap(.round)
                        context.setLineJoin(.round)
                        context.move(to: CGPoint(x: box.minX + side * 0.26, y: box.minY + side * 0.50))
                        context.addLine(to: CGPoint(x: box.minX + side * 0.44, y: box.minY + side * 0.32))
                        context.addLine(to: CGPoint(x: box.minX + side * 0.76, y: box.minY + side * 0.68))
                        context.strokePath()
                    } else {
                        context.setStrokeColor(borderColor.cgColor)
                        context.setLineWidth(borderWidth)
                        context.addPath(path)
                        context.strokePath()
                    }
                    context.restoreGState()
                    return
                }
                let image = if isChecked { kCheckedBoxImage } else { kUncheckedBoxImage }
                guard let cgImage = image.cgImage else { return }
                let imageSize = image.size
                let targetRect: CGRect = .init(
                    x: rect.minX,
                    y: rect.midY - imageSize.height / 2,
                    width: imageSize.width,
                    height: imageSize.height
                )
                let textColor = populateContextColorFromFirstRun(context: context, line: line)
                context.clip(to: targetRect, mask: cgImage)
                context.setFillColor(textColor.withAlphaComponent(0.24).cgColor)
                context.fill(targetRect)
            }
            .withThematicBreakDrawing { [weak view] context, line, lineOrigin in
                guard let view else { return }
                let boundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)

                context.setLineWidth(1)
                context.setStrokeColor(UIColor.label.withAlphaComponent(0.1).cgColor)
                context.move(to: .init(x: boundingBox.minX, y: boundingBox.midY))
                context.addLine(to: .init(x: boundingBox.minX + view.bounds.width, y: boundingBox.midY))
                context.strokePath()
            }
            .withCodeDrawing { [weak view] _, line, lineOrigin in
                guard let view else { return }
                guard let firstRun = line.glyphRuns().first else { return }
                let attributes = firstRun.attributes
                guard let codeView = attributes[.contextView] as? CodeView else {
                    assertionFailure()
                    return
                }

                if codeView.superview != view { view.addSubview(codeView) }
                let intrinsicContentSize = codeView.intrinsicContentSize
                let lineBoundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)
                var leftIndent: CGFloat = 0
                if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
                    leftIndent = paragraphStyle.headIndent
                }

                codeView.frame = .init(
                    origin: .init(x: lineOrigin.x + leftIndent, y: view.bounds.height - lineBoundingBox.maxY),
                    size: .init(width: view.bounds.width - leftIndent, height: intrinsicContentSize.height)
                )
                codeView.previewAction = view.codePreviewHandler
            }
            .withTableDrawing { [weak view] _, line, lineOrigin in
                guard let view else { return }
                guard let firstRun = line.glyphRuns().first else { return }
                let attributes = firstRun.attributes
                guard let tableView = attributes[.contextView] as? TableView else {
                    assertionFailure()
                    return
                }

                if tableView.superview != view { view.addSubview(tableView) }
                tableView.linkHandler = view.linkHandler
                let lineBoundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)
                let intrinsicContentSize = tableView.intrinsicContentSize
                var leftIndent: CGFloat = 0
                if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
                    leftIndent = paragraphStyle.headIndent
                }

                tableView.frame = .init(
                    x: lineOrigin.x + leftIndent,
                    y: view.bounds.height - lineBoundingBox.maxY,
                    width: view.bounds.width - leftIndent,
                    height: intrinsicContentSize.height
                )
            }
            .withBlockquoteMarking { _, line, lineOrigin in
                let boundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)
                blockquoteMarkingStorage = boundingBox.maxY
            }
            .withBlockquoteDrawing { context, line, lineOrigin in
                let boundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)
                defer { blockquoteMarkingStorage = nil }
                let quotingLineHeight: CGFloat = blockquoteMarkingStorage! - boundingBox.minY
                let barWidth = theme.sizes.blockquoteBarWidth
                let lineRect = CGRect(
                    x: 0,
                    y: blockquoteMarkingStorage! - quotingLineHeight,
                    width: barWidth,
                    height: quotingLineHeight
                )
                let barColor = theme.colors.blockquoteBar ?? theme.colors.body.withAlphaComponent(0.1)
                context.setFillColor(barColor.cgColor)
                let radius = min(theme.sizes.blockquoteBarCornerRadius, barWidth / 2)
                let roundedPath = CGPath(roundedRect: lineRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
                context.addPath(roundedPath)
                context.fillPath()
            }
            .build()
    }
}
