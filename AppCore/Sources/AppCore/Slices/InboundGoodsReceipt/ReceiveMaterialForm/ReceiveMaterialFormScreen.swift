#if canImport(SwiftUI)
import Foundation
import Ledjer
import SwiftUI

extension InboundGoodsReceipt.ReceiveMaterialForm {
    struct Screen: View {
        let system: AppSystem
        let poNumber: String
        @State private var live: LiveValue<[String: Item]>
        @State private var materialNumber = ""
        @State private var qtyReceived = ""
        @State private var errors: CommandErrors?

        init(system: AppSystem, poNumber: String) {
            self.init(system: system, poNumber: poNumber, live: LiveValue(system, model))
        }

        /// Also for snapshot tests, with a value loaded beforehand.
        init(system: AppSystem, poNumber: String, live: LiveValue<[String: Item]>,
             materialNumber: String = "", qtyReceived: String = "") {
            self.system = system
            self.poNumber = poNumber
            _live = State(initialValue: live)
            _materialNumber = State(initialValue: materialNumber)
            _qtyReceived = State(initialValue: qtyReceived)
        }

        var body: some View {
            content
                .navigationTitle("Receive material")
                .task { await live.run() }
        }

        @ViewBuilder private var content: some View {
            if let items = live.value {
                let found = lookup(items, poNumber: poNumber, materialNumber: materialNumber)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ListHeader("PO \(poNumber)")
                        AppGroupedTable {
                            AppTextField("Material number", text: $materialNumber)
                                .padding()
                            AppTableRow("Total QTY") {
                                AppTableDetail(LocalizedStringKey(found?.qtyTotal ?? "–"), drillIn: false)
                            }
                            AppTextField("Received QTY", text: $qtyReceived)
                                .padding()
                        }
                        ErrorMessages(errors?["materialNumber"] ?? [])
                        ErrorMessages(errors?["qtyReceived"] ?? [])
                        ErrorMessages(errors?.general ?? [])
                        AppButton("Receive", fillsWidth: true) { Task { await receive() } }
                            .disabled(!system.commands.isRegistered(receiveCommand) || found == nil || qtyReceived.isEmpty)
                    }
                    .padding(.horizontal)
                }
            } else if let failure = live.failure {
                ContentUnavailableView("Could not load", systemImage: "exclamationmark.triangle",
                                       description: Text(String(describing: failure)))
            } else {
                ProgressView()
            }
        }

        private func receive() async {
            do {
                try await system.send(receiveCommand, [
                    "poNumber": .string(poNumber),
                    "materialNumber": .string(materialNumber),
                    "qtyReceived": .string(qtyReceived),
                ])
                errors = nil
                materialNumber = ""
                qtyReceived = ""
            } catch {
                errors = CommandErrors(error)
            }
        }
    }
}

#Preview {
    PreviewHost(given: [
        MaterialCreated(poNumber: "123", qtyTotal: "24", dateReceived: "2026-10-19", materialNumber: "m1",
                        materialName: "Vodka 70cl"),
    ]) { system in
        InboundGoodsReceipt.ReceiveMaterialForm.Screen(system: system, poNumber: "123")
    }
}
#endif
