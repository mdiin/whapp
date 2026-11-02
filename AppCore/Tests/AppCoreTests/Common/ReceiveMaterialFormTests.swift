#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@testable import AppCore

/// Snapshots and logic of `ReceiveMaterialForm`, to compare with the Figma "Receive Material" variants.
@MainActor
@Suite struct ReceiveMaterialFormTests {
    private func form(
        _ tracking: MaterialTracking, quantity: String = "", identifier: String = "", expiry: Date? = nil
    ) -> some View {
        ReceiveMaterialForm(
            tracking: tracking,
            materialNumber: "100-00482", description: "Hex nut M8 zinc plated DIN 934",
            expectedQuantity: 500, unit: "PCS",
            receivedQuantity: .constant(quantity), identifier: .constant(identifier),
            expiryDate: .constant(expiry), onScan: {}, onReceive: {}
        ) {
            Rectangle().fill(AppColor.illustrationLightBlue)
        }
        .background(Color(.systemBackground))
    }

    private func snapshot<V: View>(_ view: V, named name: String, line: UInt = #line) {
        assertSnapshot(
            of: UIHostingController(rootView: view), as: .image(on: .iPhone13Pro), named: name,
            testName: "receive", line: line)
    }

    private let expiry = Date(timeIntervalSince1970: 1_826_000_000)  // fixed, for stable snapshots

    @Test func batched() {
        snapshot(form(.batched), named: "batched-empty")
        snapshot(form(.batched, quantity: "500", identifier: "B2026-0314"), named: "batched-filled")
    }

    @Test func shelfLife() {
        snapshot(form(.shelfLife), named: "shelf-life-empty")
        snapshot(
            form(.shelfLife, quantity: "500", identifier: "B2026-0314", expiry: expiry),
            named: "shelf-life-filled")
    }

    @Test func serialized() {
        snapshot(form(.serialized), named: "serialized-empty")
        snapshot(form(.serialized, quantity: "1", identifier: "SN-7788"), named: "serialized-filled")
    }

    @Test func receiveNeedsEveryFieldOfTheTrackingType() {
        func complete(_ tracking: MaterialTracking, _ quantity: String, _ id: String, _ date: Date?) -> Bool {
            ReceiveMaterialForm(
                tracking: tracking, materialNumber: "m", description: "d", expectedQuantity: 1, unit: "PCS",
                receivedQuantity: .constant(quantity), identifier: .constant(id), expiryDate: .constant(date),
                onScan: {}, onReceive: {}
            ) { EmptyView() }.isComplete
        }
        #expect(!complete(.batched, "", "B1", nil))
        #expect(!complete(.batched, "5", "  ", nil))
        #expect(complete(.batched, "5", "B1", nil))
        #expect(complete(.serialized, "1", "SN1", nil))
        #expect(!complete(.shelfLife, "5", "B1", nil))
        #expect(complete(.shelfLife, "5", "B1", expiry))
    }
}
#endif
