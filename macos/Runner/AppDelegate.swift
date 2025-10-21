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

    let appMenuTitle = localizedMenuString(forKey: "menu.app.title", fallback: "Misuzu 音乐")

    mainMenu.item(at: 0)?.title = appMenuTitle
    mainMenu.item(at: 1)?.title = localizedMenuString(forKey: "menu.control.title", fallback: "控制")
    mainMenu.item(at: 2)?.title = localizedMenuString(forKey: "menu.window.title", fallback: "窗口")
    mainMenu.item(at: 3)?.title = localizedMenuString(forKey: "menu.help.title", fallback: "帮助")

    if let appMenu = mainMenu.item(at: 0)?.submenu {
      if let aboutItem = appMenu.item(at: 0) {
        let title = String(
          format: localizedMenuString(forKey: "menu.app.about", fallback: "关于 %@"),
          appMenuTitle
        )
        aboutItem.title = title
      }

      if let settingsItem = appMenu.item(at: 2) {
        settingsItem.title = localizedMenuString(forKey: "menu.app.settings", fallback: "设置…")
      }

      if let servicesItem = appMenu.item(at: 4) {
        servicesItem.title = localizedMenuString(forKey: "menu.app.services", fallback: "服务")
      }

      if let hideItem = appMenu.item(at: 6) {
        let title = String(
          format: localizedMenuString(forKey: "menu.app.hide", fallback: "隐藏 %@"),
          appMenuTitle
        )
        hideItem.title = title
      }

      if let hideOthersItem = appMenu.item(at: 7) {
        hideOthersItem.title = localizedMenuString(forKey: "menu.app.hideOthers", fallback: "隐藏其他")
      }

      if let showAllItem = appMenu.item(at: 8) {
        showAllItem.title = localizedMenuString(forKey: "menu.app.showAll", fallback: "全部显示")
      }

      if let quitItem = appMenu.item(at: 10) {
        let title = String(
          format: localizedMenuString(forKey: "menu.app.quit", fallback: "退出 %@"),
          appMenuTitle
        )
        quitItem.title = title
      }
    }

    if let controlMenu = mainMenu.item(at: 1)?.submenu {
      controlMenu.item(at: 0)?.title = localizedMenuString(
        forKey: "menu.control.previous",
        fallback: "上一曲"
      )
      controlMenu.item(at: 1)?.title = localizedMenuString(
        forKey: "menu.control.playPause",
        fallback: "播放/暂停"
      )
      controlMenu.item(at: 2)?.title = localizedMenuString(
        forKey: "menu.control.next",
        fallback: "下一曲"
      )
      controlMenu.item(at: 4)?.title = localizedMenuString(
        forKey: "menu.control.volumeUp",
        fallback: "音量调大"
      )
      controlMenu.item(at: 5)?.title = localizedMenuString(
        forKey: "menu.control.volumeDown",
        fallback: "音量调小"
      )
      controlMenu.item(at: 7)?.title = localizedMenuString(
        forKey: "menu.control.cycleMode",
        fallback: "切换播放模式"
      )
    }

    if let windowMenu = mainMenu.item(at: 2)?.submenu {
      windowMenu.item(at: 0)?.title = localizedMenuString(
        forKey: "menu.window.minimize",
        fallback: "最小化"
      )
      windowMenu.item(at: 1)?.title = localizedMenuString(
        forKey: "menu.window.zoom",
        fallback: "缩放"
      )
      windowMenu.item(at: 3)?.title = localizedMenuString(
        forKey: "menu.window.front",
        fallback: "全部置于顶层"
      )
    }

    if let helpMenu = mainMenu.item(at: 3)?.submenu {
      if let helpItem = helpMenu.item(at: 0) {
        let title = String(
          format: localizedMenuString(forKey: "menu.help.documentation", fallback: "%@ 帮助"),
          appMenuTitle
        )
        helpItem.title = title
      }
    }
  }

  private func localizedMenuString(forKey key: String, fallback: String) -> String {
    return Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
  }
}
