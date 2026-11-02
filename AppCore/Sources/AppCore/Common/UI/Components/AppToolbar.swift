#if canImport(SwiftUI)
import SwiftUI

/// Which toolbar preset a screen uses (Figma "Toolbar / Top / iPad", `Type`).
enum AppToolbarKind {
    /// Heading and search, for a top-level list screen.
    case overview
    /// Like `overview`, with the large title and the search field on one line.
    case overviewInline
    /// Back and header/subheader, without scanner or search.
    case detail
    /// Back, header/subheader, scanner and search.
    case detailSearch
}

/// The tab bar of a toolbar (Figma `Tabs=On`): a sidebar button and the tabs. Use it when the sidebar is
/// collapsed; with an expanded sidebar leave `tabs` nil (`Tabs=Off`).
struct AppToolbarTabs {
    var titles: [String]
    @Binding var selection: Int
    var onToggleSidebar: () -> Void
}

/// Figma: "Toolbar / Top / iPad" (all seven variants). The view's heading, navigation, scan and search.
///
/// ```swift
/// AppToolbar(.overview, title: "Goods Receipt", search: $query)
/// AppToolbar(.detailSearch, title: "Delivery 80001", subtitle: "Vendor 1", search: $query,
///            onBack: { dismiss() }, onScan: { scan() })
/// AppToolbar(.detail, title: "Material", subtitle: "100-00482", onBack: { dismiss() },
///            tabs: AppToolbarTabs(titles: ["Goods Receipt", "Pick & Pack"], selection: $tab,
///                                 onToggleSidebar: { showSidebar() }))
/// ```
///
/// Choose the preset for the screen's type, and `tabs` for a collapsed sidebar. It fills its container's width.
struct AppToolbar: View {
    private let kind: AppToolbarKind
    private let title: String
    private let subtitle: String?
    private let search: Binding<String>
    private let tabs: AppToolbarTabs?
    private let onBack: () -> Void
    private let onScan: () -> Void

    init(
        _ kind: AppToolbarKind,
        title: String,
        subtitle: String? = nil,
        search: Binding<String> = .constant(""),
        tabs: AppToolbarTabs? = nil,
        onBack: @escaping () -> Void = {},
        onScan: @escaping () -> Void = {}
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.search = search
        self.tabs = tabs
        self.onBack = onBack
        self.onScan = onScan
    }

    private var hasBack: Bool { kind == .detail || kind == .detailSearch }
    private var hasSearch: Bool { kind != .detail }
    private var hasScan: Bool { kind == .detailSearch }
    private var hasLargeTitle: Bool { kind == .overview || kind == .overviewInline }

    var body: some View {
        if let tabs {
            tabbed(tabs)
        } else {
            plain
        }
    }

    // MARK: Tabs=Off

    @ViewBuilder private var plain: some View {
        switch kind {
        case .overviewInline:
            HStack {
                largeTitle
                searchField
            }
        case .overview:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    searchField
                }
                largeTitle
            }
        case .detail, .detailSearch:
            HStack(spacing: 12) {
                backButton
                Spacer(minLength: 12)
                if hasScan { scanButton }
                if hasSearch { searchField }
            }
            .overlay { centredTitle(emphasis: .subheadline) }
        }
    }

    // MARK: Tabs=On

    private func tabbed(_ tabs: AppToolbarTabs) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if hasBack { backButton }
                Spacer(minLength: 12)
                if hasScan { scanButton }
                if hasSearch { searchButton }
            }
            .overlay { tabBar(tabs) }
            if hasLargeTitle {
                largeTitle
            } else {
                centredTitle(emphasis: .headline)
            }
        }
    }

    private func tabBar(_ tabs: AppToolbarTabs) -> some View {
        HStack(spacing: 4) {
            Button(action: tabs.onToggleSidebar) {
                Image(systemName: "sidebar.leading")
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.horizontal, 12)
            }
            .accessibilityLabel("Sidebar")
            ForEach(tabs.titles.indices, id: \.self) { index in
                Button {
                    tabs.selection = index
                } label: {
                    Text(tabs.titles[index])
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            tabs.selection == index ? AppColor.stateSelected : Color.clear, in: Capsule())
                }
                .foregroundStyle(tabs.selection == index ? AppColor.materialTypeBatched : AppColor.textPrimary)
            }
        }
        .font(AppFont.subheadlineEmphasized)
        .buttonStyle(.plain)
        .padding(4)
        .glassEffect(.regular, in: Capsule())
        .overlay(Capsule().strokeBorder(AppColor.strokeSection))
    }

    // MARK: Parts

    private var largeTitle: some View {
        Text(title)
            .font(AppFont.largeTitleEmphasized)
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private enum TitleEmphasis { case subheadline, headline }

    private func centredTitle(emphasis: TitleEmphasis) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(emphasis == .headline ? AppFont.headlineRegular : AppFont.subheadlineEmphasized)
                .foregroundStyle(AppColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.caption1Regular)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .allowsHitTesting(false)
    }

    private var backButton: some View {
        Button(action: onBack) { Image(systemName: "chevron.left").foregroundStyle(AppColor.textPrimary) }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .overlay(Circle().strokeBorder(AppColor.strokeSection))
            .accessibilityLabel("Back")
    }

    private var scanButton: some View {
        Button(action: onScan) { Image(systemName: "viewfinder").foregroundStyle(AppColor.textPrimary) }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .overlay(Circle().strokeBorder(AppColor.strokeSection))
            .accessibilityLabel("Scan")
    }

    /// Tabs=On collapses the search field to a button that expands in the screen's search.
    private var searchButton: some View {
        Image(systemName: "magnifyingglass")
            .foregroundStyle(AppColor.textPrimary)
            .padding(10)
            .glassEffect(.regular, in: Circle())
            .overlay(Circle().strokeBorder(AppColor.strokeSection))
            .accessibilityLabel("Search")
    }

    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.textPrimary)
            TextField("Search", text: search)
                .font(AppFont.bodyRegular)
            if !search.wrappedValue.isEmpty {
                Button { search.wrappedValue = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 180, maxWidth: 260)
        .glassEffect(.regular, in: Capsule())
        .overlay(Capsule().strokeBorder(AppColor.strokeSection))
    }
}

#Preview("Toolbars") {
    @Previewable @State var query = ""
    @Previewable @State var tab = 0
    VStack(spacing: 24) {
        AppToolbar(.overviewInline, title: "Title", search: $query)
        AppToolbar(.overview, title: "Title", search: $query)
        AppToolbar(.detailSearch, title: "Title", subtitle: "Subtitle", search: $query)
        AppToolbar(.detail, title: "Title", subtitle: "Subtitle")
        AppToolbar(
            .detail, title: "Title", subtitle: "Subtitle",
            tabs: AppToolbarTabs(titles: ["Goods Receipt", "Pick & Pack"], selection: $tab, onToggleSidebar: {}))
    }
    .padding()
}
#endif
