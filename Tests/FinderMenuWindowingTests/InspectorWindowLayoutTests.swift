import Foundation
import Testing
@testable import FinderMenuWindowing

@Suite struct InspectorWindowLayoutTests {
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let initial = CGRect(x: 100, y: 100, width: 1120, height: 720)

    func step(_ model: inout InspectorWindowLayout, _ width: CGFloat, _ frame: CGRect,
              visible: CGRect? = nil, live: Bool = false, constrained: Bool = false) -> CGRect {
        let result = model.frame(at: width, current: frame, visible: visible ?? self.visible,
                                 liveResize: live, fullScreen: constrained)
        model.applied(result)
        return result
    }

    @Test func restoresWidthAndPositionAtRightEdge() {
        var model = InspectorWindowLayout()
        var original = initial; original.origin.x = visible.maxX - original.width
        model.begin(reveal: 0, frame: original, visible: visible, constrained: false, liveResize: false)
        let open = step(&model, 296, original)
        #expect(open.width == 1416 && open.maxX == visible.maxX)
        model.finish(closed: false)
        model.begin(reveal: 296, frame: open, visible: visible, constrained: false, liveResize: false)
        #expect(step(&model, 0, open) == original)
    }

    @Test(arguments: [CGFloat(1100), 1500])
    func manuallyChosenWidthSurvivesClose(width: CGFloat) {
        var model = InspectorWindowLayout()
        model.begin(reveal: 0, frame: initial, visible: visible, constrained: false, liveResize: false)
        let open = step(&model, 296, initial)
        model.finish(closed: false)
        var manual = open; manual.size.width = width
        let largerScreen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
        model.begin(reveal: 296, frame: manual, visible: largerScreen, constrained: false, liveResize: false)
        #expect(step(&model, 0, manual, visible: largerScreen) == manual)
    }

    @Test func manualMoveAndHeightSurviveClose() {
        var model = InspectorWindowLayout()
        model.begin(reveal: 0, frame: initial, visible: visible, constrained: false, liveResize: false)
        var manual = step(&model, 296, initial)
        manual.origin.x = 10; manual.origin.y = 80; manual.size.height += 40
        model.begin(reveal: 296, frame: manual, visible: visible, constrained: false, liveResize: false)
        let closed = step(&model, 0, manual)
        #expect(closed.width == initial.width)
        #expect(closed.origin == manual.origin && closed.height == manual.height)
    }

    @Test func manualBoundsOutsideVisibleFrameRemainAuthoritative() {
        var model = InspectorWindowLayout()
        model.begin(reveal: 0, frame: initial, visible: visible, constrained: false, liveResize: false)
        var moved = step(&model, 296, initial)
        moved.origin.x = -80
        model.begin(reveal: 296, frame: moved, visible: visible, constrained: false, liveResize: false)
        #expect(step(&model, 0, moved).minX == moved.minX)
        model.finish(closed: true)

        model.begin(reveal: 0, frame: initial, visible: visible, constrained: false, liveResize: false)
        var resized = step(&model, 296, initial)
        resized.size.width = visible.width + 100
        model.begin(reveal: 296, frame: resized, visible: visible, constrained: false, liveResize: false)
        #expect(step(&model, 0, resized) == resized)
    }

    @Test func liveResizeTakesOverBeforeFirstSizeChange() {
        var model = InspectorWindowLayout()
        model.begin(reveal: 0, frame: initial, visible: visible, constrained: false, liveResize: false)
        let partial = step(&model, 100, initial)
        #expect(step(&model, 200, partial, live: true) == partial)
        var manual = partial; manual.size.width = 1050; manual.origin.x = 50
        #expect(step(&model, 250, manual, live: true) == manual)
        #expect(step(&model, 296, manual) == manual)
        model.begin(reveal: 296, frame: manual, visible: visible, constrained: false, liveResize: false)
        #expect(step(&model, 0, manual) == manual)
    }

    @Test func reversalKeepsManualBaselineAndCanvasStable() {
        var model = InspectorWindowLayout()
        model.begin(reveal: 0, frame: initial, visible: visible, constrained: false, liveResize: false)
        let canvas = model.canvasWidth
        let partial = step(&model, 120, initial)
        #expect(model.canvasWidth == canvas)
        model.begin(reveal: 120, frame: partial, visible: visible, constrained: false, liveResize: false)
        let closing = step(&model, 60, partial)
        var manual = closing; manual.size.width = 1100
        model.begin(reveal: 60, frame: manual, visible: visible, constrained: false, liveResize: false)
        #expect(step(&model, 296, manual) == manual)
        model.begin(reveal: 296, frame: manual, visible: visible, constrained: false, liveResize: false)
        #expect(step(&model, 0, manual) == manual)
    }

    @Test func smallScreenKeepsAllThreeColumnsReadable() {
        var model = InspectorWindowLayout()
        let screen = CGRect(x: -1024, y: 0, width: 1024, height: 900)
        let original = CGRect(x: -1000, y: 100, width: 780, height: 652)
        model.begin(reveal: 0, frame: original, visible: screen, constrained: false, liveResize: false)
        var frame = original
        for width in stride(from: CGFloat(0), through: 296, by: 8) {
            frame = step(&model, width, frame, visible: screen)
            #expect(frame.width >= InspectorWindowLayout.minimumWidth(reveal: width))
            #expect(frame.minX >= screen.minX)
            #expect(frame.width <= max(screen.width, InspectorWindowLayout.minimumWidth(reveal: width)))
        }
    }

    @Test(arguments: [CGFloat(780), 800, 1024, 1120])
    func sidebarStaysExpandedAtEveryAnimationFrame(width: CGFloat) {
        for reveal in stride(from: CGFloat(0), through: 296, by: 8) {
            let windowWidth = max(width, InspectorWindowLayout.minimumWidth(reveal: reveal))
            let columns = InspectorWindowLayout.columns(contentWidth: windowWidth - 32, reveal: reveal)
            #expect(columns.sidebar == 350)
            #expect(columns.preview >= 340)
            #expect(abs(columns.sidebar + 16 + reveal + columns.preview + 32 - windowWidth) < 0.01)
        }
        #expect(InspectorWindowLayout.minimumWidth(reveal: 0) == 780)
        #expect(InspectorWindowLayout.minimumWidth(reveal: 296) == 1034)
    }

    @Test func tiledAndFullScreenWindowsKeepTheirBounds() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let tile = CGRect(x: 16, y: 16, width: 936, height: 1048)
        #expect(InspectorWindowLayout.isTiled(tile, in: screen))
        var model = InspectorWindowLayout()
        model.begin(reveal: 0, frame: tile, visible: screen, constrained: false, liveResize: false)
        #expect(step(&model, 296, tile, visible: screen) == tile)
        model.begin(reveal: 0, frame: screen, visible: screen, constrained: true, liveResize: false)
        #expect(step(&model, 296, screen, visible: screen, constrained: true) == screen)
    }

    @Test func springReversesContinuouslyAndSettles() {
        var spring = InspectorSpring()
        spring.retarget(296)
        for _ in 0..<5 { spring.advance(by: 1 / 60) }
        let value = spring.value, velocity = spring.velocity
        #expect(value > 0 && value < 296)
        spring.retarget(0)
        #expect(spring.value == value && spring.velocity == velocity)
        for _ in 0..<120 { spring.advance(by: 1 / 60) }
        #expect(spring.settled && spring.value == 0)
    }

    @Test func automaticExpansionIsNotMistakenForTilingOrZoom() {
        var model = InspectorWindowLayout()
        let original = CGRect(x: 200, y: 0, width: 1120, height: visible.height)
        model.begin(reveal: 0, frame: original, visible: visible, constrained: false, liveResize: false)
        let open = step(&model, 296, original)
        #expect(InspectorWindowLayout.isTiled(open, in: visible))
        model.finish(closed: false)
        model.begin(reveal: 296, frame: open, visible: visible, constrained: true, liveResize: false)
        #expect(step(&model, 0, open) == original)
    }

    @Test(arguments: [CGFloat(-40), 40])
    func verticalMoveDoesNotRestoreTheOldHorizontalPosition(offset: CGFloat) {
        var model = InspectorWindowLayout()
        var original = initial; original.origin.x = visible.maxX - original.width
        model.begin(reveal: 0, frame: original, visible: visible, constrained: false, liveResize: false)
        var moved = step(&model, 296, original)
        model.finish(closed: false)
        moved.origin.y += offset
        model.begin(reveal: 296, frame: moved, visible: visible, constrained: false, liveResize: false)
        let closed = step(&model, 0, moved)
        #expect(closed.origin == moved.origin && closed.width == original.width)
    }

    @Test(arguments: [60.0, 120.0], [false, true])
    func rapidReversalsKeepEveryFrameSynchronized(rate: Double, initiallyOpen: Bool) {
        var model = InspectorWindowLayout(), spring = InspectorSpring()
        model.begin(reveal: 0, frame: initial, visible: visible, constrained: false, liveResize: false)
        var frame = initial
        if initiallyOpen {
            spring.retarget(296); spring.finish()
            frame = step(&model, 296, frame)
            model.finish(closed: false)
        }
        var presented = initiallyOpen
        for count in [4, 2, 1, 6, 3, 1, 5] {
            presented.toggle()
            model.begin(reveal: spring.value, frame: frame, visible: visible, constrained: false, liveResize: false)
            spring.retarget(presented ? 296 : 0)
            for _ in 0..<count {
                spring.advance(by: 1 / rate)
                frame = step(&model, spring.value, frame)
                #expect(frame.width == (initial.width + spring.value).rounded())
                let expectedX = initial.minX + (visible.maxX - 1416 - initial.minX) * spring.value / 296
                #expect(abs(frame.minX - expectedX) < 0.01)
            }
        }
        model.begin(reveal: spring.value, frame: frame, visible: visible, constrained: false, liveResize: false)
        spring.retarget(0)
        for _ in 0..<240 where !spring.settled {
            spring.advance(by: 1 / rate)
            frame = step(&model, spring.value, frame)
        }
        #expect(spring.settled && frame == initial)
    }
}
