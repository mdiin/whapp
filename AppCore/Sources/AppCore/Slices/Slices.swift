/// Every slice registers itself here: one line per slice, calling the `register(in:)` of its own file.
///
/// ```swift
/// UnderstandingEventsourcing.AddItem.register(in: &registry)
/// ```
///
/// This is the one shared file a slice adds a line to (besides `Events/AllEvents.swift` for its events).
public enum Slices {
    public static func register(in registry: inout Registry) {
        InboundGoodsReceipt.ReceiveDeliveryData.register(in: &registry)
        InboundGoodsReceipt.ReceiveMaterialData.register(in: &registry)
        InboundGoodsReceipt.ViewDeliveries.register(in: &registry)
        InboundGoodsReceipt.ViewDelivery.register(in: &registry)
        InboundGoodsReceipt.ReceiveMaterialForm.register(in: &registry)
    }
}
