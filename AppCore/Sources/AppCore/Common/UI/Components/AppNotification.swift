#if canImport(SwiftUI)
import SwiftUI

/// The content of a notification: brief, non-blocking feedback such as "All materials received".
struct AppNotificationContent: Identifiable, Equatable, Sendable {
    let id = UUID()
    /// A short outcome, under about four words.
    var title: String
    /// One sentence of detail.
    var message: String
    /// An optional SF Symbol, shown at the leading edge.
    var systemImage: String?
    var date: Date = .now
}

/// Figma: "Notification - Collapsed". A Liquid Glass banner with an optional icon, a bold title, a one-line
/// message and the time.
///
/// Use a notification for a transient confirmation the user does not need to act on (delivery received,
/// put away completed). For a blocking decision, or anything destructive or irreversible, use an alert.
/// To show one, use `.appNotification(_:)`, which places it as the design says.
///
/// `stackedBehind` (0...2) draws collapsed notifications peeking out below, for illustrating a notification
/// history (the design's Stack 1-3).
struct AppNotification: View {
    let content: AppNotificationContent
    var stackedBehind = 0

    var body: some View {
        banner
            .background(alignment: .bottom) {
                // Collapsed notifications peeking out below, each narrower than the one in front.
                ZStack(alignment: .bottom) {
                    ForEach((1...max(min(stackedBehind, 2), 1)).reversed(), id: \.self) { depth in
                        if depth <= stackedBehind {
                            GlassShape()
                                .padding(.horizontal, CGFloat(depth) * 10)
                                .offset(y: CGFloat(depth) * 6)
                        }
                    }
                }
            }
            .padding(.bottom, CGFloat(min(max(stackedBehind, 0), 2)) * 6)
    }

    private var banner: some View {
        HStack(spacing: 10) {
            if let systemImage = content.systemImage {
                Image(systemName: systemImage)
                    .font(AppFont.title2Regular)
                    .foregroundStyle(AppColor.materialTypeBatched)
                    .frame(width: 34)
            }
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Text(content.title)
                        .font(AppFont.subheadlineEmphasized)
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer(minLength: 8)
                    Text(content.date, format: .dateTime.hour().minute())
                        .font(AppFont.subheadlineRegular)
                        .foregroundStyle(AppColor.textSecondary)
                }
                Text(content.message)
                    .font(AppFont.subheadlineRegular)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background { GlassShape() }
        .accessibilityElement(children: .combine)
    }
}

/// The frosted Liquid Glass of a notification.
private struct GlassShape: View {
    var body: some View {
        // The corner radius is the design's; there is no radius token yet.
        let shape = RoundedRectangle(cornerRadius: 24)
        shape
            .fill(.clear)
            .glassEffect(.regular, in: shape)
            .overlay(shape.strokeBorder(AppColor.strokeSection))
    }
}

extension View {
    /// Shows `notification` as a banner, centred at the top of the screen, 8 pt below the status bar and
    /// above all other content, then dismisses it after `duration`. Setting a new value replaces the
    /// banner that is showing.
    func appNotification(_ notification: Binding<AppNotificationContent?>, duration: Duration = .seconds(4))
        -> some View
    {
        overlay(alignment: .top) {
            if let content = notification.wrappedValue {
                AppNotification(content: content)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    .task(id: content.id) {
                        try? await Task.sleep(for: duration)
                        guard !Task.isCancelled else { return }
                        withAnimation { notification.wrappedValue = nil }
                    }
                    .onTapGesture { withAnimation { notification.wrappedValue = nil } }
            }
        }
        .animation(.default, value: notification.wrappedValue)
    }
}

#Preview("Notifications") {
    @Previewable @State var shown: AppNotificationContent?
    VStack(spacing: 24) {
        AppNotification(content: .init(title: "Title", message: "Message"))
        AppNotification(
            content: .init(title: "Delivery received", message: "All materials received", systemImage: "box.truck"))
        AppNotification(content: .init(title: "Title", message: "Message"), stackedBehind: 2)
        Button("Show") { shown = .init(title: "Put away", message: "Completed", systemImage: "checkmark.circle") }
    }
    .padding()
    .appNotification($shown)
}
#endif
