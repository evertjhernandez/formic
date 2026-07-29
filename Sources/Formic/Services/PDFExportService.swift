import AppKit
import PDFKit

struct PDFExportService {
    func artifacts(
        for options: PDFExportOptions,
        document: PDFDocument,
        sourcePDFData: Data,
        baseFilename: String,
        currentPageIndex: Int
    ) throws -> [PDFExportArtifact] {
        let pageIndexes = try resolvedPageIndexes(
            for: options,
            pageCount: document.pageCount,
            currentPageIndex: currentPageIndex
        )
        let safeBaseFilename = sanitizedBaseFilename(baseFilename)

        switch options.format {
        case .pdf:
            return [
                PDFExportArtifact(
                    suggestedFilename: "\(safeBaseFilename)-copy.pdf",
                    data: sourcePDFData
                )
            ]
        case .plainText:
            guard document.allowsCopying else {
                throw PDFExportError.copyingNotAllowed
            }

            let text = pageIndexes
                .map { document.page(at: $0)?.string ?? "" }
                .joined(separator: "\n\n\u{000C}\n\n")

            guard let data = text.data(using: .utf8) else {
                throw PDFExportError.couldNotEncodeText
            }

            return [
                PDFExportArtifact(
                    suggestedFilename: "\(safeBaseFilename).txt",
                    data: data
                )
            ]
        case .png, .jpeg, .tiff:
            guard document.allowsPrinting else {
                throw PDFExportError.imageExportNotAllowed
            }

            return try pageIndexes.map { pageIndex in
                guard let page = document.page(at: pageIndex) else {
                    throw PDFExportError.missingPage(pageIndex + 1)
                }

                return PDFExportArtifact(
                    suggestedFilename: "\(safeBaseFilename)-page-\(pageNumber(pageIndex + 1, pageCount: document.pageCount)).\(options.format.fileExtension)",
                    data: try imageData(
                        for: page,
                        format: options.format,
                        resolutionDPI: options.resolutionDPI,
                        jpegQuality: options.jpegQuality
                    )
                )
            }
        }
    }

    private func resolvedPageIndexes(
        for options: PDFExportOptions,
        pageCount: Int,
        currentPageIndex: Int
    ) throws -> [Int] {
        guard pageCount > 0 else {
            throw PDFExportError.emptyDocument
        }

        switch options.pageSelection {
        case .all:
            return Array(0..<pageCount)
        case .current:
            guard (0..<pageCount).contains(currentPageIndex) else {
                throw PDFExportError.invalidPageRange
            }
            return [currentPageIndex]
        case .range:
            guard options.rangeStart >= 1,
                  options.rangeEnd >= options.rangeStart,
                  options.rangeEnd <= pageCount
            else {
                throw PDFExportError.invalidPageRange
            }
            return Array((options.rangeStart - 1)..<options.rangeEnd)
        }
    }

    private func imageData(
        for page: PDFPage,
        format: PDFExportFormat,
        resolutionDPI: Int,
        jpegQuality: Double
    ) throws -> Data {
        let bounds = page.bounds(for: .cropBox)
        let normalizedRotation = ((page.rotation % 360) + 360) % 360
        let rotated = normalizedRotation == 90 || normalizedRotation == 270
        let pageSize = rotated
            ? NSSize(width: bounds.height, height: bounds.width)
            : bounds.size
        let scale = CGFloat(max(resolutionDPI, 72)) / 72
        let pixelSize = NSSize(
            width: max((pageSize.width * scale).rounded(), 1),
            height: max((pageSize.height * scale).rounded(), 1)
        )
        let thumbnail = page.thumbnail(of: pixelSize, for: .cropBox)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw PDFExportError.couldNotRenderPage
        }

        bitmap.size = pixelSize
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw PDFExportError.couldNotRenderPage
        }

        NSGraphicsContext.current = context
        NSColor.white.setFill()
        NSRect(origin: .zero, size: pixelSize).fill()
        thumbnail.draw(
            in: NSRect(origin: .zero, size: pixelSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        context.flushGraphics()

        let representation: NSBitmapImageRep.FileType
        let properties: [NSBitmapImageRep.PropertyKey: Any]

        switch format {
        case .png:
            representation = .png
            properties = [:]
        case .jpeg:
            representation = .jpeg
            properties = [.compressionFactor: min(max(jpegQuality, 0), 1)]
        case .tiff:
            representation = .tiff
            properties = [.compressionMethod: NSBitmapImageRep.TIFFCompression.lzw.rawValue]
        case .pdf, .plainText:
            throw PDFExportError.unsupportedFormat
        }

        guard let data = bitmap.representation(using: representation, properties: properties) else {
            throw PDFExportError.couldNotEncodeImage
        }
        return data
    }

    private func sanitizedBaseFilename(_ filename: String) -> String {
        let stem = (filename as NSString).deletingPathExtension
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let components = stem.components(separatedBy: invalidCharacters)
        let sanitized = components.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "Formic Export" : sanitized
    }

    private func pageNumber(_ pageNumber: Int, pageCount: Int) -> String {
        let width = max(String(pageCount).count, 2)
        return String(format: "%0*d", width, pageNumber)
    }
}

enum PDFExportError: LocalizedError {
    case emptyDocument
    case invalidPageRange
    case missingPage(Int)
    case copyingNotAllowed
    case imageExportNotAllowed
    case couldNotRenderPage
    case couldNotEncodeImage
    case couldNotEncodeText
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "This PDF does not contain any pages to export."
        case .invalidPageRange:
            return "Choose a page range that exists in this PDF."
        case let .missingPage(pageNumber):
            return "Formic could not read page \(pageNumber)."
        case .copyingNotAllowed:
            return "This PDF does not allow its text to be copied."
        case .imageExportNotAllowed:
            return "This PDF does not allow its pages to be rendered for export."
        case .couldNotRenderPage:
            return "Formic could not render one of the selected pages."
        case .couldNotEncodeImage:
            return "Formic could not create the selected image format."
        case .couldNotEncodeText:
            return "Formic could not encode the document text."
        case .unsupportedFormat:
            return "The selected export format is not supported."
        }
    }
}
