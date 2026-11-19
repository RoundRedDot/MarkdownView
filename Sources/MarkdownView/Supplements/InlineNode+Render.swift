//
//  InlineNode+Render.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2025/1/3.
//

import Foundation
import Litext
import LRUCache
import MarkdownParser
import SwiftMath
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension [MarkdownInlineNode] {
    @MainActor
    func render(
        theme: MarkdownTheme,
        context: MarkdownContent,
        decoration: TextBuilder.InlineTextDecoration? = nil,
    ) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for node in self {
            result.append(node.render(
                theme: theme,
                context: context,
                decoration: decoration,
            ))
        }
        return result
    }
}

extension MarkdownInlineNode {
    @MainActor
    func render(
        theme: MarkdownTheme,
        context: MarkdownContent,
        decoration: TextBuilder.InlineTextDecoration? = nil,
    ) -> NSAttributedString {
        assert(Thread.isMainThread)
        switch self {
        case let .text(string):
            // Past the cache, never into it: a decoration may carry an
            // attachment, and an attachment holds a view, which belongs to the
            // one text view it was built for rather than to every view that
            // draws the same words.
            let rendered = context.cachedBodyText(string, theme: theme)
            return decoration?(rendered) ?? rendered
        case .softBreak:
            return context.cachedBodyText(" ", theme: theme)
        case .lineBreak:
            return context.cachedBodyText("\n", theme: theme)
        case let .html(string) where InlineCode.isLineBreak(string):
            return NSMutableAttributedString(string: "\n", attributes: [.font: theme.fonts.body])
        case let .code(string), let .html(string):
            #if canImport(UIKit)
                if theme.sizes.inlineCodeCornerRadius > 0 {
                    return Self.renderInlineCodePill(string, theme: theme)
                }
            #endif
            return NSMutableAttributedString(attributedString: InlineCode.attributedString(string, theme: theme))
        case let .emphasis(children):
            let ans = NSMutableAttributedString()
            children
                .map { $0.render(theme: theme, context: context, decoration: decoration) }
                .forEach { ans.append($0) }
            ans.addAttributes(
                [
                    .underlineStyle: NSUnderlineStyle.thick.rawValue,
                    .underlineColor: theme.colors.emphasis,
                ],
                range: NSRange(location: 0, length: ans.length),
            )
            return ans
        case let .strong(children):
            let ans = NSMutableAttributedString()
            children
                .map { $0.render(theme: theme, context: context, decoration: decoration) }
                .forEach { ans.append($0) }
            ans.enumerateAttribute(.font, in: NSRange(location: 0, length: ans.length)) { value, range, _ in
                #if canImport(UIKit)
                    guard let font = value as? UIFont, font != theme.fonts.body else {
                        ans.addAttribute(.font, value: theme.fonts.bold, range: range)
                        return
                    }
                    let traits = font.fontDescriptor.symbolicTraits.union(.traitBold)
                    let boldFont = font.fontDescriptor.withSymbolicTraits(traits)
                        .map { UIFont(descriptor: $0, size: 0) } ?? font
                    ans.addAttribute(.font, value: boldFont, range: range)
                #elseif canImport(AppKit)
                    guard let font = value as? NSFont, font != theme.fonts.body else {
                        ans.addAttribute(.font, value: theme.fonts.bold, range: range)
                        return
                    }
                    ans.addAttribute(.font, value: font.bold, range: range)
                #endif
            }
            return ans
        case let .strikethrough(children):
            let ans = NSMutableAttributedString()
            children
                .map { $0.render(theme: theme, context: context, decoration: decoration) }
                .forEach { ans.append($0) }
            ans.addAttributes(
                [.strikethroughStyle: NSUnderlineStyle.thick.rawValue],
                range: NSRange(location: 0, length: ans.length),
            )
            return ans
        case let .link(destination, children):
            let ans = NSMutableAttributedString()
            children
                .map { $0.render(theme: theme, context: context, decoration: decoration) }
                .forEach { ans.append($0) }
            ans.addAttributes(
                [
                    .link: destination,
                    .foregroundColor: theme.colors.highlight,
                ],
                range: NSRange(location: 0, length: ans.length),
            )
            if theme.showsLinkUnderline {
                ans.addAttributes([.underlineStyle: NSUnderlineStyle.single.rawValue, .underlineColor: theme.colors.link], range: NSRange(location: 0, length: ans.length))
            }
            return ans
        case let .footnote(destination, children):
            #if canImport(UIKit)
                let ans = NSMutableAttributedString()
                children.map { $0.render(theme: theme, context: context, decoration: decoration) }.forEach { ans.append($0) }
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
                let drawingCallback = TextLabel.LineDrawingAction { context, line, lineOrigin in
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
                let attachment = TextLabel.Attachment.hold(attrString: .init(string: destination), size: imageSize)
                let attributes: [NSAttributedString.Key: Any] = [
                    .litextAttachment: attachment,
                    .litextLineDrawingAction: drawingCallback,
                    kCTRunDelegateAttributeName as NSAttributedString.Key: attachment.runDelegate,
                    .contextIdentifier: replacementIdentifier,
                    .link: destination
                ]

                return NSAttributedString(
                    string: TextLabel.Attachment.replacementText,
                    attributes: attributes
                )
            #else
                return MarkdownInlineNode.link(destination: destination, children: children).render(theme: theme, context: context, decoration: decoration)
            #endif
        case let .image(source, _): // children => alternative text can be ignored?
            return NSAttributedString(
                string: source,
                attributes: [
                    .link: source,
                    .font: theme.fonts.body,
                    .foregroundColor: theme.colors.body,
                ],
            )
        case let .math(content, replacementIdentifier):
            // Get LaTeX content from rendered context or fallback to raw content
            let latexContent = context.rendered[replacementIdentifier]?.text ?? content

            if let item = context.rendered[replacementIdentifier], let image = item.image {
                let cacheKey = InlineMathCache.Key(
                    image: ObjectIdentifier(image),
                    identifier: replacementIdentifier,
                    latex: latexContent,
                    color: theme.colors.body,
                )
                if let cached = InlineMathCache.storage.value(forKey: cacheKey) {
                    return cached
                }
                let imageSize = image.size
                let textColor = theme.colors.body
                let contextKey = NSAttributedString.Key.contextIdentifier.rawValue as CFString

                let drawingCallback = TextLabel.LineDrawingAction { context, line, lineOrigin in
                    let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
                    var runOffsetX: CGFloat = 0
                    for i in 0 ..< glyphRuns.count {
                        let run = glyphRuns[i] as! CTRun
                        let attributes = CTRunGetAttributes(run)
                        if let ptr = CFDictionaryGetValue(attributes, Unmanaged.passUnretained(contextKey).toOpaque()) {
                            let value = Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue()
                            if (value as? String) == replacementIdentifier {
                                break
                            }
                        }
                        runOffsetX += CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil)
                    }

                    var ascent: CGFloat = 0
                    var descent: CGFloat = 0
                    CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                    var drawSize = imageSize
                    if drawSize.height > ascent { // we only draw above the line
                        drawSize = CGSize(width: drawSize.width * (ascent / drawSize.height), height: ascent)
                    }

                    let rect = CGRect(
                        x: lineOrigin.x + runOffsetX,
                        y: lineOrigin.y,
                        width: drawSize.width,
                        height: drawSize.height,
                    )

                    context.saveGState()

                    #if canImport(UIKit)
                        context.translateBy(x: 0, y: rect.origin.y + rect.size.height)
                        context.scaleBy(x: 1, y: -1)
                        context.translateBy(x: 0, y: -rect.origin.y)
                        image.draw(in: rect)
                    #else
                        assert(image.isTemplate)
                        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                            // Resolve the theme's colour at draw time for dynamic appearance updates
                            context.clip(to: rect, mask: cgImage)
                            context.setFillColor(textColor.cgColor)
                            context.fill(rect)
                        } else {
                            assertionFailure()
                        }
                    #endif

                    context.restoreGState()
                }
                // The image is drawn standing on the baseline, so it reserves its
                // height above the baseline and nothing below it.
                let attachment = TextLabel.Attachment.hold(
                    attrString: .init(string: latexContent),
                    size: imageSize,
                    descent: 0,
                )

                let attributes: [NSAttributedString.Key: Any] = [
                    .litextAttachment: attachment,
                    .litextLineDrawingAction: drawingCallback,
                    kCTRunDelegateAttributeName as NSAttributedString.Key: attachment.runDelegate,
                    .contextIdentifier: replacementIdentifier,
                    .mathLatexContent: latexContent, // Store LaTeX content for on-demand rendering
                ]

                let rendered = NSAttributedString(
                    string: TextLabel.Attachment.replacementText,
                    attributes: attributes,
                )
                InlineMathCache.storage.setValue(rendered, forKey: cacheKey)
                return rendered
            } else {
                // Fallback: render failed, show original LaTeX as inline code
                return InlineCode.attributedString(latexContent, theme: theme)
            }
        }
    }
}

/// Rendered inline math, shared by every content.
///
/// A rebuilt document makes its math again, and the drawing action and run
/// delegate it carries compare by identity, so a paragraph holding math never
/// compared equal to itself: the label typeset it again on every streamed
/// update. The same formula, image and colour now yield the same string.
@MainActor
private enum InlineMathCache {
    /// The image is one `MathRenderer` cached for the formula; the entry keeps
    /// it alive, so its identifier is not reused while the entry exists.
    struct Key: Hashable, @unchecked Sendable {
        let image: ObjectIdentifier
        let identifier: String
        let latex: String
        let color: PlatformColor
    }

    static let storage = LRUCache<Key, NSAttributedString>(countLimit: 512)
}

#if canImport(UIKit)
// MARK: - Inline code as a rounded pill

extension MarkdownInlineNode {
    /// 行内代码按「文字 + 内边距 + 圆角底色」整体绘制成一张图，插入为附件。
    /// CoreText 不会绘制 .backgroundColor，也不支持内边距 / 圆角，只能这样做才能和网页编辑器的样式一致。
    /// 选中 / 复制时附件仍持有原始文字。
    @MainActor
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
        let drawingCallback = TextLabel.LineDrawingAction { context, line, lineOrigin in
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
        let attachment = TextLabel.Attachment.hold(attrString: .init(string: string), size: imageSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .litextAttachment: attachment,
            .litextLineDrawingAction: drawingCallback,
            kCTRunDelegateAttributeName as NSAttributedString.Key: attachment.runDelegate,
            .contextIdentifier: replacementIdentifier,
            .font: theme.fonts.codeInline,
        ]
        return NSAttributedString(string: TextLabel.Attachment.replacementText, attributes: attributes)
    }
}

#endif
