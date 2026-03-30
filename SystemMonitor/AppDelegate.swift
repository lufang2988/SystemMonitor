import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var closeTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建共享的 ViewModel
        let viewModel = DetailViewModel()

        // 创建菜单栏视图
        let menuBarView = MenuBarView().environmentObject(viewModel)

        // 使用 NSStatusBar 系统状态栏
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "Loading..."
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // 创建弹出面板 (使用 NSPanel 实现悬停关闭)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingController = NSHostingController(rootView: menuBarView.environmentObject(viewModel))
        hostingController.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        panel.contentViewController = hostingController

        // 存储引用用于更新
        PopoverManager.shared.viewModel = viewModel
        PopoverManager.shared.statusItem = statusItem
        PopoverManager.shared.panel = panel

        // 启动定时更新
        startUpdating()
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let panel = PopoverManager.shared.panel,
              let button = PopoverManager.shared.statusItem?.button else { return }

        if panel.isVisible {
            closePopover()
        } else {
            showPopover(relativeTo: button.bounds, of: button)
        }
    }

    private func showPopover(relativeTo buttonBounds: NSRect, of button: NSStatusBarButton) {
        guard let panel = PopoverManager.shared.panel else { return }

        // 刷新数据
        PopoverManager.shared.viewModel?.refresh()
        PopoverManager.shared.viewModel?.startAutoRefresh()

        // 获取按钮在屏幕上的位置
        guard let buttonWindow = button.window,
              let buttonScreenRect = button.window?.convertToScreen(button.bounds) else { return }

        // 计算面板位置 (显示在按钮下方)
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height
        var panelOrigin = buttonScreenRect.origin
        panelOrigin.y = buttonScreenRect.origin.y - panelHeight

        // 如果面板会超出屏幕左边，调整到屏幕内
        if panelOrigin.x < 0 {
            panelOrigin.x = 0
        }

        // 如果面板会超出屏幕右边，调整到屏幕内
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        if panelOrigin.x + panelWidth > screenFrame.maxX {
            panelOrigin.x = screenFrame.maxX - panelWidth
        }

        panel.setFrameOrigin(panelOrigin)
        panel.makeKeyAndOrderFront(nil)

        // 5秒后自动关闭
        closeTimer?.invalidate()
        closeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        closeTimer?.invalidate()
        closeTimer = nil
        PopoverManager.shared.panel?.orderOut(nil)
        PopoverManager.shared.viewModel?.stopAutoRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        PopoverManager.shared.timer?.invalidate()
        closeTimer?.invalidate()
    }

    private func startUpdating() {
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStatusBar()
        }
        PopoverManager.shared.timer = timer
        updateStatusBar()
    }

    private func updateStatusBar() {
        let stats = SystemMonitor.getStats()

        let cpuPercent = Int(stats.cpuUsage * 100)
        let memoryGB = Double(stats.usedMemory) / 1_073_741_824

        DispatchQueue.main.async {
            PopoverManager.shared.statusItem?.button?.title = "CPU: \(cpuPercent)% | Mem: \(String(format: "%.1f", memoryGB))GB"
        }
    }
}

// 全局管理器
class PopoverManager {
    static let shared = PopoverManager()
    var statusItem: NSStatusItem?
    var panel: NSPanel?
    var timer: Timer?
    var viewModel: DetailViewModel?
}