import AppKit
import CodexThreadRadarCore
import SwiftUI

@main
struct CodexThreadRadarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = ThreadRadarStore()

    var body: some Scene {
        WindowGroup("codex线程监控器", id: "main") {
            ContentView(store: store)
        }
        .defaultSize(width: 920, height: 680)
        .commands {
            CommandMenu("线程监控器") {
                Button("捕获当前线程") {
                    NotificationCenter.default.post(name: .showCreateThreadSheet, object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("复制首条续接提示") {
                    copyFirstResumePrompt()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.firstVisibleThread == nil)
            }
        }

        MenuBarExtra("线程监控", systemImage: "dot.radiowaves.left.and.right") {
            RadarMenuView(store: store)
                .frame(width: 430, height: 640)
        }
        .menuBarExtraStyle(.window)
    }
}

private extension CodexThreadRadarApp {
    func copyFirstResumePrompt() {
        guard let thread = store.firstVisibleThread else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(store.resumePrompt(for: thread), forType: .string)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let showCreateThreadSheet = Notification.Name("showCreateThreadSheet")
}
