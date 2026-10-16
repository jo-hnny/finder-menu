import FinderMenuCore
import SwiftUI

/// Reveal the fixed-width controls from the trailing edge, with glass outside the content clip.
struct InspectorReveal: View {
    let item: MenuItem
    let store: MenuStore
    let width: CGFloat

    var body: some View {
        let glassWidth = max(0, width - 16)
        GeometryReader { geometry in
            panel
                .frame(width: 280, height: geometry.size.height)
                .frame(width: glassWidth, height: geometry.size.height, alignment: .trailing)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .modifier(GlassSurface(cornerRadius: 24))
                // Below two corner radii the shape is a thin capsule; fade it instead of showing the sliver.
                .opacity(min(1, glassWidth / 48))
                .padding(.trailing, 16)
        }
        .frame(width: width)
    }

    private var panel: some View {
        ItemInspector(item: item, store: store)
            .id(item.id)
            .frame(width: 280)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
