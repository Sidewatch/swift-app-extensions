//
//  AppExtensionState.swift
//  AppExtensions
//
//  An app extension's on/off state for this user, read and flipped through `pluginkit` — for the
//  extension points macOS gives no API for (Quick Look previews, thumbnails, Spotlight…).
//
//  Created by David Sherlock on 9/24/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AppKit
import ProcessRunner

/// One app extension's state for this user, through `/usr/bin/pluginkit` — the tool System
/// Settings ▸ General ▸ Login Items & Extensions drives underneath. FinderSync has
/// `FIFinderSyncController.isExtensionEnabled`; Quick Look, thumbnail, Spotlight and share
/// extensions have nothing, so this asks: `-m -i <id>` lists the plug-in with `+` (in use), `-`
/// (ignored) or `!` (blocked), `-e use|ignore -i <id>` flips it, `-a <appex>` registers a bundle
/// Launch Services has not seen (a fresh build, a moved app). There is no callback when the user
/// flips it elsewhere, so read the state, never cache it.
public struct AppExtensionState: Sendable {
    /// What the tool answered: its exit status and its output.
    public typealias Runner = @Sendable (_ arguments: [String]) -> (status: Int32, output: String)

    /// The extension's bundle identifier (`CFBundleIdentifier` of the appex).
    public let identifier: String
    /// The appex bundle inside the host app, for `register()`.
    public let appexURL: URL
    /// Runs pluginkit (or, in a test, stands in for it).
    public let runner: Runner

    /// A handle on the extension `identifier` whose bundle is `appexURL`; `runner` defaults to
    /// the real pluginkit.
    public init(identifier: String, appexURL: URL, runner: @escaping Runner = AppExtensionState.pluginkit) {
        self.identifier = identifier
        self.appexURL = appexURL
        self.runner = runner
    }

    /// Whether the host app carries the appex at all (a bare `swift build` binary does not).
    public var isBundled: Bool { FileManager.default.fileExists(atPath: appexURL.path) }

    /// True when in use, false when ignored or blocked, nil when the extension is not registered.
    public func isEnabled() -> Bool? {
        let (status, output) = runner(["-m", "-i", identifier])
        guard status == 0 else { return nil }
        return Self.parseState(output, identifier: identifier)
    }

    /// Registers the bundled appex with Launch Services (idempotent).
    public func register() { _ = runner(["-a", appexURL.path]) }

    /// Turns the extension on or off for this user; registers it first if it is unknown.
    /// Returns whether the read-back agrees.
    @discardableResult
    public func setEnabled(_ on: Bool) -> Bool {
        if isEnabled() == nil { register() }
        _ = runner(["-e", on ? "use" : "ignore", "-i", identifier])
        return isEnabled() == on
    }

    /// `pluginkit -m` marks each plug-in with `+` (in use), `-` (ignored) or `!` (blocked).
    static func parseState(_ output: String, identifier: String) -> Bool? {
        guard let line = output.split(separator: "\n").first(where: { $0.contains(identifier) }) else { return nil }
        return line.trimmingCharacters(in: .whitespaces).hasPrefix("+")
    }

    /// System Settings' pane for an extension point — the place that can flip an extension when
    /// pluginkit's answer disagrees. `com.apple.quicklook.preview`, `com.apple.finder-sync`…
    @MainActor
    public static func openSystemSettings(extensionPoint: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=\(extensionPoint)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The real tool, with a 5 s cap so a wedged pluginkit cannot hold the caller.
    public static let pluginkit: Runner = { args in
        let result = ProcessRunner.run("/usr/bin/pluginkit", args, augmentPATH: false, timeout: 5)
        guard !result.timedOut else { return (-1, "") }
        return (result.status, result.outputText + result.errorText)
    }
}
