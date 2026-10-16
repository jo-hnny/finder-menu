import AppKit
import Observation
import QuartzCore
import SwiftUI
import WindowAnimation

/// One timeline drives the window frame and the inspector's visible space.
@MainActor @Observable
final class InspectorWindowState {
    private(set) var displayedID: UUID?
    private(set) var revealedWidth: CGFloat = 0
    private(set) var isResizing = false
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored private var automaticGrowth: CGFloat = 0
    @ObservationIgnored private var availableGrowth: CGFloat = 0
    @ObservationIgnored private var isPresented = false
    private(set) var targetWidth: CGFloat = 0
    @ObservationIgnored private var startFrame: NSRect = .zero
    @ObservationIgnored private var targetFrame: NSRect = .zero
    @ObservationIgnored private var startReveal: CGFloat = 0
    @ObservationIgnored private var lastWindowFrame: NSRect = .zero
    @ObservationIgnored private var animatesWindow = true

    func select(_ id: UUID?, reduceMotion: Bool) {
        if let id { displayedID = id }
        let presented = id != nil
        guard presented != isPresented, let window else { return }
        isPresented = presented
        if presented, revealedWidth == 0, !isResizing {
            automaticGrowth = 0
            animatesWindow = true
            let screenWidth = (window.screen ?? NSScreen.main)?.visibleFrame.width ?? window.frame.width
            availableGrowth = window.styleMask.contains(.fullScreen) ? 0 : min(296, max(0, screenWidth - window.frame.width))
        }
        if isResizing || revealedWidth > 0, window.inLiveResize || window.frame != lastWindowFrame {
            animatesWindow = false
        }
        automaticGrowth = min(automaticGrowth, max(0, window.frame.width - 780))
        if !animatesWindow { availableGrowth = automaticGrowth }
        // Rebase every retarget on the current frame, preserving manual width changes.
        let originalWidth = max(780, window.frame.width - automaticGrowth)

        startFrame = window.frame
        lastWindowFrame = startFrame
        animatesWindow = true
        startReveal = revealedWidth
        targetFrame = startFrame
        if !window.styleMask.contains(.fullScreen) {
            let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? startFrame
            targetFrame.size.width = min(originalWidth + (presented ? availableGrowth : 0), visibleFrame.width)
            targetFrame.origin.x = min(max(startFrame.minX, visibleFrame.minX), visibleFrame.maxX - targetFrame.width)
        }

        targetWidth = presented ? 296 : 0
        isResizing = true
        if reduceMotion || startReveal == targetWidth { reveal(to: targetWidth) }
    }

    /// WindowAnimation supplies one spring-driven width for both the window and panel.
    func reveal(to width: CGFloat) {
        guard isResizing, let window else { return }
        if animatesWindow, window.inLiveResize || window.frame != lastWindowFrame {
            animatesWindow = false
        }
        automaticGrowth = min(automaticGrowth, max(0, window.frame.width - 780))
        let reveal = min(296, max(0, width))
        let distance = targetWidth - startReveal
        let progress = distance == 0 ? 1 : (reveal - startReveal) / distance
        var frame = window.frame
        if animatesWindow {
            frame = startFrame
            frame.origin.x += (targetFrame.minX - startFrame.minX) * progress
            frame.size.width = (startFrame.width + (targetFrame.width - startFrame.width) * progress).rounded()
        }
        frame.size.width = max(frame.width, max(780, 350 + 16 + reveal + 340 + 32))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        revealedWidth = reveal
        // Account only for width changes actually applied, including minimum-size growth.
        let previousWidth = window.frame.width
        if frame != window.frame {
            window.setFrame(frame, display: false)
            automaticGrowth = max(0, automaticGrowth + window.frame.width - previousWidth)
        }
        lastWindowFrame = window.frame
        availableGrowth = animatesWindow ? max(availableGrowth, automaticGrowth) : automaticGrowth
        CATransaction.commit()
        if reveal == targetWidth {
            isResizing = false
            if !isPresented {
                displayedID = nil
                automaticGrowth = 0
            }
        }
    }
}

/// An invisible size driver uses the library without restricting manual window resizing.
struct InspectorWindowResize: View {
    let state: InspectorWindowState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Color.clear.frame(width: state.targetWidth + 2, height: 2)
            } else {
                Color.clear
                    // The library treats sizes within one point of zero as uninitialized.
                    .frame(width: state.targetWidth + 2, height: 2)
                    .modifier(WindowAnimationModifier(speed: 5, alignment: .leading))
                    .onGeometryChange(for: CGFloat.self) { $0.size.width - 2 } action: { state.reveal(to: $0) }
            }
        }
        .background { InspectorWindowAttachment(state: state) }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { state.reveal(to: state.targetWidth) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Attach to this view's window without changing presentation state during SwiftUI updates.
private struct InspectorWindowAttachment: NSViewRepresentable {
    let state: InspectorWindowState

    func makeNSView(context: Context) -> WindowView {
        let view = WindowView()
        view.state = state
        return view
    }

    func updateNSView(_ view: WindowView, context: Context) {}

    final class WindowView: NSView {
        var state: InspectorWindowState?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            state?.window = window
        }
    }
}
