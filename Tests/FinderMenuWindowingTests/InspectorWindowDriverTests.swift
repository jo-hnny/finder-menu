import AppKit
import FinderMenuCore
import Testing
@testable import FinderMenuWindowing

@Suite(.serialized) @MainActor struct InspectorWindowDriverTests {
    func makeDriver(width: CGFloat = 1120) -> (NSWindow, InspectorWindowState) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let visible = NSScreen.main!.visibleFrame
        let size = CGSize(width: min(width, visible.width - 200), height: min(720, visible.height - 200))
        let frame = CGRect(x: visible.minX + 100, y: visible.minY + 100, width: size.width, height: size.height)
        let window = NSWindow(contentRect: frame,
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.setFrame(frame, display: false)
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
}
