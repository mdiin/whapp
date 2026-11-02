#if canImport(SwiftUI)
import SwiftUI

/// Figma: "Text Field" (Placeholder, Focused, Typing, Value Entered). A single-line text row for a grouped
/// table or a form: a faint placeholder, a blue cursor while focused, the value in the primary colour,
/// and a clear button while typing. Add an accessory with `trailing`, for example a scan button.
///
/// ```swift
/// AppGroupedTable {
///     AppTextField("Received QTY", text: $quantity)
///     AppTextField("Batch", text: $batch) { Button("Scan", systemImage: "qrcode.viewfinder") { scan() } }
/// }
/// ```
///
/// It is a plain row: its box (rounded group, lines between rows) comes from `AppGroupedTable`.
struct AppTextField<Trailing: View>: View {
    private let title: LocalizedStringKey
    @Binding private var text: String
    private let trailing: Trailing
    @FocusState private var isFocused: Bool

    init(_ title: LocalizedStringKey, text: Binding<String>, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self._text = text
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField(
                "", text: $text,
                prompt: Text(title).foregroundStyle(AppColor.textDisabled)
            )
            .font(AppFont.bodyRegular)
            .foregroundStyle(AppColor.textPrimary)
            .tint(AppColor.materialTypeBatched)
            .focused($isFocused)
            .accessibilityLabel(title)

            if isFocused && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.textDisabled)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
            trailing
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
}

extension AppTextField where Trailing == EmptyView {
    init(_ title: LocalizedStringKey, text: Binding<String>) {
        self.init(title, text: text) { EmptyView() }
    }
}

#Preview("Text field") {
    @Previewable @State var empty = ""
    @Previewable @State var value = "Value"
    @Previewable @State var batch = ""
    AppGroupedTable {
        AppTextField("Value", text: $empty)
        AppTextField("Value", text: $value)
        AppTextField("Batch", text: $batch) {
            Button("Scan", systemImage: "qrcode.viewfinder") {}
        }
    }
    .padding()
}
#endif
