import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import SwiftUI

private enum PickerSlot { case first, second }

@MainActor
private final class SetupState: ObservableObject {
    @Published var first: TranslationLanguage
    @Published var second: TranslationLanguage?
    @Published private(set) var languages: [TranslationLanguage] = []
    @Published private(set) var partners: [TranslationLanguage] = []
    @Published private(set) var checkedLanguage: TranslationLanguage?
    @Published private(set) var loadedCatalog = false
    @Published var hasAppeared = false
    @Published var activePicker: PickerSlot?
    @Published var query = ""
    @Published var showsPermission = false
    @Published var requestedAccess = false
    @Published var hasAccess: Bool
    @Published var savedPair: LanguagePair
    @Published private(set) var loginStatus: SMAppService.Status = .notRegistered
    @Published private(set) var loginError = false

    private var preferredSecond: TranslationLanguage
    private let isEditing: Bool

    init(pair: LanguagePair, isEditing: Bool) {
        self.isEditing = isEditing
        first = pair.first
        second = pair.second
        preferredSecond = pair.second
        hasAccess = AXIsProcessTrusted()
        savedPair = pair
        if isEditing { refreshLoginItem() }
    }

    var opensAtLogin: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }

    func refreshLoginItem() {
        loginStatus = SMAppService.mainApp.status
    }

    func setOpenAtLogin(_ enabled: Bool) {
        guard enabled != opensAtLogin else { return }
        loginError = false
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginError = true
        }
        refreshLoginItem()
        if loginStatus == .requiresApproval { loginError = false }
    }

    var validPair: LanguagePair? {
        guard first == checkedLanguage, let second, partners.contains(second) else { return nil }
        return LanguagePair(first: first, second: second)
    }

    func loadPartners(for language: TranslationLanguage) async {
        if !loadedCatalog {
            let catalog = await LanguagePair.availableLanguages()
            guard !Task.isCancelled else { return }
            languages = catalog
            loadedCatalog = true
            guard !catalog.isEmpty else { return }
            if !isEditing {
                let suggestion = LanguagePair.suggested(for: Locale.preferredLanguages.first, from: catalog)
                preferredSecond = suggestion.second
                second = suggestion.second
                if first != suggestion.first {
                    first = suggestion.first
                    return
                }
            } else if !catalog.contains(first), let replacement = catalog.first {
                first = catalog.first { $0.baseCode == first.baseCode } ?? replacement
                return
            }
        }

        guard first == language else { return }
        checkedLanguage = nil
        let candidates = languages.filter { $0 != language }
        let supported = await withTaskGroup(of: TranslationLanguage?.self) { group in
            for candidate in candidates {
                group.addTask {
                    guard !Task.isCancelled,
                          await LanguagePair(first: language, second: candidate).supportsBothDirections() else { return nil }
                    return candidate
                }
            }
            var result = Set<TranslationLanguage>()
            for await candidate in group {
                if let candidate { result.insert(candidate) }
            }
            return result
        }

        guard !Task.isCancelled, first == language else { return }
        partners = candidates.filter { supported.contains($0) }
        if second.map(supported.contains) != true {
            second = supported.contains(preferredSecond) ? preferredSecond : partners.first
        }
        checkedLanguage = language
    }
}

@MainActor
struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var state: SetupState
    private let isEditing: Bool
    @ObservedObject var preferences: AppPreferences
    private var language: InterfaceLanguage { preferences.language }
    private let size: CGSize
    private let save: (LanguagePair) -> Void
    private let selectLanguage: (InterfaceLanguagePreference) -> Void
    private let setBubblePaused: (Bool) -> Void
    private let showAbout: () -> Void
    private let requestAccess: () -> Void
    private let openAccessSettings: () -> Void
    private let close: () -> Void
    private let ink = Color(red: 0.12, green: 0.11, blue: 0.23)
    private let violet = Color(red: 0.31, green: 0.26, blue: 0.79)
    private let observer = Timer.publish(every: 0.7, on: .main, in: .common).autoconnect()

    static func windowSize(isEditing: Bool) -> CGSize {
        guard isEditing else { return CGSize(width: 714, height: 446) }
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? 760
        return CGSize(width: 754, height: min(660, visibleHeight - 36))
    }

    init(pair: LanguagePair, preferences: AppPreferences, isEditing: Bool, size: CGSize,
         save: @escaping (LanguagePair) -> Void,
         selectLanguage: @escaping (InterfaceLanguagePreference) -> Void,
         setBubblePaused: @escaping (Bool) -> Void, showAbout: @escaping () -> Void,
         requestAccess: @escaping () -> Void, openAccessSettings: @escaping () -> Void, close: @escaping () -> Void) {
        state = SetupState(pair: pair, isEditing: isEditing)
        self.preferences = preferences
        self.isEditing = isEditing
        self.save = save
        self.size = size
        self.selectLanguage = selectLanguage
        self.setBubblePaused = setBubblePaused
        self.showAbout = showAbout
        self.requestAccess = requestAccess
        self.openAccessSettings = openAccessSettings
        self.close = close
    }

    var body: some View {
        HStack(spacing: 0) {
            identity
                .frame(width: 236)
            VStack(alignment: .leading, spacing: 17) {
                if isEditing {
                    settings
                } else if state.showsPermission {
                    permission.transition(stepTransition)
                } else {
                    languages.transition(stepTransition)
                }
            }
            .opacity(state.hasAppeared ? 1 : 0)
            .offset(x: state.hasAppeared || reduceMotion ? 0 : (language.isRightToLeft ? -12 : 12))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.44).delay(0.10), value: state.hasAppeared)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: state.showsPermission)
            .padding(.horizontal, isEditing ? 0 : 34)
            .padding(.vertical, isEditing ? 0 : 38)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .foregroundStyle(ink)
            .background(Color(red: 0.98, green: 0.97, blue: 0.94))
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .light)
        .environment(\.layoutDirection, language.layoutDirection)
        .environment(\.locale, language.locale)
        .task {
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(65))
            }
            guard !Task.isCancelled else { return }
            state.hasAppeared = true
        }
        .task(id: state.first) { [first = state.first] in
            await state.loadPartners(for: first)
        }
        .onReceive(observer) { _ in state.hasAccess = AXIsProcessTrusted() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if isEditing { state.refreshLoginItem() }
        }
    }

    private var stepTransition: AnyTransition {
        reduceMotion ? .identity : .opacity.combined(with: .offset(x: language.isRightToLeft ? -8 : 8))
    }

    private var identity: some View {
        VStack(spacing: 13) {
            emblem
            Text(localized("app.name"))
                .font(.system(size: 49, weight: .heavy))
                .tracking(-1.5)
                .foregroundStyle(.white)
            Text(localized("setup.tagline"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.77, green: 0.76, blue: 0.90))
        }
        .opacity(state.hasAppeared ? 1 : 0)
        .offset(y: state.hasAppeared || reduceMotion ? 0 : 10)
        .animation(reduceMotion ? nil : .spring(response: 0.63, dampingFraction: 0.82), value: state.hasAppeared)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(colors: [Color(red: 0.16, green: 0.13, blue: 0.34), ink],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

        }
        .clipped()
    }

    private var emblem: some View {
        let orbitRadius: CGFloat = 64
        let sweep = 0.78
        let startAngle = 90 + (1 - sweep) * 180
        let endAngle = startAngle + sweep * 360

        return ZStack {
            Circle()
                .trim(from: 0, to: state.hasAppeared ? sweep : 0)
                .stroke(Color(red: 0.57, green: 0.98, blue: 0.83).opacity(0.74),
                        style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                .rotationEffect(.degrees(startAngle))
                .frame(width: orbitRadius * 2, height: orbitRadius * 2)
            orbitDot(radius: orbitRadius, angle: startAngle)
            orbitDot(radius: orbitRadius, angle: state.hasAppeared ? endAngle : startAngle)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 112, height: 112)
                .scaleEffect(state.hasAppeared || reduceMotion ? 1 : 0.78)
        }
        .frame(width: 144, height: 144)
        .background {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for radius in [78.0, 112.0, 154.0, 198.0] {
                    let ring = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.stroke(Path(ellipseIn: ring), with: .color(.white.opacity(0.09)), lineWidth: 1)
                }
            }
            .frame(width: 400, height: 400)
            .allowsHitTesting(false)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    private func orbitDot(radius: CGFloat, angle: Double) -> some View {
        Circle()
            .fill(Color(red: 0.60, green: 1, blue: 0.85))
            .frame(width: 5, height: 5)
            .shadow(color: .mint.opacity(0.55), radius: 6)
            .offset(x: radius)
            .rotationEffect(.degrees(angle))
            .opacity(state.hasAppeared ? 1 : 0)
    }

    private var languages: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                Text(localized("setup.title"))
                    .font(.system(size: 32, weight: .bold))
                Text(localized("setup.description"))
                    .font(.system(size: 14))
                    .foregroundStyle(ink.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
            languageControls
            availability
            primary(localized("setup.continue"), enabled: state.validPair != nil) {
                guard let pair = state.validPair else { return }
                save(pair)
                if state.hasAccess { close() } else { state.showsPermission = true }
            }
        }
    }

    private var languageControls: some View {
        VStack(spacing: 7) {
            picker(.first, label: localized("setup.first"), value: state.first, options: state.languages) {
                state.first = $0
            }
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(violet)
                .accessibilityHidden(true)
            picker(.second, label: localized("setup.second"), value: state.checkedLanguage == state.first ? state.second : nil,
                   options: state.checkedLanguage == state.first ? state.partners : []) {
                state.second = $0
            }
        }
    }

    private var availability: some View {
        Group {
            if !state.loadedCatalog || (!state.languages.isEmpty && state.checkedLanguage != state.first) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(localized("setup.checking"))
                }
            } else if state.validPair != nil {
                Label(localized("setup.available"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color(red: 0.16, green: 0.43, blue: 0.33))
            } else {
                Text(localized("setup.unavailable"))
            }
        }
        .font(.system(size: 12, weight: .medium))
        .frame(minHeight: 17)
    }

    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text(localized("settings.title"))
                    .font(.system(size: 33, weight: .bold))
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 9) {
                    sectionTitle("setup.edit.title")
                    languageControls
                    HStack(spacing: 12) {
                        availability
                        Spacer(minLength: 0)
                        let changed = state.validPair.map { $0 != state.savedPair } ?? false
                        Button {
                            guard let pair = state.validPair else { return }
                            save(pair)
                            state.savedPair = pair
                        } label: {
                            Text(localized("setup.save"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(changed ? .white : ink.opacity(0.55))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(changed ? violet : ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!changed)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("settings.general")
                    Text(localized("settings.language.title"))
                        .font(.system(size: 13, weight: .medium))
                    interfacePicker
                    loginSetting
                    Toggle(localized("settings.bubble"), isOn: Binding(
                        get: { !preferences.bubblePaused },
                        set: { setBubblePaused(!$0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(violet)
                }

                Divider()

                HStack {
                    sectionTitle("settings.access")
                    Spacer(minLength: 6)
                    if state.hasAccess {
                        Label(localized("menu.access.active"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 0.16, green: 0.43, blue: 0.33))
                            .font(.system(size: 12, weight: .medium))
                    } else if state.requestedAccess {
                        Button(localized("setup.access.open"), action: openAccessSettings)
                    } else {
                        Button(localized("menu.access.request")) {
                            state.requestedAccess = true
                            requestAccess()
                        }
                    }
                }
                Button(localized("menu.about"), action: showAbout)
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 31)
        }
        .defaultScrollAnchor(.top)
    }

    private var interfacePicker: some View {
        HStack(spacing: 4) {
            ForEach(InterfaceLanguagePreference.allCases) { option in
                let selected = preferences.selection == option
                Button {
                    selectLanguage(option)
                } label: {
                    Text(option.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected ? .white : ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 29)
                        .background {
                            if selected { RoundedRectangle(cornerRadius: 7).fill(violet) }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localized("settings.language.title"))
    }

    private var loginSetting: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(isOn: Binding(get: { state.opensAtLogin }, set: { state.setOpenAtLogin($0) })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("settings.login"))
                        .font(.system(size: 13, weight: .medium))
                    Text(localized("settings.login.details"))
                        .font(.system(size: 12))
                        .foregroundStyle(ink.opacity(0.72))
                }
            }
            .toggleStyle(.switch)
            .tint(violet)
            .accessibilityLabel(localized("settings.login"))
            if state.loginError || state.loginStatus == .requiresApproval {
                Text(state.loginError ? localized("settings.login.error") : localized("settings.login.approval"))
                    .font(.system(size: 12))
                    .foregroundStyle(ink.opacity(0.72))
                Button(localized("settings.login.open")) { SMAppService.openSystemSettingsLoginItems() }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            }
        }
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(localized(key))
            .font(.system(size: 16, weight: .semibold))
            .accessibilityAddTraits(.isHeader)
    }

    private var permission: some View {
        Group {
            Image(systemName: state.hasAccess ? "checkmark.circle.fill" : "cursorarrow.rays")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(violet)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(state.hasAccess ? localized("setup.ready.title") : localized("setup.access.title"))
                    .font(.system(size: 32, weight: .bold))
                Text(state.hasAccess
                     ? localized("setup.ready.description")
                     : localized("setup.access.description"))
                    .font(.system(size: 14))
                    .foregroundStyle(ink.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
            primary(state.hasAccess ? localized("setup.done") : localized("menu.access.request")) {
                if state.hasAccess {
                    close()
                } else {
                    state.requestedAccess = true
                    requestAccess()
                }
            }
            if !state.hasAccess {
                HStack(spacing: 18) {
                    Button(localized("setup.later")) { close() }
                        .help(localized("setup.later.help"))
                    if state.requestedAccess {
                        Button(localized("setup.access.open"), action: openAccessSettings)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(violet)
            }
        }
    }

    private func picker(_ slot: PickerSlot, label: String, value: TranslationLanguage?,
                        options: [TranslationLanguage], choose: @escaping (TranslationLanguage) -> Void) -> some View {
        Button {
            state.query = ""
            state.activePicker = slot
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ink.opacity(0.72))
                Spacer()
                Text(value?.displayName ?? localized("setup.choose"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ink)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(violet)
            }
            .padding(.horizontal, 15)
            .frame(height: 49)
            .background(.white, in: RoundedRectangle(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11).strokeBorder(
                    state.activePicker == slot ? violet : ink.opacity(0.14)
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(options.isEmpty)
        .accessibilityLabel(label)
        .accessibilityValue(value?.displayName ?? localized("setup.none"))
        .popover(isPresented: Binding(
            get: { state.activePicker == slot },
            set: { if !$0 && state.activePicker == slot { state.activePicker = nil } }
        ), arrowEdge: .bottom) {
            optionsList(options, value: value) { language in
                state.activePicker = nil
                choose(language)
            }
        }
    }

    private func optionsList(_ options: [TranslationLanguage], value: TranslationLanguage?,
                             choose: @escaping (TranslationLanguage) -> Void) -> some View {
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = options.filter {
            query.isEmpty || $0.displayName.localizedStandardContains(query) || $0.title.localizedStandardContains(query)
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(violet)
                TextField(localized("setup.search"), text: $state.query)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            if matching.isEmpty {
                Text(localized("setup.search.empty"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(matching) { language in
                            Button {
                                choose(language)
                            } label: {
                                HStack {
                                    Text(language.displayName)
                                    Spacer()
                                    if language == value {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(violet)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .background {
                                    if language == value {
                                        RoundedRectangle(cornerRadius: 7).fill(violet.opacity(0.09))
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 270, height: 255)
        .environment(\.layoutDirection, InterfaceLanguage.current.layoutDirection)
        .environment(\.locale, InterfaceLanguage.current.locale)
    }

    private func primary(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(violet.opacity(enabled ? 1 : 0.48), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
