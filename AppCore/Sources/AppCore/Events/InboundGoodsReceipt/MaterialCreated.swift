import Foundation
import Ledjer

/// Assumption: fields are the union of those in slice specifications.
struct MaterialCreated: Event, Equatable {
    static let eventType: EventType = "inbound-goods-receipt/material-created"

    var poNumber: String
    var qtyTotal: String
    var dateReceived: String
    var materialNumber: String
    var materialName: String
}
