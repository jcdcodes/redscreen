#!/usr/bin/env swift
//
// RedScreen.swift
//
// A macOS menu bar utility that turns your display into a red-on-black
// darkroom mode. Lives in the menu bar with a toggle and quit.
//
// Run directly:     swift RedScreen.swift
// Compile:          swiftc RedScreen.swift -o RedScreen -framework Cocoa
// Then just:        ./RedScreen
//

import Cocoa
import CoreGraphics

// MARK: - Gamma Engine

class GammaEngine {
    static let shared = GammaEngine()

    private let tableSize = 256
    private var redTable   = [Float](repeating: 0, count: 256)
    private var greenTable = [Float](repeating: 0, count: 256)
    private var blueTable  = [Float](repeating: 0, count: 256)

    private var timer: DispatchSourceTimer?

    private(set) var isActive = false

    private init() {}

    // MARK: - Table building

    /// Build inverted red-only lookup tables.
    /// Red: reversed ramp (black input → red output, white input → black output)
    /// Green/Blue: all zeros.
    private func buildTables() {
        for i in 0..<tableSize {
            let t = Float(i) / Float(tableSize - 1)
            redTable[i]   = 1.0 - t
            greenTable[i] = 0.0
            blueTable[i]  = 0.0
        }
    }

    private func applyToDisplays() {
        var displayCount: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else { return }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetOnlineDisplayList(displayCount, &displays, &displayCount)

        for display in displays {
            CGSetDisplayTransferByTable(
                display,
                UInt32(tableSize),
                &redTable,
                &greenTable,
                &blueTable
            )
        }
    }

    private func buildAndApply() {
        buildTables()
        applyToDisplays()
    }

    // MARK: - Activation

    func activate() {
        guard !isActive else { return }
        isActive = true
        buildAndApply()
        startTimer()
        registerDisplayCallback()
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        stopTimer()
        unregisterDisplayCallback()
        CGDisplayRestoreColorSyncSettings()
    }

    func reapply() {
        if isActive { buildAndApply() }
    }

    func toggle() {
        if isActive { deactivate() } else { activate() }
    }

    // MARK: - Persistence timer
    // macOS ColorSync resets gamma ramps periodically. We re-apply every second.

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 1.0, repeating: 1.0)
        t.setEventHandler { [weak self] in
            guard let self = self, self.isActive else { return }
            self.applyToDisplays()
        }
        t.resume()
        timer = t
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Display reconfiguration callback

    private func registerDisplayCallback() {
        CGDisplayRegisterReconfigurationCallback(displayReconfigCallback, nil)
    }

    private func unregisterDisplayCallback() {
        CGDisplayRemoveReconfigurationCallback(displayReconfigCallback, nil)
    }
}

// C-function callback for display reconfiguration
private func displayReconfigCallback(
    display: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags,
    userInfo: UnsafeMutableRawPointer?
) {
    if !flags.contains(.beginConfigurationFlag) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            GammaEngine.shared.reapply()
        }
    }
}


// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var toggleItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = makeIcon(active: false)
            button.image?.isTemplate = true
        }

        // Build menu
        menu = NSMenu()

        // Toggle item
        toggleItem = NSMenuItem(title: "Enable Darkroom", action: #selector(toggleDarkroom), keyEquivalent: "d")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(title: "About RedScreen", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit RedScreen", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Set up menu delegate to sync state when menu opens
        menu.delegate = self
    }

    func applicationWillTerminate(_ notification: Notification) {
        GammaEngine.shared.deactivate()
    }

    // MARK: - Actions

    @objc func toggleDarkroom() {
        GammaEngine.shared.toggle()
        updateMenuState()
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "RedScreen"
        alert.informativeText = """
            Darkroom mode for macOS.

            Turns your display red-on-black by manipulating \
            the display gamma curves.
	    
            Uses CGSetDisplayTransferByTable to zero out \
            green/blue channels and invert the red channel.

            Public domain.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        // Bring app to front for the alert
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc func quitApp() {
        GammaEngine.shared.deactivate()
        NSApp.terminate(nil)
    }

    // MARK: - UI State

    private func updateMenuState() {
        let active = GammaEngine.shared.isActive
        toggleItem.title = active ? "✓ Darkroom Enabled" : "Enable Darkroom"

        if let button = statusItem.button {
            button.image = makeIcon(active: active)
            button.image?.isTemplate = !active
        }
    }

    /// Create a simple status bar icon.
    /// When inactive: a circle outline (template image, adapts to dark/light mode).
    /// When active: a filled red circle.
    private func makeIcon(active: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: 3, dy: 3)

            if active {
                NSColor.red.setFill()
                NSBezierPath(ovalIn: inset).fill()
            } else {
                NSColor.black.setStroke()
                let path = NSBezierPath(ovalIn: inset.insetBy(dx: 0.5, dy: 0.5))
                path.lineWidth = 1.5
                path.stroke()
            }
            return true
        }

        return image
    }
}

// MARK: - Menu Delegate (sync state when menu opens)

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateMenuState()
    }
}


// MARK: - Main Entry Point

// Set up as a proper accessory app (no dock icon, just menu bar)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
