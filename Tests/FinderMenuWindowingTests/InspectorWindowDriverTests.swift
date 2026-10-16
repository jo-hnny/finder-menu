import AppKit
import FinderMenuCore
import Observation
import SwiftUI
import Testing
@testable import FinderMenuWindowing

@Suite(.serialized) @MainActor struct InspectorWindowDriverTests {
    final class RecordingWindow: NSWindow {
        var frameRequests: [(width: CGFloat, minimum: CGFloat)] = []
        var recordsFrames = false
        var reportsZoomed: Bool?
        override var isZoomed: Bool { reportsZoomed ?? super.isZoomed }

        override func setFrame(_ frameRect: NSRect, display flag: Bool) {
            if recordsFrames { frameRequests.append((frameRect.width, contentMinSize.width)) }
            super.setFrame(frameRect, display: flag)
        }
    }

    @MainActor final class ChangeCount { var value = 0 }

    func makeDriver(width: CGFloat = 1120, managed: Bool = false) -> (RecordingWindow, InspectorWindowState) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let visible = NSScreen.main!.visibleFrame
        let size = CGSize(width: min(width, visible.width - 200), height: min(720, visible.height - 200))
        let frame = CGRect(x: visible.minX + 100, y: visible.minY + 100, width: size.width, height: size.height)
        let window = RecordingWindow(contentRect: frame,
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.setFrame(frame, display: false)
        window.reportsZoomed = managed ? true : nil
        let driver = InspectorWindowState()
        driver.attach(to: window)
        return (window, driver)
    }

    func settle(_ driver: InspectorWindowState) {
        for _ in 0..<120 where driver.isResizing { driver.advance(by: 1 / 60) }
    }

    @Test func displayLinkExistsOnlyDuringAnimation() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        #expect(!driver.isDisplayLinkActive)
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: false)
        #expect(driver.isDisplayLinkActive)
        settle(driver)
        #expect(!driver.isResizing && !driver.isDisplayLinkActive && driver.revealedWidth == 296)
        driver.select(nil, reduceMotion: false)
        #expect(driver.isDisplayLinkActive)
        settle(driver)
        #expect(!driver.isDisplayLinkActive && driver.displayedItem == nil)
    }

    @Test func reducedMotionAndDetachStopTheNativeLink() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        let item = MenuItem(title: "Test", action: .copyPaths)
        driver.select(item, reduceMotion: true)
        #expect(driver.revealedWidth == 296 && !driver.isDisplayLinkActive)
        driver.select(nil, reduceMotion: false)
        driver.advance(by: 1 / 60)
        driver.finish()
        #expect(driver.revealedWidth == 0 && !driver.isDisplayLinkActive)
        driver.select(item, reduceMotion: false)
        #expect(driver.isDisplayLinkActive)
        driver.attach(to: nil)
        #expect(!driver.isDisplayLinkActive && driver.window == nil)
    }

    @Test func deletedItemSnapshotSurvivesUntilCollapseCompletes() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        let item = MenuItem(title: "Removed", action: .copyPaths)
        driver.select(item, reduceMotion: true)
        driver.select(nil, reduceMotion: false)
        driver.advance(by: 1 / 60)
        #expect(driver.displayedItem == item && driver.revealedWidth > 0)
        settle(driver)
        #expect(driver.displayedItem == nil && !driver.isDisplayLinkActive)
    }

    @Test func windowResizeInterruptsFramesAndSurvivesClosing() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: false)
        driver.advance(by: 1 / 60)
        var manual = window.frame
        manual.size.width = 1100
        window.setFrame(manual, display: false)
        settle(driver)
        #expect(window.frame == manual && !driver.isDisplayLinkActive)
        driver.select(nil, reduceMotion: false)
        settle(driver)
        #expect(window.frame == manual && driver.displayedItem == nil)
    }

    @Test(arguments: [false, true], [CGFloat(824), 1120])
    func reversalBeforeFirstFrameCleansUpImmediately(initiallyOpen: Bool, width: CGFloat) {
        let (window, driver) = makeDriver(width: width)
        defer { driver.attach(to: nil); _ = window }
        let item = MenuItem(title: "Test", action: .copyPaths)
        if initiallyOpen { driver.select(item, reduceMotion: true) }
        let original = window.frame
        for _ in 0..<10 {
            driver.select(initiallyOpen ? nil : item, reduceMotion: false)
            driver.select(initiallyOpen ? item : nil, reduceMotion: false)
            #expect(!driver.isResizing && !driver.isDisplayLinkActive)
            #expect(driver.displayedItem == (initiallyOpen ? item : nil))
            #expect(window.frame == original)
        }
        driver.attach(to: nil)
        driver.select(nil, reduceMotion: true)
        driver.select(item, reduceMotion: false)
        driver.select(nil, reduceMotion: false)
        #expect(driver.displayedItem == nil && !driver.isDisplayLinkActive)
    }

    @Test func automaticZoomDoesNotPreventRestoration() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        let visible = window.screen!.visibleFrame
        let original = CGRect(x: visible.minX + 20, y: visible.minY,
                              width: visible.width - 120, height: visible.height)
        window.setFrame(original, display: false)
        #expect(!window.isZoomed)
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: false)
        settle(driver)
        #expect(window.frame.width == max(visible.width, InspectorWindowLayout.minimumWidth(reveal: 296)))
        driver.select(nil, reduceMotion: false)
        settle(driver)
        #expect(window.frame == original && !driver.isDisplayLinkActive)
    }

    @Test(arguments: [CGFloat(824), 1120])
    func verticalMovePreservesBothCoordinatesOnClose(width: CGFloat) {
        let (window, driver) = makeDriver(width: width)
        defer { driver.attach(to: nil); _ = window }
        let visible = window.screen!.visibleFrame
        let originalWidth = window.frame.width
        var right = window.frame
        right.origin.x = visible.maxX - originalWidth
        window.setFrame(right, display: false)
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: true)
        var moved = window.frame
        moved.origin.y += 40
        window.setFrame(moved, display: false)
        driver.select(nil, reduceMotion: false)
        settle(driver)
        #expect(window.frame.origin == moved.origin && window.frame.width == originalWidth)
    }

    @Test func manualZoomAfterExpansionKeepsItsBounds() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        let visible = window.screen!.visibleFrame
        window.setFrame(CGRect(x: visible.minX + 20, y: visible.minY + 100,
                               width: visible.width - 120, height: window.frame.height), display: false)
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: true)
        #expect(window.frame.width == max(visible.width, InspectorWindowLayout.minimumWidth(reveal: 296)))
        #expect(!window.isZoomed)
        window.setFrame(visible, display: false)
        #expect(window.isZoomed)
        driver.select(nil, reduceMotion: false)
        settle(driver)
        #expect(window.frame == visible)
    }

    @Test(arguments: [60.0, 120.0])
    func publishesOnlyChangedIntegralWidths(rate: Double) {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: false)
        var unchangedFrames = 0
        for _ in 0..<240 where driver.isResizing {
            let previous = driver.revealedWidth
            let widthChanges = ChangeCount(), canvasChanges = ChangeCount()
            withObservationTracking { _ = driver.revealedWidth } onChange: {
                MainActor.assumeIsolated { widthChanges.value += 1 }
            }
            withObservationTracking { _ = driver.canvasWidth } onChange: {
                MainActor.assumeIsolated { canvasChanges.value += 1 }
            }
            driver.advance(by: 1 / rate)
            #expect(driver.revealedWidth == driver.revealedWidth.rounded())
            #expect(widthChanges.value == (previous == driver.revealedWidth ? 0 : 1))
            #expect(canvasChanges.value == 0)
            if previous == driver.revealedWidth { unchangedFrames += 1 }
        }
        #expect(unchangedFrames > 0 && !driver.isDisplayLinkActive)
    }

    @Test func idleMovesDoNotInvalidatePublishedState() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        let initialCanvas = driver.canvasWidth
        for _ in 0..<20 {
            let changes = ChangeCount()
            withObservationTracking { _ = driver.canvasWidth; _ = driver.revealedWidth } onChange: {
                MainActor.assumeIsolated { changes.value += 1 }
            }
            var frame = window.frame; frame.origin.x += 1
            window.setFrame(frame, display: false)
            #expect(changes.value == 0 && driver.canvasWidth == initialCanvas)
        }
        #expect(!driver.isDisplayLinkActive)
    }

    @Test func resizingPublishesCanvasOnceAndIgnoresEqualUpdates() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        let changes = ChangeCount()
        withObservationTracking { _ = driver.canvasWidth } onChange: {
            MainActor.assumeIsolated { changes.value += 1 }
        }
        var frame = window.frame; frame.size.width -= 20
        window.setFrame(frame, display: false)
        #expect(changes.value == 1 && driver.canvasWidth == frame.width + 296)
        let equalChanges = ChangeCount()
        withObservationTracking { _ = driver.canvasWidth } onChange: {
            MainActor.assumeIsolated { equalChanges.value += 1 }
        }
        NotificationCenter.default.post(name: NSWindow.didResizeNotification, object: window)
        #expect(equalChanges.value == 0)
    }

    @Test(arguments: [60.0, 120.0])
    func minimumIsSynchronizedBeforeEveryFrameIncludingReversals(rate: Double) {
        let (window, driver) = makeDriver(width: 780)
        defer { driver.attach(to: nil); _ = window }
        let original = window.frame
        #expect(window.contentMinSize.width == 780)
        window.recordsFrames = true
        let item = MenuItem(title: "Test", action: .copyPaths)
        for selected in [item, nil, item, nil] {
            driver.select(selected, reduceMotion: false)
            for _ in 0..<5 {
                window.frameRequests = []
                driver.advance(by: 1 / rate)
                let minimum = InspectorWindowLayout.minimumWidth(reveal: driver.revealedWidth)
                #expect(window.contentMinSize.width == minimum)
                for request in window.frameRequests {
                    #expect(request.minimum == minimum && request.width >= request.minimum)
                }
            }
        }
        settle(driver)
        #expect(window.frame == original && window.contentMinSize.width == 780)
        driver.select(item, reduceMotion: true)
        #expect(window.contentMinSize.width == 1034)
        driver.select(nil, reduceMotion: true)
        #expect(window.contentMinSize.width == 780 && window.frame == original)
    }

    @Test func manualNarrowingDuringOpeningStillRespectsTheLiveMinimum() {
        let (window, driver) = makeDriver(width: 780)
        defer { driver.attach(to: nil); _ = window }
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: false)
        for _ in 0..<4 { driver.advance(by: 1 / 60) }
        var manual = window.frame
        manual.size.width = InspectorWindowLayout.minimumWidth(reveal: driver.revealedWidth) + 4
        window.setFrame(manual, display: false)
        for _ in 0..<120 where driver.isResizing {
            driver.advance(by: 1 / 60)
            #expect(window.frame.width >= window.contentMinSize.width)
        }
        #expect(window.frame.width == 1034 && window.contentMinSize.width == 1034)
        driver.select(nil, reduceMotion: false)
        settle(driver)
        #expect(window.frame.width == 1034 && window.contentMinSize.width == 780)
    }

    @Test func swiftUIAndNativeMinimumsAgreeAfterLayoutAndReversal() {
        let (window, driver) = makeDriver(width: 780)
        defer { driver.attach(to: nil); _ = window }
        let view = NSHostingView(rootView: Color.clear.modifier(InspectorWindowMinimum(state: driver)))
        window.contentView = view
        let item = MenuItem(title: "Test", action: .copyPaths)
        for selected in [item, nil, item, nil] {
            driver.select(selected, reduceMotion: false)
            for _ in 0..<120 where driver.isResizing {
                driver.advance(by: 1 / 60)
                view.layoutSubtreeIfNeeded()
                #expect(view.fittingSize.width == window.contentMinSize.width)
            }
        }
        #expect(view.fittingSize.width == 780 && !driver.isDisplayLinkActive)
    }

    @Test(arguments: [60.0, 120.0], [CGFloat(824), 960])
    func narrowManagedWindowRestoresItsBounds(rate: Double, width: CGFloat) {
        let (window, driver) = makeDriver(width: width, managed: true)
        defer { driver.attach(to: nil); _ = window }
        let original = window.frame
        let view = NSHostingView(rootView: Color.clear.modifier(InspectorWindowMinimum(state: driver)))
        window.contentView = view
        let item = MenuItem(title: "Test", action: .copyPaths)
        for selected in [item, nil] {
            driver.select(selected, reduceMotion: false)
            for _ in 0..<240 where driver.isResizing {
                driver.advance(by: 1 / rate)
                view.layoutSubtreeIfNeeded()
                #expect(window.frame.width >= window.contentMinSize.width)
                #expect(view.fittingSize.width == window.contentMinSize.width)
            }
            #expect(window.frame.width == (selected == nil ? original.width : 1034))
        }
        #expect(window.frame == original && window.contentMinSize.width == 780)
        #expect(!driver.isDisplayLinkActive)
        driver.select(item, reduceMotion: true)
        driver.select(nil, reduceMotion: true)
        #expect(window.frame == original && !driver.isDisplayLinkActive)
    }

    @Test(arguments: [false, true])
    func manualResizeOverridesManagedRestoration(duringOpening: Bool) {
        let (window, driver) = makeDriver(width: 824, managed: true)
        defer { driver.attach(to: nil); _ = window }
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: !duringOpening)
        if duringOpening { for _ in 0..<4 { driver.advance(by: 1 / 60) } }
        var manual = window.frame
        manual.size.width = 1100
        window.setFrame(manual, display: false)
        settle(driver)
        driver.select(nil, reduceMotion: false)
        settle(driver)
        #expect(window.frame == manual && window.contentMinSize.width == 780)
    }

    @Test func managedRestorationSurvivesMovingAndRapidReversals() {
        let (window, driver) = makeDriver(width: 960, managed: true)
        defer { driver.attach(to: nil); _ = window }
        let originalWidth = window.frame.width
        let item = MenuItem(title: "Test", action: .copyPaths)
        driver.select(item, reduceMotion: false)
        for _ in 0..<4 { driver.advance(by: 1 / 60) }
        var manual = window.frame
        manual.origin.y += 40
        window.setFrame(manual, display: false)
        settle(driver)
        for selected in [nil, item, nil, item, nil] {
            driver.select(selected, reduceMotion: false)
            for _ in 0..<3 { driver.advance(by: 1 / 60) }
        }
        settle(driver)
        #expect(window.frame.width == originalWidth && window.frame.origin == manual.origin)
        #expect(!driver.isDisplayLinkActive && driver.displayedItem == nil)
    }
}
