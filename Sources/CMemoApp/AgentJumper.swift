import AppKit
import CMemoKit
import SwiftUI

/// "Jump to Agent" 执行器：GUI agent 打开 cwd 对应的项目窗口并激活应用，其余仅激活应用。
@MainActor
enum AgentJumper {
    static func jump(_ target: JumpTarget) {
        switch target {
        case .app(let bundleID):
            activate(bundleID: bundleID)
        case .projectWindow(_, let url, let bundleID):
            // 先激活应用再开 URL：窗口定位失败时应用至少已在前台。
            activate(bundleID: bundleID)
            _ = NSWorkspace.shared.open(url)
        }
    }

    private static func activate(bundleID: String) {
        if let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first {
            running.activate()
            return
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config)
    }
}

/// 会话行 / 详情区共用的「Jump to Agent」菜单项：无宿主信息时置灰。
struct JumpToAgentMenu: View {
    let summary: SessionSummary

    var body: some View {
        let target = JumpTarget.resolve(hostApp: summary.hostApp, cwd: summary.cwd)
        Button {
            if let target { AgentJumper.jump(target) }
        } label: {
            if let name = summary.hostApp?.name, !name.isEmpty {
                Text("Jump to Agent（\(name)）")
            } else {
                Text("Jump to Agent")
            }
        }
        .disabled(target == nil)
    }
}
