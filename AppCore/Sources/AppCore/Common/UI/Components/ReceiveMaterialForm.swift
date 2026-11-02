#if canImport(SwiftUI)
import SwiftUI

/// How a material is tracked when it is received. Decides which fields the form asks for.
enum MaterialTracking: Sendable {
    /// Received quantity and a batch number.
    case batched
    /// Received quantity and a serial number.
    case serialized
    /// Received quantity, a batch number and an expiry date.
    case shelfLife

    var tag: ListTag {
        switch self {
        case .batched: ListTag("Batched", color: AppColor.materialTypeBatched)
        case .serialized: ListTag("Serialized", color: AppColor.materialTypeSerialized)
        case .shelfLife: ListTag("Shelf Life", color: AppColor.materialTypeShelfLife)
        }
    }

    /// The prompt of the field for the batch or serial number.
    var identifierPrompt: LocalizedStringKey {
        self == .serialized ? "Serial number" : "Batch"
    }

    var asksForExpiryDate: Bool { self == .shelfLife }
}

/// Figma: "Receive Material" (all six variants: Batched, Shelf life and Serialized, not filled and filled).
///
/// The goods-receipt form for one material: a tracking tag, the material (image, number, description) with
/// the expected quantity, the fields for the received quantity and the batch/serial number (with a scan
/// button; shelf-life materials also ask for an expiry date), and the Receive button, which is enabled
/// when every field the tracking type asks for is filled.
///
/// ```swift
/// ReceiveMaterialForm(
///     tracking: .batched,
///     materialNumber: "100-00482", description: "Hex nut M8 zinc plated DIN 934",
///     expectedQuantity: 500, unit: "PCS",
///     receivedQuantity: $quantity, identifier: $batch, expiryDate: $expiry,
///     onScan: { startScanning() }, onReceive: { send(ReceiveMaterial(...)) }
/// ) { Image("material-100-00482") }
/// ```
struct ReceiveMaterialForm<Thumbnail: View>: View {
    let tracking: MaterialTracking
    let materialNumber: String
    let description: String
    let expectedQuantity: Int
    let unit: String
    @Binding var receivedQuantity: String
    /// The batch number, or the serial number for serialized materials.
    @Binding var identifier: String
    /// Only used for shelf-life materials.
    @Binding var expiryDate: Date?
    let onScan: () -> Void
    let onReceive: () -> Void
    @ViewBuilder let thumbnail: () -> Thumbnail

    /// Every field the tracking type asks for is filled.
    var isComplete: Bool {
        !receivedQuantity.trimmingCharacters(in: .whitespaces).isEmpty
            && !identifier.trimmingCharacters(in: .whitespaces).isEmpty
            && (!tracking.asksForExpiryDate || expiryDate != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            summary
            fields
            AppButton("Receive", fillsWidth: true, action: onReceive)
                .disabled(!isComplete)
        }
        .padding()
    }

    private var summary: some View {
        VStack(alignment: .leading) {
            Label {
                Text(tracking.tag.title).foregroundStyle(AppColor.textSecondary)
            } icon: {
                Image(systemName: tracking.tag.systemImage).foregroundStyle(tracking.tag.color)
            }
            .font(AppFont.footnoteRegular)

            // Side by side where it fits (iPad); stacked on a narrow screen, so the material number never wraps.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    thumbnail().frame(width: 68, height: 68)
                    identity.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    expected
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        thumbnail().frame(width: 68, height: 68)
                        identity
                    }
                    expected.frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(materialNumber)
                .font(AppFont.largeTitleEmphasized)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(description)
                .font(AppFont.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var expected: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Expected:")
                .font(AppFont.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(expectedQuantity, format: .number)
                    .font(AppFont.largeTitleRegular)
                    .foregroundStyle(AppColor.textPrimary)
                Text(unit)
                    .font(AppFont.subheadlineRegular)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .fixedSize()
    }

    private var fields: some View {
        VStack(spacing: 24) {
            FieldGroup {
                FieldRow {
                    TextField("Received QTY", text: $receivedQuantity)
                        .keyboardType(.numberPad)
                }
            }
            FieldGroup {
                FieldRow {
                    TextField(tracking.identifierPrompt, text: $identifier)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button(action: onScan) {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                }
                if tracking.asksForExpiryDate {
                    Divider().overlay(AppColor.strokeSection)
                    FieldRow {
                        Text("Expiry Date")
                            .foregroundStyle(AppColor.textPrimary)
                        Spacer(minLength: 0)
                        if let date = expiryDate {
                            DatePicker(
                                "Expiry Date",
                                selection: Binding(get: { date }, set: { expiryDate = $0 }),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        } else {
                            Button("Select date") { expiryDate = .now }
                        }
                    }
                }
            }
        }
    }
}

/// The bordered box around one or more field rows.
private struct FieldGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        // The corner radius is the design's; there is no radius token yet.
        let shape = RoundedRectangle(cornerRadius: 26)
        VStack(spacing: 0, content: content)
            .background {
                shape.fill(AppColor.tertiary)
                shape.strokeBorder(AppColor.strokeSection)
            }
    }
}

/// One row of a `FieldGroup`: text at the leading edge, optional accessories at the trailing edge.
private struct FieldRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 16, content: content)
            .font(AppFont.bodyRegular)
            .padding(.horizontal)
            .padding(.vertical, 14)
    }
}

#Preview("Receive material") {
    @Previewable @State var quantity = ""
    @Previewable @State var batch = ""
    @Previewable @State var expiry: Date?
    ReceiveMaterialForm(
        tracking: .shelfLife, materialNumber: "300-00291", description: "Thread Locker medium 50 ml blue",
        expectedQuantity: 2000, unit: "PCS", receivedQuantity: $quantity, identifier: $batch,
        expiryDate: $expiry, onScan: {}, onReceive: {}
    ) {
        Rectangle().fill(AppColor.illustrationLightBlue)
    }
}
#endif
