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
        typeName = Self.displayName(for: annotation.type)
        self.pageNumber = pageNumber
        color = annotation.color.withAlphaComponent(1)
        author = annotation.userName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        contents = annotation.contents ?? ""
        isNote = annotation.type == "Text"

        let isEditable = allowsCommenting && !annotation.isReadOnly
        canEditAppearance = isEditable && !annotation.hasAppearanceStream
        canEditText = isEditable && isNote
        canMove = isEditable && isNote
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
