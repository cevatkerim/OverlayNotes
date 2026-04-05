import AppKit

extension NSScreen {
    var overlayDisplayID: String {
        guard let value = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return "unknown-\(frame.debugDescription)"
        }

        return value.stringValue
    }

    var overlayDisplayName: String {
        localizedName
    }

    static func overlayScreen(withDisplayID displayID: String?) -> NSScreen? {
        guard let displayID else { return nil }
        return screens.first { $0.overlayDisplayID == displayID }
    }
}
