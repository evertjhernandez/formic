import AppKit

enum StampAnnotationStyle: CaseIterable, Identifiable, Hashable {
    case approved
    case draft
    case confidential

    var id: Self { self }

    var displayName: String {
        switch self {
        case .approved:
            return "Approved"
        case .draft:
            return "Draft"
        case .confidential:
            return "Confidential"
        }
    }

    var stampName: String {
        displayName
    }

    var article: String {
        self == .approved ? "an" : "a"
    }

    var systemImage: String {
        switch self {
        case .approved:
            return "checkmark.seal"
        case .draft:
            return "pencil.and.outline"
        case .confidential:
            return "lock.shield"
        }
    }

    var color: NSColor {
        switch self {
        case .approved:
            return .systemGreen
        case .draft:
            return .systemOrange
        case .confidential:
            return .systemRed
        }
    }
}
