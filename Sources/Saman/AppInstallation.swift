import Foundation

enum AppInstallation {
    static var applicationDirectories: [URL] {
        let files = FileManager.default
        return [.localDomainMask, .userDomainMask].flatMap {
            files.urls(for: .applicationDirectory, in: $0)
        }
    }

    static func isInstalled(_ bundle: URL, in directories: [URL] = applicationDirectories) -> Bool {
        let path = bundle.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        return directories.contains { location in
            let directory = location.resolvingSymlinksInPath().standardizedFileURL.pathComponents
            return path.count > directory.count && path.starts(with: directory)
        }
    }

    static func destination(for bundle: URL) -> URL? {
        let files = FileManager.default
        return applicationDirectories
            .first { directory in
                if files.fileExists(atPath: directory.path) {
                    return files.isWritableFile(atPath: directory.path)
                }
                return files.isWritableFile(atPath: directory.deletingLastPathComponent().path)
            }
            .map { $0.appendingPathComponent(bundle.lastPathComponent, isDirectory: true) }
    }

    static func copy(_ bundle: URL, to destination: URL) throws {
        let files = FileManager.default
        let directory = destination.deletingLastPathComponent()
        let staging = directory.appendingPathComponent(".saman-install-\(UUID().uuidString)", isDirectory: true)
        let copy = staging.appendingPathComponent(destination.lastPathComponent, isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        try files.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: staging) }

        try files.copyItem(at: bundle, to: copy)
        // Publish only after the entire bundle has been copied. moveItem fails if the destination exists.
        try files.moveItem(at: copy, to: destination)
    }
}

import AppKit
import SwiftUI

@MainActor
struct InstallationView: View {
    let directory: URL
    let copy: () -> Void
    let skip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            Text(localized("install.title"))
                .font(.system(size: 22, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text(localized("install.description", directory.path))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(localized("install.copy"), action: copy)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.31, green: 0.26, blue: 0.79))
                Button(localized("install.skip"), action: skip)
                    .keyboardShortcut(.cancelAction)
            }
            .controlSize(.large)
            .padding(.top, 7)
        }
        .padding(28)
        .frame(width: 402, alignment: .leading)
        .environment(\.layoutDirection, InterfaceLanguage.current.layoutDirection)
        .environment(\.locale, InterfaceLanguage.current.locale)
    }
}
