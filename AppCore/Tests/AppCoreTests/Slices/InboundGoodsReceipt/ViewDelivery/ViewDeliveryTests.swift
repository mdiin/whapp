import Foundation
import Ledjer
import Testing

@testable import AppCore

@Suite struct ViewDeliveryTests {
    typealias Slice = InboundGoodsReceipt.ViewDelivery
    static let supplier = "Nordic Spirits A/S"

    static let given: [any Event] = [
        DeliveryReceived(poNumber: "123", deliveryNumber: "D-1001", supplierName: supplier, qtyTotal: "48",
                         dateReceived: "2026-10-19"),
        MaterialCreated(poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m1",
                        materialName: "Vodka 70cl"),
        MaterialCreated(poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m2",
                        materialName: "Gin 70cl"),
        MaterialReceived(qtyReceived: "24", materialNumber: "m1", poNumber: "123"),
    ]

    @Test func materialsOfADeliveryAreShownAsReceivedOrOpen() async throws {
        let store = InMemoryEventStore()
        try await store.append(Self.given)
        let result = Slice.items(try await Slice.model.run(on: store), poNumber: "123")
        #expect(result == [
            Slice.Item(poNumber: "123", materialNumber: "m1", materialName: "Vodka 70cl", qtyTotal: "24",
                       supplierName: Self.supplier, isReceived: true),
            Slice.Item(poNumber: "123", materialNumber: "m2", materialName: "Gin 70cl", qtyTotal: "24",
                       supplierName: Self.supplier, isReceived: false),
        ])
    }
}

#if canImport(UIKit)
extension ViewDeliveryTests {
    @Test @MainActor func screenWithMaterials() async throws {
        let system = try await AppSystem.inMemory(given: Self.given)
        let live = LiveValue(system, Slice.model)
        await live.refresh()
        assertScreenSnapshots(of: Slice.Screen(system: system, poNumber: "123", live: live), system: system,
                              named: "materials")
    }
}
#endif
