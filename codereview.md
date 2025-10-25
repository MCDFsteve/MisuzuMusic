该改动引入了桌面歌词功能以及透明置顶窗口渲染。功能层面主要包括：
1. 新增 DesktopLyricsController 负责跟踪播放器状态、加载歌词并与 desktop_multi_window 子窗体通信。
2. 主入口 main.dart 需要在多窗口模式下运行不同入口，且注册/初始化新的控制器。
3. 新增 desktop_lyrics_window.dart 作为多窗口歌词渲染 UI，实现黑色文字+白色描边。
4. LyricsOverlay 上增加桌面歌词开关按钮，并与 controller 同步翻译开关。

需要重点关注的风险：
- DesktopLyricsController 当前只在桌面平台初始化，但通过 AudioService 的 stream 获取进度，如果子窗口开启时长时间播放，Controller 的 position 推送依赖 Timer throttle，过度频繁/过慢可能导致歌词不同步，需要在后续测试中关注。
- Song track 改变时 controller 会重新 loadLyricsForTrack，与原有 LyricsOverlay 内部 cubit 并不共用，需要确保两个独立 Cubit 并行不会造成重复网络请求或性能问题。
- 多窗口交互 rely on DesktopMultiWindow.setMethodHandler，全局仅注册一次。若后续其它功能也需要 method handler，需要实现多路复用。
- 子窗口目前没有独立关闭按钮（依靠系统）且关闭后 åter 相关状态是否及时同步在 controller 中需验证。

测试建议：
- 桌面平台（macOS/Windows/Linux）实际运行，验证桌面歌词开关、翻译同步、窗口透明置顶、拖动窗口等行为。
- 歌词加载失败、无歌词情况下子窗口显示提示。
- 快速切歌、进度拖动时窗口歌词同步情况。
- 确认桌面歌词窗口关闭后按钮状态更新（ValueListenableBuilder）。
