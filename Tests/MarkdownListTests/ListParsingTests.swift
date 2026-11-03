import MarkdownParser
import XCTest

final class ListParsingTests: XCTestCase {
    func testMixedTaskAndPlainItemsKeepTheirTypesAndOrder() {
        let blocks = MarkdownParser().parse("- [ ] task\n- plain\n- [x] done").document
        XCTAssertEqual(blocks, mixedBlocks)
    }

    func testNestedMixedListsUnderPlainAndTaskItems() {
        for prefix in ["- parent", "- [ ] parent"] {
            let blocks = MarkdownParser().parse("\(prefix)\n  - [ ] task\n  - plain\n  - [x] done").document
            XCTAssertEqual(blocks.count, 1)
            XCTAssertEqual(blocks.first?.children, [paragraph("parent")] + mixedBlocks)
        }
    }

    func testBlockquotePreservesExistingFlattenedText() {
        let blocks = MarkdownParser().parse("> - [ ] task\n> - plain\n> - [x] done").document
        // 引用内列表仍沿用当前库的扁平文本展示规则。
        XCTAssertEqual(blocks, [.blockquote(children: [paragraph("task"), paragraph("plain"), paragraph("done")])])
    }

    func testNumberedMixedListPreservesFollowingOrdinal() {
        let blocks = MarkdownParser().parse("3. plain\n4. [ ] task\n5. next").document
        XCTAssertEqual(blocks, [
            .numberedList(isTight: true, start: 3, items: [RawListItem(children: [paragraph("plain")])]),
            .taskList(isTight: true, items: [RawTaskListItem(isCompleted: false, children: [paragraph("task")])]),
            .numberedList(isTight: true, start: 5, items: [RawListItem(children: [paragraph("next")])]),
        ])
    }

    func testHomogeneousListsAndPlainTextRemainIntact() {
        XCTAssertEqual(MarkdownParser().parse("- first\n- second").document, [
            .bulletedList(isTight: true, items: ["first", "second"].map { RawListItem(children: [paragraph($0)]) }),
        ])
        XCTAssertEqual(MarkdownParser().parse("- [ ] task\n- [x] done").document, [
            .taskList(isTight: true, items: [
                RawTaskListItem(isCompleted: false, children: [paragraph("task")]),
                RawTaskListItem(isCompleted: true, children: [paragraph("done")]),
            ]),
        ])
        XCTAssertEqual(MarkdownParser().parse("plain").document, [paragraph("plain")])
        XCTAssertEqual(MarkdownParser().parse("").document, [])
    }

    private var mixedBlocks: [MarkdownBlockNode] {
        [
            .taskList(isTight: true, items: [RawTaskListItem(isCompleted: false, children: [paragraph("task")])]),
            .bulletedList(isTight: true, items: [RawListItem(children: [paragraph("plain")])]),
            .taskList(isTight: true, items: [RawTaskListItem(isCompleted: true, children: [paragraph("done")])]),
        ]
    }

    private func paragraph(_ text: String) -> MarkdownBlockNode {
        .paragraph(content: [.text(text)])
    }
}
