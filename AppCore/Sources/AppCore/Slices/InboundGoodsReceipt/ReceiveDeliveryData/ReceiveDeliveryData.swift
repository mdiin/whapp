import Foundation
import Ledjer

extension InboundGoodsReceipt {
    enum ReceiveDeliveryData {
        static let name = "inbound-goods-receipt/receive-delivery-data"

        /// One delivery waiting to be received: exactly the fields of "Delivery Data TODO".
        struct Item: Codable, Sendable, Equatable {
            var poNumber: String
            var deliveryNumber: String
            var supplierName: String
            var qtyTotal: String
            var dateReceived: String
            var materialNumbers: String
        }

        // Keyed by poNumber. SAP data puts an item on the list, "Delivery received" takes it off.
        static let todo = ReadModel(initial: [String: Item](), bindings: [
            .on(DeliveryDataReceivedFromSAP.self) { items, event in
                items[event.poNumber] = Item(
                    poNumber: event.poNumber, deliveryNumber: event.deliveryNumber,
                    supplierName: event.supplierName, qtyTotal: event.qtyTotal,
                    dateReceived: event.dateReceived,
                    materialNumbers: event.materials.map(\.materialNumber).joined(separator: ","))
            },
            .on(DeliveryReceived.self) { items, event in items[event.poNumber] = nil },
        ])

        struct Command: Codable, Sendable, Equatable {
            var poNumber: String
            var deliveryNumber: String
            var supplierName: String
            var qtyTotal: String
            var dateReceived: String
            var materialNumbers: String
        }

        /// Which purchase orders were received already. (String ids can't be tags: read unfiltered.)
        static let received = ReadModel(initial: Set<String>(), bindings: [
            .on(DeliveryReceived.self) { set, event in set.insert(event.poNumber) },
        ])

        static func handle(_ command: Command, store: any EventStore) async throws {
            let decision = try await received.decide(on: store)
            guard !decision.state.contains(command.poNumber) else {
                throw CommandRejected("A delivery has already been received for this PO number")
            }
            try await store.append(
                [DeliveryReceived(poNumber: command.poNumber, deliveryNumber: command.deliveryNumber,
                                  supplierName: command.supplierName, qtyTotal: command.qtyTotal,
                                  dateReceived: command.dateReceived, materialNumbers: command.materialNumbers)],
                condition: decision.condition)
        }

        static func start(
            on store: any EventStore,
            onError: @escaping @Sendable (any Error) -> Void
        ) async throws -> Automation {
            try await automation(
                on: store,
                triggers: [.onStart, .event(DeliveryDataReceivedFromSAP.self)],
                onError: onError
            ) { store in
                for item in try await todo.run(on: store).values.sorted(by: { $0.poNumber < $1.poNumber }) {
                    try Task.checkCancellation()
                    do {
                        try await handle(
                            Command(poNumber: item.poNumber, deliveryNumber: item.deliveryNumber,
                                    supplierName: item.supplierName, qtyTotal: item.qtyTotal,
                                    dateReceived: item.dateReceived, materialNumbers: item.materialNumbers),
                            store: store)
                    } catch is CancellationError {
                        return
                    } catch {
                        onError(error)
                    }
                }
            }
        }

        /// Mock of the external SAP event (board comment: "mock some data"). Appends it once per PO number.
        static let mockData: [DeliveryDataReceivedFromSAP] = [
            DeliveryDataReceivedFromSAP(
                poNumber: "4500001001", deliveryNumber: "D-1001", supplierName: "Nordic Spirits A/S",
                qtyTotal: "24", dateReceived: "2026-10-18",
                materials: [.init(materialNumber: "m1", qty: 12, name: "Vodka 70cl"),
                            .init(materialNumber: "m2", qty: 12, name: "Gin 70cl")]),
            DeliveryDataReceivedFromSAP(
                poNumber: "4500001002", deliveryNumber: "D-1002", supplierName: "Nordic Spirits A/S",
                qtyTotal: "24", dateReceived: "2026-10-20",
                materials: [.init(materialNumber: "m3", qty: 24, name: "Rum 70cl")]),
        ]

        static func seedMockData(on store: any EventStore) async throws {
            let existing = try await store.source(try EventQuery.of(DeliveryDataReceivedFromSAP.self))
                .compactMap { try? $0.decode(DeliveryDataReceivedFromSAP.self).poNumber }
            let missing = mockData.filter { !existing.contains($0.poNumber) }
            if !missing.isEmpty { try await store.append(missing) }
        }

        static func register(in registry: inout Registry) {
            registry.automation(name) { system in
                try await seedMockData(on: system.store)
                return try await start(on: system.store, onError: system.reportError)
            }
        }
    }
}
