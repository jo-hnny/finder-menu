import SwiftUI

struct WorkspaceBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("CanvasSurface")
                if !reduceTransparency {
                    Ellipse()
                        .fill(Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.16))
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.9)
                        .blur(radius: 65)
                        .offset(x: -geometry.size.width * 0.35, y: -geometry.size.height * 0.2)
                    Ellipse()
                        .fill(Color.purple.opacity(colorScheme == .dark ? 0.18 : 0.13))
                        .frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.8)
                        .blur(radius: 75)
                        .offset(x: geometry.size.width * 0.2, y: geometry.size.height * 0.35)
                    Ellipse()
                        .stroke(
                            LinearGradient(colors: [.cyan.opacity(0.12), .indigo.opacity(0.14), .clear],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 70
                        )
                        .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.75)
                        .rotationEffect(.degrees(-30))
                        .blur(radius: 28)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
