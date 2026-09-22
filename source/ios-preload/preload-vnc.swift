import Foundation

@MainActor
final class IOSVNCPreloadRuntime {
    private var visibilityGate = IOSVNCViewerVisibilityGate()
    private var livenessDetector = IOSVNCLivenessDetector()

    func updateViewerVisibility(_ visible: Bool) -> Bool {
        visibilityGate.update(visible)
    }

    var viewerIsVisible: Bool {
        visibilityGate.visible
    }

    func sampleLiveness(
        nowMilliseconds: Int64,
        counters: IOSVNCLivenessCounters
    ) -> IOSVNCLivenessReport? {
        livenessDetector.sample(nowMilliseconds: nowMilliseconds, counters: counters)
    }

    func resetLiveness() {
        livenessDetector.reset()
    }

    func trustedClipboardPasteScript(text: String) -> String {
        IOSVNCClipboardPaste.buildTrustedNoVNCPasteScript(text: text)
    }

    func resolveClipboardSync(text: String, didPaste: Bool) -> String? {
        IOSVNCClipboardPaste.resolveHostToBoxSync(text: text, didPaste: didPaste)
    }
}
