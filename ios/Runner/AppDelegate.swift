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

    if let controller = window?.rootViewController as? FlutterViewController {
      fileAssociationChannel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: controller.binaryMessenger
      )
      fileAssociationChannel?.setMethodCallHandler({ [weak self] call, result in
        guard call.method == "collectPendingFiles" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.dartReadyForFiles = true
        result(self?.drainPendingFiles() ?? [])
      })
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
    handleIncoming(urls: [url])
    return true
  }

  override func application(
    _ application: UIApplication,
    open inputURLs: [URL],
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    handleIncoming(urls: inputURLs)
    return true
  }

  private func handleIncoming(urls: [URL]) {
    guard !urls.isEmpty else { return }
    let paths = urls.compactMap { url -> String? in
      guard url.isFileURL else { return nil }
      return url.path
    }
    guard !paths.isEmpty else { return }

    if dartReadyForFiles, let channel = fileAssociationChannel {
      channel.invokeMethod("openFiles", arguments: paths)
    } else {
      pendingOpenFiles.append(contentsOf: paths)
    }
  }

  private func drainPendingFiles() -> [String] {
    if pendingOpenFiles.isEmpty { return [] }
    let result = pendingOpenFiles
    pendingOpenFiles.removeAll()
    return result
  }
}
