import Flutter
import UIKit
import AVFoundation
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "com.aimessoft.misuzumusic/file_association"
  private var fileAssociationChannel: FlutterMethodChannel?
  private var pendingOpenFiles: [String] = []
  private var dartReadyForFiles = false
  private var carPlayBridge: CarPlayPlayableContentBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      print("Failed to configure AVAudioSession: \(error)")
    }

    if let registrar = self.registrar(forPlugin: "com.aimessoft.misuzumusic.file_association") {
      fileAssociationChannel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: registrar.messenger()
      )
      fileAssociationChannel?.setMethodCallHandler({ [weak self] call, result in
        guard call.method == "collectPendingFiles" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.dartReadyForFiles = true
        result(self?.drainPendingFiles() ?? [])
      })
    } else {
      print("Failed to create file association channel: missing FlutterPluginRegistrar.")
    }

    if let url = launchOptions?[.url] as? URL {
      handleIncoming(urls: [url])
    }

    configureCarPlayBridge()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    let handledFiles = handleIncoming(urls: [url])
    let handledFlutter = super.application(app, open: url, options: options)
    return handledFiles || handledFlutter
  }

  @discardableResult
  private func handleIncoming(urls: [URL]) -> Bool {
    guard !urls.isEmpty else { return false }
    let paths = urls.compactMap { url -> String? in
      guard url.isFileURL else { return nil }
      return url.path
    }
    guard !paths.isEmpty else { return false }

    if dartReadyForFiles, let channel = fileAssociationChannel {
      channel.invokeMethod("openFiles", arguments: paths)
    } else {
      pendingOpenFiles.append(contentsOf: paths)
    }
    return true
  }

  private func drainPendingFiles() -> [String] {
    if pendingOpenFiles.isEmpty { return [] }
    let result = pendingOpenFiles
    pendingOpenFiles.removeAll()
    return result
  }

  private func configureCarPlayBridge() {
    guard let registrar = self.registrar(forPlugin: "com.aimessoft.misuzumusic.carplay") else {
      print("Failed to create CarPlay channel: missing FlutterPluginRegistrar.")
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.aimessoft.misuzumusic/carplay",
      binaryMessenger: registrar.messenger()
    )
    let bridge = CarPlayPlayableContentBridge(channel: channel)
    self.carPlayBridge = bridge
    bridge.activate()

    channel.setMethodCallHandler({ [weak self] call, result in
      guard let bridge = self?.carPlayBridge else {
        result(
          FlutterError(
            code: "carplay_unavailable",
            message: "CarPlay bridge not available.",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "ready":
        bridge.setDartReady()
        result(true)
      case "reload":
        bridge.reload()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
  }
}

private final class CarPlayNode {
  let identifier: String
  let contentItem: MPContentItem
  let isPlayable: Bool
  let isContainer: Bool
  var children: [CarPlayNode]

  init(
    identifier: String,
    title: String,
    subtitle: String? = nil,
    isPlayable: Bool,
    isContainer: Bool,
    children: [CarPlayNode] = []
  ) {
    self.identifier = identifier
    self.isPlayable = isPlayable
    self.isContainer = isContainer
    self.children = children

    let item = MPContentItem(identifier: identifier)
    item.title = title
    item.subtitle = subtitle
    item.isPlayable = isPlayable
    item.isContainer = isContainer
    self.contentItem = item
  }

  static func fromPayload(_ payload: [String: Any]) -> CarPlayNode? {
    guard let identifier = payload["id"] as? String, !identifier.isEmpty else {
      return nil
    }
    guard let title = payload["title"] as? String, !title.isEmpty else {
      return nil
    }
    let subtitle = payload["subtitle"] as? String
    let isPlayable = payload["isPlayable"] as? Bool ?? false
    let isContainer = payload["isContainer"] as? Bool ?? !isPlayable

    return CarPlayNode(
      identifier: identifier,
      title: title,
      subtitle: subtitle,
      isPlayable: isPlayable,
      isContainer: isContainer
    )
  }
}

private final class CarPlayPlayableContentBridge: NSObject, MPPlayableContentDataSource, MPPlayableContentDelegate {
  private let channel: FlutterMethodChannel
  private var dartReady = false
  private let root: CarPlayNode

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    self.root = CarPlayNode(
      identifier: "root",
      title: "Misuzu Music",
      isPlayable: false,
      isContainer: true,
      children: [
        CarPlayNode(identifier: "tracks", title: "歌曲", isPlayable: false, isContainer: true),
        CarPlayNode(identifier: "artists", title: "艺术家", isPlayable: false, isContainer: true),
        CarPlayNode(identifier: "albums", title: "专辑", isPlayable: false, isContainer: true),
        CarPlayNode(identifier: "playlists", title: "播放列表", isPlayable: false, isContainer: true),
      ]
    )
    super.init()
  }

  func activate() {
    let manager = MPPlayableContentManager.shared()
    manager.dataSource = self
    manager.delegate = self
    manager.isEnabled = true
    manager.reloadData()
  }

  func setDartReady() {
    dartReady = true
    reload()
  }

  func reload() {
    for child in root.children {
      child.children.removeAll()
    }
    MPPlayableContentManager.shared().reloadData()
  }

  func numberOfChildItems(at indexPath: IndexPath) -> Int {
    guard let node = node(at: indexPath) else { return 0 }
    return node.children.count
  }

  func contentItem(at indexPath: IndexPath) -> MPContentItem? {
    return node(at: indexPath)?.contentItem
  }

  func beginLoadingChildItems(
    at indexPath: IndexPath,
    completionHandler: @escaping (Error?) -> Void
  ) {
    guard dartReady else {
      completionHandler(nil)
      return
    }
    guard let node = node(at: indexPath) else {
      completionHandler(nil)
      return
    }
    guard node.isContainer else {
      completionHandler(nil)
      return
    }
    if node.identifier == root.identifier {
      completionHandler(nil)
      return
    }

    let args: [String: Any] = ["nodeId": node.identifier]
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod("getChildren", arguments: args) { result in
        guard let self else {
          completionHandler(nil)
          return
        }
        if let notImplemented = result as? NSObject,
           notImplemented === FlutterMethodNotImplemented {
          completionHandler(nil)
          return
        }
        if let error = result as? FlutterError {
          print("CarPlay getChildren failed: \(error)")
          completionHandler(
            NSError(
              domain: "com.aimessoft.misuzumusic.carplay",
              code: 1,
              userInfo: [NSLocalizedDescriptionKey: error.message ?? "FlutterError"]
            )
          )
          return
        }

        let rawItems: [Any]
        if let items = result as? [Any] {
          rawItems = items
        } else {
          rawItems = []
        }

        let children = rawItems.compactMap { element -> CarPlayNode? in
          guard let dict = element as? [String: Any] else {
            return nil
          }
          return CarPlayNode.fromPayload(dict)
        }

        node.children = children
        completionHandler(nil)
      }
    }
  }

  func playableContentManager(
    _ contentManager: MPPlayableContentManager,
    initiatePlaybackOfContentItemAt indexPath: IndexPath,
    completionHandler: @escaping (Error?) -> Void
  ) {
    guard dartReady else {
      completionHandler(nil)
      return
    }
    guard let node = node(at: indexPath), node.isPlayable else {
      completionHandler(nil)
      return
    }

    let args: [String: Any] = ["id": node.identifier]
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod("playItem", arguments: args) { result in
        if let error = result as? FlutterError {
          print("CarPlay playItem failed: \(error)")
        }
        completionHandler(nil)
      }
    }
  }

  func childItemsDisplayPlaybackProgress(at indexPath: IndexPath) -> Bool {
    return false
  }

  func playableContentManager(
    _ contentManager: MPPlayableContentManager,
    initializePlaybackQueueWithCompletionHandler completionHandler: @escaping (Error?) -> Void
  ) {
    completionHandler(nil)
  }

  func playableContentManager(
    _ contentManager: MPPlayableContentManager,
    didUpdate context: MPPlayableContentManagerContext
  ) {
    // No-op: selection and playback is handled via initiatePlaybackOfContentItemAt.
  }

  private func node(at indexPath: IndexPath) -> CarPlayNode? {
    var current = root
    if indexPath.count == 0 {
      return current
    }
    for index in indexPath {
      if index < 0 || index >= current.children.count {
        return nil
      }
      current = current.children[index]
    }
    return current
  }
}
