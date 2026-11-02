#if canImport(SwiftUI)
import SwiftUI

/// Figma: "Progress Bar - Determinate Linear". A determinate, linear progress bar with a count label at
/// the leading end and the percentage at the trailing end, filling its container's width.
///
/// Use it above the list it summarises, and keep it visible while the list is processed: it is the user's
/// checklist, not a loading state.
///
/// ```swift
/// AppProgressBar(completed: 2, of: 3, label: "materials received")   // "2 out of 3 materials received", 67%
/// AppProgressBar(value: 0.4, label: "Counting")
/// ```
struct AppProgressBar: View {
    private let fraction: Double
    private let label: String

    /// `value` is the fraction done (0...1; values outside are clamped), `label` the text at the leading end.
    init(value: Double, label: String) {
        self.fraction = min(max(value.isFinite ? value : 0, 0), 1)
        self.label = label
    }

    /// "`completed` out of `total` `noun`", with the share as the value. An empty `total` counts as 0%.
    init(completed: Int, of total: Int, label noun: String) {
        let done = max(completed, 0)
        self.init(
            value: total > 0 ? Double(done) / Double(total) : 0,
            label: "\(done) out of \(max(total, 0)) \(noun)")
    }

    private var percent: String { "\(Int((fraction * 100).rounded()))%" }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                Spacer(minLength: 8)
                Text(percent)
            }
            .font(AppFont.footnoteRegular)
            .foregroundStyle(AppColor.textSecondary)

            ProgressView(value: fraction)
                .tint(AppColor.brandSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(percent)
    }
}

#Preview("Progress bar") {
    VStack(spacing: 16) {
        AppProgressBar(completed: 0, of: 3, label: "materials received")
        AppProgressBar(completed: 2, of: 3, label: "materials received")
        AppProgressBar(completed: 3, of: 3, label: "materials received")
    }
    .padding()
}
#endif
