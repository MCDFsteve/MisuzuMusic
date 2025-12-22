import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "com.aimessoft.misuzumusic/file_association"
  private var fileAssociationChannel: FlutterMethodChannel?
  private var pendingOpenFiles: [String] = []
  private var dartReadyForFiles = false

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
}
