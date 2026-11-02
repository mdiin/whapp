#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@testable import AppCore

/// Snapshots of `AppNotification`, to compare with the Figma "Notification - Collapsed" variants.
@MainActor
@Suite struct NotificationComponentTests {
    private let at = Date(timeIntervalSince1970: 1_826_000_000)  // fixed, for stable snapshots

    private func content(_ title: String, _ message: String, symbol: String? = nil) -> AppNotificationContent {
        AppNotificationContent(title: title, message: message, systemImage: symbol, date: at)
    }

    @Test func banners() {
        let view = VStack(spacing: 24) {
            AppNotification(content: content("Title", "Message"))
            AppNotification(content: content("Delivery received", "All materials received", symbol: "box.truck"))
            AppNotification(content: content("Title", "Message"), stackedBehind: 1)
            AppNotification(content: content("Title", "Message"), stackedBehind: 2)
        }
        .padding()
        .frame(maxHeight: .infinity)
        .background(AppColor.illustrationLightBlue)

        assertSnapshot(
            of: UIHostingController(rootView: view), as: .image(on: .iPhone13Pro), named: "banners",
            testName: "notification")
    }

    @Test func placement() {
        // Centred at the top, below the status bar, above the content.
        let view = Color(.systemBackground)
            .ignoresSafeArea()
            .appNotification(.constant(content("Put away", "Completed", symbol: "checkmark.circle")))
        assertSnapshot(
            of: UIHostingController(rootView: view), as: .image(on: .iPhone13Pro), named: "placement",
            testName: "notification")
    }
}
#endif
