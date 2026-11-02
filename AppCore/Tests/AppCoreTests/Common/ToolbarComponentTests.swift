#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@testable import AppCore

/// Snapshots of `AppToolbar`, to compare with the Figma "Toolbar / Top / iPad" variants.
@MainActor
@Suite struct ToolbarComponentTests {
    private func tabs() -> AppToolbarTabs {
        AppToolbarTabs(titles: ["Goods Receipt", "Pick & Pack"], selection: .constant(0), onToggleSidebar: {})
    }

    private func snapshot<V: View>(_ view: V, named name: String, line: UInt = #line) {
        assertSnapshot(
            of: UIHostingController(rootView: view.padding().background(AppColor.illustrationLightBlue)),
            as: .image(on: .iPadPro11(.portrait)), named: name, testName: "toolbar", line: line)
    }

    @Test func tabsOff() {
        snapshot(
            VStack(spacing: 32) {
                AppToolbar(.overviewInline, title: "Title")
                AppToolbar(.overview, title: "Title")
                AppToolbar(.detailSearch, title: "Title", subtitle: "Subtitle")
                AppToolbar(.detail, title: "Title", subtitle: "Subtitle")
                Spacer()
            },
            named: "tabs-off")
    }

    @Test func tabsOn() {
        snapshot(
            VStack(spacing: 32) {
                AppToolbar(.overview, title: "Title", tabs: tabs())
                AppToolbar(.detailSearch, title: "Title", subtitle: "Subtitle", tabs: tabs())
                AppToolbar(.detail, title: "Title", subtitle: "Subtitle", tabs: tabs())
                Spacer()
            },
            named: "tabs-on")
    }
}
#endif
