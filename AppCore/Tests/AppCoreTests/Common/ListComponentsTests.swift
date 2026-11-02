#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@testable import AppCore

/// Snapshots of the shared list components (`Common/UI/Components`), to compare with the Figma "List" page.
@MainActor
@Suite struct ListComponentsTests {
    private struct Delivery: Identifiable {
        let id: Int
        let po: String, number: String, vendor: String, qty: Int
    }

    private func assertSnapshot<V: View>(_ view: V, named name: String, line: UInt = #line) {
        let host = UIHostingController(rootView: view.padding().background(Color(.systemGroupedBackground)))
        SnapshotTesting.assertSnapshot(
            of: host, as: .image(on: .iPhone13Pro), named: name, testName: "list", line: line)
    }

    @Test func table() {
        let rows = (1...6).map {
            Delivery(id: $0, po: "45000000\($0)", number: "80000\($0)", vendor: "Vendor \($0)", qty: $0 * 12)
        }
        assertSnapshot(
            ListTable(rows, columns: [
                .init("PO") { $0.po },
                .init("Del. No.") { $0.number },
                .init("Vendor") { $0.vendor },
                .init("QTY", kind: .number) { $0.qty.formatted() },
            ]),
            named: "table")
    }

    @Test func taggedList() {
        let items = [
            TaggedListItem(id: 1, title: "10000123", subtitle: "Hex bolt M8", tag: .batched, detail: "24 PC"),
            TaggedListItem(id: 2, title: "10000456", subtitle: "Pump housing", tag: .serialized, detail: "2 PC"),
            TaggedListItem(id: 3, title: "10000789", subtitle: "Lubricant 5 L", tag: .shelfLife, detail: "6 BOX"),
        ]
        assertSnapshot(
            TaggedList(items) { _ in Rectangle().fill(AppColor.illustrationLightBlue) },
            named: "tagged-list")
    }

    @Test func headers() {
        assertSnapshot(
            VStack(alignment: .leading, spacing: 24) {
                ListLargeTitleHeader(title: "Goods Receipt", subtitle: "4500000001")
                ListHeader("Deliveries")
                ListHeader("Deliveries", badge: 7)
                ListHeader("Materials", badge: 3) {
                    Picker("Filter", selection: .constant(0)) {
                        Text("Open").tag(0)
                        Text("All").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
            },
            named: "headers")
    }
}
#endif
