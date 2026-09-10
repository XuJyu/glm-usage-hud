import AppKit

@main
enum Launch {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?
    /// 抑制 App Nap，保证 15 分钟定时刷新尽量准点（配合 tolerance 60s）。
    private var activityToken: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "GLM Usage HUD 定时刷新"
        )
        let controller = StatusItemController()
        controller.start()
        statusController = controller
    }
}
