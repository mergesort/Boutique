import Security

// Inspired by Valet's KeychainError implementation:
// https://github.com/square/Valet/blob/master/Sources/Valet/KeychainError.swift
public enum KeychainError: Error {
    /// The keychain could not be accessed.
    case couldNotAccessKeychain

    /// No data was found for the requested key.
    case itemNotFound

    /// The application does not have the proper entitlements to perform the requested action.
    /// This may be due to an Apple Keychain bug. As a workaround try running on a device that is not attached to a debugger.
    /// - SeeAlso: https://forums.developer.apple.com/thread/4743
    case missingEntitlement

    /// We did not match any commonly encountered keychain errors and want to bubble up the status code
    case errorWithStatus(status: OSStatus)

    init(status: OSStatus) {
        switch status {

        case errSecInvalidAccessCredentials, errSecInvalidAccessRequest, errSecInvalidAttributeAccessCredentials, errSecMissingAttributeAccessCredentials, errSecNoAccessForItem:
            self = .couldNotAccessKeychain

        case errSecItemNotFound:
            self = .itemNotFound

        case errSecMissingEntitlement:
            self = .missingEntitlement

        default:
            self = .errorWithStatus(status: status)
        }
    }
}
