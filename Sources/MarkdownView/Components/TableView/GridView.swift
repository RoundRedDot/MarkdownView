//
//  GridView.swift
//  MarkdownView
//
//  Created by ktiays on 2025/1/27.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import UIKit

final class GridView: UIView {
    private var widths: [CGFloat] = []
    private var heights: [CGFloat] = []
    private var totalWidth: CGFloat = 0
    private var totalHeight: CGFloat = 0

    private lazy var shapeLayer: CAShapeLayer = .init()
    private lazy var rowLineLayer: CAShapeLayer = .init()
    private lazy var headerBackgroundLayer: CAShapeLayer = .init()
    private lazy var backgroundLayer: CAShapeLayer = .init()
    private lazy var stripeLayer: CAShapeLayer = .init()
    var padding: CGFloat = 2
    private var theme: MarkdownTheme = .default
    private var hasHeaderRow: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    @MainActor
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 动态色要按当前 trait 解析，否则深色模式下 layer 拿到的还是浅色值
    private func cg(_ color: UIColor) -> CGColor {
        color.resolvedColor(with: traitCollection).cgColor
    }

    private func setupView() {
        // background layer
        backgroundLayer.fillColor = cg(theme.table.cellBackgroundColor)
        backgroundLayer.strokeColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = 0
        layer.addSublayer(backgroundLayer)

        // stripe layer
        stripeLayer.fillColor = cg(theme.table.stripeCellBackgroundColor)
        layer.addSublayer(stripeLayer)

        // header background
        headerBackgroundLayer.fillColor = cg(theme.table.headerBackgroundColor)
        stripeLayer.fillColor = cg(theme.table.stripeCellBackgroundColor)
        layer.addSublayer(headerBackgroundLayer)

        // row separators（可与外框 / 列线不同色）
        rowLineLayer.lineWidth = theme.table.borderWidth
        rowLineLayer.strokeColor = cg((theme.table.rowSeparatorColor ?? theme.table.borderColor))
        rowLineLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(rowLineLayer)

        // borders
        shapeLayer.lineWidth = theme.table.borderWidth
        shapeLayer.strokeColor = cg(theme.table.borderColor)
        shapeLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(shapeLayer)

        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateThemeColors()
    }

    private func updateThemeColors() {
        backgroundLayer.fillColor = cg(theme.table.cellBackgroundColor)
        backgroundLayer.strokeColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = 0
        stripeLayer.fillColor = cg(theme.table.stripeCellBackgroundColor)
        shapeLayer.strokeColor = cg(theme.table.borderColor)
        shapeLayer.lineWidth = theme.table.borderWidth
        rowLineLayer.strokeColor = cg((theme.table.rowSeparatorColor ?? theme.table.borderColor))
        rowLineLayer.lineWidth = theme.table.borderWidth
        headerBackgroundLayer.fillColor = cg(theme.table.headerBackgroundColor)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundLayer.frame = bounds
        shapeLayer.frame = bounds
        rowLineLayer.frame = bounds
        headerBackgroundLayer.frame = bounds
        stripeLayer.frame = bounds
        drawBackground()
        drawStripeRows()
        drawGrid()
        drawHeaderBackground()
    }

    private func drawBackground() {
        let cornerRadius = theme.table.cornerRadius
        let lineWidth = theme.table.borderWidth

        // slighty smaller background
        let backgroundRect = CGRect(
            x: padding + lineWidth,
            y: padding + lineWidth,
            width: totalWidth - lineWidth * 2,
            height: totalHeight - lineWidth * 2
        )

        let backgroundPath = UIBezierPath(
            roundedRect: backgroundRect, cornerRadius: max(0, cornerRadius - lineWidth)
        )
        backgroundLayer.path = backgroundPath.cgPath
    }

    private func drawStripeRows() {
        let path = UIBezierPath()
        let lineWidth = theme.table.borderWidth

        var y: CGFloat = padding
        if hasHeaderRow {
            guard !heights.isEmpty else {
                stripeLayer.path = nil
                return
            }
            y += heights[0]
        }

        let startRow = hasHeaderRow ? 1 : 0
        for i in startRow ..< heights.count {
            let dataRowIndex = i - startRow
            if dataRowIndex % 2 == 1 {
                let stripeRect = CGRect(
                    x: padding + lineWidth,
                    y: y,
                    width: totalWidth - (lineWidth * 2),
                    height: heights[i]
                )
                path.append(UIBezierPath(rect: stripeRect))
            }
            y += heights[i]
        }

        let cornerRadius = theme.table.cornerRadius
        let backgroundRect = CGRect(
            x: padding + lineWidth,
            y: padding + lineWidth,
            width: totalWidth - lineWidth * 2,
            height: totalHeight - lineWidth * 2
        )
        let clipPath = UIBezierPath(
            roundedRect: backgroundRect, cornerRadius: max(0, cornerRadius - lineWidth)
        )
        let mask = CAShapeLayer()
        mask.path = clipPath.cgPath
        stripeLayer.mask = mask

        stripeLayer.path = path.cgPath
    }

    private func drawGrid() {
        let path = UIBezierPath()
        let cornerRadius = theme.table.cornerRadius
        let lineWidth = theme.table.borderWidth
        let halfLineWidth = lineWidth / 2

        let outerRect = CGRect(
            x: padding + halfLineWidth,
            y: padding + halfLineWidth,
            width: totalWidth - lineWidth,
            height: totalHeight - lineWidth
        )

        let outerPath = UIBezierPath(roundedRect: outerRect, cornerRadius: cornerRadius)
        path.append(outerPath)

        // Draw vertical lines
        var x: CGFloat = padding
        for (index, width) in widths.enumerated() {
            if index < widths.count - 1 {
                x += width
                path.move(to: .init(x: x, y: padding + halfLineWidth))
                path.addLine(to: .init(x: x, y: totalHeight + padding - halfLineWidth))
            }
        }

        shapeLayer.path = path.cgPath

        // Draw horizontal lines（单独一层，颜色可独立配置）
        let rowPath = UIBezierPath()
        var y: CGFloat = padding
        for (index, height) in heights.enumerated() {
            if index < heights.count - 1 {
                y += height
                rowPath.move(to: .init(x: padding + halfLineWidth, y: y))
                rowPath.addLine(to: .init(x: totalWidth + padding - halfLineWidth, y: y))
            }
        }
        rowLineLayer.path = rowPath.cgPath
    }

    private func drawHeaderBackground() {
        guard hasHeaderRow, !heights.isEmpty else {
            headerBackgroundLayer.path = nil
            return
        }

        let cornerRadius = theme.table.cornerRadius
        let lineWidth = theme.table.borderWidth
        let headerHeight = heights[0]

        let headerRect = CGRect(
            x: padding + lineWidth,
            y: padding + lineWidth,
            width: totalWidth - lineWidth * 2,
            height: headerHeight - lineWidth
        )

        let adjustedCornerRadius = max(0, cornerRadius - lineWidth)
        let path = UIBezierPath()

        // top rounded corners
        path.move(to: CGPoint(x: headerRect.minX, y: headerRect.minY + adjustedCornerRadius))
        path.addArc(
            withCenter: CGPoint(
                x: headerRect.minX + adjustedCornerRadius, y: headerRect.minY + adjustedCornerRadius
            ),
            radius: adjustedCornerRadius, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true
        )
        path.addLine(to: CGPoint(x: headerRect.maxX - adjustedCornerRadius, y: headerRect.minY))
        path.addArc(
            withCenter: CGPoint(
                x: headerRect.maxX - adjustedCornerRadius, y: headerRect.minY + adjustedCornerRadius
            ),
            radius: adjustedCornerRadius, startAngle: 3 * .pi / 2, endAngle: 0, clockwise: true
        )
        path.addLine(to: CGPoint(x: headerRect.maxX, y: headerRect.maxY))
        path.addLine(to: CGPoint(x: headerRect.minX, y: headerRect.maxY))
        path.close()

        headerBackgroundLayer.path = path.cgPath
    }

    func update(widths: [CGFloat], heights: [CGFloat]) {
        self.widths = widths
        self.heights = heights
        totalWidth = widths.reduce(0, +)
        totalHeight = heights.reduce(0, +)
        setNeedsLayout()
    }

    func setTheme(_ theme: MarkdownTheme) {
        self.theme = theme
        updateThemeColors()
        shapeLayer.lineWidth = theme.table.borderWidth
        setNeedsLayout()
    }

    func setHeaderRow(_ hasHeader: Bool) {
        hasHeaderRow = hasHeader
        setNeedsLayout()
    }
}
