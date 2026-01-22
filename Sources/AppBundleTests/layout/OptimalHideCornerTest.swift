@testable import AppBundle
import AppKit
import XCTest

private struct TestMonitor: Monitor {
    let monitorAppKitNsScreenScreensId: Int
    let name: String
    let rect: Rect
    let visibleRect: Rect

    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
}

final class OptimalHideCornerTest: XCTestCase {
    func testPrefersBottomLeftWhenBottomRightOverlapsAnotherMonitor() {
        let leftRect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        let rightRect = Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800)
        let monitors: [Monitor] = [
            TestMonitor(monitorAppKitNsScreenScreensId: 1, name: "Left", rect: leftRect, visibleRect: leftRect),
            TestMonitor(monitorAppKitNsScreenScreensId: 2, name: "Right", rect: rightRect, visibleRect: rightRect),
        ]

        let monitorToCorner = computeMonitorToOptimalHideCorner(monitors: monitors)

        XCTAssertEqual(monitorToCorner[leftRect.topLeftCorner], .bottomLeftCorner)
        XCTAssertEqual(monitorToCorner[rightRect.topLeftCorner], .bottomRightCorner)
    }
}
