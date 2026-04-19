import Foundation

enum KeepAwakeError: LocalizedError {
    case helperMissing
    case devicesUnavailable
    case keyboardUnavailable
    case trackpadUnavailable
    case permissionDenied(String)
    case seizeFailed(String)
    case invalidHelperArguments

    var errorDescription: String? {
        switch self {
        case .helperMissing:
            "The timed cleaning helper is missing from the app bundle."
        case .devicesUnavailable:
            "KeepAwake couldn't find the built-in keyboard and trackpad yet. If macOS asks for approval, please allow access and try again."
        case .keyboardUnavailable:
            "KeepAwake couldn't find the built-in keyboard."
        case .trackpadUnavailable:
            "KeepAwake couldn't find the built-in trackpad."
        case .permissionDenied(let details):
            "macOS denied input access. \(details)"
        case .seizeFailed(let details):
            "KeepAwake couldn't disable the built-in input device. \(details)"
        case .invalidHelperArguments:
            "The helper process received an invalid request."
        }
    }
}
