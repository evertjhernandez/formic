enum WorkspaceRibbonTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case view = "View"
    case find = "Find"

    var id: Self { self }
}
