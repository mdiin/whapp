#if canImport(SwiftUI)
import Foundation
import Ledjer
import SwiftUI

extension InboundGoodsReceipt.ViewDelivery {
    struct Screen: View {
        let system: AppSystem
        let poNumber: String
        @State private var live: LiveValue<Materials>

        init(system: AppSystem, poNumber: String) {
            self.init(system: system, poNumber: poNumber, live: LiveValue(system, model))
        }

        /// Also for snapshot tests, with a value loaded beforehand.
        init(system: AppSystem, poNumber: String, live: LiveValue<Materials>) {
            self.system = system
            self.poNumber = poNumber
            _live = State(initialValue: live)
        }

        var body: some View {
            content
                .navigationTitle("PO \(poNumber)")
                .task { await live.run() }
        }

        @ViewBuilder private var content: some View {
            if let state = live.value {
                let materials = items(state, poNumber: poNumber)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ListHeader("Materials", badge: materials.count)
                            .padding(.horizontal)
                        ListTable(materials, columns: [
                            .init("Material") { $0.materialNumber },
                            .init("Name") { $0.materialName },
                            .init("QTY", kind: .number) { $0.qtyTotal },
                            .init("Status") { $0.isReceived ? "Received" : "Open" },
                        ])
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
#endif
