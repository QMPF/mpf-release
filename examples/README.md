# MPF 框架样例代码学习指南

本文档是 MPF（Modular Plugin Framework）框架样例代码的总索引，帮助学习者按正确的顺序理解框架的全部能力。

## 框架全景

```
┌─────────────────────────────────────────────────────────────┐
│                        mpf-host                             │
│  ┌──────────────┐  ┌──────────┐  ┌────────┐  ┌──────────┐ │
│  │ServiceRegistry│  │ EventBus │  │ Theme  │  │Navigation│ │
│  │   Settings    │  │  Logger  │  │  Menu  │  │ QmlCtx   │ │
│  └──────────────┘  └──────────┘  └────────┘  └──────────┘ │
└────────────┬──────────────┬───────────────┬────────────────┘
             │              │               │
         ┌───┴───┐    ┌────┴────┐    ┌─────┴─────┐
         │mpf-sdk│    │  QML    │    │  Plugins   │
         │(接口) │    │import   │    │(动态库)    │
         └───┬───┘    └────┬────┘    └─────┬─────┘
             │             │               │
    ┌────────┤      ┌──────┤        ┌──────┴───────┐
    │        │      │      │        │              │
┌───┴───┐ ┌──┴──┐ ┌┴──────┴──┐ ┌───┴─────┐ ┌─────┴────┐
│orders │ │rules│ │ui-comps  │ │orders   │ │rules     │
│plugin │ │plugn│ │MPFButton │ │plugin   │ │plugin    │
│(C++)  │ │(C++)│ │MPFCard.. │ │(QML)    │ │(QML)     │
└───┬───┘ └─────┘ └──────────┘ └─────────┘ └──────────┘
    │
┌───┴──────┐
│http-client│
│(C++ lib)  │
└───────────┘
```

## 学习路径

### 第一步：理解 SDK 接口（5 分钟）

阅读 `mpf-sdk/include/mpf/` 下的头文件，了解框架定义了哪些抽象接口。

**重点文件：**
- `interfaces/iplugin.h` — 插件生命周期接口
- `interfaces/ieventbus.h` — 事件总线接口（最复杂）
- `service_registry.h` — 服务注册表模板
- `interfaces/inavigation.h` — 导航接口
- `interfaces/imenu.h` — 菜单接口

### 第二步：理解 Host 如何组装一切（15 分钟）

阅读 `mpf-host/examples/` 目录下的样例：

| 顺序 | 文件 | 学习目标 |
|------|------|----------|
| 1 | `01_service_registry.cpp` | ServiceRegistry 如何存储和查找服务 |
| 2 | `02_event_bus.cpp` | EventBus 的发布/订阅机制 |
| 3 | `03_plugin_lifecycle.cpp` | 插件发现→加载→初始化→启动→停止 |
| 4 | `04_qml_context.cpp` | 服务如何暴露给 QML 层 |
| 5 | `05_theme_and_settings.cpp` | Theme 和 Settings 的实现与使用 |

### 第三步：理解公共组件（10 分钟）

阅读 `mpf-ui-components/examples/` 目录：

| 顺序 | 文件 | 学习目标 |
|------|------|----------|
| 1 | `01_theme_aware_component.qml` | 如何编写自适应 Theme 的组件 |
| 2 | `02_component_api_design.qml` | 组件属性接口设计 |
| 3 | `03_plugin_usage.qml` | 插件如何使用公共组件 |

### 第四步：理解完整的业务插件（20 分钟）

阅读 `mpf-plugin-orders/examples/` 目录：

| 顺序 | 文件 | 学习目标 |
|------|------|----------|
| 1 | `01_eventbus_publish.cpp` | C++ 层发布事件 |
| 2 | `02_eventbus_subscribe.cpp` | C++ 层订阅事件 |
| 3 | `03_service_registry_usage.cpp` | ServiceRegistry 的消费者和提供者角色 |
| 4 | `04_http_client_usage.cpp` | 使用 mpf-http-client 网络请求 |
| 5 | `05_eventbus_qml.qml` | QML 层的 EventBus 完整示例 |
| 6 | `06_full_plugin_example.cpp` | 集成所有能力的完整插件模板 |

### 第五步：理解跨插件协作（10 分钟）

阅读 `mpf-plugin-rules/examples/` 目录：

| 顺序 | 文件 | 学习目标 |
|------|------|----------|
| 1 | `01_subscribe_orders_events.cpp` | 如何监听并响应其他插件的事件 |
| 2 | `02_lightweight_plugin.cpp` | 纯 SDK 依赖的最小化插件 |
| 3 | `03_cross_plugin_qml.qml` | QML 层完整的跨插件通信示例 |

## 四大架构特色

### 1. 编译时依赖（Compile-time Dependencies）

```
插件 ──→ mpf-sdk           所有插件只依赖 SDK 接口（头文件）
orders ──→ mpf-http-client  需要 HTTP 的插件额外链接
rules  ──→ (无额外依赖)    轻量插件模式
```

**插件永远不依赖 Host 的实现类**，这是框架解耦的基础。

### 2. 运行时依赖（Runtime Dependencies）

```
QML 页面 ──→ MPF.Components  通过 import path 在运行时加载
QML 页面 ──→ Theme           通过 context property 在运行时注入
QML 页面 ──→ EventBus        通过 context property 在运行时注入
```

Host 负责设置所有运行时路径和注入全局对象。

### 3. 跨插件通信（Cross-Plugin Communication）

```
orders: EventBus.publish("orders/created", data, senderId)
           ↓ (EventBus 匹配订阅，发射 eventPublished 信号)
rules:  onEventPublished(topic, data, senderId) { ... }
           ↓ (处理后发布结果)
rules:  EventBus.publish("rules/check/completed", result, senderId)
           ↓
orders: onEventPublished(topic, data, senderId) { ... }
```

两个插件完全不知道对方的存在，只通过 topic 字符串约定通信。

### 4. 服务注册与发现（Service Registry）

```
Host:    registry->add<INavigation>(navImpl, version, "host")
Plugin:  auto* nav = registry->get<INavigation>()
         if (nav) nav->registerRoute("orders", pageUrl)
```

类型安全的服务查找，支持版本控制。

## 快速创建新插件

1. 复制 `mpf-plugin-orders` 或 `mpf-plugin-rules` 作为模板
2. 修改命名空间、类名、插件 ID
3. 修改 `xxx_plugin.json` 元数据
4. 修改 `CMakeLists.txt`
5. 实现 `initialize()` / `start()` / `stop()`
6. 创建 QML 页面（使用 `import MPF.Components 1.0`）

详见 `mpf-plugin-orders/examples/06_full_plugin_example.cpp` 中的完整模板。
