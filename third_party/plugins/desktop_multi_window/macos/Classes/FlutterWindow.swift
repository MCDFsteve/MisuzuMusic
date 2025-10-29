//
//  FlutterWindow.swift
//  flutter_multi_window
//
//  Created by Bin Yang on 2022/1/10.
//
import Cocoa
import FlutterMacOS
import Foundation

class BaseFlutterWindow: NSObject {
  private let window: NSWindow
  let windowChannel: WindowChannel

  init(window: NSWindow, channel: WindowChannel) {
    self.window = window
    self.windowChannel = channel
    super.init()
  }

  func show() {
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func hide() {
    window.orderOut(nil)
  }

  func center() {
    window.center()
  }

  func setFrame(frame: NSRect) {
    window.setFrame(frame, display: false, animate: true)
  }

  func setTitle(title: String) {
    window.title = title
  }

  func resizable(resizable: Bool) {
    if (resizable) {
      window.styleMask.insert(.resizable)
    } else {
      window.styleMask.remove(.resizable)
    }
  }

  func close() {
    window.close()
  }

  func setFrameAutosaveName(name: String) {
    window.setFrameAutosaveName(name)
  }
}

private class LyricsDesktopPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

class FlutterWindow: BaseFlutterWindow {
  let windowId: Int64

  let window: NSWindow

  weak var delegate: WindowManagerDelegate?

  init(id: Int64, arguments: String) {
    windowId = id
    let decodedArguments = FlutterWindow.parseArguments(arguments)
    if FlutterWindow.shouldUsePanel(arguments: decodedArguments) {
      let panel = LyricsDesktopPanel(
        contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
        styleMask: [.nonactivatingPanel, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      panel.hidesOnDeactivate = false
      panel.isFloatingPanel = true
      panel.collectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .stationary,
        .ignoresCycle,
        .transient
      ]
      panel.level = .statusBar
      panel.standardWindowButton(.closeButton)?.isHidden = true
      panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
      panel.standardWindowButton(.zoomButton)?.isHidden = true
      panel.backgroundColor = .clear
      panel.isOpaque = false
      window = panel
    } else {
      window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
        styleMask: [.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
    }
    let project = FlutterDartProject()
    project.dartEntrypointArguments = ["multi_window", "\(windowId)", arguments]
    let flutterViewController = FlutterViewController(project: project)
    window.contentViewController = flutterViewController

    let plugin = flutterViewController.registrar(forPlugin: "FlutterMultiWindowPlugin")
    FlutterMultiWindowPlugin.registerInternal(with: plugin)
    let windowChannel = WindowChannel.register(with: plugin, windowId: id)
    // Give app a chance to register plugin.
    FlutterMultiWindowPlugin.onWindowCreatedCallback?(flutterViewController)

    super.init(window: window, channel: windowChannel)

    window.delegate = self
    window.isReleasedWhenClosed = false
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    if let panel = window as? LyricsDesktopPanel {
      panel.collectionBehavior.insert(.fullScreenAuxiliary)
    }
  }

  deinit {
    debugPrint("release window resource")
    window.delegate = nil
    if let flutterViewController = window.contentViewController as? FlutterViewController {
      flutterViewController.engine.shutDownEngine()
    }
    window.contentViewController = nil
    window.windowController = nil
  }
}

extension FlutterWindow {
  private static func parseArguments(_ arguments: String) -> [String: Any]? {
    guard let data = arguments.data(using: .utf8) else {
      return nil
    }
    return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
  }

  private static func shouldUsePanel(arguments: [String: Any]?) -> Bool {
    guard let arguments else { return false }
    if let override = arguments["force_panel"] as? Bool {
      return override
    }
    if let kind = arguments["kind"] as? String, kind == "lyrics" {
      return true
    }
    return false
  }
}

extension FlutterWindow: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    delegate?.onClose(windowId: windowId)
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    delegate?.onClose(windowId: windowId)
    return true
  }
}
