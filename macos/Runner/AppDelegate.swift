import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var hotKeyChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    DispatchQueue.main.async { [weak self] in
      guard
        let self,
        let controller = self.mainFlutterWindow?.contentViewController as? FlutterViewController
      else {
        return
      }

      self.hotKeyChannel = FlutterMethodChannel(
        name: "com.aimessoft.misuzumusic/hotkeys",
        binaryMessenger: controller.engine.binaryMessenger
      )

      self.localizeMenuTitles()
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // MARK: - Menu Actions

  @objc func openSettings(_ sender: Any?) {
    hotKeyChannel?.invokeMethod("openSettings", arguments: nil)
  }

  @objc func handlePlayPause(_ sender: Any?) {
    hotKeyChannel?.invokeMethod("togglePlayPause", arguments: nil)
  }

  @objc func handleNextTrack(_ sender: Any?) {
    hotKeyChannel?.invokeMethod("mediaControl", arguments: "next")
  }

  @objc func handlePreviousTrack(_ sender: Any?) {
    hotKeyChannel?.invokeMethod("mediaControl", arguments: "previous")
  }

  @objc func handleVolumeUp(_ sender: Any?) {
    hotKeyChannel?.invokeMethod("mediaControl", arguments: "volumeUp")
  }

  @objc func handleVolumeDown(_ sender: Any?) {
    hotKeyChannel?.invokeMethod("mediaControl", arguments: "volumeDown")
  }

  @objc func handleCyclePlayMode(_ sender: Any?) {
    hotKeyChannel?.invokeMethod("mediaControl", arguments: "cyclePlayMode")
  }

  @objc func openSupportPage(_ sender: Any?) {
    guard let url = URL(string: "https://github.com/aimess/misuzu-music") else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  // MARK: - Helpers

  private func localizeMenuTitles() {
    guard let mainMenu = NSApp.mainMenu else {
      return
    }

    mainMenu.item(at: 0)?.title = "Misuzu Music"
    mainMenu.item(at: 1)?.title = "控制"
    mainMenu.item(at: 2)?.title = "窗口"
    mainMenu.item(at: 3)?.title = "帮助"

    if let appMenu = mainMenu.item(at: 0)?.submenu {
      appMenu.item(withTitle: "关于 Misuzu Music")?.title = "关于 Misuzu Music"
      appMenu.item(withTitle: "设置…")?.title = "设置…"
      appMenu.item(withTitle: "隐藏 Misuzu Music")?.title = "隐藏 Misuzu Music"
      appMenu.item(withTitle: "隐藏其他")?.title = "隐藏其他"
      appMenu.item(withTitle: "全部显示")?.title = "全部显示"
      appMenu.item(withTitle: "退出 Misuzu Music")?.title = "退出 Misuzu Music"
    }

    if let controlMenu = mainMenu.item(at: 1)?.submenu {
      controlMenu.item(at: 0)?.title = "上一曲"
      controlMenu.item(at: 1)?.title = "播放/暂停"
      controlMenu.item(at: 2)?.title = "下一曲"
      controlMenu.item(at: 4)?.title = "音量调大"
      controlMenu.item(at: 5)?.title = "音量调小"
      controlMenu.item(at: 7)?.title = "切换播放模式"
    }

    if let windowMenu = mainMenu.item(at: 2)?.submenu {
      windowMenu.item(withTitle: "Minimize")?.title = "最小化"
      windowMenu.item(withTitle: "缩放")?.title = "缩放"
      windowMenu.item(withTitle: "Bring All to Front")?.title = "全部置于顶层"
    }

    if let helpMenu = mainMenu.item(at: 3)?.submenu {
      helpMenu.item(at: 0)?.title = "Misuzu Music 帮助"
    }
  }
}
