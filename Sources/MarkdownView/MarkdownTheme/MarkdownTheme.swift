//
//  MarkdownTheme.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2025/1/3.
//

import Foundation
import Splash
import UIKit

public extension MarkdownTheme {
    static var `default`: MarkdownTheme = .init()
    static let codeScale = 0.85
}

public struct MarkdownTheme: Equatable {
    public struct Fonts: Equatable {
        public var body = UIFont.preferredFont(forTextStyle: .body)
        public var codeInline = UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            weight: .regular
        )
        public var bold = UIFont.preferredFont(forTextStyle: .body).bold
        public var italic = UIFont.preferredFont(forTextStyle: .body).italic
        public var code = UIFont.monospacedSystemFont(
            ofSize: ceil(UIFont.preferredFont(forTextStyle: .body).pointSize * codeScale),
            weight: .regular
        )
        public var largeTitle = UIFont.preferredFont(forTextStyle: .body).bold
        public var title = UIFont.preferredFont(forTextStyle: .body).bold
        public var footnote = UIFont.preferredFont(forTextStyle: .footnote)
        /// 分级标题字体：nil 时回退到 `title`（保持旧行为，所有级别同一字号）。
        /// heading1 → H1，heading2 → H2，heading3 → H3～H6。
        public var heading1: UIFont?
        public var heading2: UIFont?
        public var heading3: UIFont?
        /// 有序列表序号字体，nil 时用 `body`
        public var listNumber: UIFont?
    }

    public var fonts: Fonts = .init()

    public struct Colors: Equatable {
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
        public var codeBackground = UIColor.gray.withAlphaComponent(0.25)
        // 增加脚注文字颜色和背景色
        public var footnote = UIColor.black
        public var footnoteBackground = UIColor.gray.withAlphaComponent(0.35)
        // 链接下划线颜色
        public var link = UIColor.blue
        /// 引用块文字颜色，nil 时用 body
        public var blockquoteText: UIColor?
        /// 引用块左侧竖条颜色，nil 时用 body 10%
        public var blockquoteBar: UIColor?
        /// 任务列表复选框边框 / 勾选填充色，nil 时沿用旧的图标画法
        public var checkboxBorder: UIColor?
        public var checkboxFill: UIColor?
        public var checkboxCheck: UIColor = .white
    }

    public var colors: Colors = .init()
    public var showsLinkUnderline = true

    public struct Spacings: Equatable {
        public var final: CGFloat = 16
        public var general: CGFloat = 8
        public var list: CGFloat = 12
        public var cell: CGFloat = 32
        /// 段落之间的间距（paragraphSpacing）
        public var paragraph: CGFloat = 16
        /// 段落内行距（lineSpacing）
        public var line: CGFloat = 4
        /// H1 / H2 上下间距
        public var heading1Before: CGFloat = 16
        public var heading1After: CGFloat = 16
        /// H3～H6 上下间距
        public var headingBefore: CGFloat = 16
        public var headingAfter: CGFloat = 16
        /// 列表项之间 / 列表结束后的间距
        public var listItem: CGFloat = 8
        public var listEnd: CGFloat = 16
        /// 引用块内段落间距
        public var blockquoteParagraph: CGFloat = 8
    }

    public var spacings: Spacings = .init()

    public struct Sizes: Equatable {
        public var bullet: CGFloat = 4
        /// 列表每级缩进
        public var listIndent: CGFloat = 24
        /// 有序列表序号右缘与正文之间的间距
        public var listNumberGap: CGFloat = 2
        /// 任务复选框边长（配合 colors.checkboxBorder 使用自绘样式）
        public var checkbox: CGFloat = 18
        public var checkboxBorderWidth: CGFloat = 2
        public var checkboxCornerRadius: CGFloat = 4
        /// 行内代码：圆角 > 0 时按「文字 + 内边距 + 圆角底」整体绘制，否则只给文字加背景色
        public var inlineCodeCornerRadius: CGFloat = 0
        public var inlineCodePadding: UIEdgeInsets = .zero
        /// 引用块竖条
        public var blockquoteBarWidth: CGFloat = 4
        public var blockquoteBarCornerRadius: CGFloat = 2
        /// 引用块文字距左边缘（含竖条）
        public var blockquoteIndent: CGFloat = 16
    }

    public var sizes: Sizes = .init()

    public struct Table: Equatable {
        public var cornerRadius: CGFloat = 8
        public var borderWidth: CGFloat = 1
        public var borderColor = UIColor.separator
        public var headerBackgroundColor = UIColor.systemGray6
        public var cellBackgroundColor = UIColor.clear
        public var stripeCellBackgroundColor = UIColor.systemGray.withAlphaComponent(0.03)
        /// 行分隔线颜色，nil 时同 borderColor
        public var rowSeparatorColor: UIColor?
        /// 表头 / 数据单元格字体，nil 时沿用正文字体（表头加粗）
        public var headerFont: UIFont?
        public var cellFont: UIFont?
        /// 单元格内边距（水平 / 垂直）
        public var cellPadding: CGFloat = 10
        /// 行最小高度
        public var minimumRowHeight: CGFloat = 0
    }

    public var table: Table = .init()

    public init() {}
}

public extension MarkdownTheme {
    static var defaultValueFont: Fonts { Fonts() }
    static var defaultValueColor: Colors { Colors() }
    static var defaultValueSpacing: Spacings { Spacings() }
    static var defaultValueSize: Sizes { Sizes() }
    static var defaultValueTable: Table { Table() }
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

    func scale(_ font: UIFont) -> UIFont {
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
        fonts.codeInline = fonts.codeInline.withSize(pointSize)
        fonts.bold = fonts.bold.withSize(pointSize).bold
        fonts.italic = fonts.italic.withSize(pointSize)
        fonts.code = fonts.code.withSize(pointSize * Self.codeScale)
        fonts.largeTitle = fonts.largeTitle.withSize(pointSize).bold
        fonts.title = fonts.title.withSize(pointSize).bold
    }
}
