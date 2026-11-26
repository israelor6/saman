import AppKit
import ApplicationServices

struct Selection {
    let text: TranslationText
    let bounds: CGRect?
}

/// Access to foreign applications is serialized off the UI thread.
final class SelectionReader: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.saman.accessibility", qos: .userInitiated)
    private let system = AXUIElementCreateSystemWide()
    private var preparedProcess: pid_t?

    func prepare(pid: pid_t, bundleID: String?) {
        guard let bundleID, Self.chromiumApplications.contains(bundleID) else { return }
        queue.async {
            guard self.preparedProcess != pid else { return }
            self.preparedProcess = pid
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.15)
            // Chromium initializes its web accessibility tree on this request.
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
    }

    func read(pid: pid_t, point: CGPoint, preferHit: Bool, pair: LanguagePair) async -> Selection? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.readSelection(pid: pid, point: point, preferHit: preferHit, pair: pair))
            }
        }
    }

    private func readSelection(pid: pid_t, point: CGPoint, preferHit: Bool, pair: LanguagePair) -> Selection? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        AXUIElementSetMessagingTimeout(system, 0.15)

        let focused = element(attribute(app, kAXFocusedUIElementAttribute))
        var hit: AXUIElement?
        AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit)
        if let candidate = hit {
            var hitPID: pid_t = 0
            if AXUIElementGetPid(candidate, &hitPID) != .success || hitPID != pid { hit = nil }
        }

        var visited: [AXUIElement] = []
        let candidates = preferHit ? [hit, focused] : [focused, hit]
        for candidate in candidates {
            var cursor = candidate
            for _ in 0..<16 {
                guard let item = cursor, !visited.contains(where: { CFEqual($0, item) }) else { break }
                visited.append(item)
                let role = attribute(item, kAXRoleAttribute) as? String
                if role == kAXApplicationRole || role == kAXWindowRole { break }
                if attribute(item, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole { return nil }
                if let selection = selection(in: item, pair: pair) { return selection }
                cursor = element(attribute(item, kAXParentAttribute))
            }
        }
        return nil
    }

    private func selection(in item: AXUIElement, pair: LanguagePair) -> Selection? {
        if let text = TranslationText(attribute(item, kAXSelectedTextAttribute) as? String, pair: pair) {
            if let range = attribute(item, kAXSelectedTextRangeAttribute),
               let bounds = rectangle(parameter(item, kAXBoundsForRangeParameterizedAttribute, range)) {
                return Selection(text: text, bounds: bounds)
            }
            return Selection(text: text, bounds: markerSelection(in: item, pair: pair)?.bounds)
        }
        return markerSelection(in: item, pair: pair)
    }

    private func markerSelection(in item: AXUIElement, pair: LanguagePair) -> Selection? {
        // Safari and Chromium can expose document selections as text-marker ranges.
        guard let range = attribute(item, "AXSelectedTextMarkerRange"),
              let text = TranslationText(parameter(item, "AXStringForTextMarkerRange", range) as? String, pair: pair)
        else { return nil }
        return Selection(text: text, bounds: rectangle(parameter(item, "AXBoundsForTextMarkerRange", range)))
    }

    private func attribute(_ item: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, name as CFString, &value) == .success else { return nil }
        return value
    }

    private func parameter(_ item: AXUIElement, _ name: String, _ parameter: CFTypeRef) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(item, name as CFString, parameter, &value) == .success
        else { return nil }
        return value
    }

    private func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func rectangle(_ value: CFTypeRef?) -> CGRect? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        var bounds = CGRect.zero
        guard AXValueGetType(axValue) == .cgRect, AXValueGetValue(axValue, .cgRect, &bounds),
              !bounds.isEmpty, bounds.minX.isFinite, bounds.minY.isFinite,
              bounds.maxX.isFinite, bounds.maxY.isFinite
        else { return nil }
        return bounds
    }

    private static let chromiumApplications: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser",
        "org.chromium.Chromium", "com.vivaldi.Vivaldi", "com.operasoftware.Opera"
    ]
}
