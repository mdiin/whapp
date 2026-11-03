import Foundation
import Ledjer

extension InboundGoodsReceipt {
    enum ReceiveMaterialData {
        static let name = "inbound-goods-receipt/receive-material-data"

        /// One material waiting to be created: exactly the fields of "Materials TODO".
        struct Item: Codable, Sendable, Equatable {
            var poNumber: String
            var qtyTotal: String
            var dateReceived: String
            var materialNumber: String
            var materialName: String
        }

        // Keyed by "poNumber|materialNumber". Assumption: the SAP event puts one item per material on the list;
        // "Material Created" takes it off.
        static func key(_ poNumber: String, _ materialNumber: String) -> String { "\(poNumber)|\(materialNumber)" }

        static let todo = ReadModel(initial: [String: Item](), bindings: [
            .on(DeliveryDataReceivedFromSAP.self) { items, event in
                for material in event.materials {
                    items[key(event.poNumber, material.materialNumber)] = Item(
                        poNumber: event.poNumber, qtyTotal: event.qtyTotal, dateReceived: event.dateReceived,
                        materialNumber: material.materialNumber, materialName: material.name)
                }
            },
            .on(MaterialCreated.self) { items, event in
                items[key(event.poNumber, event.materialNumber)] = nil
            },
        ])

        struct Command: Codable, Sendable, Equatable {
            var poNumber: String
            var qtyTotal: String
            var dateReceived: String
            var materialNumber: String
            var materialName: String
        }

        /// Which PO number / material number combinations exist already. (String ids can't be tags: read unfiltered.)
        static let created = ReadModel(initial: Set<String>(), bindings: [
            .on(MaterialCreated.self) { set, event in set.insert(key(event.poNumber, event.materialNumber)) },
        ])

        static func handle(_ command: Command, store: any EventStore) async throws {
            let decision = try await created.decide(on: store)
            guard !decision.state.contains(key(command.poNumber, command.materialNumber)) else {
                throw CommandRejected("This material number already exists on this PO number")
            }
            try await store.append(
                [MaterialCreated(poNumber: command.poNumber, qtyTotal: command.qtyTotal,
                                 dateReceived: command.dateReceived, materialNumber: command.materialNumber,
                                 materialName: command.materialName)],
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
                for item in try await todo.run(on: store).values.sorted(by: { key($0.poNumber, $0.materialNumber) < key($1.poNumber, $1.materialNumber) }) {
                    try Task.checkCancellation()
                    do {
                        try await handle(
                            Command(poNumber: item.poNumber, qtyTotal: item.qtyTotal, dateReceived: item.dateReceived,
                                    materialNumber: item.materialNumber, materialName: item.materialName),
                            store: store)
                    } catch is CancellationError {
                        return
                    } catch {
                        onError(error)
                    }
                }
            }
        }

        static func register(in registry: inout Registry) {
            registry.automation(name) { system in
                try await start(on: system.store, onError: system.reportError)
            }
        }
    }
}
