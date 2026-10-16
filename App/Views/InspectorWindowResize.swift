import AppKit
import FinderMenuCore
import Observation
import QuartzCore
import SwiftUI

/// One native display link drives both the window and the sliding inspector, only while animating.
@MainActor @Observable
final class InspectorWindowState: NSObject {
    private(set) var displayedItem: MenuItem?
    @ObservationIgnored private var animation = InspectorSpring()
    @ObservationIgnored private var layout = InspectorWindowLayout()
    private(set) var revealedWidth: CGFloat = 0
    private(set) var canvasWidth: CGFloat = 0
    var isResizing: Bool { !animation.settled }
    var isDisplayLinkActive: Bool { displayLink != nil }
    @ObservationIgnored private(set) weak var window: NSWindow?
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var lastTimestamp: CFTimeInterval?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var applyingFrame = false

    private var visibleFrame: CGRect { window?.screen?.visibleFrame ?? window?.frame ?? .zero }
    private var constrained: Bool { window.map { $0.styleMask.contains(.fullScreen) || $0.isZoomed } ?? false }

    func attach(to window: NSWindow?) {
        guard self.window !== window else { return }
        stopDisplayLink()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        self.window = window
        guard let window else { return }
        layout.observe(window.frame, liveResize: window.inLiveResize)
        if !animation.settled {
            layout.begin(reveal: revealedWidth, frame: window.frame, visible: visibleFrame,
                         constrained: constrained, liveResize: window.inLiveResize)
        }
        applyFrame()
        let center = NotificationCenter.default
        for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification,
                     NSWindow.willStartLiveResizeNotification, NSWindow.didEndLiveResizeNotification,
                     NSWindow.didChangeScreenNotification] {
            observers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.observeWindow() }
            })
        }
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.attach(to: nil) }
        })
        if !animation.settled { startDisplayLink() }
    }

    func select(_ item: MenuItem?, reduceMotion: Bool) {
        if let item, item != displayedItem { displayedItem = item }
        let target: CGFloat = item == nil ? 0 : InspectorWindowLayout.revealWidth
        guard animation.target != target else { return }
        if let window {
            layout.begin(reveal: revealedWidth, frame: window.frame, visible: visibleFrame,
                         constrained: constrained, liveResize: window.inLiveResize)
        }
        animation.retarget(target)
        if reduceMotion || animation.settled { finish() } else { startDisplayLink() }
    }

    func finish() {
        withTransaction(Transaction(animation: nil)) {
            animation.finish()
            applyFrame()
        }
    }

    /// Also used by regression tests to advance the actual driver without waiting for a display.
    func advance(by delta: TimeInterval) {
        guard !animation.settled else { return }
        withTransaction(Transaction(animation: nil)) {
            animation.advance(by: delta)
            applyFrame()
        }
    }

    private func observeWindow() {
        guard !applyingFrame, let window else { return }
        layout.observe(window.frame, liveResize: window.inLiveResize,
                       constrained: constrained || InspectorWindowLayout.isTiled(window.frame, in: visibleFrame))
        publishCanvasWidth()
    }

    private func applyFrame() {
        let reveal = animation.displayedValue
        if let window {
            let fullScreen = window.styleMask.contains(.fullScreen)
            var frame = layout.frame(at: reveal, current: window.frame, visible: visibleFrame,
                                     liveResize: window.inLiveResize, fullScreen: fullScreen)
            let minimum = InspectorWindowLayout.minimumWidth(reveal: reveal)
            if !fullScreen { frame.size.width = max(frame.width, minimum) }
            applyingFrame = true
            // Update the native constraint before resizing, including the first closing frame.
            // The isolated SwiftUI modifier reports the same constraint during its layout pass.
            if window.contentMinSize.width != minimum {
                window.contentMinSize = CGSize(width: minimum, height: window.contentMinSize.height)
            }
            if frame != window.frame { window.setFrame(frame, display: false) }
            applyingFrame = false
            layout.applied(window.frame)
        } else {
            stopDisplayLink()
        }
        if revealedWidth != reveal { revealedWidth = reveal }
        publishCanvasWidth()
        if animation.settled {
            stopDisplayLink()
            let closed = animation.target == 0
            layout.finish(closed: closed)
            if closed { displayedItem = nil }
        }
    }

    private func publishCanvasWidth() {
        if canvasWidth != layout.canvasWidth { canvasWidth = layout.canvasWidth }
    }

    private func startDisplayLink() {
        guard displayLink == nil, !animation.settled, let window else { return }
        let link = window.displayLink(target: self, selector: #selector(tick(_:)))
        displayLink = link
        lastTimestamp = nil
        link.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let delta = lastTimestamp.map { link.targetTimestamp - $0 } ?? link.duration
        lastTimestamp = link.targetTimestamp
        advance(by: max(0, delta))
    }
}

/// Keep SwiftUI's scene constraint in sync without observing each frame in ContentView.
struct InspectorWindowMinimum: ViewModifier {
    let state: InspectorWindowState

    func body(content: Content) -> some View {
        content.frame(minWidth: InspectorWindowLayout.minimumWidth(reveal: state.revealedWidth), minHeight: 620)
    }
}

/// Only attaches the SwiftUI scene's window; it does not provide an animation-sized view.
struct InspectorWindowResize: NSViewRepresentable {
    let state: InspectorWindowState

    func makeNSView(context: Context) -> WindowView {
        let view = WindowView()
        view.state = state
        return view
    }
    func updateNSView(_ view: WindowView, context: Context) {}
    static func dismantleNSView(_ view: WindowView, coordinator: ()) { view.state?.attach(to: nil) }

    final class WindowView: NSView {
        weak var state: InspectorWindowState?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            state?.attach(to: window)
        }
    }
}
