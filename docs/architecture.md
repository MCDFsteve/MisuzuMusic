# Misuzu Music 项目架构设计

## 架构概述

本项目采用 Clean Architecture + BLoC (Business Logic Component) 模式，严格分离业务逻辑与UI界面，确保代码的可维护性和跨平台兼容性。

## 架构分层

### 1. 表现层 (Presentation Layer)
- **责任**: UI组件、用户交互、状态管理
- **技术栈**: Flutter Widget、BLoC/Cubit
- **目录**: `lib/presentation/`

```
presentation/
├── pages/           # 页面组件
├── widgets/         # 通用UI组件
├── blocs/          # BLoC状态管理
└── themes/         # 主题和样式
```

### 2. 领域层 (Domain Layer)
- **责任**: 业务逻辑、用例定义、实体模型
- **技术栈**: 纯Dart代码，无框架依赖
- **目录**: `lib/domain/`

```
domain/
├── entities/       # 业务实体
├── usecases/       # 用例
├── repositories/   # 仓库接口
└── services/       # 服务接口
```

### 3. 数据层 (Data Layer)
- **责任**: 数据源管理、API调用、本地存储
- **技术栈**: HTTP客户端、数据库、文件系统
- **目录**: `lib/data/`

```
data/
├── models/         # 数据模型
├── repositories/   # 仓库实现
├── datasources/    # 数据源
└── services/       # 服务实现
```

### 4. 核心层 (Core Layer)
- **责任**: 依赖注入、错误处理、工具类
- **目录**: `lib/core/`

```
core/
├── di/            # 依赖注入
├── error/         # 错误处理
├── utils/         # 工具类
└── constants/     # 常量定义
```

## 跨平台UI适配策略

### 平台特定UI
```
presentation/
├── platform/
│   ├── macos/     # macOS原生风格UI
│   ├── windows/   # Windows原生风格UI
│   └── linux/     # Linux原生风格UI
└── common/        # 共通UI组件
```

### 适配机制
- 使用工厂模式根据平台创建对应UI组件
- 主题系统支持平台特定的设计语言
- 响应式布局适配不同屏幕尺寸

## 依赖关系

```
Presentation Layer (UI)
        ↓
Domain Layer (Business Logic)
        ↓
Data Layer (Data Access)
```

**依赖规则**:
- 上层依赖下层
- 下层不依赖上层
- Domain层为纯业务逻辑，不依赖任何框架