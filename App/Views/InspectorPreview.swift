import FinderMenuCore
import SwiftUI

/// Only this portion of the workspace observes the inspector's displayed width.
struct InspectorPreview: View {
    let store: MenuStore
    let state: InspectorWindowState
    @Binding var target: SelectionKind
    let availableWidth: CGFloat

    var body: some View {
        let width = state.revealedWidth
        HStack(spacing: 0) {
            Group {
                if let item = state.displayedItem {
                    InspectorReveal(item: item, store: store, width: width)
                } else {
                    Color.clear
                }
            }
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .allowsHitTesting(store.selectedID != nil && width >= 296)
            .accessibilityHidden(width < 296 || store.selectedID == nil)
            MenuPreview(configuration: store.configuration, highlightedID: store.selectedID,
                        dismissEditor: { store.selectedID = nil }, target: $target)
                .frame(width: max(0, availableWidth - width))
                .frame(maxHeight: .infinity)
        }
    }
}
