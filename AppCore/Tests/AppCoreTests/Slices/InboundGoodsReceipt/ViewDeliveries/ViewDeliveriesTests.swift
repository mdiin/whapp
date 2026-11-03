import Foundation
import Ledjer
import Testing

@testable import AppCore

@Suite struct ViewDeliveriesTests {
    typealias Slice = InboundGoodsReceipt.ViewDeliveries
    static let supplier = "Nordic Spirits A/S"

    static func delivered(_ po: String, _ number: String, qty: String, date: String, materials: String? = nil)
        -> DeliveryReceived
    {
        DeliveryReceived(poNumber: po, deliveryNumber: number, supplierName: supplier, qtyTotal: qty,
                         dateReceived: date, materialNumbers: materials)
    }

    static func created(_ po: String, _ material: String, _ name: String = "", qty: String = "24", date: String = "")
        -> MaterialCreated
    {
        MaterialCreated(poNumber: po, qtyTotal: qty, dateReceived: date, materialNumber: material, materialName: name)
    }

    func items(_ given: [any Event]) async throws -> [Slice.Item] {
        let store = InMemoryEventStore()
        try await store.append(given)
        return Slice.items(try await Slice.model.run(on: store))
    }

    @Test func sortByDate() async throws {
        let result = try await items([
            Self.delivered("123", "D-1001", qty: "24", date: "2026-10-18"),
            Self.created("123", "m1", "Vodka 70cl", date: "2026-10-18"),
            Self.delivered("124", "D-1002", qty: "24", date: "2026-10-20"),
            Self.created("124", "m3", "Rum 70cl", date: "2026-10-20"),
            Self.delivered("125", "D-1003", qty: "24", date: "2026-10-19"),
            Self.created("125", "m4", "Whisky 70cl", date: "2026-10-19"),
        ])
        #expect(result.map(\.deliveryNumber) == ["D-1002", "D-1003", "D-1001"])
        #expect(result.map(\.poNumber) == ["124", "125", "123"])
    }

    @Test func fullyReceivedDeliveriesAreNotShown() async throws {
        let result = try await items([
            Self.delivered("123", "D-1001", qty: "24", date: "2026-10-19"),
            Self.created("123", "m1", "Vodka 70cl"),
            MaterialReceived(qtyReceived: "24", materialNumber: "m1", poNumber: "123"),
        ])
        #expect(result.isEmpty)
    }

    @Test func partiallyReceivedDeliveriesAreShown() async throws {
        let result = try await items([
            Self.delivered("123", "D-1001", qty: "48", date: "2026-10-19"),
            Self.created("123", "m1", "Vodka 70cl"),
            Self.created("123", "m2", "Gin 70cl"),
            MaterialReceived(qtyReceived: "24", materialNumber: "m1", poNumber: "123"),
        ])
        #expect(result == [Slice.Item(poNumber: "123", deliveryNumber: "D-1001", supplierName: Self.supplier,
                                      qtyTotal: "48", dateReceived: "2026-10-19")])
    }

    @Test func deliveriesWithMaterialsStillBeingCreatedAreNotShown() async throws {
        let result = try await items([
            Self.delivered("123", "D-1001", qty: "48", date: "2026-10-19", materials: "m1,m2"),
            Self.created("123", "m1"),
        ])
        #expect(result.isEmpty)
    }

    @Test func deliveryAppearsOnceAllItsMaterialsAreCreated() async throws {
        let result = try await items([
            Self.delivered("123", "D-1001", qty: "48", date: "2026-10-19", materials: "m1,m2"),
            Self.created("123", "m1"),
            Self.created("123", "m2"),
        ])
        #expect(result == [Slice.Item(poNumber: "123", deliveryNumber: "D-1001", supplierName: Self.supplier,
                                      qtyTotal: "48", dateReceived: "2026-10-19")])
    }
}

#if canImport(UIKit)
extension ViewDeliveriesTests {
    @Test @MainActor func emptyScreen() async throws {
        let system = try await AppSystem.inMemory()
        let live = LiveValue(system, Slice.model)
        await live.refresh()
        assertScreenSnapshots(of: Slice.Screen(system: system, live: live), system: system, named: "empty")
    }

    @Test @MainActor func screenWithDeliveries() async throws {
        let system = try await AppSystem.inMemory(given: [
            Self.delivered("123", "D-1001", qty: "24", date: "2026-10-18"),
            Self.created("123", "m1", "Vodka 70cl", date: "2026-10-18"),
            Self.delivered("124", "D-1002", qty: "24", date: "2026-10-20"),
            Self.created("124", "m3", "Rum 70cl", date: "2026-10-20"),
            Self.delivered("125", "D-1003", qty: "24", date: "2026-10-19"),
            Self.created("125", "m4", "Whisky 70cl", date: "2026-10-19"),
        ])
        let live = LiveValue(system, Slice.model)
        await live.refresh()
        assertScreenSnapshots(of: Slice.Screen(system: system, live: live), system: system, named: "three-deliveries")
    }
}
#endif
