import Cocoa
import FlutterMacOS
import QuartzCore
import window_manager_plus

@main
class AppDelegate: FlutterAppDelegate {
  private var hotKeyChannel: FlutterMethodChannel?
  private var windowChannel: FlutterMethodChannel?
  private var channelsConfigured = false
  private lazy var menuLocalizationBundle: Bundle = {
    if let path = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"),
      let bundle = Bundle(path: path)
    {
      return bundle
    }
    if let path = Bundle.main.path(forResource: "Base", ofType: "lproj"),
      let bundle = Bundle(path: path)
    {
      return bundle
    }
    return Bundle.main
  }()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    configureChannelsIfNeeded()
    configureChannelsIfNeeded()
    localizeMenuTitles()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.localizeMenuTitles()
    }
  }

  func configureChannelsIfNeeded(with controller: FlutterViewController? = nil) {
    guard !channelsConfigured else {
      return
    }
    let flutterController: FlutterViewController?
    if let controller {
      flutterController = controller
    } else {
      flutterController = mainFlutterWindow?.contentViewController as? FlutterViewController
    }
    guard let controller = flutterController else {
      return
    }

    hotKeyChannel = FlutterMethodChannel(
      name: "com.aimessoft.misuzumusic/hotkeys",
      binaryMessenger: controller.engine.binaryMessenger
    )

    windowChannel = FlutterMethodChannel(
      name: "com.aimessoft.misuzumusic/macos_window",
      binaryMessenger: controller.engine.binaryMessenger
    )
    windowChannel?.setMethodCallHandler(handleWindowChannel)

    channelsConfigured = true
    NSLog("✅ macOS MethodChannels 初始化完成")
  }

  private func handleWindowChannel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    NSLog("[Misuzu][MacOSWindow] method=\(call.method) args=\(String(describing: call.arguments))")
    switch call.method {
    case "setTransparent":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "Missing arguments", details: nil))
        return
      }

      guard let windowId = parseInt64(from: args["windowId"]) else {
        result(FlutterError(code: "invalid_args", message: "Missing windowId", details: nil))
        return
      }

      guard let window = resolveWindow(by: windowId) else {
        result(FlutterError(code: "window_not_found", message: "Cannot find window for id \(windowId)", details: nil))
        return
      }

      applyTransparentStyle(to: window)
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func resolveWindow(by id: Int64) -> NSWindow? {
    if id == 0 {
      return mainFlutterWindow
    }

    if let managerOptional = WindowManagerPlus.windowManagers[id],
       let manager = managerOptional {
      return manager.mainWindow
    }

    return NSApp.windows.first { window in
      window.windowNumber == Int(id)
    }
  }

  private func parseInt64(from value: Any?) -> Int64? {
    switch value {
    case let number as NSNumber:
      return number.int64Value
    case let intValue as Int:
      return Int64(intValue)
    case let int64Value as Int64:
      return int64Value
    default:
      return nil
    }
  }

  private func applyTransparentStyle(to window: NSWindow) {
    NSLog("[Misuzu][Transparent] Applying styles to window title=\(window.title) number=\(window.windowNumber)")
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask.insert(.fullSizeContentView)
    window.contentView?.alphaValue = 1.0

    makeViewTreeTransparent(window.contentView)
    makeViewTreeTransparent(window.contentViewController?.view)
    if let superview = window.contentView?.superview {
      makeViewTreeTransparent(superview)
    }
    scheduleTransparentRefresh(for: window, remaining: 5)
    logViewHierarchy(for: window)
  }

  private func makeViewTreeTransparent(_ view: NSView?) {
    guard let view = view else {
      return
    }
    if view.layer == nil {
      view.wantsLayer = true
    }
    updateLayerTransparency(view.layer)
    if let effectView = view as? NSVisualEffectView {
      effectView.material = .fullScreenUI
      effectView.state = .active
      effectView.isEmphasized = false
      effectView.blendingMode = .withinWindow
    }
    view.subviews.forEach { makeViewTreeTransparent($0) }
  }

  private func updateLayerTransparency(_ layer: CALayer?) {
    guard let layer = layer else {
      return
    }
    layer.isOpaque = false
    layer.backgroundColor = NSColor.clear.cgColor
    layer.masksToBounds = false
    if let metalLayer = layer as? CAMetalLayer {
      metalLayer.isOpaque = false
      metalLayer.backgroundColor = NSColor.clear.cgColor
    }
    layer.sublayers?.forEach { updateLayerTransparency($0) }
  }

  private func scheduleTransparentRefresh(for window: NSWindow, remaining: Int) {
    guard remaining > 0 else {
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak window] in
      guard let self, let window else {
        return
      }
      self.makeViewTreeTransparent(window.contentView)
      self.makeViewTreeTransparent(window.contentViewController?.view)
      if let superview = window.contentView?.superview {
        self.makeViewTreeTransparent(superview)
      }
      self.scheduleTransparentRefresh(for: window, remaining: remaining - 1)
    }
  }

  private func logViewHierarchy(for window: NSWindow) {
    #if DEBUG
    let title = window.title.isEmpty ? "<untitled>" : window.title
    NSLog("[Misuzu][Transparent] Dump begin for window: \(title)")
    if let contentView = window.contentView {
      logView(contentView, indent: "  ")
    }
    NSLog("[Misuzu][Transparent] Dump end")
    #endif
  }

  private func logView(_ view: NSView, indent: String) {
    let layerDescription: String
    if let layer = view.layer {
      let className = String(describing: type(of: layer))
      layerDescription = "layer=\(className) opaque=\(layer.isOpaque) bg=\(layer.backgroundColor != nil)"
    } else {
      layerDescription = "layer=nil"
    }
    NSLog("[Misuzu][Transparent]\(indent)<\(String(describing: type(of: view)))> \(layerDescription)")
    for subview in view.subviews {
      logView(subview, indent: indent + "  ")
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return NSApp.windows.filter({ $0 is MainFlutterWindow || $0 is WindowManagerPlusFlutterWindow }).count == 1
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidBecomeActive(_ notification: Notification) {
    localizeMenuTitles()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.localizeMenuTitles()
    }
  }

  // MARK: - Menu Actions

  @objc func openSettings(_ sender: Any?) {
    hotKeyChannel?.invokeMethod("openSettings", arguments: nil)
  }

  @objc func handlePlayPause(_ sender: Any?) {
    logMenuAction("播放/暂停")
    hotKeyChannel?.invokeMethod("togglePlayPause", arguments: nil)
  }

  @objc func handleNextTrack(_ sender: Any?) {
    logMenuAction("下一曲")
    hotKeyChannel?.invokeMethod("mediaControl", arguments: "next")
  }

  @objc func handlePreviousTrack(_ sender: Any?) {
    logMenuAction("上一曲")
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
    guard let url = URL(string: "https://github.com/dfsteve/misuzumusic") else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  // MARK: - Helpers

  private func localizeMenuTitles() {
    guard let mainMenu = NSApp.mainMenu else {
      return
    }

    let appMenuTitle = localizedMenuString(forKey: "menu.app.title", fallback: "Misuzu Music")

    mainMenu.item(at: 0)?.title = appMenuTitle

    if let controlItem = mainMenu.item(at: 1) {
      let title = localizedMenuString(forKey: "menu.control.title", fallback: "控制")
      controlItem.title = title
      controlItem.submenu?.title = title
    }

    if let windowItem = mainMenu.item(at: 2) {
      let title = localizedMenuString(forKey: "menu.window.title", fallback: "窗口")
      windowItem.title = title
      windowItem.submenu?.title = title
    }

    if let helpItem = mainMenu.item(at: 3) {
      let title = localizedMenuString(forKey: "menu.help.title", fallback: "帮助")
      helpItem.title = title
      helpItem.submenu?.title = title
    }

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
    return menuLocalizationBundle.localizedString(forKey: key, value: fallback, table: nil)
  }

  private func logMenuAction(_ action: String) {
    let status = hotKeyChannel == nil ? "未初始化" : "已就绪"
    NSLog("🎯 菜单动作: %@, hotKeyChannel=%@", action, status)
    guard hotKeyChannel == nil,
      let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    else {
      return
    }

    hotKeyChannel = FlutterMethodChannel(
      name: "com.aimessoft.misuzumusic/hotkeys",
      binaryMessenger: controller.engine.binaryMessenger
    )
    NSLog("✅ hotKeyChannel 重新初始化完成")
  }
}
