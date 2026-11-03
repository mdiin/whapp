import Foundation
import Ledjer

extension InboundGoodsReceipt {
    enum ReceiveMaterialForm {
        static let name = "inbound-goods-receipt/receive-material-form"
        static let receiveCommand = "inbound-goods-receipt/receive-material"

        /// The route parameter: which delivery the material is received on.
        struct Parameters: Codable, Sendable, Equatable {
            var poNumber: String
        }

        /// One entry of the "Material lookup" read model.
        struct Item: Codable, Sendable, Equatable {
            var poNumber: String
            var materialNumber: String
            var qtyTotal: String
        }

        // Assumptions: keyed "po|material"; Delivery received has no effect on the fields (only
        // Material Created carries the material), so its binding does nothing. The command's payload
        // (poNumber, materialNumber, qtyReceived) is taken from the Material Received event; no
        // navigation.json exists for the command, so the screen stays after sending.
        static let model = ReadModel(initial: [String: Item](), bindings: [
            .on(DeliveryReceived.self) { _, _ in },
            .on(MaterialCreated.self) { items, event in
                items["\(event.poNumber)|\(event.materialNumber)"] =
                    Item(poNumber: event.poNumber, materialNumber: event.materialNumber, qtyTotal: event.qtyTotal)
            },
        ])

        static func lookup(_ items: [String: Item], poNumber: String, materialNumber: String) -> Item? {
            items["\(poNumber)|\(materialNumber)"]
        }

        static func register(in registry: inout Registry) {
            registry.route(name, title: "Receive material", parameters: ["poNumber"]) { route, system in
                Screen(system: system, poNumber: try route.decode(Parameters.self).poNumber)
            }
            registry.uses(command: receiveCommand, from: name)
        }
    }
}
