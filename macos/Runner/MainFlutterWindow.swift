import Cocoa
import FlutterMacOS
import window_manager
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    styleMask.insert(.titled)
    styleMask.insert(.closable)
    styleMask.insert(.miniaturizable)
    styleMask.insert(.resizable)
    isMovableByWindowBackground = true

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    if let delegate = NSApp.delegate as? AppDelegate {
      delegate.configureChannelsIfNeeded(with: flutterViewController)
    }

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
