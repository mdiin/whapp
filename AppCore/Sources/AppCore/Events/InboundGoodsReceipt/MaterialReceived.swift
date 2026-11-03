import Foundation
import Ledjer

struct MaterialReceived: Event, Equatable {
    static let eventType: EventType = "inbound-goods-receipt/material-received"

    var qtyReceived: String
    var materialNumber: String
    var poNumber: String
}
