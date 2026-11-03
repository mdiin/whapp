import Foundation
import Ledjer
import Testing

@testable import AppCore

@Suite struct ReceiveMaterialTests {
    typealias Slice = InboundGoodsReceipt.ReceiveMaterial

    func created(po: String, material: String, qty: String) -> MaterialCreated {
        MaterialCreated(poNumber: po, qtyTotal: qty, dateReceived: "2026-10-19", materialNumber: material,
                        materialName: "Vodka 70cl")
    }
    var delivery: DeliveryReceived {
        DeliveryReceived(poNumber: "po123", deliveryNumber: "dn123", supplierName: "Nordic Spirits A/S",
                         qtyTotal: "42", dateReceived: "2026-10-19")
    }

    @Test func receivedMaterialCanNotBeEdited() async throws {
        try await gwt(
            given: [created(po: "123", material: "m1", qty: "24"),
                    MaterialReceived(qtyReceived: "24", materialNumber: "m1", poNumber: "123")],
            when: { try await Slice.handle(.init(qtyReceived: "30", materialNumber: "m1", poNumber: "123"), store: $0) },
            thenThrows: { ($0 as? CommandRejected)?.message == "Material has already been received and can no longer be edited" })
    }

    @Test func quantityReceivedCanBeGreaterThanExpected() async throws {
        try await gwt(
            given: [delivery, created(po: "po123", material: "mn123", qty: "42")],
            when: { try await Slice.handle(.init(qtyReceived: "45", materialNumber: "mn123", poNumber: "po123"), store: $0) },
            then: [MaterialReceived(qtyReceived: "45", materialNumber: "mn123", poNumber: "po123")])
    }

    @Test func quantityReceivedCanBeLessThanExpected() async throws {
        try await gwt(
            given: [delivery, created(po: "po123", material: "mn123", qty: "42")],
            when: { try await Slice.handle(.init(qtyReceived: "21", materialNumber: "mn123", poNumber: "po123"), store: $0) },
            then: [MaterialReceived(qtyReceived: "21", materialNumber: "mn123", poNumber: "po123")])
    }

    @Test func neverCreatedMaterialCannotBeReceived() async throws {
        try await gwt(
            given: [created(po: "123", material: "m1", qty: "24")],
            when: { try await Slice.handle(.init(qtyReceived: "24", materialNumber: "m9", poNumber: "123"), store: $0) },
            thenThrows: { ($0 as? CommandRejected)?.message == "This material does not exist on this PO number" })
    }
}
