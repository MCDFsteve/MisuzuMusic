import Cocoa
import FlutterMacOS
import ObjectiveC.runtime

class DesktopLyricsSpacesBridge {
  private static let channelName = "com.aimessoft.misuzumusic/desktop_lyrics_window"
  private static var channelAssociationKey: UInt8 = 0

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )

    objc_setAssociatedObject(
      controller,
      &channelAssociationKey,
      channel,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )

    channel.setMethodCallHandler { [weak controller] call, result in
      guard let controller = controller else {
        result(FlutterError(code: "controller_released", message: "控制器已释放", details: nil))
        return
      }
      switch call.method {
      case "pinToAllSpaces":
        guard let arguments = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "参数错误", details: nil))
          return
        }
        pinWindow(arguments: arguments, controller: controller, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func pinWindow(
    arguments: [String: Any],
    controller: FlutterViewController,
    result: FlutterResult
  ) {
    let windowNumber = arguments["windowId"] as? Int

    guard let targetWindow = resolveWindow(number: windowNumber, controller: controller) else {
      result(FlutterError(code: "window_not_found", message: "未找到窗口", details: windowNumber))
      return
    }

    debugPrint("DesktopLyrics window class = \(type(of: targetWindow)), isPanel=\(targetWindow is NSPanel)")

    targetWindow.level = .statusBar
    var behavior = targetWindow.collectionBehavior
    behavior.remove(.moveToActiveSpace)
    behavior.remove(.fullScreenPrimary)
    behavior.remove(.managed)
    behavior.insert(.canJoinAllSpaces)
    behavior.insert(.fullScreenAuxiliary)
    behavior.insert(.stationary)
    behavior.insert(.ignoresCycle)
    behavior.insert(.transient)
    targetWindow.collectionBehavior = behavior
    targetWindow.styleMask.insert(.nonactivatingPanel)
    targetWindow.orderFrontRegardless()

    result(true)
  }

  private static func resolveWindow(
    number: Int?,
    controller: FlutterViewController
  ) -> NSWindow? {
    if let explicitNumber = number,
       let window = NSApp.window(withWindowNumber: explicitNumber) {
      return window
    }

    if let controllerWindow = controller.view.window {
      return controllerWindow
    }

    return NSApp.windows.first { $0.contentViewController === controller }
  }
}
