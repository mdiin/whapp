#if canImport(SwiftUI)
import Foundation
import Ledjer
import SwiftUI

extension InboundGoodsReceipt.ViewDeliveries {
    struct Screen: View {
        let system: AppSystem
        @Environment(Navigator.self) private var navigator: Navigator?
        @State private var live: LiveValue<[String: Entry]>
        @State private var query = ""

        init(system: AppSystem) {
            self.init(system: system, live: LiveValue(system, model))
        }

        /// Also for snapshot tests, with a value loaded beforehand.
        init(system: AppSystem, live: LiveValue<[String: Entry]>) {
            self.system = system
            _live = State(initialValue: live)
        }

        var body: some View {
            content
                .task { await live.run() }
        }

        @ViewBuilder private var content: some View {
            if let entries = live.value {
                let all = items(entries)
                let deliveries = query.isEmpty ? all : all.filter {
                    [$0.poNumber, $0.deliveryNumber, $0.supplierName].contains { $0.localizedCaseInsensitiveContains(query) }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        AppToolbar(.overview, title: "Deliveries", search: $query)
                        ListHeader("Incoming", badge: deliveries.count)
                            .padding(.horizontal)
                        // Rows are tappable and open the delivery (ListTable has no row action).
                        TaggedList(deliveries.map { item in
                            TaggedListItem(id: item.poNumber, title: "PO \(item.poNumber) · \(item.deliveryNumber)",
                                           subtitle: "\(item.supplierName) · \(item.dateReceived)",
                                           detail: item.qtyTotal)
                        }, onSelect: { item in
                            navigator?.navigate(to: Route("inbound-goods-receipt/view-delivery",
                                                          ["poNumber": .string(item.id)]))
                        }, leading: { _ in
                            Image(systemName: "shippingbox").font(.title2).foregroundStyle(AppColor.textSecondary)
                        })
                    }
                }
            } else if let failure = live.failure {
                ContentUnavailableView("Could not load", systemImage: "exclamationmark.triangle",
                                       description: Text(String(describing: failure)))
            } else {
                ProgressView()
            }
        }
    }
}

#Preview {
    PreviewHost(given: [
        DeliveryReceived(poNumber: "123", deliveryNumber: "D-1001", supplierName: "Nordic Spirits A/S",
                         qtyTotal: "24", dateReceived: "2026-10-18"),
        MaterialCreated(poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-18",
                        materialNumber: "m1", materialName: "Vodka 70cl"),
    ]) { system in
        InboundGoodsReceipt.ViewDeliveries.Screen(system: system)
    }
}
#endif
