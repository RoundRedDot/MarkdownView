//
//  Created by Litext Team.
//  Copyright (c) 2025 Litext Team. All rights reserved.
//

import CoreGraphics
import CoreText
import Foundation
import QuartzCore

public extension LTXLabel {
    @objc func selectAllText() {
        guard let range = selectAllRange() else { return }
        selectionRange = range
    }

    /// 选中某一点所在的词（中文按系统分词，通常两三个字），给宿主做「长按选字」；没选上返回 false
    @discardableResult
    func selectWord(at point: CGPoint) -> Bool {
        guard isSelectable, let index = textIndexAtPoint(point) else { return false }
        selectWordAtIndex(index)
        guard let range = selectionRange, range.length > 0 else { return false }
        return true
    }

    /// 在当前选区上方弹出系统的拷贝菜单
    func presentSelectionMenu() {
        showSelectionMenuController()
    }

    /// 清掉当前选区
    func clearTextSelection() {
        clearSelection()
    }
}

extension LTXLabel {
    func selectWordAtIndex(_ index: Int) {
        guard isSelectable else { return }
        let attributedString = textLayout.attributedString
        guard attributedString.length > 0, index < attributedString.length else { return }
        let nsString = attributedString.string as NSString
        let range = nsString.rangeOfWord(at: index)
        guard range.location != NSNotFound, range.length > 0 else { return }
        selectionRange = range
    }

    func selectSentenceAtIndex(_ index: Int) {
        guard isSelectable else { return }
        guard let text = textLayout.attributedString.string as NSString? else { return }
        let sentenceDelimiters = CharacterSet(charactersIn: ".!?")
        var startIndex = index
        while startIndex > 0 {
            let prevChar = text.substring(with: NSRange(location: startIndex - 1, length: 1))
            if sentenceDelimiters.contains(prevChar.unicodeScalars.first!) {
                break
            }
            startIndex -= 1
        }
        var endIndex = index
        while endIndex < text.length {
            if endIndex < text.length - 1 {
                let currentChar = text.substring(with: NSRange(location: endIndex, length: 1))
                if sentenceDelimiters.contains(currentChar.unicodeScalars.first!) {
                    endIndex += 1
                    break
                }
            }
            endIndex += 1
        }
        let range = NSRange(location: startIndex, length: endIndex - startIndex)
        selectionRange = range
    }

    func selectLineAtIndex(_ index: Int) {
        guard isSelectable else { return }
        let attributedString = textLayout.attributedString
        guard attributedString.length > 0,
              index < attributedString.length
        else { return }

        let nsString = attributedString.string as NSString
        let lineRange = nsString.rangeOfLine(at: index)

        guard lineRange.location != NSNotFound, lineRange.length > 0 else { return }
        selectionRange = lineRange
    }

    func selectAllRange() -> NSRange? {
        guard isSelectable else { return nil }
        let attributedString = textLayout.attributedString
        guard attributedString.length > 0 else { return nil }
        return NSRange(location: 0, length: attributedString.length)
    }
}
