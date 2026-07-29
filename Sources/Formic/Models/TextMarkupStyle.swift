import AppKit
import PDFKit

enum TextMarkupStyle: String, CaseIterable, Identifiable {
    case highlight
    case underline
    case strikeOut

    var id: Self { self }

    var displayName: String {
        switch self {
        case .highlight:
            return "Highlight"
        case .underline:
            return "Underline"
        case .strikeOut:
            return "Strikeout"
        }
    }

    var actionName: String {
        displayName
    }

    var systemImage: String {
        switch self {
        case .highlight:
            return "highlighter"
        case .underline:
            return "underline"
        case .strikeOut:
            return "strikethrough"
        }
    }

    var annotationSubtype: PDFAnnotationSubtype {
        switch self {
        case .highlight:
            return .highlight
        case .underline:
            return .underline
        case .strikeOut:
            return .strikeOut
        }
    }

    var color: NSColor {
        switch self {
        case .highlight:
            return NSColor.systemYellow.withAlphaComponent(0.55)
        case .underline:
            return NSColor.systemBlue.withAlphaComponent(0.9)
        case .strikeOut:
            return NSColor.systemRed.withAlphaComponent(0.9)
        }
    }
}
