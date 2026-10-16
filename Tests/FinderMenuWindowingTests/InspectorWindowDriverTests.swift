import AppKit
import FinderMenuCore
import Testing
@testable import FinderMenuWindowing

@Suite(.serialized) @MainActor struct InspectorWindowDriverTests {
    func makeDriver() -> (NSWindow, InspectorWindowState) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 1120, height: 720),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
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

    @Test(arguments: [false, true])
    func reversalBeforeFirstFrameCleansUpImmediately(initiallyOpen: Bool) {
        let (window, driver) = makeDriver()
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
        #expect(window.frame.width == visible.width)
        driver.select(nil, reduceMotion: false)
        settle(driver)
        #expect(window.frame == original && !driver.isDisplayLinkActive)
    }

    @Test func verticalMovePreservesBothCoordinatesOnClose() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        let visible = window.screen!.visibleFrame
        window.setFrame(CGRect(x: visible.maxX - 1120, y: visible.minY + 100,
                               width: 1120, height: 720), display: false)
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: true)
        var moved = window.frame
        moved.origin.y += 40
        window.setFrame(moved, display: false)
        driver.select(nil, reduceMotion: false)
        settle(driver)
        #expect(window.frame.origin == moved.origin && window.frame.width == 1120)
    }

    @Test func moveDuringOpeningDoesNotExpandAgainOnClose() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: false)
        for _ in 0..<4 { driver.advance(by: 1 / 60) }
        var moved = window.frame
        moved.origin.y += 40
        window.setFrame(moved, display: false)
        settle(driver)
        #expect(window.frame == moved && driver.revealedWidth == 296)
        driver.select(nil, reduceMotion: false)
        driver.advance(by: 1 / 60)
        #expect(window.frame.width <= moved.width && window.frame.origin == moved.origin)
        settle(driver)
        #expect(window.frame.width == 1120 && window.frame.origin == moved.origin)
    }

    @Test func manualZoomAfterExpansionKeepsItsBounds() {
        let (window, driver) = makeDriver()
        defer { driver.attach(to: nil); _ = window }
        let visible = window.screen!.visibleFrame
        window.setFrame(CGRect(x: visible.minX + 20, y: visible.minY + 100,
                               width: visible.width - 120, height: 720), display: false)
        driver.select(MenuItem(title: "Test", action: .copyPaths), reduceMotion: true)
        #expect(window.frame.width == visible.width && !window.isZoomed)
        window.setFrame(visible, display: false)
        #expect(window.isZoomed)
        driver.select(nil, reduceMotion: false)
        settle(driver)
        #expect(window.frame == visible)
    }
}
