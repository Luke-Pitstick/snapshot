import AppKit
import ScreenCaptureKit

/// Runs a single capture from start to finish: checks permissions, presents
/// the right UI (region overlay, window picker, or nothing for full screen),
/// invokes the capture service, and hands the result to the `ResultRouter`.
@MainActor
final class CaptureCoordinator {

    private let router: ResultRouter
    private let preferences: Preferences

    /// Kept alive for the duration of an active capture session so their
    /// overlay windows don't disappear when we return from `run`.
    private var regionController: RegionSelectionController?
    private var windowController: WindowPickerController?

    private var isCapturing = false

    /// Tracks whether we've already asked the system to prompt for Screen
    /// Recording access in this launch. The system only ever shows its
    /// prompt once per launch, so on the second attempt (with permission
    /// still missing) we fall back to our own "open Settings" alert.
    private var didRequestPermissionThisLaunch = false

    init(preferences: Preferences, router: ResultRouter) {
        self.preferences = preferences
        self.router = router
    }

    /// Entry point called by hotkeys and menu items.
    ///
    /// `sourceFlags` are the modifier flags present when the invocation
    /// happened (used for the destination override). For menu-item calls
    /// we read the current modifier state via `NSEvent.modifierFlags`.
    func run(_ mode: CaptureMode, sourceFlags: NSEvent.ModifierFlags? = nil) {
        guard !isCapturing else { return }

        guard PermissionsChecker.hasScreenRecordingPermission() else {
            // First attempt this launch: trigger the system prompt and
            // return silently. Don't stack our own alert on top of it —
            // the user needs to interact with the system dialog (and
            // then relaunch), not two competing prompts.
            if !didRequestPermissionThisLaunch {
                didRequestPermissionThisLaunch = true
                _ = PermissionsChecker.requestScreenRecordingPermission()
            } else {
                PermissionsChecker.showPermissionAlert()
            }
            return
        }

        let flags = sourceFlags ?? NSEvent.modifierFlags

        isCapturing = true
        switch mode {
        case .region:     runRegion(flags: flags)
        case .fullScreen: runFullScreen(flags: flags)
        case .window:     runWindow(flags: flags)
        }
    }

    // MARK: - Region

    private func runRegion(flags: NSEvent.ModifierFlags) {
        let controller = RegionSelectionController()
        regionController = controller
        controller.present { [weak self] selection in
            guard let self else { return }
            self.regionController = nil
            guard let selection else {
                self.isCapturing = false
                return
            }
            Task { await self.captureRegion(selection, flags: flags) }
        }
    }

    private func captureRegion(_ selection: RegionSelectionController.Selection, flags: NSEvent.ModifierFlags) async {
        defer { isCapturing = false }
        do {
            let content = try await ScreenCaptureService.shareableContent()
            guard let display = ScreenCaptureService.display(for: selection.screen, in: content) else {
                throw CaptureError.noDisplay
            }
            // SCStreamConfiguration.sourceRect is in points with origin at
            // the top-left of the target display. Convert our AppKit
            // screen-local rect (origin bottom-left) into that space.
            let screenHeight = selection.screen.frame.height
            let sourceRect = CGRect(
                x: selection.rect.origin.x,
                y: screenHeight - selection.rect.origin.y - selection.rect.height,
                width: selection.rect.width,
                height: selection.rect.height
            )
            let image = try await ScreenCaptureService.captureRegion(sourceRect, on: display)
            router.handle(CaptureResult(cgImage: image), overrideFlags: flags)
        } catch {
            await MainActor.run { showError(error) }
        }
    }

    // MARK: - Full screen

    private func runFullScreen(flags: NSEvent.ModifierFlags) {
        Task { [weak self] in
            guard let self else { return }
            defer { self.isCapturing = false }
            do {
                let content = try await ScreenCaptureService.shareableContent()
                let mouseScreen = NSScreen.screens.first { screen in
                    screen.frame.contains(NSEvent.mouseLocation)
                } ?? NSScreen.main
                guard let screen = mouseScreen,
                      let display = ScreenCaptureService.display(for: screen, in: content) else {
                    throw CaptureError.noDisplay
                }
                let image = try await ScreenCaptureService.captureFullScreen(display: display)
                router.handle(CaptureResult(cgImage: image), overrideFlags: flags)
            } catch {
                showError(error)
            }
        }
    }

    // MARK: - Window

    private func runWindow(flags: NSEvent.ModifierFlags) {
        let controller = WindowPickerController()
        windowController = controller
        controller.present { [weak self] window in
            guard let self else { return }
            self.windowController = nil
            guard let window else {
                self.isCapturing = false
                return
            }
            Task { await self.captureWindow(window, flags: flags) }
        }
    }

    private func captureWindow(_ window: SCWindow, flags: NSEvent.ModifierFlags) async {
        defer { isCapturing = false }
        do {
            let image = try await ScreenCaptureService.captureWindow(window)
            router.handle(CaptureResult(cgImage: image), overrideFlags: flags)
        } catch {
            showError(error)
        }
    }

    // MARK: - Errors

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
