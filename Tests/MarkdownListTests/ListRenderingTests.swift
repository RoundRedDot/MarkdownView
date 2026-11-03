import Litext
import MarkdownParser
@testable import MarkdownView
import XCTest

final class ListRenderingTests: XCTestCase {
    @MainActor
    func testContinuationParagraphsDoNotRepeatMarkers() {
        let children: [MarkdownBlockNode] = [
            .paragraph(content: [.text("first")]),
            .paragraph(content: [.text("continuation")]),
        ]
        let processor = ListProcessor(
            theme: .default,
            viewProvider: .init(),
            context: .init(),
            bulletDrawing: { _, _, _, _ in },
            numberedDrawing: { _, _, _, _ in },
            checkboxDrawing: { _, _, _, _ in }
        )
        let plainItems = [RawListItem(children: children)]
        let outputs = [
            processor.processBulletedList(items: plainItems),
            processor.processNumberedList(startAt: 3, items: plainItems),
            processor.processTaskList(items: [RawTaskListItem(isCompleted: false, children: children)]),
            processor.processTaskList(items: [RawTaskListItem(isCompleted: true, children: children)]),
        ]
        for output in outputs {
            var markerCount = 0
            output.enumerateAttribute(.ltxLineDrawingCallback, in: NSRange(location: 0, length: output.length)) { value, _, _ in
                if value != nil { markerCount += 1 }
            }
            XCTAssertEqual(markerCount, 1)
            XCTAssertTrue(output.string.contains("first\ncontinuation\n"))
        }
    }
}
