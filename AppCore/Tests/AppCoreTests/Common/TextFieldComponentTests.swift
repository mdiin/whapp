#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@testable import AppCore

/// Snapshot of `AppTextField` in a grouped table, to compare with the Figma "Text Field" states.
/// Focused and typing (cursor, clear button) depend on live focus and are not snapshotted.
@MainActor
@Suite struct TextFieldComponentTests {
    @Test func states() {
        let view = AppGroupedTable {
            AppTextField("Value", text: .constant(""))
            AppTextField("Value", text: .constant("Value"))
            AppTextField("Batch", text: .constant("")) {
                Button("Scan", systemImage: "qrcode.viewfinder") {}
            }
        }
        .frame(maxWidth: 402)
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))

        assertSnapshot(
            of: UIHostingController(rootView: view), as: .image(on: .iPhone13Pro), named: "states",
            testName: "textfield")
    }
}
#endif
