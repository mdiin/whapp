#if canImport(SwiftUI)
import SwiftUI

/// One column of a `ListTable` (Figma: "Lists / Column"). `.text` columns align leading, `.number`
/// columns trailing, for the header and the cells alike (Apple's `TableColumnAlignment`).
struct ListTableColumn<Row> {
    enum Kind { case text, number }

    let title: LocalizedStringKey
    let kind: Kind
    let value: (Row) -> String

    init(_ title: LocalizedStringKey, kind: Kind = .text, value: @escaping (Row) -> String) {
        self.title = title
        self.kind = kind
        self.value = value
    }

    fileprivate var alignment: HorizontalAlignment { kind == .number ? .trailing : .leading }
    fileprivate var textAlignment: TextAlignment { kind == .number ? .trailing : .leading }
    fileprivate var frameAlignment: Alignment { kind == .number ? .trailing : .leading }
}

/// Figma: "Lists / Table format". A custom operational list: several aligned columns, a header row and
/// one row per record, with a line on top of every row but the first.
///
/// ```swift
/// ListTable(deliveries, columns: [
///     .init("PO") { $0.purchaseOrder },
///     .init("Del. No.") { $0.deliveryNumber },
///     .init("Vendor") { $0.vendor },
///     .init("QTY", kind: .number) { $0.quantity.formatted() },
/// ])
/// ```
///
/// Rows are `Identifiable`. Each column is at least as wide as its widest value, so a value is never split or clipped; spare width is shared out.
struct ListTable<Row: Identifiable>: View {
    private let rows: [Row]
    private let columns: [ListTableColumn<Row>]

    init(_ rows: [Row], columns: [ListTableColumn<Row>]) {
        self.rows = rows
        self.columns = columns
    }

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(columns.indices, id: \.self) { index in
                    let column = columns[index]
                    Text(column.title)
                        .font(AppFont.footnoteRegular)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(column.textAlignment)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: column.frameAlignment)
                        .padding(.horizontal, 8)
                        .padding(.vertical)
                        .gridColumnAlignment(column.alignment)
                }
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
                if offset > 0 {
                    Divider().overlay(AppColor.strokeSection)
                        .gridCellUnsizedAxes(.horizontal)
                }
                GridRow {
                    ForEach(columns.indices, id: \.self) { index in
                        let column = columns[index]
                        Text(column.value(row))
                            .font(AppFont.bodyRegular)
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(column.textAlignment)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(maxWidth: .infinity, alignment: column.frameAlignment)
                            .padding(.horizontal, 8)
                            .padding(.vertical)
                    }
                }
            }
        }
        .padding(.horizontal)
        .background(AppColor.tertiary)
    }
}

#Preview("List table") {
    struct Delivery: Identifiable {
        let id: Int
        let po: String, number: String, vendor: String, qty: Int
    }
    let rows = (1...6).map {
        Delivery(id: $0, po: "45000000\($0)", number: "80000\($0)", vendor: "Vendor \($0)", qty: $0 * 12)
    }
    return ListTable(rows, columns: [
        .init("PO") { $0.po },
        .init("Del. No.") { $0.number },
        .init("Vendor") { $0.vendor },
        .init("QTY", kind: .number) { $0.qty.formatted() },
    ])
    .padding()
}
#endif
