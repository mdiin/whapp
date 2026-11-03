import Foundation
import Ledjer
import Testing

@testable import AppCore

@Suite struct ReceiveMaterialDataTests {
    typealias Slice = InboundGoodsReceipt.ReceiveMaterialData

    static let command = Slice.Command(
        poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m1", materialName: "Vodka 70cl")
    static let created = MaterialCreated(
        poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m1", materialName: "Vodka 70cl")
    static let ginCommand = Slice.Command(
        poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m2", materialName: "Gin 70cl")
    static let ginCreated = MaterialCreated(
        poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m2", materialName: "Gin 70cl")
    static let sap = DeliveryDataReceivedFromSAP(
        poNumber: "123", deliveryNumber: "D-1", supplierName: "Nordic Spirits A/S", qtyTotal: "24",
        dateReceived: "2026-10-19",
        materials: [.init(materialNumber: "m1", qty: 12, name: "Vodka 70cl"), .init(materialNumber: "m2", qty: 12, name: "Gin 70cl")])

    @Test func sapMaterialsAreToDo() async throws {
        try await gwt(
            given: [Self.sap], view: { try await Slice.todo.run(on: $0) },
            then: ["123|m1": Slice.Item(poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m1", materialName: "Vodka 70cl"),
                   "123|m2": Slice.Item(poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m2", materialName: "Gin 70cl")])
    }

    @Test func createdMaterialIsDone() async throws {
        try await gwt(
            given: [Self.sap, Self.created], view: { try await Slice.todo.run(on: $0) },
            then: ["123|m2": Slice.Item(poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m2", materialName: "Gin 70cl")])
    }

    // Specification: PO number and material number combination is unique
    @Test func poAndMaterialNumberCombinationIsUnique() async throws {
        let store = InMemoryEventStore()
        try await store.append([Self.created])
        await #expect(throws: CommandRejected("This material number already exists on this PO number")) {
            try await Slice.handle(Self.command, store: store)
        }
    }

    // Specification: A new material on a PO is created
    @Test func aNewMaterialOnAPOIsCreated() async throws {
        try await gwt(when: { try await Slice.handle(Self.ginCommand, store: $0) }, then: [Self.ginCreated])
    }

    @Test func automationCreatesMaterials() async throws {
        try await gt(
            automation: { try await Slice.start(on: $0, onError: { _ in }) },
            given: [Self.sap], then: [Self.created, Self.ginCreated])
    }
}
