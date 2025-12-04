//
//  NSAttributedString+Extension.swift
//  MarkdownView
//
//  Created by 秋星桥 on 1/23/25.
//

import CoreText
import Foundation
import Litext

public extension NSAttributedString.Key {
    @inline(__always) static let coreTextRunDelegate = NSAttributedString.Key(rawValue: kCTRunDelegateAttributeName as String)
}

extension NSAttributedString {
    func drawToImage(
            padding: UIEdgeInsets = .zero,
            backgroundColor: UIColor? = .clear,
            minSize: CGSize = .zero,
            scale: CGFloat = UIScreen.main.scale
        ) -> UIImage {

            // MARK: - CoreText 计算真实文字尺寸
            let line = CTLineCreateWithAttributedString(self)

            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let textWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
            let textHeight = ascent + descent

            let contentWidth = textWidth + padding.left + padding.right
            let contentHeight = textHeight + padding.top + padding.bottom

            // MARK: - 加入 minSize（关键）
            let finalWidth = max(contentWidth, minSize.width)
            let finalHeight = max(contentHeight, minSize.height)
            let finalSize = CGSize(width: finalWidth, height: finalHeight)

            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = false

            return UIGraphicsImageRenderer(size: finalSize, format: format).image { ctx in
                let cg = ctx.cgContext

                // 背景
                if let bg = backgroundColor {
                    let rect = CGRect(origin: .zero, size: finalSize)
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: finalSize.height / 2.0)
                    cg.addPath(path.cgPath)
                    cg.setFillColor(bg.cgColor)
                    cg.drawPath(using: .fill)
                    path.addClip()
                }

                // MARK: - 翻转坐标系
                cg.translateBy(x: 0, y: finalSize.height)
                cg.scaleBy(x: 1, y: -1)

                // MARK: - 计算“文字实际绘制点”
                // 最终大小可能大于文本，需要将文字居中
                let totalTextHeight = ascent + descent
                let originX = (finalSize.width - textWidth) / 2
                // baseline Y = 中心位置 + descent（因为 baseline 在字形上方）
                let originY = (finalSize.height - totalTextHeight) / 2 + descent

                cg.textPosition = CGPoint(x: originX, y: originY)

                // 绘制
                CTLineDraw(line, cg)
            }
        }
}
