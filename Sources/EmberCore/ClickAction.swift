/// What a click on the menu-bar icon does.
public enum ClickAction: Equatable, Sendable {
    /// Plain left click: switch red on or off.
    case toggle
    /// Right click or Control-click: open the menu (Open at Login, Quit).
    case showMenu

    public init(isRightClick: Bool, isControlHeld: Bool) {
        self = (isRightClick || isControlHeld) ? .showMenu : .toggle
    }
}
