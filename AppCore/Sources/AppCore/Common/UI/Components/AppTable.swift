#if canImport(SwiftUI)
import SwiftUI

/// Figma: "Grouped Table View". A rounded group of rows with a line between them (and none after the
/// last), for settings- and form-like tables.
///
/// ```swift
/// AppSectionTitle("Select Pallet Size")
/// AppGroupedTable {
///     AppTableRow("Pallet") { AppTableDetail("EUR 1", drillIn: true) }
///     AppTableRow("Weight", subtitle: "Gross") { Stepper("", value: $weight).labelsHidden() }
///     AppTableRow("Fragile") { Toggle("", isOn: $fragile).labelsHidden() }
///     AppTableActionRow("Add pallet") { addPallet() }
/// }
/// ```
///
/// For columns of records (deliveries, materials) use `ListTable` instead.
struct AppGroupedTable<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content()) { rows in
                ForEach(rows.indices, id: \.self) { index in
                    if index > 0 {
                        Divider().overlay(AppColor.strokeSection)
                            .padding(.leading)
                    }
                    rows[index]
                }
            }
        }
        // The corner radius is the design's; there is no radius token yet.
        .background(AppColor.tertiary, in: RoundedRectangle(cornerRadius: 26))
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

/// Figma: "Row". A title with an optional subtitle and leading image, and a trailing control: pass the
/// control as `trailing`, for example `AppTableDetail`, a `Toggle`, a `Stepper`, a `DatePicker` or a
/// `Menu` (pop-up). Without a trailing control the row shows only its text.
struct AppTableRow<Leading: View, Trailing: View>: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let leading: Leading
    private let trailing: Trailing

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            leading
            VStack(alignment: .leading) {
                Text(title)
                    .font(AppFont.bodyRegular)
                    .foregroundStyle(AppColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.subheadlineRegular)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

extension AppTableRow where Leading == EmptyView {
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.init(title, subtitle: subtitle, leading: { EmptyView() }, trailing: trailing)
    }
}

extension AppTableRow where Leading == EmptyView, Trailing == EmptyView {
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.init(title, subtitle: subtitle, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

/// The trailing detail of a row: secondary text, an optional symbol and an optional drill-in chevron.
struct AppTableDetail: View {
    private let text: LocalizedStringKey
    private let systemImage: String?
    private let drillIn: Bool

    init(_ text: LocalizedStringKey, systemImage: String? = nil, drillIn: Bool = true) {
        self.text = text
        self.systemImage = systemImage
        self.drillIn = drillIn
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(AppFont.bodyRegular)
                .foregroundStyle(AppColor.textSecondary)
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(AppColor.materialTypeBatched)
            }
            if drillIn {
                Image(systemName: "chevron.right")
                    .font(AppFont.footnoteEmphasized)
                    .foregroundStyle(AppColor.textDisabled)
            }
        }
    }
}

/// Figma: "Row - Button". A centred, tappable action at the bottom of a group.
struct AppTableActionRow: View {
    private let title: LocalizedStringKey
    private let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.bodyRegular)
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(ListRowButtonStyle())
    }
}

/// Figma: "Section Title". The heading above a group.
struct AppSectionTitle: View {
    private let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(AppFont.bodyEmphasized)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Figma: "Segmented Control" (large). Choose one of a few options, such as a pallet size.
///
/// ```swift
/// AppSegmentedControl(PalletSize.allCases, selection: $size) { $0.title }
/// ```
struct AppSegmentedControl<Value: Hashable>: View {
    private let options: [Value]
    @Binding private var selection: Value
    private let label: (Value) -> String

    init(_ options: [Value], selection: Binding<Value>, label: @escaping (Value) -> String) {
        self.options = options
        self._selection = selection
        self.label = label
    }

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option)).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .labelsHidden()
    }
}

#Preview("Table") {
    @Previewable @State var weight = 1
    @Previewable @State var fragile = true
    @Previewable @State var size = "EUR 1"
    VStack(alignment: .leading, spacing: 16) {
        AppSectionTitle("Select Pallet Size")
        AppSegmentedControl(["EUR 1", "EUR 2", "Half"], selection: $size) { $0 }
        AppGroupedTable {
            AppTableRow("Title") { AppTableDetail("Detail", systemImage: "star") }
            AppTableRow("Title", subtitle: "Subtitle") { AppTableDetail("Detail") }
            AppTableRow("Weight") { Stepper("", value: $weight).labelsHidden() }
            AppTableRow("Fragile") { Toggle("", isOn: $fragile).labelsHidden() }
            AppTableActionRow("Action") {}
        }
    }
    .padding()
}
#endif
