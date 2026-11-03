import Foundation
import Ledjer

extension InboundGoodsReceipt {
    enum ViewDelivery {
        static let name = "inbound-goods-receipt/view-delivery"

        /// The route parameter: which delivery to show.
        struct Parameters: Codable, Sendable, Equatable {
            var poNumber: String
        }

        /// One row of the "Delivery materials" read model.
        struct Item: Codable, Sendable, Equatable, Identifiable {
            var poNumber: String
            var materialNumber: String
            var materialName: String
            var qtyTotal: String
            var supplierName: String
            var isReceived: Bool
            var id: String { materialNumber }
        }

        struct Materials: Codable, Sendable, Equatable {
            var suppliers: [String: String] = [:]          // poNumber -> supplierName
            var materials: [String: [MaterialCreated]] = [:] // poNumber -> created materials, in order
            var received: Set<String> = []                 // "po|material"
        }

        // Assumptions: the read model is queried per purchase order (route parameter `poNumber`);
        // a material is received once any Material Received exists for it; the supplier comes from
        // Delivery received; qtyTotal is the material's own (from Material Created).
        static let model = ReadModel(initial: Materials(), bindings: [
            .on(DeliveryReceived.self) { state, event in
                state.suppliers[event.poNumber] = event.supplierName
            },
            .on(MaterialCreated.self) { state, event in
                var list = state.materials[event.poNumber, default: []]
                if !list.contains(where: { $0.materialNumber == event.materialNumber }) { list.append(event) }
                state.materials[event.poNumber] = list
            },
            .on(MaterialReceived.self) { state, event in
                state.received.insert("\(event.poNumber)|\(event.materialNumber)")
            },
        ])

        static func items(_ state: Materials, poNumber: String) -> [Item] {
            (state.materials[poNumber] ?? []).map {
                Item(poNumber: poNumber, materialNumber: $0.materialNumber, materialName: $0.materialName,
                     qtyTotal: $0.qtyTotal, supplierName: state.suppliers[poNumber] ?? "",
                     isReceived: state.received.contains("\(poNumber)|\($0.materialNumber)"))
            }
        }

        static func register(in registry: inout Registry) {
            registry.route(name, title: "Delivery", parameters: ["poNumber"]) { route, system in
                Screen(system: system, poNumber: try route.decode(Parameters.self).poNumber)
            }
        }
    }
}
