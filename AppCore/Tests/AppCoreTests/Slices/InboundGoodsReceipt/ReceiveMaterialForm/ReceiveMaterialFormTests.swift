import Foundation
import Ledjer
import Testing

@testable import AppCore

@Suite struct ReceiveMaterialFormTests {
    typealias Slice = InboundGoodsReceipt.ReceiveMaterialForm

    static let given: [any Event] = [
        DeliveryReceived(poNumber: "123", deliveryNumber: "D-1001", supplierName: "Nordic Spirits A/S",
                         qtyTotal: "24", dateReceived: "2026-10-19"),
        MaterialCreated(poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m1",
                        materialName: "Vodka 70cl"),
    ]

    @Test func aMaterialCreatedOnADeliveryCanBeLookedUpForReceiving() async throws {
        let store = InMemoryEventStore()
        try await store.append(Self.given)
        let state = try await Slice.model.run(on: store)
        #expect(Slice.lookup(state, poNumber: "123", materialNumber: "m1")
                == Slice.Item(poNumber: "123", materialNumber: "m1", qtyTotal: "24"))
    }
}

#if canImport(UIKit)
extension ReceiveMaterialFormTests {
    @Test @MainActor func emptyScreen() async throws {
        let system = try await AppSystem.inMemory()
        let live = LiveValue(system, Slice.model)
        await live.refresh()
        assertScreenSnapshots(of: Slice.Screen(system: system, poNumber: "123", live: live), system: system,
                              named: "empty")
    }

    @Test @MainActor func screenWithMaterial() async throws {
        let system = try await AppSystem.inMemory(given: Self.given)
        let live = LiveValue(system, Slice.model)
        await live.refresh()
        assertScreenSnapshots(
            of: Slice.Screen(system: system, poNumber: "123", live: live, materialNumber: "m1", qtyReceived: "24"),
            system: system, named: "material")
    }
}
#endif
