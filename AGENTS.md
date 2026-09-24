# Swift App Extensions

An app extension's on/off state for this user, read and flipped through `pluginkit` — for the
extension points macOS gives no API for (Quick Look previews and thumbnails, Spotlight, Share).
One type, `AppExtensionState`: `isEnabled()` (true / false / nil for unregistered), `setEnabled(_:)`
(registers if unknown, flips, returns whether the read-back agrees), `register()`, `isBundled`, and
`openSystemSettings(extensionPoint:)` for the pane that can flip it when pluginkit disagrees. The
`runner` is injectable; tests use a stand-in and never touch the user's extensions.

- Module `AppExtensions` in `Sources/AppExtensions`; tests in `Tests`; `swift test` is the whole check.
- No dependencies. macOS 14, tools 6.2, Swift 6 language mode.
- Read the state, never cache it: nothing tells a host when the user flips an extension in System Settings.

@CONTRIBUTING.md
