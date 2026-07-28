import SwiftUI

struct WorkspaceRootView: View {
    @ObservedObject var session: PDFDocumentSession
    let saveDocument: () -> Void
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showsInspector = false
    @State private var ribbonTab: WorkspaceRibbonTab = .home

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeaderView(
                title: session.title,
                isEncrypted: session.isEncrypted,
                selectedTab: $ribbonTab
            )

            Divider()

            WorkspaceRibbonView(
                session: session,
                selectedTab: ribbonTab,
                sidebarVisible: columnVisibility != .detailOnly,
                inspectorVisible: showsInspector,
                toggleSidebar: toggleSidebar,
                toggleInspector: { showsInspector.toggle() },
                saveDocument: saveDocument
            )

            Divider()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(session: session)
                    .navigationSplitViewColumnWidth(min: 190, ideal: 228, max: 330)
            } detail: {
                PDFCanvasView(session: session)
                    .overlay(alignment: .bottom) {
                        pageStatus
                    }
                    .inspector(isPresented: $showsInspector) {
                        DocumentInspectorView(session: session)
                            .inspectorColumnWidth(min: 230, ideal: 270, max: 360)
                    }
            }
            .navigationSplitViewStyle(.balanced)
        }
        .tint(FormicTheme.accent)
    }

    private var pageStatus: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(FormicTheme.accent)
                .frame(width: 6, height: 6)

            Text(session.currentPageLabel)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        .padding(.bottom, 14)
        .accessibilityLabel(session.currentPageLabel)
    }

    private func toggleSidebar() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }
}
