import SwiftUI

struct PDFExportSheetView: View {
    @ObservedObject var session: PDFDocumentSession
    let onCancel: () -> Void
    let onExport: (PDFExportOptions) -> Void

    @State private var options: PDFExportOptions

    init(
        session: PDFDocumentSession,
        onCancel: @escaping () -> Void,
        onExport: @escaping (PDFExportOptions) -> Void
    ) {
        self.session = session
        self.onCancel = onCancel
        self.onExport = onExport
        _options = State(
            initialValue: PDFExportOptions(
                rangeEnd: max(session.pageCount, 1)
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "square.and.arrow.up.on.square")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(FormicTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(FormicTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Export PDF")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))

                    Text("Creates a new file. The open PDF remains unchanged.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                GridRow {
                    fieldLabel("Format")

                    Picker("Format", selection: $options.format) {
                        ForEach(availableFormats) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 230)
                }

                if options.format != .pdf {
                    GridRow {
                        fieldLabel("Pages")

                        Picker("Pages", selection: $options.pageSelection) {
                            ForEach(PDFExportPageSelection.allCases) { selection in
                                Text(selection.displayName).tag(selection)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 230)
                    }
                }

                if options.format != .pdf, options.pageSelection == .range {
                    GridRow {
                        fieldLabel("Range")

                        HStack(spacing: 8) {
                            pageField(value: $options.rangeStart)
                            Text("to")
                                .foregroundStyle(.secondary)
                            pageField(value: $options.rangeEnd)
                            Text("of \(session.pageCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if options.format.isImage {
                    GridRow {
                        fieldLabel("Quality")

                        Picker("Resolution", selection: $options.resolutionDPI) {
                            Text("Screen · 72 dpi").tag(72)
                            Text("Standard · 144 dpi").tag(144)
                            Text("Print · 300 dpi").tag(300)
                        }
                        .labelsHidden()
                        .frame(width: 230)
                    }
                }

                if options.format == .jpeg {
                    GridRow {
                        fieldLabel("Compression")

                        HStack(spacing: 10) {
                            Slider(value: $options.jpegQuality, in: 0.5...1)
                            Text("\(Int(options.jpegQuality * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 38, alignment: .trailing)
                        }
                        .frame(width: 230)
                    }
                }
            }

            exportExplanation

            Divider()

            HStack {
                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Choose Destination…") {
                    onExport(validatedOptions)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(FormicTheme.accent)
                .disabled(!hasValidRange)
            }
        }
        .padding(24)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var availableFormats: [PDFExportFormat] {
        PDFExportFormat.allCases.filter { format in
            switch format {
            case .pdf:
                return true
            case .plainText:
                return session.allowsCopying
            case .png, .jpeg, .tiff:
                return session.allowsPrinting
            }
        }
    }

    private var hasValidRange: Bool {
        guard options.pageSelection == .range else { return true }
        return options.rangeStart >= 1
            && options.rangeEnd >= options.rangeStart
            && options.rangeEnd <= session.pageCount
    }

    private var validatedOptions: PDFExportOptions {
        var result = options
        result.rangeStart = min(max(result.rangeStart, 1), max(session.pageCount, 1))
        result.rangeEnd = min(max(result.rangeEnd, result.rangeStart), max(session.pageCount, 1))
        return result
    }

    @ViewBuilder
    private var exportExplanation: some View {
        let message: String = switch options.format {
        case .pdf:
            "PDF export makes an exact copy of the open file. Use Save later when Formic has edits to write back."
        case .plainText:
            "Text export preserves readable text, but not the PDF's visual layout, fonts, or images."
        case .png, .jpeg, .tiff:
            options.pageSelection == .current
                ? "The current page will be rendered as a new image."
                : "Each selected page will be rendered as a separate numbered image."
        }

        Label(message, systemImage: "info.circle")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 82, alignment: .trailing)
    }

    private func pageField(value: Binding<Int>) -> some View {
        TextField("Page", value: value, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 58)
            .multilineTextAlignment(.trailing)
    }
}
