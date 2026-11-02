#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@testable import AppCore

/// Snapshots of the shared buttons (`Common/UI/Components/AppButton.swift`), to compare with the Figma
/// "Button" page.
@MainActor
@Suite struct ButtonComponentsTests {
    @Test func buttons() {
        let view = VStack(alignment: .leading, spacing: 16) {
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
        .background(Color(.systemBackground))

        assertSnapshot(
            of: UIHostingController(rootView: view), as: .image(on: .iPhone13Pro), named: "buttons",
            testName: "button")
    }
}
#endif
