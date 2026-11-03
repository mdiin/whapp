#if canImport(SwiftUI)
import Foundation
import Ledjer
import SwiftUI

extension InboundGoodsReceipt.ViewDeliveries {
    struct Screen: View {
        let system: AppSystem
        @State private var live: LiveValue<[String: Entry]>

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
                .navigationTitle("Deliveries")
                .task { await live.run() }
        }

        @ViewBuilder private var content: some View {
            if let entries = live.value {
                let deliveries = items(entries)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ListHeader("Incoming", badge: deliveries.count)
                            .padding(.horizontal)
                        // The table never clips a value: on a narrow screen (iPhone) the supplier column
                        // is dropped so PO, delivery number, quantity and date stay readable.
                        ViewThatFits(in: .horizontal) {
                            ListTable(deliveries, columns: [
                                .init("PO") { $0.poNumber },
                                .init("Del. No.") { $0.deliveryNumber },
                                .init("Supplier") { $0.supplierName },
                                .init("QTY", kind: .number) { $0.qtyTotal },
                                .init("Received") { $0.dateReceived },
                            ])
                            ListTable(deliveries, columns: [
                                .init("PO") { $0.poNumber },
                                .init("Del. No.") { $0.deliveryNumber },
                                .init("QTY", kind: .number) { $0.qtyTotal },
                                .init("Received") { $0.dateReceived },
                            ])
                        }
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
