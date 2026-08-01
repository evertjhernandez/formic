import AppKit
import SwiftUI

struct WorkspaceHeaderView: View {
    let title: String
    let isEncrypted: Bool
    @Binding var selectedTab: WorkspaceRibbonTab

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [FormicTheme.accentSoft, FormicTheme.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    FormicMarkView()
                        .padding(6)
                }
                .frame(width: 30, height: 30)

                Text("FORMIC")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(1.2)
            }
            .frame(width: 154, alignment: .leading)

            HStack(spacing: 2) {
                ForEach(WorkspaceRibbonTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundStyle(selectedTab == tab ? FormicTheme.accent : .secondary)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(FormicTheme.accent.opacity(0.10))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 12)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if isEncrypted {
                HeaderBadge(title: "Protected", systemImage: "lock.fill")
            }

            HeaderBadge(title: "On-device", systemImage: "checkmark.shield.fill")
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(.bar)
    }
}

struct WorkspaceRibbonView: View {
    @ObservedObject var session: PDFDocumentSession
    let selectedTab: WorkspaceRibbonTab
    let sidebarVisible: Bool
    let inspectorVisible: Bool
    let toggleSidebar: () -> Void
    let toggleInspector: () -> Void
    let saveDocument: () -> Void
    let saveDocumentCopy: () -> Void
    let showExportSheet: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            switch selectedTab {
            case .home:
                homeTools
            case .annotate:
                annotateTools
            case .view:
                viewTools
            case .find:
                findTools
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(height: 76)
        .background(.ultraThinMaterial)
    }

    private var annotateTools: some View {
        Group {
            RibbonGroup(title: "Add") {
                RibbonToolButton(
                    "Note",
                    systemImage: "note.text.badge.plus",
                    isActive: session.annotationTool == .note,
                    action: session.toggleNoteTool
                )
                .disabled(!session.allowsCommenting)
                .help(placementToolHelp(.note))

                RibbonToolButton(
                    "Text",
                    systemImage: "character.textbox",
                    isActive: session.annotationTool == .freeText,
                    action: session.toggleFreeTextTool
                )
                .disabled(!session.allowsCommenting)
                .help(placementToolHelp(.freeText))

                ForEach(ShapeAnnotationStyle.allCases) { style in
                    RibbonToolButton(
                        style.displayName,
                        systemImage: style.systemImage,
                        isActive: session.annotationTool == .shape(style),
                        action: { session.toggleShapeTool(style) }
                    )
                    .disabled(!session.allowsCommenting)
                    .help(placementToolHelp(.shape(style)))
                }
            }

            RibbonSeparator()

            RibbonGroup(title: "Text markup") {
                ForEach(TextMarkupStyle.allCases) { style in
                    RibbonToolButton(
                        style.displayName,
                        systemImage: style.systemImage,
                        action: { session.applyTextMarkup(style) }
                    )
                    .disabled(!session.canApplyTextMarkup)
                    .help(markupHelp)
                }
            }

            RibbonSeparator()

            RibbonGroup(title: "Selection") {
                RibbonSelectionStatus(
                    title: selectionStatusTitle,
                    detail: selectionStatusDetail,
                    systemImage: selectionStatusImage,
                    isReady: session.annotationTool.isPlacementTool
                        || session.canApplyTextMarkup
                        || session.hasSelectedAnnotation
                )

                if session.hasSelectedAnnotation {
                    RibbonToolButton("Delete", systemImage: "trash", action: session.deleteSelectedAnnotation)
                        .disabled(session.annotationSelection?.canDelete != true)
                        .help("Delete the selected annotation")
                }
            }

            RibbonSeparator()

            RibbonGroup(title: "History") {
                RibbonToolButton("Undo", systemImage: "arrow.uturn.backward", action: session.undo)
                    .disabled(!session.canUndo)
                RibbonToolButton("Redo", systemImage: "arrow.uturn.forward", action: session.redo)
                    .disabled(!session.canRedo)
            }
        }
    }

    private var homeTools: some View {
        Group {
            RibbonGroup(title: "Document") {
                RibbonToolButton("Open", systemImage: "folder", action: openDocument)
                RibbonToolButton(
                    saveButtonTitle,
                    systemImage: saveButtonSystemImage,
                    isActive: session.saveState == .saved,
                    action: saveDocument
                )
                .disabled(!session.hasUnsavedChanges || session.saveState == .saving)
                .help(session.hasUnsavedChanges ? "Save changes to this PDF" : "No changes to save")
                RibbonToolButton("Save a Copy", systemImage: "doc.on.doc", action: saveDocumentCopy)
                    .disabled(!session.hasDocument)
                    .help("Create an identical PDF without changing the open file")
                RibbonToolButton("Export", systemImage: "square.and.arrow.up", action: showExportSheet)
                    .disabled(!session.hasDocument)
                    .help("Create a new PDF, image, or text file")
                RibbonToolButton("Print", systemImage: "printer", action: printDocument)
                    .disabled(!session.hasDocument)
            }

            RibbonSeparator()

            RibbonGroup(title: "Workspace") {
                RibbonToolButton(
                    "Pages",
                    systemImage: "sidebar.left",
                    isActive: sidebarVisible,
                    action: toggleSidebar
                )
                RibbonToolButton(
                    "Details",
                    systemImage: "sidebar.right",
                    isActive: inspectorVisible,
                    action: toggleInspector
                )
            }
        }
    }

    private var viewTools: some View {
        Group {
            RibbonGroup(title: "Navigate") {
                RibbonToolButton("Previous", systemImage: "arrow.up", action: previousPage)
                RibbonToolButton("Next", systemImage: "arrow.down", action: nextPage)
            }

            RibbonSeparator()

            RibbonGroup(title: "Zoom") {
                RibbonToolButton("Zoom out", systemImage: "minus.magnifyingglass", action: session.zoomOut)
                RibbonToolButton("Fit page", systemImage: "arrow.up.left.and.arrow.down.right", action: session.zoomToFit)
                RibbonToolButton("Zoom in", systemImage: "plus.magnifyingglass", action: session.zoomIn)
            }

            RibbonSeparator()

            RibbonGroup(title: "Panels") {
                RibbonToolButton(
                    "Pages",
                    systemImage: "sidebar.left",
                    isActive: sidebarVisible,
                    action: toggleSidebar
                )
                RibbonToolButton(
                    "Details",
                    systemImage: "sidebar.right",
                    isActive: inspectorVisible,
                    action: toggleInspector
                )
            }
        }
    }

    private var findTools: some View {
        Group {
            RibbonGroup(title: "Search document") {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Find words or phrases", text: $session.searchQuery)
                        .textFieldStyle(.plain)
                        .onSubmit(session.performSearch)

                    if !session.searchQuery.isEmpty {
                        Button {
                            session.searchQuery = ""
                            session.performSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 11)
                .frame(width: 310, height: 34)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator.opacity(0.65), lineWidth: 1)
                }

                RibbonToolButton("Search", systemImage: "magnifyingglass", action: session.performSearch)
            }

            RibbonSeparator()

            RibbonGroup(title: resultLabel) {
                RibbonToolButton("Previous", systemImage: "chevron.up", action: session.showPreviousSearchResult)
                    .disabled(session.searchResults.isEmpty)
                RibbonToolButton("Next", systemImage: "chevron.down", action: session.showNextSearchResult)
                    .disabled(session.searchResults.isEmpty)
            }
        }
    }

    private var resultLabel: String {
        guard !session.searchResults.isEmpty else { return "No results" }
        return "Result \((session.selectedSearchResultIndex ?? 0) + 1) of \(session.searchResults.count)"
    }

    private var markupHelp: String {
        if !session.allowsCommenting {
            return "This PDF does not allow annotations"
        }
        if !session.hasTextSelection {
            return "Select text on a page first"
        }
        return "Apply markup to the selected text"
    }

    private func placementToolHelp(_ tool: AnnotationTool) -> String {
        if !session.allowsCommenting {
            return "This PDF does not allow annotations"
        }
        if session.annotationTool == tool {
            switch tool {
            case .selection:
                return ""
            case .note:
                return "Cancel note placement"
            case .freeText:
                return "Cancel text box placement"
            case .shape(let style):
                return "Cancel \(style.displayName.lowercased()) placement"
            }
        }
        switch tool {
        case .selection:
            return ""
        case .note:
            return "Add a note by clicking on a page"
        case .freeText:
            return "Add editable text by clicking on a page"
        case .shape(let style):
            let article = style == .oval ? "an" : "a"
            return "Add \(article) \(style.displayName.lowercased()) by clicking on a page"
        }
    }

    private var selectionStatusTitle: String {
        if !session.allowsCommenting {
            return "Read-only PDF"
        }
        if session.annotationTool.isPlacementTool {
            return session.annotationTool.placementTitle
        }
        if let annotation = session.annotationSelection {
            return "\(annotation.typeName) selected"
        }
        return session.hasTextSelection ? "Text selected" : "Select text"
    }

    private var selectionStatusDetail: String {
        if !session.allowsCommenting {
            return "Annotations aren't permitted"
        }
        if session.annotationTool.isPlacementTool {
            return "Click anywhere on a page"
        }
        if session.annotationSelection?.canMove == true {
            return "Drag it on the page or edit Details"
        }
        if session.hasSelectedAnnotation {
            return "Edit it in the Details panel"
        }
        return session.hasTextSelection ? "Choose a markup style" : "Drag across text on the page"
    }

    private var selectionStatusImage: String {
        if !session.allowsCommenting {
            return "lock.fill"
        }
        if session.annotationTool.isPlacementTool {
            return session.annotationTool.systemImage
        }
        if session.hasSelectedAnnotation {
            return "selection.pin.in.out"
        }
        return session.hasTextSelection ? "checkmark.circle.fill" : "text.cursor"
    }

    private var saveButtonTitle: String {
        switch session.saveState {
        case .idle:
            return "Save"
        case .saving:
            return "Saving…"
        case .saved:
            return "Saved"
        case .failed:
            return "Save failed"
        }
    }

    private var saveButtonSystemImage: String {
        switch session.saveState {
        case .idle:
            return "square.and.arrow.down"
        case .saving:
            return "arrow.triangle.2.circlepath"
        case .saved:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private func previousPage() {
        session.goToPage(at: session.currentPageIndex - 1)
    }

    private func nextPage() {
        session.goToPage(at: session.currentPageIndex + 1)
    }

    private func openDocument() {
        NSDocumentController.shared.openDocument(nil)
    }

    private func printDocument() {
        NSApp.sendAction(#selector(NSDocument.printDocument(_:)), to: nil, from: nil)
    }
}

private struct HeaderBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(.primary.opacity(0.055), in: Capsule())
    }
}

private struct RibbonGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                content
            }
            .frame(height: 44)

            Text(title.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
    }
}

private struct RibbonToolButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void
    @State private var isHovering = false

    init(
        _ title: String,
        systemImage: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? FormicTheme.accent : .primary)
            .frame(minWidth: 48, minHeight: 42)
            .padding(.horizontal, 3)
            .background(background, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(title)
    }

    private var background: Color {
        if isActive { return FormicTheme.accent.opacity(0.12) }
        if isHovering { return Color.primary.opacity(0.07) }
        return .clear
    }
}

private struct RibbonSeparator: View {
    var body: some View {
        Divider()
            .frame(height: 48)
            .padding(.horizontal, 5)
    }
}

private struct RibbonSelectionStatus: View {
    let title: String
    let detail: String
    let systemImage: String
    let isReady: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isReady ? FormicTheme.accent : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 190, height: 36, alignment: .leading)
        .padding(.horizontal, 10)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
