//
//  MarkdownTheme.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2025/1/3.
//

import Foundation
import Litext

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public extension MarkdownTheme {
    @MainActor static var `default`: MarkdownTheme = .init()
    static let codeScale = 0.85
    /// Inline code is set at the body's size.
    static let codeInlineScale = 1.0
}

public struct MarkdownTheme: Equatable, @unchecked Sendable {
    public struct Fonts: Equatable, @unchecked Sendable {
        #if canImport(UIKit)
            public var body = UIFont.preferredFont(forTextStyle: .body)
            public var codeInline = UIFont.monospacedSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize * codeInlineScale,
                weight: .regular,
            )
            public var bold = UIFont.preferredFont(forTextStyle: .body).bold
            public var italic = UIFont.preferredFont(forTextStyle: .body).italic
            public var code = UIFont.monospacedSystemFont(
                ofSize: ceil(UIFont.preferredFont(forTextStyle: .body).pointSize * codeScale),
                weight: .regular,
            )
            public var largeTitle = UIFont.preferredFont(forTextStyle: .body).bold
            public var title = UIFont.preferredFont(forTextStyle: .body).bold
            public var footnote = UIFont.preferredFont(forTextStyle: .footnote)
        #elseif canImport(AppKit)
            public var body = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            public var codeInline = NSFont.monospacedSystemFont(
                ofSize: NSFont.systemFontSize * codeInlineScale,
                weight: .regular,
            )
            public var bold = NSFont.systemFont(ofSize: NSFont.systemFontSize).bold
            public var italic = NSFont.systemFont(ofSize: NSFont.systemFontSize).italic
            public var code = NSFont.monospacedSystemFont(
                ofSize: ceil(NSFont.systemFontSize * codeScale),
                weight: .regular,
            )
            public var largeTitle = NSFont.systemFont(ofSize: NSFont.systemFontSize).bold
            public var title = NSFont.systemFont(ofSize: NSFont.systemFontSize).bold
            public var footnote = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        #endif
        public var heading1: PlatformFont?
        public var heading2: PlatformFont?
        public var heading3: PlatformFont?
        public var listNumber: PlatformFont?
    }

    public var fonts: Fonts = .init()

    public struct Colors: Equatable, @unchecked Sendable {
        #if canImport(UIKit)
            public var body = UIColor.label
            public var highlight =
                UIColor(named: "AccentColor")
                    ?? UIColor(named: "accentColor")
                    ?? .systemOrange
            public var emphasis =
                UIColor(named: "AccentColor")
                    ?? UIColor(named: "accentColor")
                    ?? .systemOrange
            public var code = UIColor.label
            public var codeBackground = CodeBlockDefaults.background
            public var codeBlockBackground = CodeBlockDefaults.background
            public var codeBlockBarBackground = CodeBlockDefaults.barBackground
            public var selectionBackground: UIColor? =
                (UIColor(named: "AccentColor")
                        ?? UIColor(named: "accentColor")
                        ?? .systemOrange).withAlphaComponent(0.2)
        #elseif canImport(AppKit)
            public var body = NSColor.labelColor
            public var highlight =
                NSColor(named: "AccentColor")
                    ?? NSColor(named: "accentColor")
                    ?? .systemOrange
            public var emphasis =
                NSColor(named: "AccentColor")
                    ?? NSColor(named: "accentColor")
                    ?? .systemOrange
            public var code = NSColor.labelColor
            public var codeBackground = CodeBlockDefaults.background
            public var codeBlockBackground = CodeBlockDefaults.background
            public var codeBlockBarBackground = CodeBlockDefaults.barBackground
            public var selectionBackground: NSColor? =
                (NSColor(named: "AccentColor")
                        ?? NSColor(named: "accentColor")
                        ?? .systemOrange).withAlphaComponent(0.2)
        #endif
        public var footnote = PlatformColor.black
        public var footnoteBackground = PlatformColor.gray.withAlphaComponent(0.35)
        public var link = PlatformColor.blue
        public var blockquoteText: PlatformColor?
        public var blockquoteBar: PlatformColor?
        public var checkboxBorder: PlatformColor?
        public var checkboxFill: PlatformColor?
        public var checkboxCheck = PlatformColor.white
    }

    public var showsLinkUnderline = true
    public var colors: Colors = .init()

    public struct Spacings: Equatable, Sendable {
        public var final: CGFloat = 16
        public var general: CGFloat = 8
        public var list: CGFloat = 12
        public var cell: CGFloat = 32
        /// Space after every block-level element (paragraphs, headings,
        /// code blocks, tables…). Defaults match the previously hardcoded
        /// 16 pt so existing consumers render unchanged.
        public var paragraph: CGFloat = 16
        /// Extra space above a heading.
        public var headingBefore: CGFloat = 16
        public var line: CGFloat = 4
        public var heading1Before: CGFloat = 16
        public var heading1After: CGFloat = 16
        public var headingAfter: CGFloat = 16
        public var listItem: CGFloat = 8
        public var listEnd: CGFloat = 16
        public var blockquoteParagraph: CGFloat = 8
    }

    public var spacings: Spacings = .init()

    public struct Sizes: Equatable, Sendable {
        public var bullet: CGFloat = 4
        public var listIndent: CGFloat = 24
        public var listNumberGap: CGFloat = 2
        public var checkbox: CGFloat = 18
        public var checkboxBorderWidth: CGFloat = 2
        public var checkboxCornerRadius: CGFloat = 4
        public var inlineCodeCornerRadius: CGFloat = 0
        #if canImport(UIKit)
            public var inlineCodePadding: UIEdgeInsets = .zero
        #endif
        public var blockquoteBarWidth: CGFloat = 4
        public var blockquoteBarCornerRadius: CGFloat = 2
        public var blockquoteIndent: CGFloat = 16
    }

    public var sizes: Sizes = .init()

    public struct Table: Equatable, @unchecked Sendable {
        public var cornerRadius: CGFloat = 8
        public var borderWidth: CGFloat = 1
        #if canImport(UIKit)
            public var borderColor = UIColor.separator
            public var headerBackgroundColor = UIColor.systemGray6
            public var cellBackgroundColor = UIColor.clear
            public var stripeCellBackgroundColor = UIColor.systemGray.withAlphaComponent(0.03)
        #elseif canImport(AppKit)
            public var borderColor = NSColor.separatorColor
            public var headerBackgroundColor = NSColor.windowBackgroundColor
            public var cellBackgroundColor = NSColor.clear
            public var stripeCellBackgroundColor = NSColor.systemGray.withAlphaComponent(0.03)
        #endif
        public var rowSeparatorColor: PlatformColor?
        public var headerFont: PlatformFont?
        public var cellFont: PlatformFont?
        public var cellPadding: CGFloat = 10
        public var minimumRowHeight: CGFloat = 0
    }

    public var table: Table = .init()

    public var syntax: Syntax = .init()

    public init() {}
}

/// Translucent, so a code block shades whatever it sits on rather than
/// laying a fixed grey over a tinted page: 5% black in light appearance,
/// 10% white in dark. The bar sits on the body and lays the same layer
/// again, so it is one step further from the page.
enum CodeBlockDefaults {
    static let background = PlatformColor(
        light: PlatformColor.black.withAlphaComponent(0.05),
        dark: PlatformColor.white.withAlphaComponent(0.1),
    )
    static let barBackground = background
}

public extension MarkdownTheme {
    static var defaultValueFont: Fonts {
        Fonts()
    }

    static var defaultValueColor: Colors {
        Colors()
    }

    static var defaultValueSpacing: Spacings {
        Spacings()
    }

    static var defaultValueSize: Sizes {
        Sizes()
    }

    static var defaultValueTable: Table {
        Table()
    }
}

public extension MarkdownTheme {
    enum FontScale: String, CaseIterable {
        case tiny
        case small
        case middle
        case large
        case huge
    }
}

public extension MarkdownTheme.FontScale {
    var offset: Int {
        switch self {
        case .tiny: -4
        case .small: -2
        case .middle: 0
        case .large: 2
        case .huge: 4
        }
    }

    func scale(_ font: PlatformFont) -> PlatformFont {
        let size = max(4, font.pointSize + CGFloat(offset))
        return font.withSize(size)
    }
}

public extension MarkdownTheme {
    mutating func scaleFont(by scale: FontScale) {
        let defaultFont = Self.defaultValueFont
        fonts.body = scale.scale(defaultFont.body)
        fonts.codeInline = scale.scale(defaultFont.codeInline)
        fonts.bold = scale.scale(defaultFont.bold)
        fonts.italic = scale.scale(defaultFont.italic)
        fonts.code = scale.scale(defaultFont.code)
        fonts.largeTitle = scale.scale(defaultFont.largeTitle)
        fonts.title = scale.scale(defaultFont.title)
    }

    mutating func align(to pointSize: CGFloat) {
        fonts.body = fonts.body.withSize(pointSize)
        fonts.codeInline = fonts.codeInline.withSize(pointSize * Self.codeInlineScale)
        fonts.bold = fonts.bold.withSize(pointSize).bold
        fonts.italic = fonts.italic.withSize(pointSize)
        fonts.code = fonts.code.withSize(pointSize * Self.codeScale)
        fonts.largeTitle = fonts.largeTitle.withSize(pointSize).bold
        fonts.title = fonts.title.withSize(pointSize).bold
    }
}
