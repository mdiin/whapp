import Foundation
import Ledjer

extension InboundGoodsReceipt {
    enum ReceiveMaterial {
        static let name = "inbound-goods-receipt/receive-material"

        struct Command: Codable, Sendable, Equatable {
            var qtyReceived: String
            var materialNumber: String
            var poNumber: String
        }

        struct Materials: Sendable {
            var created: Set<String> = []
            var received: Set<String> = []
        }

        static func key(_ po: String, _ material: String) -> String { "\(po)|\(material)" }

        /// String ids can't be tags: read unfiltered.
        static let materials = ReadModel(initial: Materials(), bindings: [
            .on(MaterialCreated.self) { m, e in m.created.insert(key(e.poNumber, e.materialNumber)) },
            .on(MaterialReceived.self) { m, e in m.received.insert(key(e.poNumber, e.materialNumber)) },
        ])

        static func handle(_ command: Command, store: any EventStore) async throws {
            let decision = try await materials.decide(on: store)
            let k = key(command.poNumber, command.materialNumber)
            // Assumption: a material is never "received" before its creation, so check existence first.
            guard decision.state.created.contains(k) else {
                throw CommandRejected("This material does not exist on this PO number")
            }
            guard !decision.state.received.contains(k) else {
                throw CommandRejected("Material has already been received and can no longer be edited")
            }
            try await store.append(
                [MaterialReceived(qtyReceived: command.qtyReceived, materialNumber: command.materialNumber,
                                  poNumber: command.poNumber)],
                condition: decision.condition)
        }

        static func register(in registry: inout Registry) {
            registry.command(name, Command.self) { command, system in
                try await handle(command, store: system.store)
            }
        }
    }
}
