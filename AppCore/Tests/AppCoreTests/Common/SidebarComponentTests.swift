#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@testable import AppCore

/// Snapshots of `AppSidebar`, to compare with the Figma "Sidebar / iPad" component.
@MainActor
@Suite struct SidebarComponentTests {
    private enum Destination: Hashable { case goodsReceipt, putAway, stock, movement, pickPack, settings, signOut }

    private func sections() -> [AppSidebarSection<Destination>] {
        [
            .init(title: nil, items: [
                .init(id: .goodsReceipt, title: "Goods Receipt", systemImage: "truck.box"),
                .init(id: .putAway, title: "Put Away", systemImage: "shippingbox"),
                .init(id: .stock, title: "Stock Overview", systemImage: "list.bullet.rectangle"),
                .init(id: .movement, title: "Goods Movement", systemImage: "list.clipboard"),
                .init(id: .pickPack, title: "Pick & Pack", systemImage: "shippingbox.and.arrow.backward"),
            ]),
            .init(title: "Settings", items: [
                .init(id: .settings, title: "Settings", systemImage: "gearshape"),
                .init(id: .signOut, title: "Sign Out", systemImage: "rectangle.portrait.and.arrow.right"),
            ]),
        ]
    }

    private func sidebar(selection: Destination?, search: String = "") -> some View {
        AppSidebar(sections: sections(), selection: .constant(selection), search: .constant(search))
            .frame(width: 320, height: 834, alignment: .top)
            .background(Color(.systemBackground))
    }

    @Test func sidebar() {
        assertSnapshot(
            of: UIHostingController(rootView: sidebar(selection: .goodsReceipt)),
            as: .image(on: .iPadPro11(.portrait)), named: "selected", testName: "sidebar")
    }

    @Test func searchFiltersDestinations() {
        assertSnapshot(
            of: UIHostingController(rootView: sidebar(selection: nil, search: "pack")),
            as: .image(on: .iPadPro11(.portrait)), named: "filtered", testName: "sidebar")
    }
}
#endif
