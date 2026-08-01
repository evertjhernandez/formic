enum AnnotationTool: Equatable {
    case selection
    case note
    case freeText
    case shape(ShapeAnnotationStyle)
    case stamp(StampAnnotationStyle)

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
        case .stamp(let style):
            return "Place \(style.article) \(style.displayName.lowercased()) stamp"
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
        case .stamp(let style):
            return style.systemImage
        }
    }
}
