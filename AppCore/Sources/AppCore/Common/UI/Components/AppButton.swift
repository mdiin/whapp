#if canImport(SwiftUI)
import SwiftUI

/// The look of an `AppButton`. Every kind turns grey automatically when the button is disabled
/// (`.disabled(true)`), as in the design's "Disabled" variants.
enum AppButtonKind {
    /// Figma "Buttons / Text" = Enabled, "Buttons / Enter": dark fill, light label.
    case primary
    /// Figma "Buttons / Text" = Variant 5 (label with icon): dark fill, accent-coloured label and icon.
    case accent
    /// Figma "Button - Liquid Glass - Text", "Button / Login": a light capsule with the system's Liquid Glass effect while enabled.
    case glass
}

/// Figma: the "Button" page. A capsule button with a label and an optional leading SF Symbol.
///
/// ```swift
/// AppButton("Receive") { send(ReceiveGoods(...)) }
/// AppButton("Details", systemImage: "info.circle", kind: .accent) { ... }
/// AppButton("Login", systemImage: "person.crop.circle", kind: .glass) { ... }
/// AppButton("Enter", fillsWidth: true) { ... }            // Figma "Buttons / Enter"
/// AppButton("Save") { ... }.disabled(!form.isValid)        // Figma "Disabled"
/// ```
struct AppButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let kind: AppButtonKind
    private let fillsWidth: Bool
    private let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        kind: AppButtonKind = .primary,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.fillsWidth = fillsWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(AppButtonStyle(kind: kind, fillsWidth: fillsWidth))
    }
}

/// Figma: "Buttons / Text" = Variant 4 / Variant 6. A round, icon-only button; `label` is its
/// accessibility label.
struct AppIconButton: View {
    private let systemImage: String
    private let label: LocalizedStringKey
    private let kind: AppButtonKind
    private let action: () -> Void

    init(
        systemImage: String,
        label: LocalizedStringKey,
        kind: AppButtonKind = .primary,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.kind = kind
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(AppButtonStyle(kind: kind, fillsWidth: false))
        .accessibilityLabel(label)
    }
}

/// The capsule style behind `AppButton` and `AppIconButton`; usable on any `Button`.
struct AppButtonStyle: ButtonStyle {
    var kind: AppButtonKind = .primary
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        AppButtonBody(configuration: configuration, kind: kind, fillsWidth: fillsWidth)
    }
}

private struct AppButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: AppButtonKind
    let fillsWidth: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let content = configuration.label
            .font(AppFont.bodyRegular)
            .foregroundStyle(labelColor)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: fillsWidth ? .infinity : nil)

        Group {
            if kind == .glass && isEnabled {
                content
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .overlay(Capsule().strokeBorder(AppColor.strokeSection))
            } else {
                content.background(fill, in: Capsule())
            }
        }
        .opacity(configuration.isPressed ? 0.7 : 1)
        .contentShape(Capsule())
    }

    private var labelColor: Color {
        guard isEnabled else { return AppColor.textDisabled }
        switch kind {
        case .primary: return AppColor.textInverted
        case .accent: return AppColor.brandSecondary
        case .glass: return AppColor.textPrimary
        }
    }

    /// The solid fill (glass buttons use the system's glass effect while enabled).
    private var fill: Color {
        guard isEnabled else { return AppColor.stateDisabled }
        return AppColor.primaryDark
    }
}

#Preview("Buttons") {
    VStack(alignment: .leading, spacing: 16) {
        AppButton("Label") {}
        AppButton("Label") {}.disabled(true)
        AppButton("Label with icon", systemImage: "info.circle", kind: .accent) {}
        AppButton("Label with icon", systemImage: "info.circle") {}.disabled(true)
        HStack {
            AppIconButton(systemImage: "info.circle", label: "Info") {}
            AppIconButton(systemImage: "info.circle", label: "Info") {}.disabled(true)
        }
        AppButton("TSS TEST", kind: .glass) {}
        AppButton("Login", systemImage: "person.crop.circle", kind: .glass) {}
        AppButton("Enter", fillsWidth: true) {}
        AppButton("Enter", fillsWidth: true) {}.disabled(true)
    }
    .padding()
}
#endif
