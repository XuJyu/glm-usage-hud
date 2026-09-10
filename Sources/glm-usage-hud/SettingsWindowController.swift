import AppKit
import GLMUsageCore

/// 配置窗口：输入 key → 保存 Keychain → 实时测试连接。
@MainActor
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let keychain: KeychainStore
    private let api: UsageAPI
    private let onSave: () -> Void
    private let keyField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "保存并测试", target: nil, action: nil)

    init(keychain: KeychainStore, api: UsageAPI, onSave: @escaping () -> Void) {
        self.keychain = keychain
        self.api = api
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "配置智谱 API Key"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("不支持从 coder 初始化") }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let hint = NSTextField(labelWithString: "智谱 API Key（open.bigmodel.cn 控制台创建，仅存本机 Keychain）：")
        keyField.placeholderString = "粘贴你的 API Key"
        keyField.delegate = self
        if let existing = keychain.read() { keyField.stringValue = existing }

        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveAndTest)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        [hint, keyField, saveButton, statusLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; content.addSubview($0) }
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            hint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            keyField.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 10),
            keyField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            keyField.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),

            saveButton.centerYAnchor.constraint(equalTo: keyField.centerYAnchor),
            saveButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            statusLabel.topAnchor.constraint(equalTo: keyField.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -12),
        ])
    }

    /// LSUIElement 应用必须显式激活才能拿到键盘焦点。
    func showWindow() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(keyField)
    }

    func controlTextDidChange(_ obj: Notification) {
        statusLabel.stringValue = ""
    }

    @objc private func saveAndTest() {
        let key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            statusLabel.stringValue = "请先输入 Key"
            return
        }
        guard keychain.save(key) else {
            statusLabel.stringValue = "❌ Keychain 写入失败"
            return
        }
        statusLabel.stringValue = "测试连接中…"
        saveButton.isEnabled = false
        Task { [weak self] in
            guard let self else { return }
            defer { self.saveButton.isEnabled = true }
            do {
                let snapshot = try await self.api.fetch(apiKey: key)
                self.statusLabel.stringValue =
                    "✅ 连接成功：5小时已用 \(snapshot.fiveHour.usedPercent)% · 本周已用 \(snapshot.week.usedPercent)%（\(HUDFormatting.planLevel(snapshot.planLevel))）"
                self.onSave()
            } catch let error as UsageAPIError {
                self.statusLabel.stringValue = "❌ \(error.description)"
            } catch {
                self.statusLabel.stringValue = "❌ \(error.localizedDescription)"
            }
        }
    }
}
