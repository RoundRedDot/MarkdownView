//
//  LTXLabelMenuItem.swift
//  Litext
//
//  Created by OpenAI Codex.
//

import UIKit

enum LTXLabelMenuItem: CaseIterable {
    case copy
    case selectAll
    case share

    var action: Selector? {
        switch self {
        case .copy:
            return #selector(LTXLabel.copyMenuItemTapped)
        case .selectAll:
            return #selector(LTXLabel.selectAllTapped)
        case .share:
            return #selector(LTXLabel.shareMenuItemTapped)
        }
    }

    var title: String {
        switch self {
        case .copy:
            return LocalizedText.copy
        case .selectAll:
            return LocalizedText.selectAll
        case .share:
            return LocalizedText.share
        }
    }

    var image: UIImage? {
        switch self {
        case .copy:
            return UIImage(systemName: "doc.on.doc")
        case .selectAll:
            return UIImage(systemName: "selection.pin.in.out")
        case .share:
            return UIImage(systemName: "square.and.arrow.up")
        }
    }

    static func textSelectionMenu() -> [LTXLabelMenuItem] {
        allCases
    }
}
