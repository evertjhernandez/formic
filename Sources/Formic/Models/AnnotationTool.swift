enum AnnotationTool: Equatable {
    case selection
    case note
    case freeText
    case shape(ShapeAnnotationStyle)

    var isPlacementTool: Bool {
        self != .selection
    }

    var placementTitle: String {
        switch self {
        case .selection:
            return "Select text"
        case .note:
            return "Place a note"
        case .freeText:
            return "Place a text box"
        case .shape(let style):
            return "Place a \(style.displayName.lowercased())"
        }
    }

    var systemImage: String {
        switch self {
        case .selection:
            return "text.cursor"
        case .note:
            return "note.text.badge.plus"
        case .freeText:
            return "character.textbox"
        case .shape(let style):
            return style.systemImage
        }
    }
}
