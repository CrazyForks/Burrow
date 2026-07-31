//
//  CrashReporter.swift
//  Burrow
//
//  Crash + error reporting, via Sentry. For a tool that runs destructive
//  cleans/purges, "did it crash on someone" is at least as valuable as usage
//  analytics — a crash mid-delete is the thing we most need to hear about.
//
//  Same privacy posture as `Telemetry`:
//    * Gated on the shared `Store.telemetryEnabled` opt-in (the one Settings
//      switch covers both PostHog and Sentry).
//    * Inert without a DSN. The Sentry DSN is injected at release time
//      (Info.plist `SentryDSN`); dev builds ship it empty → no reporting.
//    * No PII: `sendDefaultPii` off, no screenshots, no performance tracing —
//      just crash/error events.
//
//  Runtime toggle is start/stop: Sentry has no live "mute" flag, so opting out
//  calls `SentrySDK.close()` and opting back in re-`start`s it.
//

import Foundation
import AppKit
import Sentry

enum CrashReporter {

    /// Whether the SDK is currently running (started and not closed).
    private static var running = false

    /// Run a synchronous, USER-PACED block (a modal confirm, an auth prompt)
    /// without Sentry's app-hang monitor flagging the expected main-thread
    /// block as an ANR. A person reading an NSAlert for >2 s is not a defect —
    /// the genuine render-path hangs we care about don't go through here. No-op
    /// when the SDK isn't running (dev builds / opted out).
    @discardableResult
    static func withoutAppHangTracking<T>(_ body: () -> T) -> T {
        guard running else { return body() }
        SentrySDK.pauseAppHangTracking()
        defer { SentrySDK.resumeAppHangTracking() }
        return body()
    }

    private static var dsn: String {
        (Bundle.main.infoDictionary?["SentryDSN"] as? String) ?? ""
    }

    /// Start at launch if opted in and a DSN is configured. No-op otherwise.
    static func start(enabled: Bool) {
        guard enabled, !dsn.isEmpty, !running else { return }
        startSDK()
    }

    /// Follow the shared opt-in switch: start when enabled, close when not.
    static func setEnabled(_ enabled: Bool) {
        guard !dsn.isEmpty else { return }
        if enabled, !running {
            startSDK()
        } else if !enabled, running {
            SentrySDK.close()
            running = false
        }
    }

    private static func startSDK() {
        let dsn = self.dsn
        let release = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = "production"
            options.releaseName = release
            options.tracesSampleRate = 0.0   // crashes/errors only, no perf tracing
            options.sendDefaultPii = false   // never attach IP/user identifiers
            // Session tracking would add a per-launch "release health"
            // beacon — a network ping carrying a persistent install id on
            // every run with zero crashes. TELEMETRY.md promises crash/error
            // events only; keep that promise.
            options.enableAutoSessionTracking = false
            // Crashes/errors only. Turn off auto-instrumentation that could
            // attach request URLs, network activity, or UI breadcrumbs to an
            // event — upholds the "no PII, no URLs" promise in TELEMETRY.md.
            options.enableNetworkTracking = false
            options.enableNetworkBreadcrumbs = false
            options.enableCaptureFailedRequests = false
            options.enableAutoBreadcrumbTracking = false
            options.enableMetrics = false
            // App-hang (ANR) detection stays ON (SDK default). For a
            // disk-I/O- and render-heavy app a ≥2 s main-thread freeze is a
            // real defect, not noise — it's how we caught a genuine SwiftUI
            // layout hang in the Analyze treemap (Sentry BURROW-1/2). The
            // earlier worry was that modal confirms (NSAlert.runModal, Touch
            // ID) would trip false positives, but the reported hangs were all
            // in the render path, not modals. If a specific modal ever does
            // trip one, wrap that call site in
            // SentrySDK.pauseAppHangTracking()/resumeAppHangTracking() rather
            // than disabling detection app-wide.
            // Binary-image and frame paths embed /Users/<name>/… whenever
            // the app runs from Downloads, a home-dir checkout, or another
            // manually relocated path. Scrub the username; the rest of the
            // path is the diagnostic part.
            options.beforeSend = { event in
                scrubUserPaths(event)
                // App-hang (ANR) events fan out badly: one main-thread freeze
                // gets fingerprinted by whatever frame the sampler caught
                // (malloc/swift_retain/layout internals), exploding a single
                // hang into dozens of distinct issues that drained the whole
                // error quota (all 81 issues were "App hanging"). Collapse them
                // into one issue and sample the volume down so a hang storm
                // can't exhaust the quota again — we only need to know that
                // hangs are happening, not to log every event of the same one.
                if isAppHang(event) {
                    event.fingerprint = ["burrow-app-hang"]
                    if Double.random(in: 0..<1) >= appHangKeepRate { return nil }
                }
                // Drop App-Hang (ANR) reports from acutely memory-starved
                // machines: a ≥2 s main-thread stall when the system has only
                // tens of MB free is the OS thrashing the render/display commit
                // (these dominate the ANR feed from a few RAM-starved macOS 27
                // betas), not a Burrow defect. Real hangs on healthy machines
                // still report.
                if isMemoryStarvedAppHang(event) { return nil }
                return event
            }
        }
        running = true
    }

    /// Fraction of App Hang events kept after fingerprint-collapse. Enough to
    /// confirm hangs are still happening without letting a burst drain quota.
    private static let appHangKeepRate = 0.05

    /// True for Sentry app-hang (ANR) events. The Cocoa SDK tags them with an
    /// exception mechanism whose `type` begins with "AppHang" (V1 "AppHang",
    /// V2 "AppHangFullyBlocked"/"AppHangNonFullyBlocked") and an exception
    /// `type` of "App Hanging".
    private static func isAppHang(_ event: Event) -> Bool {
        (event.exceptions ?? []).contains { ex in
            (ex.mechanism?.type.hasPrefix("AppHang") ?? false)
                || ex.type == "App Hanging"
        }
    }

    /// Replace `/Users/<name>` with a placeholder in every path-bearing
    /// field a crash event carries (loaded images + stack frames).
    private static func scrubUserPaths(_ event: Event) {
        func redact(_ s: String?) -> String? {
            s?.replacingOccurrences(of: "/Users/[^/]+", with: "/Users/REDACTED",
                                    options: .regularExpression)
        }
        event.debugMeta?.forEach { $0.codeFile = redact($0.codeFile) }
        let stacktraces = (event.exceptions?.compactMap { $0.stacktrace } ?? [])
            + (event.threads?.compactMap { $0.stacktrace } ?? [])
        for st in stacktraces {
            for frame in st.frames {
                frame.package = redact(frame.package)
                frame.fileName = redact(frame.fileName)
            }
        }
    }

    /// True for an App-Hang event whose device reports critically low free
    /// memory (< 150 MB). At that point a ≥2 s main-thread freeze is the system
    /// thrashing the render/display commit under memory pressure — not a Burrow
    /// defect — and these dominate the ANR feed from a handful of RAM-starved
    /// machines (notably macOS 27 betas). Healthy machines still report hangs.
    /// Conservative: if free memory can't be read, the event is kept.
    private static func isMemoryStarvedAppHang(_ event: Event) -> Bool {
        let isAppHang = event.exceptions?.contains {
            ($0.mechanism?.type ?? "").hasPrefix("AppHang")
        } ?? false
        guard isAppHang else { return false }
        guard let free = (event.context?["device"]?["free_memory"] as? NSNumber)?.int64Value
        else { return false }
        return free < 150 * 1024 * 1024
    }
}

extension NSAlert {
    /// `runModal()` that pauses Sentry app-hang tracking for the duration —
    /// a user deciding at a confirm dialog blocks the main thread by design
    /// and must not be reported as an ANR (the cause of the modal-class
    /// "App Hanging" Sentry issues, e.g. the Touch ID toggle confirm).
    @discardableResult
    func runModalQuiet() -> NSApplication.ModalResponse {
        CrashReporter.withoutAppHangTracking { runModal() }
    }
}
