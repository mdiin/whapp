import Foundation
import Ledjer

/// Assumption: the board defines this event only through slice specifications; fields are their union.
/// `materialNumbers` (comma-separated, e.g. "m1,m2") is optional: not every specification gives it.
struct DeliveryReceived: Event, Equatable {
    static let eventType: EventType = "inbound-goods-receipt/delivery-received"

    var poNumber: String
    var deliveryNumber: String
    var supplierName: String
    var qtyTotal: String
    var dateReceived: String
    var materialNumbers: String?
}
