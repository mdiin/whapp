import Foundation
import Ledjer
import Testing

@testable import AppCore

@Suite struct ReceiveDeliveryDataTests {
    typealias Slice = InboundGoodsReceipt.ReceiveDeliveryData

    static let command = Slice.Command(
        poNumber: "123", deliveryNumber: "D-1", supplierName: "Nordic Spirits A/S", qtyTotal: "24",
        dateReceived: "2026-10-18", materialNumbers: "m1,m2")
    static let sap = DeliveryDataReceivedFromSAP(
        poNumber: "123", deliveryNumber: "D-1", supplierName: "Nordic Spirits A/S", qtyTotal: "24",
        dateReceived: "2026-10-18",
        materials: [.init(materialNumber: "m1", qty: 12, name: "Vodka"), .init(materialNumber: "m2", qty: 12, name: "Gin")])
    static let received = DeliveryReceived(
        poNumber: "123", deliveryNumber: "D-1", supplierName: "Nordic Spirits A/S", qtyTotal: "24",
        dateReceived: "2026-10-18", materialNumbers: "m1,m2")

    @Test func sapDataIsToDo() async throws {
        try await gwt(
            given: [Self.sap], view: { try await Slice.todo.run(on: $0) },
            then: ["123": Slice.Item(poNumber: "123", deliveryNumber: "D-1", supplierName: "Nordic Spirits A/S",
                                     qtyTotal: "24", dateReceived: "2026-10-18", materialNumbers: "m1,m2")])
    }

    @Test func receivedDeliveryIsDone() async throws {
        try await gwt(given: [Self.sap, Self.received], view: { try await Slice.todo.run(on: $0) }, then: [:])
    }

    // Specification: A delivery from SAP is received
    @Test func aDeliveryFromSAPIsReceived() async throws {
        try await gwt(when: { try await Slice.handle(Self.command, store: $0) }, then: [Self.received])
    }

    // Specification: PO number is unique
    @Test func poNumberIsUnique() async throws {
        let store = InMemoryEventStore()
        try await store.append([Self.received])
        await #expect(throws: CommandRejected("A delivery has already been received for this PO number")) {
            try await Slice.handle(Self.command, store: store)
        }
    }

    @Test func automationReceivesSAPDeliveries() async throws {
        try await gt(
            automation: { try await Slice.start(on: $0, onError: { _ in }) },
            given: [Self.sap], then: [Self.received])
    }
}
