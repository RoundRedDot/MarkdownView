import MarkdownParser
@testable import MarkdownView
import XCTest

final class ForkCompatibilityTests: XCTestCase {
    func testCitationLinkRetainsFootnoteIdentity() {
        let blocks = MarkdownParser().parse("[^1](https://example.com)").document
        XCTAssertEqual(blocks, [.paragraph(content: [
            .footnote(destination: "https://example.com", children: [.text("1")]),
        ])])
    }

    @MainActor
    func testCustomHeadingFontAndListIndentReachRenderedText() {
        var theme = MarkdownTheme.default
        theme.fonts.heading1 = .systemFont(ofSize: 22)
        theme.sizes.listIndent = 28
        let view = MarkdownTextView()
        view.theme = theme
        view.setMarkdownManually(.init(parserResult: MarkdownParser().parse("# title\n\n- item"), theme: theme))
        let text = view.textView.attributedText
        let title = (text.string as NSString).range(of: "title")
        let item = (text.string as NSString).range(of: "item")
        XCTAssertNotEqual(title.location, NSNotFound)
        XCTAssertNotEqual(item.location, NSNotFound)
        guard title.location != NSNotFound, item.location != NSNotFound else { return }
        XCTAssertEqual((text.attribute(.font, at: title.location, effectiveRange: nil) as? PlatformFont)?.pointSize, 22)
        XCTAssertEqual((text.attribute(.paragraphStyle, at: item.location, effectiveRange: nil) as? NSParagraphStyle)?.headIndent, 28)
    }

    #if canImport(UIKit)
        @MainActor
        func testFootnoteIsALinkRatherThanMathPreview() {
            let theme = MarkdownTheme.default
            let view = MarkdownTextView()
            view.setMarkdownManually(.init(parserResult: MarkdownParser().parse("[^1](https://example.com)"), theme: theme))
            let text = view.textView.attributedText
            XCTAssertGreaterThan(text.length, 0)
            guard text.length > 0 else { return }
            XCTAssertEqual(text.attribute(.link, at: 0, effectiveRange: nil) as? String, "https://example.com")
            XCTAssertNil(text.attribute(.mathLatexContent, at: 0, effectiveRange: nil))
        }
    #endif
}
