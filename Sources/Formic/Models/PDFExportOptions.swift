import Foundation

enum PDFExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case png
    case jpeg
    case tiff
    case plainText

    var id: Self { self }

    var displayName: String {
        switch self {
        case .pdf:
            return "PDF"
        case .png:
            return "PNG Image"
        case .jpeg:
            return "JPEG Image"
        case .tiff:
            return "TIFF Image"
        case .plainText:
            return "Plain Text"
        }
    }

    var fileExtension: String {
        switch self {
        case .pdf:
            return "pdf"
        case .png:
            return "png"
        case .jpeg:
            return "jpg"
        case .tiff:
            return "tiff"
        case .plainText:
            return "txt"
        }
    }

    var isImage: Bool {
        switch self {
        case .png, .jpeg, .tiff:
            return true
        case .pdf, .plainText:
            return false
        }
    }
}

enum PDFExportPageSelection: String, CaseIterable, Identifiable {
    case all
    case current
    case range

    var id: Self { self }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .current:
            return "Current"
        case .range:
            return "Range"
        }
    }
}

struct PDFExportOptions {
    var format: PDFExportFormat = .pdf
    var pageSelection: PDFExportPageSelection = .all
    var rangeStart = 1
    var rangeEnd = 1
    var resolutionDPI = 144
    var jpegQuality = 0.9
}

struct PDFExportArtifact: Equatable {
    let suggestedFilename: String
    let data: Data
}
