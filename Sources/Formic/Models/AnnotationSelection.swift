import AppKit
import PDFKit

struct AnnotationSelection {
    let id: ObjectIdentifier
    let typeName: String
    let pageNumber: Int
    let color: NSColor
    let author: String?
    let contents: String
    let isNote: Bool
    let isFreeText: Bool
    let isTextAnnotation: Bool
    let isShape: Bool
    let isStamp: Bool
    let isInk: Bool
    let canEditAppearance: Bool
    let canEditText: Bool
    let canMove: Bool
    let canDelete: Bool

    init(
        annotation: PDFAnnotation,
        pageNumber: Int,
        allowsCommenting: Bool
    ) {
        id = ObjectIdentifier(annotation)
        typeName = Self.displayName(for: annotation)
        self.pageNumber = pageNumber
        isNote = annotation.type == "Text"
        isFreeText = annotation.type == "FreeText"
        isTextAnnotation = isNote || isFreeText
        isShape = annotation.type == "Square" || annotation.type == "Circle"
        isStamp = annotation.type == "Stamp"
        isInk = annotation.type == "Ink"
        color = (isFreeText ? annotation.fontColor ?? .black : annotation.color)
            .withAlphaComponent(1)
        author = annotation.userName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        contents = annotation.contents ?? ""

        let isEditable = allowsCommenting && !annotation.isReadOnly
        canEditAppearance = isEditable && !annotation.hasAppearanceStream
        canEditText = isEditable && isTextAnnotation
        canMove = isEditable && (isTextAnnotation || isShape || isStamp || isInk)
        canDelete = isEditable && annotation.type != "Link" && annotation.type != "Widget"
    }

    private static func displayName(for type: String?) -> String {
        switch type {
        case "Highlight": return "Highlight"
        case "Underline": return "Underline"
        case "StrikeOut": return "Strikeout"
        case "FreeText": return "Text box"
        case "Text": return "Note"
        case "Square": return "Rectangle"
        case "Circle": return "Oval"
        case "Ink": return "Drawing"
        case "Stamp": return "Stamp"
        case "Link": return "Link"
        case "Widget": return "Form field"
        case let type?: return type
        case nil: return "Annotation"
        }
    }

    private static func displayName(for annotation: PDFAnnotation) -> String {
        if annotation.type == "Stamp",
           let stampName = annotation.stampName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !stampName.isEmpty {
            let displayName = stampName.hasPrefix("/") ? String(stampName.dropFirst()) : stampName
            return "\(displayName) stamp"
        }
        return displayName(for: annotation.type)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
