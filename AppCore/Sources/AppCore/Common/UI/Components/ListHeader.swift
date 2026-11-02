#if canImport(SwiftUI)
import SwiftUI

/// Figma: "List Header / Large Title". A large title with an optional subtitle (e.g. a document number),
/// for lists that need a bigger heading than `ListHeader`.
struct ListLargeTitleHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(AppFont.largeTitleEmphasized)
                .foregroundStyle(AppColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.caption1Regular)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Figma: "List Header / Title2". A list heading with an optional count badge and, to the trailing side,
/// an optional segmented control (pass `trailing`, e.g. a `Picker` with `.pickerStyle(.segmented)`).
///
/// ```swift
/// ListHeader("Deliveries", badge: 7)
/// ListHeader("Materials", badge: 3) {
///     Picker("Filter", selection: $filter) { ... }.pickerStyle(.segmented)
/// }
/// ```
struct ListHeader<Trailing: View>: View {
    private let title: String
    private let badge: Int?
    private let trailing: Trailing

    init(_ title: String, badge: Int? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.badge = badge
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(AppFont.title2Emphasized)
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let badge {
                ListBadge(count: badge)
            }
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension ListHeader where Trailing == EmptyView {
    init(_ title: String, badge: Int? = nil) {
        self.init(title, badge: badge) { EmptyView() }
    }
}

/// The round count badge of a `ListHeader`. Keeps its size for any number up to two digits.
struct ListBadge: View {
    let count: Int

    var body: some View {
        Text(count, format: .number)
            .font(AppFont.footnoteRegular)
            .foregroundStyle(AppColor.textInverted)
            .padding(.horizontal)
            .frame(minHeight: 28)
            .background(AppColor.brandSecondary, in: Capsule())
            .fixedSize()
    }
}

#Preview("List headers") {
    @Previewable @State var filter = 0
    VStack(alignment: .leading, spacing: 24) {
        ListLargeTitleHeader(title: "Goods Receipt", subtitle: "4500000001")
        ListHeader("Deliveries")
        ListHeader("Deliveries", badge: 7)
        ListHeader("Materials", badge: 3) {
            Picker("Filter", selection: $filter) {
                Text("Open").tag(0)
                Text("All").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        }
    }
    .padding()
}
#endif
