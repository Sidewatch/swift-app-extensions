//
//  AppExtensionStateTests.swift
//  AppExtensionsTests
//
//  pluginkit's answers parsed, and the flips it is asked for — through a stand-in runner, never
//  the user's real extensions.
//
//  Created by David Sherlock on 9/24/26.
//

import XCTest
@testable import AppExtensions

final class AppExtensionStateTests: XCTestCase {
    let id = "app.example.Preview"

    func testParsesPluginkitsMarks() {
        XCTAssertEqual(AppExtensionState.parseState("+    app.example.Preview(1.0)\tUUID\t2026\t/path\n (1 plug-in)", identifier: id), true)
        XCTAssertEqual(AppExtensionState.parseState("-    app.example.Preview(1.0)", identifier: id), false)
        XCTAssertEqual(AppExtensionState.parseState("!    app.example.Preview(1.0)", identifier: id), false)
        XCTAssertNil(AppExtensionState.parseState("+    app.other.Thing(1.0)", identifier: id))
        XCTAssertNil(AppExtensionState.parseState("", identifier: id))
    }

    /// A stand-in pluginkit with a state the flips change; every call it sees is recorded.
    private final class FakeKit: @unchecked Sendable {
        var enabled: Bool? = false
        var calls: [[String]] = []
        let lock = NSLock()
        func run(_ args: [String]) -> (status: Int32, output: String) {
            lock.lock(); defer { lock.unlock() }
            calls.append(args)
            switch args.first {
            case "-m": return enabled.map { (0, "\($0 ? "+" : "-")    app.example.Preview(1.0)") } ?? (0, " (0 plug-ins)")
            case "-e": enabled = args[1] == "use"; return (0, "")
            case "-a": enabled = false; return (0, "")
            default: return (1, "")
            }
        }
    }

    func testReadsFlipsAndReadsBack() {
        let kit = FakeKit()
        let state = AppExtensionState(identifier: id, appexURL: URL(fileURLWithPath: "/x/Preview.appex")) { kit.run($0) }
        XCTAssertEqual(state.isEnabled(), false)
        XCTAssertTrue(state.setEnabled(true))
        XCTAssertEqual(state.isEnabled(), true)
        XCTAssertTrue(state.setEnabled(false))
        XCTAssertEqual(kit.calls.filter { $0.first == "-e" }, [["-e", "use", "-i", id], ["-e", "ignore", "-i", id]])
        XCTAssertFalse(kit.calls.contains { $0.first == "-a" }, "a known extension is not re-registered")
    }

    func testAnUnknownExtensionIsRegisteredBeforeItIsEnabled() {
        let kit = FakeKit(); kit.enabled = nil
        let state = AppExtensionState(identifier: id, appexURL: URL(fileURLWithPath: "/x/Preview.appex")) { kit.run($0) }
        XCTAssertNil(state.isEnabled())
        XCTAssertTrue(state.setEnabled(true))
        XCTAssertEqual(kit.calls.first { $0.first == "-a" }, ["-a", "/x/Preview.appex"])
        XCTAssertEqual(state.isEnabled(), true)
    }

    func testAFailingToolReadsAsUnregistered() {
        let state = AppExtensionState(identifier: id, appexURL: URL(fileURLWithPath: "/x/Preview.appex")) { _ in (1, "no such tool") }
        XCTAssertNil(state.isEnabled())
        XCTAssertFalse(state.isBundled)
    }
}
