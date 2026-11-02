#if canImport(SwiftUI)
import SwiftUI

/// The tag line of a `TaggedList` row: a coloured symbol and a label (e.g. the material's tracking type).
struct ListTag: Sendable {
    let title: LocalizedStringResource
    let systemImage: String
    let color: Color

    init(_ title: LocalizedStringResource, systemImage: String = "square.dashed", color: Color) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
    }

    /// The material tracking types of the design system (colours: `Material Type/…`).
    static let batched = ListTag("Batch", color: AppColor.materialTypeBatched)
    static let serialized = ListTag("Serial", color: AppColor.materialTypeSerialized)
    static let shelfLife = ListTag("Shelf life", color: AppColor.materialTypeShelfLife)
}

/// Content of one `TaggedList` row.
struct TaggedListItem<ID: Hashable>: Identifiable {
    let id: ID
    var title: String
    var subtitle: String?
    var tag: ListTag?
    /// The trailing text, e.g. quantity and unit.
    var detail: String?
}

/// Figma: "Lists / With tag" (Goods Receipt materials). A custom list of rows with a leading image, a
/// title, a subtitle, a tag and a trailing detail with a disclosure chevron.
///
/// The image is the caller's: pass any view (a thumbnail, a placeholder). Rows are buttons that give a
/// neutral touch-down highlight (`ListRowButtonStyle`), never a persistent selection.
struct TaggedList<ID: Hashable, Leading: View>: View {
    private let items: [TaggedListItem<ID>]
    private let onSelect: (TaggedListItem<ID>) -> Void
    private let leading: (TaggedListItem<ID>) -> Leading

    init(
        _ items: [TaggedListItem<ID>],
        onSelect: @escaping (TaggedListItem<ID>) -> Void = { _ in },
        @ViewBuilder leading: @escaping (TaggedListItem<ID>) -> Leading
    ) {
        self.items = items
        self.onSelect = onSelect
        self.leading = leading
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                if offset > 0 {
                    Divider().overlay(AppColor.strokeSection)
                }
                Button { onSelect(item) } label: {
                    row(item)
                }
                .buttonStyle(ListRowButtonStyle())
            }
        }
        .background(AppColor.tertiary)
    }

    private func row(_ item: TaggedListItem<ID>) -> some View {
        HStack(spacing: 16) {
            leading(item)
                .frame(width: 68, height: 68)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(AppFont.bodyRegular)
                    .foregroundStyle(AppColor.textPrimary)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(AppFont.subheadlineRegular)
                        .foregroundStyle(AppColor.textSecondary)
                }
                if let tag = item.tag {
                    Label {
                        Text(tag.title)
                            .foregroundStyle(AppColor.textSecondary)
                    } icon: {
                        Image(systemName: tag.systemImage)
                            .foregroundStyle(tag.color)
                    }
                    .font(AppFont.footnoteRegular)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let detail = item.detail {
                Text(detail)
                    .font(AppFont.bodyRegular)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(AppFont.footnoteEmphasized)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

/// Pressed feedback of list rows: a neutral highlight while touching down, nothing afterwards.
struct ListRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? AppColor.stateSelected : .clear)
    }
}

#Preview("Tagged list") {
    let items = [
        TaggedListItem(id: 1, title: "10000123", subtitle: "Hex bolt M8", tag: .batched, detail: "24 PC"),
        TaggedListItem(id: 2, title: "10000456", subtitle: "Pump housing", tag: .serialized, detail: "2 PC"),
        TaggedListItem(id: 3, title: "10000789", subtitle: "Lubricant 5 L", tag: .shelfLife, detail: "6 BOX"),
    ]
    return TaggedList(items) { _ in
        Rectangle().fill(AppColor.illustrationLightBlue)
    }
    .padding()
}
#endif
