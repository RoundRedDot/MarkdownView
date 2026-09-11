//
//  InlineNode+Render.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2025/1/3.
//

import Foundation
import Litext
import MarkdownParser
import SwiftMath
import UIKit

extension [MarkdownInlineNode] {
    func render(theme: MarkdownTheme, context: MarkdownTextView.PreprocessedContent, viewProvider: ReusableViewProvider) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for node in self {
            result.append(node.render(theme: theme, context: context, viewProvider: viewProvider))
        }
        return result
    }
}

extension MarkdownInlineNode {
    func render(theme: MarkdownTheme, context: MarkdownTextView.PreprocessedContent, viewProvider: ReusableViewProvider) -> NSAttributedString {
        assert(Thread.isMainThread)
        switch self {
        case let .text(string):
            return NSMutableAttributedString(
                string: string,
                attributes: [
                    .font: theme.fonts.body,
                    .foregroundColor: theme.colors.body,
                ]
            )
        case .softBreak:
            return NSAttributedString(string: " ", attributes: [
                .font: theme.fonts.body,
                .foregroundColor: theme.colors.body,
            ])
        case .lineBreak:
            return NSAttributedString(string: "\n", attributes: [
                .font: theme.fonts.body,
                .foregroundColor: theme.colors.body,
            ])
        case let .code(string), let .html(string):
            if theme.sizes.inlineCodeCornerRadius > 0 {
                return Self.renderInlineCodePill(string, theme: theme)
            }
            let controlAttributes: [NSAttributedString.Key: Any] = [
                .font: theme.fonts.codeInline,
                .backgroundColor: theme.colors.codeBackground.withAlphaComponent(0.05),
            ]
            let text = NSMutableAttributedString(string: string, attributes: [.foregroundColor: theme.colors.code])
            text.addAttributes(controlAttributes, range: .init(location: 0, length: text.length))
            return text
        case let .emphasis(children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, context: context, viewProvider: viewProvider) }.forEach { ans.append($0) }
            ans.addAttributes(
                [
                    .underlineStyle: NSUnderlineStyle.thick.rawValue,
                    .underlineColor: theme.colors.emphasis,
                ],
                range: NSRange(location: 0, length: ans.length)
            )
            return ans
        case let .strong(children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, context: context, viewProvider: viewProvider) }.forEach { ans.append($0) }
            ans.addAttributes(
                [.font: theme.fonts.bold],
                range: NSRange(location: 0, length: ans.length)
            )
            return ans
        case let .strikethrough(children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, context: context, viewProvider: viewProvider) }.forEach { ans.append($0) }
            ans.addAttributes(
                [.strikethroughStyle: NSUnderlineStyle.thick.rawValue],
                range: NSRange(location: 0, length: ans.length)
            )
            return ans
        case let .link(destination, children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, context: context, viewProvider: viewProvider) }.forEach { ans.append($0) }
            var attributes: [NSAttributedString.Key: Any] = [
                .link: destination,
                .foregroundColor: theme.colors.highlight,
            ]
            if theme.showsLinkUnderline {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                attributes[.underlineColor] = theme.colors.link
            }
            ans.addAttributes(attributes, range: NSRange(location: 0, length: ans.length))
            return ans
        case let .image(source, _): // children => alternative text can be ignored?
            return NSAttributedString(
                string: source,
                attributes: [
                    .link: source,
                    .font: theme.fonts.body,
                    .foregroundColor: theme.colors.body,
                ]
            )
        case let .math(content, replacementIdentifier):
            // Get LaTeX content from rendered context or fallback to raw content
            let latexContent = context.rendered[replacementIdentifier]?.text ?? content
            
            if let item = context.rendered[replacementIdentifier], let image = item.image {
                var imageSize = image.size

                let drawingCallback = LTXLineDrawingAction { context, line, lineOrigin in
                    let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
                    var runOffsetX: CGFloat = 0
                    for i in 0 ..< glyphRuns.count {
                        let run = glyphRuns[i] as! CTRun
                        let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
                        if attributes[.contextIdentifier] as? String == replacementIdentifier {
                            break
                        }
                        runOffsetX += CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil)
                    }

                    var ascent: CGFloat = 0
                    var descent: CGFloat = 0
                    CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                    if imageSize.height > ascent { // we only draw above the line
                        let newWidth = imageSize.width * (ascent / imageSize.height)
                        imageSize = CGSize(width: newWidth, height: ascent)
                    }

                    let rect = CGRect(
                        x: lineOrigin.x + runOffsetX,
                        y: lineOrigin.y,
                        width: imageSize.width,
                        height: imageSize.height
                    )

                    context.saveGState()
                    context.translateBy(x: 0, y: rect.origin.y + rect.size.height)
                    context.scaleBy(x: 1, y: -1)
                    context.translateBy(x: 0, y: -rect.origin.y)
                    image.draw(in: rect)
                    context.restoreGState()
                }
                let attachment = LTXAttachment.hold(attrString: .init(string: latexContent))
                attachment.size = imageSize
                
                let attributes: [NSAttributedString.Key: Any] = [
                    LTXAttachmentAttributeName: attachment,
                    LTXLineDrawingCallbackName: drawingCallback,
                    kCTRunDelegateAttributeName as NSAttributedString.Key: attachment.runDelegate,
                    .contextIdentifier: replacementIdentifier,
                    .mathLatexContent: latexContent, // Store LaTeX content for on-demand rendering
                ]
                
                return NSAttributedString(
                    string: LTXReplacementText,
                    attributes: attributes
                )
            } else {
                // Fallback: render failed, show original LaTeX as inline code
                return NSAttributedString(
                    string: latexContent,
                    attributes: [
                        .font: theme.fonts.codeInline,
                        .foregroundColor: theme.colors.code,
                        .backgroundColor: theme.colors.codeBackground.withAlphaComponent(0.05),
                    ]
                )
            }
        case let .footnote(destination, children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, context: context, viewProvider: viewProvider) }.forEach { ans.append($0) }
            ans.addAttributes(
                [
                    .link: destination,
                    .foregroundColor: theme.colors.footnote
                ],
                range: NSRange(location: 0, length: ans.length)
            )
            let padding = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)
            let image = ans.drawToImage(padding: padding, backgroundColor: theme.colors.footnoteBackground, minSize: CGSize(width: 22, height: 22))
            let imageSize = image.size
            let replacementIdentifier = destination
            let drawingCallback = LTXLineDrawingAction { context, line, lineOrigin in
                let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
                var runOffsetX: CGFloat = 0
                for i in 0 ..< glyphRuns.count {
                    let run = glyphRuns[i] as! CTRun
                    let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
                    if attributes[.contextIdentifier] as? String == replacementIdentifier {
                        break
                    }
                    runOffsetX += CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil)
                }

                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                let x = lineOrigin.x + runOffsetX
                let y = lineOrigin.y - descent - padding.top
                let rect = CGRect(
                    x: x,
                    y: y,
                    width: imageSize.width,
                    height: imageSize.height
                )

                context.saveGState()
                context.translateBy(x: 0, y: rect.origin.y + rect.size.height)
                context.scaleBy(x: 1, y: -1)
                context.translateBy(x: 0, y: -rect.origin.y)
                image.draw(in: rect)
                context.restoreGState()
            }
            let attachment = LTXAttachment.hold(attrString: .init(string: destination))
            attachment.size = imageSize
            let attributes: [NSAttributedString.Key: Any] = [
                LTXAttachmentAttributeName: attachment,
                LTXLineDrawingCallbackName: drawingCallback,
                kCTRunDelegateAttributeName as NSAttributedString.Key: attachment.runDelegate,
                .contextIdentifier: replacementIdentifier,
                .mathLatexContent: destination, // Store LaTeX content for on-demand rendering
                .link: destination
            ]

            return NSAttributedString(
                string: LTXReplacementText,
                attributes: attributes
            )
        }
    }
}


// MARK: - Inline code as a rounded pill

extension MarkdownInlineNode {
    /// 行内代码按「文字 + 内边距 + 圆角底色」整体绘制成一张图，插入为附件。
    /// CoreText 不会绘制 .backgroundColor，也不支持内边距 / 圆角，只能这样做才能和网页编辑器的样式一致。
    /// 选中 / 复制时附件仍持有原始文字。
    static func renderInlineCodePill(_ string: String, theme: MarkdownTheme) -> NSAttributedString {
        let text = NSAttributedString(string: string, attributes: [
            .font: theme.fonts.codeInline,
            .foregroundColor: theme.colors.code,
        ])
        let padding = theme.sizes.inlineCodePadding
        let image = text.drawToImage(
            padding: padding,
            backgroundColor: theme.colors.codeBackground,
            cornerRadius: theme.sizes.inlineCodeCornerRadius
        )
        let imageSize = image.size
        let replacementIdentifier = "inline-code-" + UUID().uuidString
        let drawingCallback = LTXLineDrawingAction { context, line, lineOrigin in
            let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
            var runOffsetX: CGFloat = 0
            for i in 0 ..< glyphRuns.count {
                let run = glyphRuns[i] as! CTRun
                let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
                if attributes[.contextIdentifier] as? String == replacementIdentifier {
                    break
                }
                runOffsetX += CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil)
            }

            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, nil)
            let x = lineOrigin.x + runOffsetX
            // 图片按行基线垂直居中：图片中心对齐正文 x-height 中心附近（基线 + (ascent - descent) / 2）
            let centerY = lineOrigin.y + (ascent - descent) / 2
            let rect = CGRect(
                x: x,
                y: centerY - imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            )

            context.saveGState()
            context.translateBy(x: 0, y: rect.origin.y + rect.size.height)
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: 0, y: -rect.origin.y)
            image.draw(in: rect)
            context.restoreGState()
        }
        let attachment = LTXAttachment.hold(attrString: .init(string: string))
        attachment.size = imageSize
        let attributes: [NSAttributedString.Key: Any] = [
            LTXAttachmentAttributeName: attachment,
            LTXLineDrawingCallbackName: drawingCallback,
            kCTRunDelegateAttributeName as NSAttributedString.Key: attachment.runDelegate,
            .contextIdentifier: replacementIdentifier,
            .font: theme.fonts.codeInline,
        ]
        return NSAttributedString(string: LTXReplacementText, attributes: attributes)
    }
}
