import Ledjer

/// Every event type of the app. Add each new event here.
///
/// ledjer-swift has no registry of event types: two Swift types declaring the same `eventType` are only
/// caught where they meet in one query, view or automation. `AllEventsTests` checks this list, so a
/// duplicate is caught by the test suite instead.
public enum AllEvents {
    public static let types: [any Event.Type] = [
        DeliveryDataReceivedFromSAP.self,
        DeliveryReceived.self,
        MaterialCreated.self,
        MaterialReceived.self,
    ]
}
