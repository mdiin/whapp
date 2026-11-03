import Foundation
import Ledjer

extension InboundGoodsReceipt {
    enum ViewDeliveries {
        static let name = "inbound-goods-receipt/view-deliveries"

        /// One row of the list.
        struct Item: Codable, Sendable, Equatable, Identifiable {
            var poNumber: String
            var deliveryNumber: String
            var supplierName: String
            var qtyTotal: String
            var dateReceived: String
            var id: String { poNumber }
        }

        /// Per purchase order, what the events say so far.
        struct Entry: Codable, Sendable, Equatable {
            var delivery: DeliveryReceived?
            var createdMaterials: [String] = []
            var qtyReceived = 0
        }

        // Assumptions (board comments leave this open):
        // - a delivery is listed once all its `materialNumbers` have a Material Created (without
        //   `materialNumbers`, once at least one material was created);
        // - it is dropped once the received quantity reaches `qtyTotal`;
        // - the list is sorted by `dateReceived`, newest first.
        static let model = ReadModel(initial: [String: Entry](), bindings: [
            .on(DeliveryReceived.self) { entries, event in
                entries[event.poNumber, default: Entry()].delivery = event
            },
            .on(MaterialCreated.self) { entries, event in
                var entry = entries[event.poNumber, default: Entry()]
                if !entry.createdMaterials.contains(event.materialNumber) {
                    entry.createdMaterials.append(event.materialNumber)
                }
                entries[event.poNumber] = entry
            },
            .on(MaterialReceived.self) { entries, event in
                entries[event.poNumber, default: Entry()].qtyReceived += Int(event.qtyReceived) ?? 0
            },
        ])

        /// The deliveries to show, newest first.
        static func items(_ entries: [String: Entry]) -> [Item] {
            entries.values.compactMap { entry -> Item? in
                guard let delivery = entry.delivery else { return nil }
                let expected = (delivery.materialNumbers ?? "")
                    .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let created = Set(entry.createdMaterials)
                let materialsCreated = expected.isEmpty ? !created.isEmpty : expected.allSatisfy(created.contains)
                guard materialsCreated else { return nil }
                if let total = Int(delivery.qtyTotal), entry.qtyReceived >= total { return nil }
                return Item(poNumber: delivery.poNumber, deliveryNumber: delivery.deliveryNumber,
                            supplierName: delivery.supplierName, qtyTotal: delivery.qtyTotal,
                            dateReceived: delivery.dateReceived)
            }
            .sorted { ($0.dateReceived, $1.poNumber) > ($1.dateReceived, $0.poNumber) }
        }

        static func register(in registry: inout Registry) {
            registry.uses(route: "inbound-goods-receipt/view-delivery", from: name)
            registry.route(name, title: "Deliveries") { _, system in
                Screen(system: system)
            }
        }
    }
}
