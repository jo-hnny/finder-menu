import Foundation
import SwiftUI

/// Window geometry is independent of AppKit callbacks so interruption rules can be tested.
struct InspectorWindowLayout {
    static let revealWidth: CGFloat = 296

    struct Columns {
        let sidebar: CGFloat
        let preview: CGFloat
    }

    static func minimumWidth(reveal: CGFloat) -> CGFloat {
        max(780, 350 + 16 + reveal + 340 + 32)
    }

    static func columns(contentWidth: CGFloat, reveal: CGFloat) -> Columns {
        let sidebar: CGFloat = 350
        return Columns(sidebar: sidebar, preview: max(0, contentWidth - sidebar - 16 - reveal))
    }

    // There is no public AppKit tiled-state flag. Respect standard tile bounds, including tile margins.
    static func isTiled(_ frame: CGRect, in visible: CGRect) -> Bool {
        let halves = [
            CGRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height),
            CGRect(x: visible.midX, y: visible.minY, width: visible.width / 2, height: visible.height),
            CGRect(x: visible.minX, y: visible.minY, width: visible.width, height: visible.height / 2),
            CGRect(x: visible.minX, y: visible.midY, width: visible.width, height: visible.height / 2)
        ]
        let quarters = [visible.minX, visible.midX].flatMap { x in
            [visible.minY, visible.midY].map { y in
                CGRect(x: x, y: y, width: visible.width / 2, height: visible.height / 2)
            }
        }
        return ([visible] + halves + quarters).contains { tile in
            abs(frame.minX - tile.minX) <= 24 && abs(frame.maxX - tile.maxX) <= 24
                && abs(frame.minY - tile.minY) <= 24 && abs(frame.maxY - tile.maxY) <= 24
        }
    }

    private struct Transition {
        var closed: CGRect
        var open: CGRect
    }

    private var transition: Transition?
    private var lastFrame: CGRect?
    private var automaticFrame = true
    private var managedWindow = false
    private var manuallySized = false
    private var manuallyMoved = false
    private(set) var canvasWidth: CGFloat = 0

    mutating func observe(_ frame: CGRect, liveResize: Bool, constrained: Bool = false) {
        if let previous = lastFrame, frame != previous {
            automaticFrame = false
            if var transition {
                if frame.size != previous.size, constrained { managedWindow = true }
                if frame.width != previous.width {
                    // A manually chosen width becomes the new baseline for this cycle.
                    manuallySized = true
                } else if frame.origin != previous.origin {
                    transition.closed.origin = frame.origin
                    transition.open.origin = frame.origin
                    manuallyMoved = true
                }
                self.transition = transition
            }
            if frame.width != previous.width { canvasWidth = frame.width + Self.revealWidth }
        }
        if liveResize { automaticFrame = false }
        if canvasWidth == 0 { canvasWidth = frame.width + Self.revealWidth }
        lastFrame = frame
    }

    mutating func begin(reveal: CGFloat, frame: CGRect, visible: CGRect, constrained: Bool, liveResize: Bool) {
        observe(frame, liveResize: liveResize, constrained: constrained || Self.isTiled(frame, in: visible))
        if transition == nil {
            // Capture once: our own expansion can also make AppKit report a zoomed window.
            managedWindow = constrained || Self.isTiled(frame, in: visible)
            var open = frame
            if !managedWindow {
                open.size.width = min(frame.width + Self.revealWidth, visible.width)
                open.origin.x = min(max(frame.minX, visible.minX), visible.maxX - open.width)
            }
            transition = Transition(closed: frame, open: open)
            canvasWidth = max(canvasWidth, frame.width, open.width)
        } else if !automaticFrame, !manuallySized, !managedWindow, reveal > 0, var transition {
            // A manual interruption may leave the window behind the panel's progress.
            // Rebase once on resumption, then keep this mapping through later reversals.
            let progress = reveal / Self.revealWidth
            transition.open.size.width = transition.closed.width + (frame.width - transition.closed.width) / progress
            transition.open.origin.x = transition.closed.minX + (frame.minX - transition.closed.minX) / progress
            self.transition = transition
        }
        automaticFrame = !managedWindow && !liveResize && !manuallySized
    }

    mutating func frame(at reveal: CGFloat, current: CGRect, visible: CGRect, liveResize: Bool,
                        fullScreen: Bool) -> CGRect {
        observe(current, liveResize: liveResize)
        guard automaticFrame, !fullScreen, let transition else { return current }
        // Retargeting the spring never rebases this mapping, including its remaining momentum.
        let progress = reveal / Self.revealWidth
        var result = current
        result.size.width = max(Self.minimumWidth(reveal: reveal), min(visible.width, (transition.closed.width + (transition.open.width - transition.closed.width) * progress).rounded()))
        result.origin.x = transition.closed.minX + (transition.open.minX - transition.closed.minX) * progress
        if !manuallyMoved {
            result.origin.x = max(visible.minX, min(result.minX, visible.maxX - result.width))
        }
        return result
    }

    mutating func applied(_ frame: CGRect) { lastFrame = frame }

    mutating func finish(closed: Bool) {
        if closed {
            transition = nil
            managedWindow = false
            manuallySized = false
            manuallyMoved = false
        }
    }
}

/// Apple's spring preserves velocity when a new target interrupts an animation.
struct InspectorSpring {
    private let spring = Spring(settlingDuration: 0.30, dampingRatio: 1)
    private(set) var value: CGFloat = 0
    private(set) var velocity: CGFloat = 0
    private(set) var target: CGFloat = 0
    var settled: Bool { value == target && velocity == 0 }
    var displayedValue: CGFloat { value.rounded() }

    mutating func retarget(_ target: CGFloat) { self.target = target }

    mutating func advance(by delta: TimeInterval) {
        spring.update(value: &value, velocity: &velocity, target: target, deltaTime: delta)
        if value < 0 || value > InspectorWindowLayout.revealWidth {
            value = min(InspectorWindowLayout.revealWidth, max(0, value))
            velocity = 0
        }
        if abs(value - target) < 0.1 && abs(velocity) < 0.5 { finish() }
    }

    mutating func finish() { value = target; velocity = 0 }
}
