---
name: boutique-stored-values
description: Persist individual values with Boutique's @StoredValue (UserDefaults) and @SecurelyStoredValue (Keychain), including set, reset, toggle, bindings, keypath setters, array and dictionary helpers, and async observation. Use when storing preferences, settings, feature flags, or sensitive data like auth tokens.
---

# Boutique Stored Values

Use this skill when you need to persist individual values (preferences, settings, feature flags) using `@StoredValue` (backed by UserDefaults) or sensitive data (auth tokens, passwords) using `@SecurelyStoredValue` (backed by the system Keychain).

## Prerequisites

- Boutique added as a dependency via Swift Package Manager.
- Stored values must conform to `Codable`, `Sendable`, and `Equatable`.

## @StoredValue (UserDefaults)

### Basic declaration

```swift
@StoredValue(key: "hasHapticsEnabled")
var hasHapticsEnabled = false

@StoredValue(key: "lastOpenedDate")
var lastOpenedDate: Date? = nil

@StoredValue(key: "currentTheme")
var currentlySelectedTheme: Theme = .light
```

### In @Observable classes

Always pair with `@ObservationIgnored` to prevent duplicate observation tracking.

```swift
@Observable
final class Preferences {
    @ObservationIgnored
    @StoredValue(key: "hasHapticsEnabled")
    var hasHapticsEnabled = false

    @ObservationIgnored
    @StoredValue(key: "lastOpenedDate")
    var lastOpenedDate: Date? = nil

    @ObservationIgnored
    @StoredValue(key: "currentTheme")
    var currentlySelectedTheme: Theme = .light
}
```

### Setting and resetting values

Use the `$` projected value to access `set` and `reset`.

```swift
// Set a new value
$lastOpenedDate.set(.now)
$currentlySelectedTheme.set(.dark)

// Reset to the default value provided at declaration
$lastOpenedDate.reset()          // Back to nil
$currentlySelectedTheme.reset()  // Back to .light
```

### Boolean toggle

```swift
$hasHapticsEnabled.toggle()

// Equivalent to:
// $hasHapticsEnabled.set(!hasHapticsEnabled)
```

### Keypath setter (nested property updates)

Update a single property inside a complex stored object without manually copying.

```swift
struct UserPreferences: Codable, Sendable, Equatable {
    var hasHapticsEnabled: Bool
    var prefersDarkMode: Bool
    var prefersWideScreen: Bool
}

@ObservationIgnored
@StoredValue(key: "userPreferences")
var preferences = UserPreferences(
    hasHapticsEnabled: true,
    prefersDarkMode: false,
    prefersWideScreen: false
)

// Update a single nested property
$preferences.set(\.prefersDarkMode, to: true)
```

### Array helpers

When a `@StoredValue` holds an array, convenience methods are available.

```swift
@ObservationIgnored
@StoredValue(key: "favoriteTags")
var favoriteTags: [String] = []

// Append an element
$favoriteTags.append("swift")

// Toggle presence (add if missing, remove if present)
$favoriteTags.togglePresence("swift")

// Replace an element
$favoriteTags.replace("swfit", with: "swift")
```

### Dictionary helpers

```swift
@ObservationIgnored
@StoredValue(key: "featureFlags")
var featureFlags: [String: Bool] = [:]

// Update a key
$featureFlags.update(key: "darkMode", value: true)

// Remove a key by setting nil
$featureFlags.update(key: "darkMode", value: nil)
```

### Async observation

Observe changes over time with the `values` AsyncStream.

```swift
func monitorThemeChanges() async {
    for await theme in preferences.$currentlySelectedTheme.values {
        print("Theme changed to", theme)
    }
}
```

### Custom UserDefaults

```swift
@StoredValue(key: "sharedSetting", storage: UserDefaults(suiteName: "group.com.example.app")!)
var sharedSetting = false
```

### Direct initialization (without property wrapper syntax)

Useful in contexts where property wrappers are not supported.

```swift
let hasHapticsEnabled = StoredValue(key: "hasHapticsEnabled", default: false)
```

## @SecurelyStoredValue (Keychain)

### Key differences from @StoredValue

| Aspect                | @StoredValue          | @SecurelyStoredValue        |
|-----------------------|-----------------------|-----------------------------|
| Backing store         | UserDefaults          | System Keychain             |
| Default value         | Required              | Not supported               |
| `wrappedValue` type   | `Item`                | `Item?` (always optional)   |
| Mutation methods      | `set(_:)`, `reset()`  | `set(_:) throws`, `remove() throws` |
| Use case              | Preferences, settings | Passwords, tokens, secrets  |

### Declaration

Do not make the type optional yourself, the wrapper handles that. Declaring `@SecurelyStoredValue<String?>` creates a double optional.

```swift
@Observable
final class SecurityManager {
    @ObservationIgnored
    @SecurelyStoredValue<String>(key: "authToken")
    var authToken

    @ObservationIgnored
    @SecurelyStoredValue<String>(key: "refreshToken")
    var refreshToken
}
```

### Setting and removing values

```swift
// Set a value (throws on keychain errors)
try $authToken.set("eyJhbGciOiJIUzI1NiIs...")

// Remove from keychain
try $authToken.remove()

// Set to nil (same as remove)
try $authToken.set(nil)
```

### Keychain service and group

```swift
@SecurelyStoredValue<String>(
    key: "authToken",
    service: KeychainService(value: "com.example.auth"),
    group: KeychainGroup(value: "group.com.example.shared")
)
var authToken
```

### Boolean toggle (throws)

```swift
@ObservationIgnored
@SecurelyStoredValue<Bool>(key: "biometricsEnabled")
var biometricsEnabled

try $biometricsEnabled.toggle()
```

### Array and dictionary helpers (throws)

```swift
@ObservationIgnored
@SecurelyStoredValue<[String]>(key: "trustedDevices")
var trustedDevices

try $trustedDevices.append("device-abc-123")
try $trustedDevices.replace("device-old", with: "device-new")
```

### Keypath setter (throws)

```swift
try $credentials.set(\.accessToken, to: "new-token")
```

### Async observation

```swift
func monitorAuthState() async {
    for await token in securityManager.$authToken.values {
        if let token {
            print("Authenticated")
        } else {
            print("Logged out")
        }
    }
}
```

## Structuring Preferences

For apps with many preferences, break them into focused `@Observable` classes.

```swift
@Observable
final class Preferences {
    var userExperience = UserExperiencePreferences()
    var notifications = NotificationPreferences()
}

@Observable
final class UserExperiencePreferences {
    @ObservationIgnored
    @StoredValue(key: "hasSoundEffectsEnabled")
    var hasSoundEffectsEnabled = false

    @ObservationIgnored
    @StoredValue(key: "hasHapticsEnabled")
    var hasHapticsEnabled = true
}

@Observable
final class NotificationPreferences {
    @ObservationIgnored
    @StoredValue(key: "pushEnabled")
    var pushEnabled = true

    @ObservationIgnored
    @StoredValue(key: "emailDigestEnabled")
    var emailDigestEnabled = false
}
```

## Common Mistakes

- **Forgetting `$`**: Use `$storedValue.set(value)`, not `storedValue.set(value)`. The `wrappedValue` is the raw value; the `projectedValue` (via `$`) is the `StoredValue` with mutation methods.
- **Missing `@ObservationIgnored`**: Always add `@ObservationIgnored` before `@StoredValue` or `@SecurelyStoredValue` in `@Observable` classes.
- **Double optional**: Don't write `@SecurelyStoredValue<String?>`. The wrapper already makes `wrappedValue` optional.

## Notes

- `@StoredValue` and `@SecurelyStoredValue` are both `@MainActor` isolated.
- Values from `@StoredValue` are available synchronously on app launch.
- Values from `@SecurelyStoredValue` are read from the Keychain synchronously.
- See `boutique-swiftui` skill for using `.binding` with SwiftUI controls.
