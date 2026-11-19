@testable import MarkdownParser
@testable import MarkdownView
import XCTest

final class PreprocessedContentHighlightTests: XCTestCase {
    @MainActor
    func testNestedCodeBlocksKeepTheirHighlightMaps() async throws {
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
        let swiftKey = CodeHighlighter.current.key(for: swift, language: "swift")
        let plainKey = CodeHighlighter.current.key(for: plain, language: "text")
        let _: [Int: CodeHighlighter.HighlightMap] = result.highlightMaps(theme: .default)
        try await waitForHighlights([swiftKey, plainKey])
        let maps: [Int: CodeHighlighter.HighlightMap] = result.highlightMaps(theme: .default)
        XCTAssertEqual(maps.count, 2)
        XCTAssertEqual(maps[swiftKey], CodeHighlighter.current.highlight(key: swiftKey, content: swift, language: "swift"))
        XCTAssertNotNil(maps[plainKey])
    }

    @MainActor
    func testDeepAndLargeDocumentsFindCodeBlock() async throws {
        let code = "let result = 123"
        var nested: MarkdownBlockNode = .codeBlock(fenceInfo: "swift", content: code)
        for _ in 0..<30 {
            nested = .blockquote(children: [nested])
        }
        let blocks = Array(repeating: MarkdownBlockNode.paragraph(content: []), count: 5_000) + [nested]
        let result = MarkdownParser.ParseResult(document: blocks, mathContext: [:])
        let key = CodeHighlighter.current.key(for: code, language: "swift")
        let _: [Int: CodeHighlighter.HighlightMap] = result.highlightMaps(theme: .default)
        try await waitForHighlights([key])
        let maps: [Int: CodeHighlighter.HighlightMap] = result.highlightMaps(theme: .default)
        XCTAssertEqual(maps.count, 1)
        XCTAssertNotNil(maps[key])
    }

    @MainActor
    func testCodeViewUpdatesWhenBackgroundHighlightCompletes() async throws {
        let identifier = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let code = "let value_\(identifier) = 123"
        let key = CodeHighlighter.current.key(for: code, language: "swift")
        let markdownView = MarkdownTextView()
        let result = MarkdownParser.ParseResult(
            document: [.codeBlock(fenceInfo: "swift", content: code)], mathContext: [:]
        )
        markdownView.setMarkdownManually(.init(parserResult: result, theme: .default))
        try await waitForHighlights([key])
        guard let map = CodeHighlighter.current.cachedHighlightMap(for: key) else {
            return XCTFail("后台高亮未完成")
        }
        let view = try XCTUnwrap(markdownView.contextViews.compactMap { $0 as? CodeView }.first)
        XCTAssertEqual(view.highlightMap, map)
        XCTAssertTrue(view.textView.attributedText.isEqual(to: map.apply(to: code, with: view.theme)))
    }

    @MainActor
    private func waitForHighlights(_ keys: [Int]) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !keys.allSatisfy({ CodeHighlighter.current.cachedHighlightMap(for: $0) != nil }) {
            guard ContinuousClock.now < deadline else {
                XCTFail("后台高亮未完成")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
