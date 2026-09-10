import AppKit
import GLMUsageCore
import ServiceManagement

/// 菜单栏 HUD 控制器：HUDState 是唯一状态源，顶栏标题与下拉菜单都由它派生。
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    enum HUDState: Equatable {
        case noKey
        case loading
        case loaded(UsageSnapshot)
        case failed(String)
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let api = UsageAPI()
    private let keychain = KeychainStore()
    private var state: HUDState = .noKey {
        didSet { render() }
    }
    private var timer: Timer?
    private var settingsWindow: SettingsWindowController?

    /// 从 AppDelegate 显式调用（避免在 init 里触发状态副作用）。
    func start() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.autosaveName = "glm-usage-hud-status-item"

        if let key = keychain.read(), !key.isEmpty {
            state = .loading
            refresh()
        } else {
            state = .noKey
        }
        startTimer()
        observeWake()
        render()
    }

    // MARK: - 状态渲染

    private func render() {
        switch state {
        case .noKey:
            setTitle("未配置")
            setRing(nil)
        case .loading:
            setTitle("…")
            setRing(nil)
        case .loaded(let snapshot):
            setTitle(HUDFormatting.title(
                fiveHourUsedPercent: snapshot.fiveHour.usedPercent,
                weekUsedPercent: snapshot.week.usedPercent
            ))
            setRing(snapshot.fiveHour.usedPercent)
        case .failed:
            setTitle("⚠️")
            setRing(nil)
        }
        rebuildMenu()
    }

    private func setRing(_ filledPercent: Int?) {
        statusItem.button?.image = filledPercent.map(Self.ringImage(filledPercent:))
    }

    /// 5 小时用量圆环：模板图像（track α0.22 + 进度弧 α1.0），自动适配亮/暗外观。
    /// 12 点方向起顺时针，sweep 与已用% 成正比；>0 时至少露出 4°。
    /// 用 drawingHandler 矢量绘制（lockFocus 已弃用且混合 DPI 下会发虚），按目标屏 scale 恒清晰。
    private static func ringImage(filledPercent: Int) -> NSImage {
        let diameter: CGFloat = 16
        let lineWidth: CGFloat = 2.5
        let center = NSPoint(x: diameter / 2, y: diameter / 2)
        let radius = (diameter - lineWidth) / 2
        let clamped = min(max(filledPercent, 0), 100)
        let sweep = clamped == 0 ? 0 : max(Double(clamped) / 100 * 360, 4)
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { _ in
            NSColor.black.withAlphaComponent(0.22).setStroke()
            let track = NSBezierPath()
            track.lineWidth = lineWidth
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.stroke()
            if sweep > 0 {
                NSColor.black.setStroke()
                let arc = NSBezierPath()
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - sweep, clockwise: true)
                arc.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func setTitle(_ text: String) {
        statusItem.button?.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular),
        ])
    }

    // MARK: - 菜单

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        let calendar = Calendar.current

        switch state {
        case .noKey:
            menu.addItem(boldItem("配置 Key…", action: #selector(openSettings)))

        case .loading:
            menu.addItem(disabledItem("刷新中…"))

        case .failed(let message):
            menu.addItem(disabledItem("⚠️ \(message)"))
            menu.addItem(.separator())
            menu.addItem(actionItem("立即重试", action: #selector(refreshNow)))
            menu.addItem(actionItem("配置 Key…", action: #selector(openSettings)))

        case .loaded(let snapshot):
            menu.addItem(disabledItem("GLM Coding Plan · \(HUDFormatting.planLevel(snapshot.planLevel))"))
            menu.addItem(.separator())
            let five = snapshot.fiveHour
            menu.addItem(disabledItem("5小时窗口   已用 \(five.usedPercent)%"))
            menu.addItem(disabledItem("  \(HUDFormatting.grouped(five.used)) / \(HUDFormatting.grouped(five.total)) · 重置 \(five.nextReset.map { HUDFormatting.shortReset($0, now: Date(), calendar: calendar) } ?? "未知")"))
            let week = snapshot.week
            menu.addItem(disabledItem("本周额度   已用 \(week.usedPercent)%"))
            menu.addItem(disabledItem("  \(HUDFormatting.grouped(week.used)) / \(HUDFormatting.grouped(week.total)) · 重置 \(week.nextReset.map { HUDFormatting.weekReset($0, calendar: calendar) } ?? "未知")"))
            menu.addItem(.separator())
            menu.addItem(disabledItem("更新于 \(HUDFormatting.timeHM(snapshot.fetchedAt, calendar: calendar))"))
            menu.addItem(.separator())
            menu.addItem(actionItem("立即刷新", action: #selector(refreshNow), keyEquivalent: "r"))
            menu.addItem(actionItem("配置 Key…", action: #selector(openSettings)))
        }

        menu.addItem(.separator())
        menu.addItem(autoLaunchItem())
        menu.addItem(.separator())
        menu.addItem(actionItem("退出", action: #selector(quit), keyEquivalent: "q"))
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func boldItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = actionItem(title, action: action)
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
        ])
        return item
    }

    // MARK: - 开机自启

    private func autoLaunchItem() -> NSMenuItem {
        let item = NSMenuItem(title: "开机自启", action: #selector(toggleAutoLaunch), keyEquivalent: "")
        item.target = self
        switch SMAppService.mainApp.status {
        case .enabled:
            item.state = .on
        case .requiresApproval:
            item.state = .mixed
            item.title = "开机自启（需在系统设置批准）"
        default:
            item.state = .off
        }
        return item
    }

    @objc private func toggleAutoLaunch() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            default:
                try service.register()
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "开机自启设置失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        rebuildMenu()
    }

    // MARK: - 刷新调度

    /// 15 分钟定时；Timer 强持有 self（target-action 版），控制器与应用同生命周期。
    private func startTimer() {
        let timer = Timer(timeInterval: 15 * 60, target: self, selector: #selector(timerFire), userInfo: nil, repeats: true)
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func observeWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func timerFire() { refresh() }
    @objc private func handleWake() { refresh() }
    @objc private func refreshNow() { refresh() }

    func refresh() {
        guard let key = keychain.read(), !key.isEmpty else {
            state = .noKey
            return
        }
        // 已有数据时刷新期间不闪 loading
        if case .loaded = state {} else { state = .loading }
        Task {
            do {
                state = .loaded(try await api.fetch(apiKey: key))
            } catch let error as UsageAPIError {
                state = .failed(error.description)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - 配置窗口与退出

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(keychain: keychain, api: api) { [weak self] in
                self?.refresh()
            }
        }
        settingsWindow?.showWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
