//
//  Created by ktiays on 2025/1/20.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import CoreText
import Litext
import MarkdownParser
import UIKit

// MARK: - BlockProcessor

final class BlockProcessor {
    private let theme: MarkdownTheme
    private let viewProvider: ReusableViewProvider
    private let context: MarkdownTextView.PreprocessedContent
    private let thematicBreakDrawing: TextBuilder.DrawingCallback?
    private let codeDrawing: TextBuilder.DrawingCallback?
    private let tableDrawing: TextBuilder.DrawingCallback?
    private let blockquoteMarking: TextBuilder.BlockquoteMarkingCallback?
    private let blockquoteDrawing: TextBuilder.BlockquoteDrawingCallback?

    init(
        theme: MarkdownTheme,
        viewProvider: ReusableViewProvider,
        context: MarkdownTextView.PreprocessedContent,
        thematicBreakDrawing: TextBuilder.DrawingCallback?,
        codeDrawing: TextBuilder.DrawingCallback?,
        tableDrawing: TextBuilder.DrawingCallback?,
        blockquoteMarking: TextBuilder.BlockquoteMarkingCallback?,
        blockquoteDrawing: TextBuilder.BlockquoteDrawingCallback?
    ) {
        self.theme = theme
        self.viewProvider = viewProvider
        self.context = context
        self.thematicBreakDrawing = thematicBreakDrawing
        self.codeDrawing = codeDrawing
        self.tableDrawing = tableDrawing
        self.blockquoteMarking = blockquoteMarking
        self.blockquoteDrawing = blockquoteDrawing
    }

    func processHeading(level: Int, contents: [MarkdownInlineNode]) -> NSAttributedString {
        let font: UIFont
        let spacingBefore: CGFloat
        let spacingAfter: CGFloat
        switch level {
        case 1:
            font = theme.fonts.heading1 ?? theme.fonts.title
            spacingBefore = theme.spacings.heading1Before
            spacingAfter = theme.spacings.heading1After
        case 2:
            font = theme.fonts.heading2 ?? theme.fonts.title
            spacingBefore = theme.spacings.heading1Before
            spacingAfter = theme.spacings.heading1After
        default:
            font = theme.fonts.heading3 ?? theme.fonts.title
            spacingBefore = theme.spacings.headingBefore
            spacingAfter = theme.spacings.headingAfter
        }

        return buildWithParagraphSync { paragraph in
            paragraph.paragraphSpacing = spacingAfter
            paragraph.paragraphSpacingBefore = spacingBefore
        } content: {
            let string = contents.render(theme: theme, context: context, viewProvider: viewProvider)
            string.addAttributes(
                [.font: font],
                range: NSRange(location: 0, length: string.length)
            )
            return string
        }
    }

    func processParagraph(contents: [MarkdownInlineNode]) -> NSAttributedString {
        buildWithParagraphSync { paragraph in
            paragraph.paragraphSpacing = theme.spacings.paragraph
            paragraph.lineSpacing = theme.spacings.line
        } content: {
            let rendered = contents.render(theme: theme, context: context, viewProvider: viewProvider)
            if rendered.length == 0 {
                return NSMutableAttributedString(string: " ", attributes: [.font: theme.fonts.body])
            }
            return rendered
        }
    }

    func processThematicBreak() -> NSAttributedString {
        buildWithParagraphSync {
            let drawingCallback = self.thematicBreakDrawing
            return .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxAttachment: LTXAttachment.hold(attrString: .init(string: "\n\n")),
                .ltxLineDrawingCallback: LTXLineDrawingAction(action: { context, line, lineOrigin in
                    drawingCallback?(context, line, lineOrigin)
                }),
            ])
        }
    }

    func processCodeBlock(
        language: String?,
        content: String,
        highlightMap: CodeHighlighter.HighlightMap
    ) -> (NSAttributedString, CodeView) {
        let content = content.deletingSuffix(of: .whitespacesAndNewlines)
        let codeView = viewProvider.acquireCodeView()
        codeView.theme = theme
        codeView.language = language ?? ""
        codeView.highlightMap = highlightMap
        codeView.content = content
        let drawer = codeDrawing!
        let text = buildWithParagraphSync { paragraph in
            let height = CodeView.intrinsicHeight(for: content, theme: theme)
            paragraph.minimumLineHeight = height
        } content: {
            .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxAttachment: LTXAttachment.hold(attrString: .init(string: content + "\n")),
                .ltxLineDrawingCallback: LTXLineDrawingAction { drawer($0, $1, $2) },
                .contextView: codeView,
            ])
        }
        return (text, codeView)
    }

    func processBlockquote(_ children: [MarkdownBlockNode]) -> NSAttributedString {
        guard !children.isEmpty else { return NSAttributedString() }

        let result = NSMutableAttributedString()

        let baseParagraphStyle = NSMutableParagraphStyle()
        baseParagraphStyle.firstLineHeadIndent = theme.sizes.blockquoteIndent
        baseParagraphStyle.headIndent = theme.sizes.blockquoteIndent
        baseParagraphStyle.tailIndent = -4
        baseParagraphStyle.paragraphSpacing = theme.spacings.blockquoteParagraph
        baseParagraphStyle.lineSpacing = theme.spacings.line

        for child in children {
            guard case let .paragraph(content) = child else {
                assertionFailure("Blockquote should only contain paragraphs after flattening")
                continue
            }
            let paragraphContent = content.render(theme: theme, context: context, viewProvider: viewProvider)
            if let quoteColor = theme.colors.blockquoteText {
                // 只覆盖仍是正文色的文字，保留链接 / 代码等自带颜色
                paragraphContent.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: paragraphContent.length)) { value, range, _ in
                    if let color = value as? UIColor, color == theme.colors.body {
                        paragraphContent.addAttribute(.foregroundColor, value: quoteColor, range: range)
                    }
                }
            }
            result.append(paragraphContent)
        }

        while result.string.hasSuffix("\n") {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        guard result.length > 0 else { return result }
//        result.append(.init(string: "\n"))

        result.addAttribute(
            .paragraphStyle,
            value: baseParagraphStyle, range: NSRange(location: 0, length: result.length)
        )

        let marker = blockquoteMarking!
        let drawer = blockquoteDrawing!

        result.insert(buildWithParagraphSync(withNewLine: false) { paragraph in
            paragraph = baseParagraphStyle
        } content: {
            .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .paragraphStyle: baseParagraphStyle,
                .ltxLineDrawingCallback: LTXLineDrawingAction { marker($0, $1, $2) },
            ])
        }, at: 0)
        result.append(buildWithParagraphSync(withNewLine: true) {
            .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxLineDrawingCallback: LTXLineDrawingAction { drawer($0, $1, $2) },
            ])
        })

        return result
    }

    func processTable(rows: [RawTableRow]) -> (NSAttributedString, TableView) {
        let tableView = viewProvider.acquireTableView()
        // 复用的 TableView 一直停留在 .default 主题，必须先同步当前主题再填内容（影响表头底色、边框、字体、行高）
        tableView.setTheme(theme)
        let contents = rows.map {
            $0.cells.map { rawCell in
                rawCell.content.render(theme: theme, context: context, viewProvider: viewProvider)
            }
        }
        let allContent = contents
            .map { $0.map(\.string).joined(separator: "\t") }
            .joined(separator: "\n")
        let representedText = NSAttributedString(string: allContent + "\n")
        tableView.setContents(contents)
        let drawer = tableDrawing!

        let text = buildWithParagraphSync { paragraph in
            paragraph.minimumLineHeight = tableView.intrinsicContentHeight
        } content: {
            .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxAttachment: LTXAttachment.hold(attrString: representedText),
                .ltxLineDrawingCallback: LTXLineDrawingAction { drawer($0, $1, $2) },
                .contextView: tableView,
            ])
        }
        return (text, tableView)
    }
}

// MARK: - Paragraph Helper

extension BlockProcessor {
    private func buildWithParagraphSync(
        withNewLine: Bool = true,
        modifier: (inout NSMutableParagraphStyle) -> Void = { _ in },
        content: () -> NSMutableAttributedString
    ) -> NSMutableAttributedString {
        var paragraphStyle: NSMutableParagraphStyle = .init()
        paragraphStyle.paragraphSpacing = theme.spacings.paragraph
        paragraphStyle.lineSpacing = theme.spacings.line
        modifier(&paragraphStyle)

        let string = content()
        string.addAttributes(
            [.paragraphStyle: paragraphStyle],
            range: .init(location: 0, length: string.length)
        )
        if withNewLine, !string.string.hasSuffix("\n") {
            string.append(.init(string: "\n"))
        }
        return string
    }

    private func removeLeadingSpacing(from attributedString: NSAttributedString) -> NSAttributedString {
        let mutableString = attributedString.mutableCopy() as! NSMutableAttributedString
        mutableString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: mutableString.length), options: []) { value, range, _ in
            if let style = value as? NSParagraphStyle {
                let mutableStyle = style.mutableCopy() as! NSMutableParagraphStyle
                mutableStyle.paragraphSpacingBefore = 0
                mutableString.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
            }
        }
        return mutableString
    }
}
