#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@testable import AppCore

/// Snapshot of the shared progress bar (`Common/UI/Components/AppProgressBar.swift`), to compare with the
/// Figma "Progressbar" page.
@MainActor
@Suite struct ProgressBarComponentTests {
    @Test func progressBar() {
        let view = VStack(spacing: 16) {
            AppProgressBar(completed: 0, of: 3, label: "materials received")
            AppProgressBar(completed: 2, of: 3, label: "materials received")
            AppProgressBar(completed: 3, of: 3, label: "materials received")
            AppProgressBar(completed: 0, of: 0, label: "materials received")
        }
        .padding()
        .background(Color(.systemBackground))

        assertSnapshot(
            of: UIHostingController(rootView: view), as: .image(on: .iPhone13Pro), named: "progress-bar",
            testName: "progress")
    }

    @Test func clampsTheValue() {
        // Out-of-range and non-finite values must not crash or overflow the bar.
        _ = AppProgressBar(value: 1.7, label: "x").body
        _ = AppProgressBar(value: -1, label: "x").body
        _ = AppProgressBar(value: .nan, label: "x").body
    }
}
#endif
