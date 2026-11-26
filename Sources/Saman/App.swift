import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI
import Translation

@main
@MainActor
struct Saman {
    static func main() {
        if CommandLine.arguments.contains("--check") {
            Task {
                do {
                    try await runChecks()
                    exit(0)
                } catch {
                    FileHandle.standardError.write(Data("Check failed: \(error)\n".utf8))
                    exit(1)
                }
            }
            dispatchMain()
        }

        let app = NSApplication.shared
        let delegate = AppController()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    private static func runChecks() async throws {
        precondition(TranslationText("  Hello, שלום! \n")?.value == "Hello, שלום!")
        precondition(TranslationText("המשפט כולל iMessage")?.source == .hebrew)
        precondition(TranslationText("English with café and שלום")?.source == .english)
        precondition(TranslationText("שָׁלוֹם")?.source == .hebrew)
        precondition(TranslationText("abc אבג")?.source == .english)
        precondition(TranslationText("123 🎉 \n") == nil)

        let screen = CGRect(x: -1000, y: 300, width: 1000, height: 800)
        let size = CGSize(width: 400, height: 310)
        for anchor in [CGPoint(x: -10, y: 310), CGPoint(x: -1000, y: 1098), CGPoint(x: -450, y: 750)] {
            let origin = Overlay.origin(for: size, anchor: anchor, screen: screen)
            precondition(screen.insetBy(dx: 8, dy: 8).contains(CGRect(origin: origin, size: size)))
        }

        let line = CGRect(x: -700, y: 650, width: 200, height: 18)
        let rightIcon = Overlay.iconFrame(near: CGPoint(x: -498, y: 659), selectionBounds: line, screen: screen)
        precondition(rightIcon.minX == line.maxX + 3 && rightIcon.midY == line.midY)
        let leftIcon = Overlay.iconFrame(near: CGPoint(x: -703, y: 659), selectionBounds: line, screen: screen)
        precondition(leftIcon.maxX == line.minX - 3 && leftIcon.midY == line.midY)
        let belowIcon = Overlay.iconFrame(near: CGPoint(x: -600, y: 657), selectionBounds: line, screen: screen)
        precondition(belowIcon.maxY == line.minY - 3 && belowIcon.midX == line.midX)
        let edge = CGRect(x: -195, y: 308, width: 185, height: 18)
        let edgeIcon = Overlay.iconFrame(near: CGPoint(x: -10, y: 316), selectionBounds: edge, screen: screen)
        precondition(edgeIcon.minY == edge.maxY + 3 && screen.contains(edgeIcon))
        let pointer = CGPoint(x: -450, y: 750)
        let fallback = Overlay.iconFrame(near: pointer, selectionBounds: nil, screen: screen)
        precondition(fallback.minX == pointer.x + 3 && fallback.midY == pointer.y)

        let files = FileManager.default
        let scratch = files.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let applications = scratch.appendingPathComponent("Applications", isDirectory: true)
        let sourceBundle = Bundle.main.bundleURL
        let installed = applications.appendingPathComponent(sourceBundle.lastPathComponent, isDirectory: true)
        try files.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: scratch) }
        precondition(!AppInstallation.isInstalled(sourceBundle, in: [applications]))
        try AppInstallation.copy(sourceBundle, to: installed)
        precondition(AppInstallation.isInstalled(installed, in: [applications]))
        precondition(Bundle(url: installed)?.bundleIdentifier == Bundle.main.bundleIdentifier)
        do {
            try AppInstallation.copy(sourceBundle, to: installed)
            throw CheckError("Installation replaced an existing application.")
        } catch let error as CocoaError where error.code == .fileWriteFileExists {
            precondition(Bundle(url: installed)?.bundleIdentifier == Bundle.main.bundleIdentifier)
        }

        let spanish = TranslationLanguage(id: "es")
        let spanishEnglish = LanguagePair(first: .english, second: spanish)
        precondition(TranslationText("Esta mañana hay un tren a Madrid.", pair: spanishEnglish)?.target == .english)
        precondition(TranslationText("The station opens early.", pair: spanishEnglish)?.target == spanish)
        precondition(TranslationText("La estación abre temprano.", pair: spanishEnglish)?.reversed.target == spanish)
        let languages: [TranslationLanguage] = [.english, .hebrew, spanish]
        precondition(InterfaceLanguage.preferred(from: ["he-IL", "en-US"]).layoutDirection == .rightToLeft)
        precondition(InterfaceLanguage.preferred(from: ["en-GB", "he-IL"]).layoutDirection == .leftToRight)
        precondition(InterfaceLanguage.preferred(from: ["es-ES", "he-IL"]) == .spanish)
        precondition(InterfaceLanguage.preferred(from: ["fr-FR", "es-MX"]).layoutDirection == .leftToRight)
        precondition(InterfaceLanguage.preferred(from: ["fr-FR", "es-MX"]) == .spanish)
        precondition(InterfaceLanguage.preferred(from: ["fr-FR"]) == .english)
        precondition(InterfaceLanguage.english.string("app.name") == "Saman")
        precondition(InterfaceLanguage.hebrew.string("app.name") == "סמן")
        precondition(InterfaceLanguage.spanish.string("app.language.name") == "Español")
        precondition(InterfaceLanguage.spanish.string("menu.settings") == "Ajustes…")
        precondition(LanguagePair.suggested(for: "en-GB", from: languages) == .standard)
        precondition(LanguagePair.suggested(for: "he-IL", from: languages).ids == ["he", "en"])
        precondition(LanguagePair.suggested(for: "es-MX", from: languages).ids == ["es", "en"])
        precondition(LanguagePair.suggested(for: "is-IS", from: [.hebrew, .english]) == .standard)
        let suite = "Saman.Check.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suite) {
            defer { defaults.removePersistentDomain(forName: suite) }
            precondition(LanguagePair.saved(in: defaults) == nil)
            spanishEnglish.save(in: defaults)
            precondition(LanguagePair.saved(in: defaults) == spanishEnglish)
            precondition(InterfaceLanguagePreference.saved(in: defaults) == .system)
            InterfaceLanguagePreference.hebrew.save(in: defaults)
            precondition(InterfaceLanguagePreference.saved(in: defaults).resolve(preferredLanguages: ["en-US"]) == .hebrew)
            InterfaceLanguagePreference.english.save(in: defaults)
            precondition(InterfaceLanguagePreference.saved(in: defaults).resolve(preferredLanguages: ["he-IL"]) == .english)
            InterfaceLanguagePreference.spanish.save(in: defaults)
            precondition(InterfaceLanguagePreference.saved(in: defaults).resolve(preferredLanguages: ["he-IL"]) == .spanish)
            InterfaceLanguagePreference.system.save(in: defaults)
            precondition(InterfaceLanguagePreference.saved(in: defaults).resolve(preferredLanguages: ["he-IL"]) == .hebrew)
            precondition(InterfaceLanguagePreference.saved(in: defaults).resolve(preferredLanguages: ["es-AR"]) == .spanish)
            precondition(LanguagePair.saved(in: defaults) == spanishEnglish)
        }

        if CommandLine.arguments.contains("--skip-models") {
            print("Geometry, installation, language detection and localization checks passed.")
            return
        }

        let catalog = await LanguagePair.availableLanguages()
        precondition(catalog.contains(.english) && catalog.contains(.hebrew))
        let standardIsSupported = await LanguagePair.standard.supportsBothDirections()
        let duplicatesAreSupported = await LanguagePair(first: .english, second: .english).supportsBothDirections()
        precondition(standardIsSupported && !duplicatesAreSupported)

        let samples: [(TranslationLanguage, [String])] = [
            (.english, ["Hello", "The train arrives at the station at noon."]),
            (.hebrew, ["שלום", "הרכבת מגיעה לתחנה בצהריים."])
        ]
        for (language, examples) in samples {
            let other = language == .english ? TranslationLanguage.hebrew : .english
            let availability = await LanguageAvailability().status(from: language.locale, to: other.locale)
            guard availability == .installed else {
                throw CheckError("Install both system translation languages first. Status for \(language): \(availability).")
            }
            let session = TranslationSession(installedSource: language.locale, target: other.locale)
            for sample in examples {
                guard let text = TranslationText(sample), text.source == language else {
                    throw CheckError("Could not identify the source language of \(sample).")
                }
                let response = try await session.translate(text.value)
                guard TranslationText(response.targetText)?.source == text.target else {
                    throw CheckError("Expected \(text.target) for \(sample). Received: \(response.targetText)")
                }
                print("\(sample) → \(response.targetText)")
            }
        }
        print("Geometry, language detection and Apple Translation checks passed in both directions.")
    }
}

private struct CheckError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

@MainActor
private final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let overlay = Overlay()
    private let preferences = AppPreferences()
    private let reader = SelectionReader()
    private let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menuTitle = NSMenuItem(title: localized("app.name"), action: nil, keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "", action: #selector(requestAccess), keyEquivalent: "")
    private let accessSettingsItem = NSMenuItem(title: "", action: #selector(openAccessSettings), keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "", action: #selector(togglePause), keyEquivalent: "")
    private let shortcutItem = NSMenuItem(title: "", action: #selector(translateFromMenu), keyEquivalent: "")
    private let clipboardItem = NSMenuItem(title: "", action: #selector(translateClipboard), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "", action: #selector(showSettings), keyEquivalent: ",")
    private let aboutItem = NSMenuItem(title: "", action: #selector(showAbout), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "", action: #selector(quitApp), keyEquivalent: "q")
    private var monitors: [Any] = []
    private var permissionTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var pendingRead: Task<Void, Never>?
    private var keyRegistration: EventHotKeyRef?
    private var keyHandler: EventHandlerRef?
    private var handlingInstallation = false
    private var installationWindow: NSWindow?
    private var trusted = false
    private var didRequestAccess = false
    private var pair = LanguagePair.saved() ?? .standard
    private var onboardingWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var mouseDown: CGPoint?
    private var lastExternalPID: pid_t?
    private var menuSourcePID: pid_t?
    private var menuIsOpen = false
    private var gesture: (pid: pid_t, point: CGPoint)?
    private var detectedSelection: (pid: pid_t, value: Selection)?
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    private var frontSourcePID: pid_t? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        return pid == ownPID ? lastExternalPID : pid
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundle = Bundle.main.bundleURL
        let offerKey = "didOfferApplicationsInstallation"
        if !CommandLine.arguments.contains("--preview"),
           LanguagePair.saved() == nil, !UserDefaults.standard.bool(forKey: offerKey),
           !AppInstallation.isInstalled(bundle),
           let destination = AppInstallation.destination(for: bundle),
           !FileManager.default.fileExists(atPath: destination.path) {
            handlingInstallation = true
            UserDefaults.standard.set(true, forKey: offerKey)
            presentInstallOffer(from: bundle, to: destination)
        } else {
            finishLaunching()
        }
    }

    private func presentInstallOffer(from bundle: URL, to destination: URL) {
        let window = utilityWindow(title: localized("app.name"), content: InstallationView(
            directory: destination.deletingLastPathComponent(),
            copy: { [weak self] in self?.copyAndOpenInstallation(from: bundle, to: destination) },
            skip: { [weak self] in self?.installationWindow?.close() }
        ))
        window.delegate = self
        installationWindow = window
        present(window)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === installationWindow else { return }
        installationWindow = nil
        handlingInstallation = false
        Task { @MainActor [weak self] in self?.finishLaunching() }
    }

    private func copyAndOpenInstallation(from bundle: URL, to destination: URL) {
        guard let window = installationWindow else { return }
        window.delegate = nil
        window.close()
        installationWindow = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            if await install(from: bundle, to: destination) {
                NSApp.terminate(nil)
            } else {
                handlingInstallation = false
                finishLaunching()
            }
        }
    }

    private func install(from bundle: URL, to destination: URL) async -> Bool {
        do {
            try AppInstallation.copy(bundle, to: destination)
        } catch {
            let key = (error as? CocoaError)?.code == .fileWriteFileExists ? "install.exists" : "install.copy.failed"
            showInstallMessage(localized(key, destination.path))
            return false
        }

        do {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            configuration.allowsRunningApplicationSubstitution = false
            _ = try await NSWorkspace.shared.openApplication(at: destination, configuration: configuration)
            return true
        } catch {
            showInstallMessage(localized("install.open.failed", destination.path))
            return false
        }
    }

    private func showInstallMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = localized("app.name")
        alert.informativeText = message
        alert.addButton(withTitle: localized("install.ok"))
        alert.runModal()
    }

    private func finishLaunching() {
        lastExternalPID = frontSourcePID
        configureMenu()
        registerShortcut()
        refreshPermission()

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.processIdentifier != self.ownPID
                else { return }
                if self.lastExternalPID != app.processIdentifier {
                    self.lastExternalPID = app.processIdentifier
                    self.clearSelection()
                }
                self.prepareFrontApp()
            }
        }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermission() }
        }

        if CommandLine.arguments.contains("--preview"),
           let example = TranslationText("הרכבת מגיעה לתחנה בצהריים.") {
            overlay.showTranslation(example, near: NSEvent.mouseLocation)
        } else if LanguagePair.saved() == nil {
            showLanguageSetup()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !handlingInstallation { showSettings() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        monitors.forEach(NSEvent.removeMonitor)
        if let keyRegistration { UnregisterEventHotKey(keyRegistration) }
        if let keyHandler { RemoveEventHandler(keyHandler) }
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        menuTitle.isEnabled = false
        for item in [permissionItem, accessSettingsItem, shortcutItem, clipboardItem, settingsItem, aboutItem, pauseItem, quitItem] {
            item.target = self
        }
        [
            menuTitle, .separator(), permissionItem, accessSettingsItem, shortcutItem, clipboardItem, .separator(),
            settingsItem, pauseItem, .separator(), aboutItem, quitItem
        ].forEach(menu.addItem)
        status.menu = menu
        updateMenu()
    }

    @objc private func showSettings() { showLanguageSetup() }

    @objc private func showAbout() {
        if aboutWindow == nil {
            aboutWindow = utilityWindow(title: localized("menu.about"), content: AboutView(preferences: preferences))
        }
        if let aboutWindow { present(aboutWindow) }
    }

    private func utilityWindow<Content: View>(title: String, content: Content) -> NSWindow {
        let hostingView = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.center()
        return window
    }

    private func present(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func changeInterfaceLanguage(to selection: InterfaceLanguagePreference) {
        let previous = preferences.language
        preferences.set(selection)
        guard previous != preferences.language else { return }

        clearSelection()
        overlay.dismiss()
        overlay.updateLocalization()
        onboardingWindow?.title = LanguagePair.saved() == nil ? localized("app.name") : localized("settings.title")
        aboutWindow?.title = localized("menu.about")
        updateMenu()
    }

    private func showLanguageSetup() {
        if let window = onboardingWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        clearSelection()
        overlay.dismiss()
        let isEditing = LanguagePair.saved() != nil
        let size = OnboardingView.windowSize(isEditing: isEditing)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = isEditing ? localized("settings.title") : localized("app.name")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        let hostingView = NSHostingView(rootView: OnboardingView(
            pair: pair,
            preferences: preferences,
            isEditing: isEditing, size: size,
            save: { [weak self] pair in
                self?.pair = pair
                pair.save()
                self?.clearSelection()
                self?.updateMenu()
            },
            selectLanguage: { [weak self] in self?.changeInterfaceLanguage(to: $0) },
            setBubblePaused: { [weak self] in self?.setBubblePaused($0) },
            showAbout: { [weak self] in self?.showAbout() },
            requestAccess: { [weak self] in self?.requestAccess() },
            openAccessSettings: { [weak self] in self?.openAccessSettings() },
            close: { [weak window] in window?.close() }
        ))
        hostingView.safeAreaRegions = []
        window.contentView = hostingView
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        onboardingWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuSourcePID = frontSourcePID
        menuIsOpen = true
        overlay.dismiss()
        refreshPermission()
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
    }

    private func updateMenu() {
        status.button?.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: localized("app.name"))
        status.button?.toolTip = localized("app.tooltip")
        status.button?.setAccessibilityLabel(localized("app.tooltip"))
        status.menu?.userInterfaceLayoutDirection = InterfaceLanguage.current.isRightToLeft ? .rightToLeft : .leftToRight
        settingsItem.title = localized("menu.settings")
        aboutItem.title = localized("menu.about")
        clipboardItem.title = localized("menu.clipboard")
        quitItem.title = localized("menu.quit")
        menuTitle.title = localized("menu.pair", pair.first.displayName, pair.second.displayName)
        permissionItem.title = trusted ? localized("menu.access.active") : localized("menu.access.request")
        permissionItem.isEnabled = !trusted
        accessSettingsItem.title = localized("setup.access.open")
        accessSettingsItem.isHidden = trusted || !didRequestAccess
        shortcutItem.title = keyRegistration == nil ? localized("menu.selection") : localized("menu.selection.shortcut")
        shortcutItem.isEnabled = trusted
        pauseItem.title = preferences.bubblePaused ? localized("menu.resume") : localized("menu.pause")
        pauseItem.isEnabled = trusted
    }

    private func refreshPermission() {
        let accessible = AXIsProcessTrusted()
        guard accessible != trusted else { return }
        trusted = accessible
        updateMenu()

        if accessible {
            installMonitors()
            prepareFrontApp()
        } else {
            monitors.forEach(NSEvent.removeMonitor)
            monitors.removeAll()
            clearSelection()
            overlay.dismiss()
        }
    }

    @objc private func requestAccess() {
        refreshPermission()
        guard !trusted else { return }

        didRequestAccess = true
        updateMenu()
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @objc private func openAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func togglePause() { setBubblePaused(!preferences.bubblePaused) }

    private func setBubblePaused(_ paused: Bool) {
        preferences.setBubblePaused(paused)
        pendingRead?.cancel()
        overlay.dismiss()
        updateMenu()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func translateClipboard() {
        let point = NSEvent.mouseLocation
        if let text = TranslationText(NSPasteboard.general.string(forType: .string), pair: pair) {
            overlay.showTranslation(text, near: point)
        } else {
            overlay.showMessage(localized("message.clipboard.empty"), near: point)
        }
    }

    @objc private func translateFromMenu() {
        translateNow(sourcePID: menuSourcePID ?? frontSourcePID)
    }

    private func translateNow(sourcePID: pid_t? = nil) {
        guard trusted else {
            requestAccess()
            return
        }
        guard let pid = sourcePID ?? frontSourcePID else { return }
        let point = gesture?.pid == pid ? gesture?.point ?? NSEvent.mouseLocation : NSEvent.mouseLocation
        readSelection(near: point, pid: pid, preferHit: false, translateImmediately: true)
    }

    private func prepareFrontApp() {
        guard trusted, let app = NSWorkspace.shared.frontmostApplication else { return }
        reader.prepare(pid: app.processIdentifier, bundleID: app.bundleIdentifier)
    }

    private func installMonitors() {
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .scrollWheel]
        for mask in [mouseEvents, .keyDown] {
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
                MainActor.assumeIsolated { self?.handle(event) }
            }) {
                monitors.append(monitor)
            }
        }
    }

    private func clearSelection() {
        pendingRead?.cancel()
        gesture = nil
        detectedSelection = nil
        overlay.hideIcon()
    }

    private func handleSelectionGesture(at point: CGPoint, preferHit: Bool) {
        guard let pid = frontSourcePID else { return }
        gesture = (pid, point)
        detectedSelection = nil
        // Keep the gesture for the menu even while the floating icon is paused.
        if !preferences.bubblePaused { readSelection(near: point, pid: pid, preferHit: preferHit) }
    }

    private func handle(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        guard !overlay.contains(point) || event.type == .keyDown else { return }

        switch event.type {
        case .leftMouseDown:
            mouseDown = point
            clearSelection()
            overlay.dismiss()
        case .leftMouseUp:
            let start = mouseDown
            mouseDown = nil
            let dragged = start.map { hypot(point.x - $0.x, point.y - $0.y) >= 3 } ?? false
            if dragged || event.clickCount > 1 || event.modifierFlags.contains(.shift) {
                handleSelectionGesture(at: point, preferHit: true)
            }
        case .keyDown:
            let shortcutModifiers: NSEvent.ModifierFlags = [.option, .shift]
            let modifiers = event.modifierFlags.intersection([.option, .shift, .control, .command])
            if keyRegistration != nil && event.keyCode == UInt16(kVK_ANSI_T) && modifiers == shortcutModifiers {
                return
            }
            if event.keyCode == UInt16(kVK_Escape) {
                clearSelection()
                overlay.dismiss()
            } else if !overlay.isShowingResult {
                let selectionKey = event.modifierFlags.contains(.shift)
                    && [115, 116, 119, 121, 123, 124, 125, 126].contains(event.keyCode)
                let selectAll = event.keyCode == UInt16(kVK_ANSI_A) && event.modifierFlags.contains(.command)
                if selectionKey || selectAll {
                    handleSelectionGesture(at: point, preferHit: false)
                } else {
                    clearSelection()
                }
            }
        case .rightMouseDown, .scrollWheel:
            pendingRead?.cancel()
            overlay.hideIcon()
            if event.type == .rightMouseDown {
                clearSelection()
                overlay.dismissResult()
            }
        default:
            break
        }
    }

    private func readSelection(near point: CGPoint, pid: pid_t, preferHit: Bool, translateImmediately: Bool = false) {
        pendingRead?.cancel()
        let axPoint = Overlay.accessibilityPoint(point)
        let pair = self.pair

        pendingRead = Task { [weak self] in
            guard let self else { return }
            // Event monitors receive the gesture before the source app updates its selection.
            try? await Task.sleep(for: .milliseconds(110))
            guard !Task.isCancelled else { return }
            var selection = await reader.read(pid: pid, point: axPoint, preferHit: preferHit, pair: pair)
            if selection == nil && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(160))
                guard !Task.isCancelled else { return }
                selection = await reader.read(pid: pid, point: axPoint, preferHit: preferHit, pair: pair)
            }
            guard !Task.isCancelled, frontSourcePID == pid else { return }
            if translateImmediately {
                // Some applications stop exposing the selection while the status menu is active.
                if selection == nil, detectedSelection?.pid == pid {
                    selection = detectedSelection?.value
                }
                if let selection {
                    overlay.showTranslation(selection.text, near: keyboardAnchor(for: selection, fallback: point))
                } else {
                    overlay.showMessage(localized("message.selection.empty"), near: point)
                }
            } else if let selection {
                detectedSelection = (pid, selection)
                guard !menuIsOpen else { return }
                let anchor = preferHit ? point : keyboardAnchor(for: selection, fallback: point)
                overlay.showIcon(near: anchor, selectionBounds: selection.bounds) { [weak self] in
                    self?.overlay.showTranslation(selection.text)
                }
            }
        }
    }

    private func keyboardAnchor(for selection: Selection, fallback: CGPoint) -> CGPoint {
        guard let bounds = selection.bounds else { return fallback }
        let point = Overlay.accessibilityPoint(CGPoint(x: bounds.minX, y: bounds.maxY))
        return NSScreen.screens.contains { $0.frame.contains(point) } ? point : fallback
    }

    private func registerShortcut() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<AppController>.fromOpaque(context).takeUnretainedValue().translateNow()
            }
            return noErr
        }, 1, &event, context, &keyHandler)
        guard handlerStatus == noErr else { return }

        let id = EventHotKeyID(signature: OSType(0x53414D4E), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_T), UInt32(optionKey | shiftKey), id,
                            GetApplicationEventTarget(), 0, &keyRegistration)
        updateMenu()
    }
}
