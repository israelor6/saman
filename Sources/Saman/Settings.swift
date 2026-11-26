import AppKit
import SwiftUI

@MainActor
struct AboutView: View {
    @ObservedObject var preferences: AppPreferences

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return localized("about.version", version, build)
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 98, height: 98)
                .accessibilityHidden(true)
            Text(localized("app.name"))
                .font(.system(size: 31, weight: .heavy))
            Text(versionLabel)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
                .environment(\.layoutDirection, .leftToRight)
            Text(localized("about.description"))
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)
            Label(localized("about.local"), systemImage: "lock")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 5)
        }
        .padding(26)
        .frame(width: 340)
        .environment(\.layoutDirection, preferences.language.layoutDirection)
        .environment(\.locale, preferences.language.locale)
    }
}
