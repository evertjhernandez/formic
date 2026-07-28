import PDFKit
import SwiftUI

struct SidebarView: View {
    @ObservedObject var session: PDFDocumentSession

    var body: some View {
        VStack(spacing: 0) {
            sidebarModePicker
                .padding(10)

            Divider()

            switch session.sidebarMode {
            case .thumbnails:
                ThumbnailListView(session: session)
            case .outline:
                OutlineListView(session: session)
            }
        }
        .background(.regularMaterial)
    }

    private var sidebarModePicker: some View {
        HStack(spacing: 4) {
            ForEach(SidebarMode.allCases) { mode in
                Button {
                    session.sidebarMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 29)
                        .foregroundStyle(session.sidebarMode == mode ? FormicTheme.accent : .secondary)
                        .background {
                            if session.sidebarMode == mode {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(FormicTheme.accent.opacity(0.11))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct ThumbnailListView: View {
    @ObservedObject var session: PDFDocumentSession

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(0..<session.pageCount, id: \.self) { index in
                        if let page = session.document?.page(at: index) {
                            ThumbnailRow(
                                page: page,
                                index: index,
                                isSelected: session.currentPageIndex == index
                            ) {
                                session.goToPage(at: index)
                            }
                            .id(index)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .onChange(of: session.currentPageIndex) { _, newValue in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

private struct ThumbnailRow: View {
    let page: PDFPage
    let index: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topLeading) {
                    Image(nsImage: page.thumbnail(of: NSSize(width: 148, height: 192), for: .cropBox))
                        .resizable()
                        .scaledToFit()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(
                                    isSelected ? FormicTheme.accent : Color.primary.opacity(0.12),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        }
                        .shadow(color: .black.opacity(isSelected ? 0.20 : 0.12), radius: 5, y: 2)

                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(FormicTheme.accent, in: UnevenRoundedRectangle(cornerRadii: .init(topLeading: 3, bottomTrailing: 6)))
                        .opacity(isSelected ? 1 : 0)
                }

                Text(page.label ?? "Page \(index + 1)")
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? FormicTheme.accent : .secondary)
            }
            .padding(6)
            .background(
                (isHovering && !isSelected ? Color.primary.opacity(0.045) : Color.clear),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Page \(page.label ?? "\(index + 1)")")
    }
}

private struct OutlineListView: View {
    @ObservedObject var session: PDFDocumentSession

    var body: some View {
        if let root = session.document?.outlineRoot, root.numberOfChildren > 0 {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    OutlineChildren(outline: root, session: session, depth: 0)
                }
                .padding(10)
            }
        } else {
            ContentUnavailableView(
                "No outline",
                systemImage: "list.bullet.indent",
                description: Text("This PDF does not include a document outline.")
            )
        }
    }
}

private struct OutlineChildren: View {
    let outline: PDFOutline
    @ObservedObject var session: PDFDocumentSession
    let depth: Int

    var body: some View {
        ForEach(0..<outline.numberOfChildren, id: \.self) { index in
            if let child = outline.child(at: index) {
                if child.numberOfChildren > 0 {
                    DisclosureGroup {
                        OutlineChildren(outline: child, session: session, depth: depth + 1)
                    } label: {
                        outlineButton(child)
                    }
                } else {
                    outlineButton(child)
                }
            }
        }
    }

    private func outlineButton(_ outline: PDFOutline) -> some View {
        Button {
            if let page = outline.destination?.page {
                session.goToPage(at: session.document?.index(for: page) ?? 0)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 10))
                    .foregroundStyle(FormicTheme.accent.opacity(0.8))

                Text(outline.label ?? "Untitled")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 7)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
