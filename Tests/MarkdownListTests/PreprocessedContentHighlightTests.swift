@testable import MarkdownParser
@testable import MarkdownView
import XCTest

final class PreprocessedContentHighlightTests: XCTestCase {
    @MainActor
    func testNestedCodeBlocksKeepTheirHighlightMaps() {
        let swift = "let answer = 42"
        let plain = "plain code"
        let blocks: [MarkdownBlockNode] = [
            .blockquote(children: [
                .bulletedList(isTight: true, items: [RawListItem(children: [
                    .numberedList(isTight: true, start: 1, items: [RawListItem(children: [
                        .codeBlock(fenceInfo: "swift", content: swift),
                    ])]),
                ])]),
            ]),
            .taskList(isTight: true, items: [RawTaskListItem(isCompleted: false, children: [
                .codeBlock(fenceInfo: "text", content: plain),
            ])]),
        ]
        let result = MarkdownParser.ParseResult(document: blocks, mathContext: [:])
        let maps: [Int: CodeHighlighter.HighlightMap] = result.render(theme: .default)
        let swiftKey = CodeHighlighter.current.key(for: swift, language: "swift")
        let plainKey = CodeHighlighter.current.key(for: plain, language: "text")
        XCTAssertEqual(maps.count, 2)
        XCTAssertEqual(maps[swiftKey], CodeHighlighter.current.highlight(key: swiftKey, content: swift, language: "swift"))
        XCTAssertNotNil(maps[plainKey])
    }

    @MainActor
    func testDeepAndLargeDocumentsFindCodeBlock() {
        let code = "let result = 123"
        var nested: MarkdownBlockNode = .codeBlock(fenceInfo: "swift", content: code)
        for _ in 0..<30 {
            nested = .blockquote(children: [nested])
        }
        let blocks = Array(repeating: MarkdownBlockNode.paragraph(content: []), count: 5_000) + [nested]
        let result = MarkdownParser.ParseResult(document: blocks, mathContext: [:])
        let maps: [Int: CodeHighlighter.HighlightMap] = result.render(theme: .default)
        XCTAssertEqual(maps.count, 1)
        XCTAssertNotNil(maps[CodeHighlighter.current.key(for: code, language: "swift")])
    }
}
