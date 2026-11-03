import Foundation
import Ledjer

/// External event: the data SAP holds about a purchase order. For now it is mocked
/// (see `ReceiveDeliveryData.seedMockData`), as the board comment asks.
struct DeliveryDataReceivedFromSAP: Event, Equatable {
    static let eventType: EventType = "inbound-goods-receipt/delivery-data-received-from-sap"

    var poNumber: String
    var deliveryNumber: String
    var supplierName: String
    var qtyTotal: String
    var dateReceived: String
    var materials: [Material]

    struct Material: Codable, Sendable, Equatable {
        var materialNumber: String
        var qty: Double  // slice.json type "Number": closest match is Double (assumption)
        var name: String
    }
}
