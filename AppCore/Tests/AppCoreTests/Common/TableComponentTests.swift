#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@testable import AppCore

/// Snapshots of the grouped table components (`AppTable.swift`), to compare with the Figma "Grouped Table View".
@MainActor
@Suite struct TableComponentTests {
    private func snapshot<V: View>(_ view: V, named name: String, line: UInt = #line) {
        assertSnapshot(
            of: UIHostingController(
                rootView: view.padding().frame(maxHeight: .infinity, alignment: .top).background(Color(.systemGroupedBackground))),
            as: .image(on: .iPadPro11(.portrait)), named: name, testName: "table", line: line)
    }

    @Test func groupedTable() {
        snapshot(
            VStack(alignment: .leading, spacing: 16) {
                AppSectionTitle("Select Pallet Size")
                AppSegmentedControl(["EUR 1", "EUR 2", "Half"], selection: .constant("EUR 1")) { $0 }
                AppGroupedTable {
                    AppTableRow("Title") { AppTableDetail("Detail", systemImage: "star") }
                    AppTableRow("Title", subtitle: "Subtitle") { AppTableDetail("Detail") }
                    AppTableRow("Title", subtitle: "Subtitle", leading: {
                        Rectangle().fill(AppColor.illustrationLightBlue).frame(width: 68, height: 68)
                    }, trailing: { AppTableDetail("Detail") })
                    AppTableRow("Title") { Button("Button") {} }
                    AppTableRow("Title") { AppTableDetail("Detail", drillIn: true) }
                    AppTableRow("Weight") { Stepper("", value: .constant(1)).labelsHidden() }
                    AppTableRow("Title") { Toggle("", isOn: .constant(true)).labelsHidden() }
                    AppTableActionRow("Action") {}
                }
            }
            .frame(maxWidth: 648),
            named: "grouped")
    }

    @Test func singleRowGroupHasNoDivider() {
        snapshot(
            AppGroupedTable { AppTableRow("Only row") { AppTableDetail("Detail") } }.frame(maxWidth: 648),
            named: "single")
    }
}
#endif
