enum AnnotationTool {
    case selection
    case note
    case freeText

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
        }
    }
}
