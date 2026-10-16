import FinderMenuCore
import SwiftUI

/// A scroll viewport keeps the sliding glass panel and its controls inside their column.
struct InspectorReveal: View {
    let item: MenuItem
    let store: MenuStore
    let width: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                panel
                    .frame(width: 280, height: geometry.size.height)
            }
            .defaultScrollAnchor(.trailing)
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(width: max(0, width - 16), height: geometry.size.height)
            .modifier(GlassSurface(cornerRadius: 24))
            .padding(.trailing, 16)
            .opacity(width / 296)
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
