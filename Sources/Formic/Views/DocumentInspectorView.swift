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
                        Text("DOCUMENT DETAILS")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(FormicTheme.accent)

                        Text(session.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                    }
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

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private func allowed(_ value: Bool) -> String {
        value ? "Allowed" : "Restricted"
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
