import SwiftUI

struct DocumentInspectorView: View {
    @ObservedObject var session: PDFDocumentSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(FormicTheme.accent.opacity(0.13))

                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(FormicTheme.accent)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.hasSelectedAnnotation ? "ANNOTATION DETAILS" : "DOCUMENT DETAILS")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(FormicTheme.accent)

                        Text(session.annotationSelection?.typeName ?? session.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                    }
                }

                if let selection = session.annotationSelection {
                    annotationInspector(selection)
                }

                InspectorCard(title: "Overview", systemImage: "doc.plaintext") {
                    InspectorRow(label: "Pages", value: "\(session.pageCount)")
                    InspectorRow(label: "Position", value: "\(session.currentPageIndex + 1) of \(session.pageCount)")
                }

                InspectorCard(title: "Permissions", systemImage: "checkmark.shield") {
                    InspectorRow(label: "Encrypted", value: yesNo(session.isEncrypted), positive: !session.isEncrypted)
                    InspectorRow(label: "Copy content", value: allowed(session.allowsCopying), positive: session.allowsCopying)
                    InspectorRow(label: "Print", value: allowed(session.allowsPrinting), positive: session.allowsPrinting)
                }

                HStack(spacing: 7) {
                    Image(systemName: "lock.shield")
                    Text("Your document stays on this Mac.")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .padding(14)
        }
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func annotationInspector(_ selection: AnnotationSelection) -> some View {
        InspectorCard(title: "Selected annotation", systemImage: "selection.pin.in.out") {
            InspectorRow(label: "Type", value: selection.typeName)
            InspectorRow(label: "Page", value: "\(selection.pageNumber)")

            if !selection.isNote {
                InspectorRow(label: "Author", value: selection.author ?? "Not specified")
            }

            Divider()

            if selection.isNote {
                NoteAnnotationEditor(
                    contents: selection.contents,
                    author: selection.author ?? "",
                    isEditable: selection.canEditText,
                    applyChanges: session.updateSelectedNote
                )
                .id(selection.id)

                Divider()
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("COLOR")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.tertiary)

                HStack(spacing: 8) {
                    ForEach(AnnotationColorOption.allCases) { option in
                        Button {
                            session.setSelectedAnnotationColor(option.color)
                        } label: {
                            Circle()
                                .fill(Color(nsColor: option.color))
                                .frame(width: 20, height: 20)
                                .overlay {
                                    if option.matches(selection.color) {
                                        Circle()
                                            .stroke(.primary, lineWidth: 2)
                                            .padding(-3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(!selection.canEditAppearance)
                        .help(option.title)
                        .accessibilityLabel("Set annotation color to \(option.title)")
                    }
                }
            }

            if !selection.canEditAppearance {
                Label("This annotation's appearance can't be edited safely.", systemImage: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if selection.canMove {
                Label("Drag this note on the page to reposition it.", systemImage: "hand.draw")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Clear Selection") {
                    session.selectAnnotation(nil)
                }

                Spacer()

                Button("Delete", role: .destructive) {
                    session.deleteSelectedAnnotation()
                }
                .disabled(!selection.canDelete)
            }
            .controlSize(.small)
        }
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private func allowed(_ value: Bool) -> String {
        value ? "Allowed" : "Restricted"
    }
}

private struct NoteAnnotationEditor: View {
    let contents: String
    let author: String
    let isEditable: Bool
    let applyChanges: (String, String) -> Void

    @State private var draftContents: String
    @State private var draftAuthor: String

    init(
        contents: String,
        author: String,
        isEditable: Bool,
        applyChanges: @escaping (String, String) -> Void
    ) {
        self.contents = contents
        self.author = author
        self.isEditable = isEditable
        self.applyChanges = applyChanges
        _draftContents = State(initialValue: contents)
        _draftAuthor = State(initialValue: author)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                inspectorLabel("NOTE")

                ZStack(alignment: .topLeading) {
                    if draftContents.isEmpty {
                        Text("Write a note…")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 9)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $draftContents)
                        .font(.system(size: 11))
                        .scrollContentBackground(.hidden)
                        .padding(4)
                }
                .frame(minHeight: 82)
                .background(.background.opacity(0.58), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.separator.opacity(0.65), lineWidth: 1)
                }
                .disabled(!isEditable)
            }

            VStack(alignment: .leading, spacing: 6) {
                inspectorLabel("AUTHOR")
                TextField("Not specified", text: $draftAuthor)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .disabled(!isEditable)
            }

            HStack {
                if !isEditable {
                    Label("Read-only", systemImage: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Apply Changes") {
                    applyChanges(draftContents, draftAuthor)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!isEditable || !hasChanges)
            }
        }
        .onChange(of: contents) { _, newValue in
            draftContents = newValue
        }
        .onChange(of: author) { _, newValue in
            draftAuthor = newValue
        }
    }

    private var hasChanges: Bool {
        draftContents != contents
            || draftAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
                != author.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inspectorLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(.tertiary)
    }
}

private enum AnnotationColorOption: String, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case red

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var color: NSColor {
        switch self {
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .pink: return .systemPink
        case .red: return .systemRed
        }
    }

    func matches(_ other: NSColor) -> Bool {
        guard let lhs = color.usingColorSpace(.deviceRGB),
              let rhs = other.usingColorSpace(.deviceRGB)
        else { return false }

        let tolerance = 0.08
        return abs(lhs.redComponent - rhs.redComponent) < tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) < tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) < tolerance
    }
}

private struct InspectorCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            content
        }
        .padding(13)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct InspectorRow: View {
    let label: String
    let value: String
    var positive: Bool? = nil

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            if let positive {
                Circle()
                    .fill(positive ? Color.green : FormicTheme.accent)
                    .frame(width: 6, height: 6)
            }

            Text(value)
                .fontWeight(.medium)
        }
        .font(.system(size: 11))
    }
}
