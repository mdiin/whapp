#if canImport(SwiftUI)
import SwiftUI

/// One destination in an `AppSidebar` (Figma "Sidebar Row").
struct AppSidebarItem<ID: Hashable>: Identifiable {
    let id: ID
    var title: String
    /// The row's SF Symbol.
    var systemImage: String
    var subtitle: String?
    var isEnabled = true
}

/// A group of destinations. With a `title` the group is expandable (Figma "Section Header" with a
/// disclosure); without one the items are listed plainly.
struct AppSidebarSection<ID: Hashable>: Identifiable {
    let id = UUID()
    var title: String?
    var items: [AppSidebarItem<ID>]
}

/// Figma: "Sidebar / iPad". The navigation column: Edit and sidebar buttons, a search field, the
/// destinations with the current one selected, and expandable groups.
///
/// ```swift
/// AppSidebar(
///     sections: [
///         .init(title: nil, items: [
///             .init(id: Destination.goodsReceipt, title: "Goods Receipt", systemImage: "truck.box"),
///             .init(id: Destination.putAway, title: "Put Away", systemImage: "shippingbox"),
///         ]),
///         .init(title: "Settings", items: [
///             .init(id: Destination.settings, title: "Settings", systemImage: "gearshape"),
///         ]),
///     ],
///     selection: $destination, search: $query,
///     onEdit: {}, onToggleSidebar: {})
/// ```
///
/// The sidebar is the navigation column, not content that fills the screen: give it its column width
/// (for example as the sidebar of a `NavigationSplitView`) and let the content fill the rest. It scrolls,
/// so long lists work. Use the approved destination names and order, with the current destination
/// selected; keep it consistent with the toolbar's tabs (`Tabs=Off` while the sidebar is expanded).
struct AppSidebar<ID: Hashable>: View {
    let sections: [AppSidebarSection<ID>]
    @Binding var selection: ID?
    @Binding var search: String
    var onEdit: () -> Void = {}
    var onToggleSidebar: () -> Void = {}

    @State private var collapsed: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                AppButton("Edit", kind: .glass, action: onEdit)
                Spacer()
                AppIconButton(systemImage: "sidebar.left", label: "Sidebar", kind: .glass, action: onToggleSidebar)
            }
            searchField
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredSections) { section in
                        sectionView(section)
                    }
                }
            }
        }
        .padding()
    }

    /// The sections with only the items matching the search text.
    private var filteredSections: [AppSidebarSection<ID>] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sections }
        return sections.compactMap { section in
            var section = section
            section.items = section.items.filter { $0.title.localizedCaseInsensitiveContains(query) }
            return section.items.isEmpty ? nil : section
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.textSecondary)
            TextField("Search", text: $search)
                .font(AppFont.bodyRegular)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: Capsule())
    }

    @ViewBuilder private func sectionView(_ section: AppSidebarSection<ID>) -> some View {
        if let title = section.title {
            let isOpen = !collapsed.contains(section.id)
            Button {
                withAnimation {
                    if isOpen { collapsed.insert(section.id) } else { collapsed.remove(section.id) }
                }
            } label: {
                HStack {
                    Text(title)
                        .font(AppFont.bodyRegular)
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isOpen ? 0 : -90))
                        .foregroundStyle(AppColor.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            if isOpen {
                ForEach(section.items) { row($0) }
            }
        } else {
            ForEach(section.items) { row($0) }
        }
    }

    private func row(_ item: AppSidebarItem<ID>) -> some View {
        let isSelected = selection == item.id
        return Button {
            selection = item.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(item.isEnabled ? AppColor.brandPrimaryLight : AppColor.textDisabled)
                    .frame(width: 28)
                VStack(alignment: .leading) {
                    Text(item.title)
                        .font(AppFont.bodyRegular)
                        .foregroundStyle(item.isEnabled ? AppColor.textPrimary : AppColor.textDisabled)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(AppFont.footnoteRegular)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppColor.stateSelected : Color.clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private enum PreviewDestination: Hashable {
    case goodsReceipt, putAway, stock, movement, pickPack, settings, signOut
}

#Preview("Sidebar") {
    @Previewable @State var selection: PreviewDestination? = .goodsReceipt
    @Previewable @State var query = ""
    AppSidebar(
        sections: [
            .init(title: nil, items: [
                .init(id: PreviewDestination.goodsReceipt, title: "Goods Receipt", systemImage: "truck.box"),
                .init(id: .putAway, title: "Put Away", systemImage: "shippingbox"),
                .init(id: .stock, title: "Stock Overview", systemImage: "list.bullet.rectangle"),
                .init(id: .movement, title: "Goods Movement", systemImage: "list.clipboard"),
                .init(id: .pickPack, title: "Pick & Pack", systemImage: "shippingbox.and.arrow.backward"),
            ]),
            .init(title: "Settings", items: [
                .init(id: .settings, title: "Settings", systemImage: "gearshape"),
                .init(id: .signOut, title: "Sign Out", systemImage: "rectangle.portrait.and.arrow.right"),
            ]),
        ],
        selection: $selection, search: $query
    )
    .frame(width: 320)
}
#endif
