# Misuzu Music

一个本地音乐播放器，专门为日语歌曲提供汉字和片假名的平假名注音功能。

## 特色功能

- 🎵 **本地音乐播放**: 支持 MP3, FLAC, AAC, WAV, OGG 等常见音频格式
- 🈂️ **日语歌词注音**: 自动为汉字和片假名添加平假名注音（振り仮名）
- 🎨 **原生界面设计**: 每个平台都采用该平台的原生设计风格
  - macOS: Apple Human Interface Guidelines
  - Windows: Fluent Design System
  - Linux: Material Design
- 📚 **音乐库管理**: 自动扫描和管理本地音乐文件
- 📝 **歌词同步**: 支持 LRC 格式时间轴歌词

## 项目架构

本项目采用 Clean Architecture + BLoC 模式，严格分离业务逻辑与UI界面：

```
lib/
├── core/           # 核心功能（依赖注入、错误处理、工具类）
├── data/           # 数据层（数据模型、仓库实现、数据源）
├── domain/         # 领域层（业务实体、用例、仓库接口）
└── presentation/   # 表现层（UI组件、状态管理、平台适配）
```

## 技术栈

- **Framework**: Flutter
- **状态管理**: BLoC
- **音频处理**: just_audio
- **日语处理**: kana_kit, japanese
- **数据库**: SQLite
- **平台UI**: macos_ui, fluent_ui

## 开发环境

- Flutter 3.9.0+
- Dart 3.0+
- macOS 10.14+ / Windows 10+ / Linux Ubuntu 18.04+

## 安装和运行

1. 克隆项目
```bash
git clone <repository-url>
cd misuzu_music
```

2. 安装依赖
```bash
flutter pub get
```

3. 运行项目
```bash
flutter run
```

## 文档

- [架构设计](docs/architecture.md)
- [功能需求](docs/requirements.md)
- [技术设计](docs/technical_design.md)

## 许可证

MIT License
