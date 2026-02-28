# MPF 架构文档

> 最后更新: 2026-02-26

## 概述

MPF (Modular Plugin Framework) 是一个基于 Qt 6 的模块化插件框架，支持：
- 插件动态发现、加载、依赖拓扑排序
- 跨插件通信（EventBus：发布/订阅 + 请求/响应）
- 服务注册表（ServiceRegistry，基于 `dynamic_cast` 类型安全）
- 跨 DLL 内存安全（MinGW/Windows，`CrossDllSafety::deepCopy()`）
- 开发环境隔离（mpf-dev CLI + dev.json 自动发现）

## 仓库结构

```
mpf-sdk             纯头文件接口库（IPlugin, IEventBus, INavigation 等）
mpf-host            宿主应用（插件管理、服务实现、QML Shell）
mpf-http-client     HTTP 客户端库（基于 QNetworkAccessManager）
mpf-ui-components   公共 QML 组件库 + C++ 工具类（ColorHelper, InputValidator）
mpf-plugin-orders   示例插件：订单管理（完整模板）
mpf-plugin-rules    示例插件：规则管理（多插件共存演示）
mpf-release         SDK 打包发布 + 文档
mpf-dev             开发环境 CLI 工具（Rust 实现）
```

## 核心接口（mpf-sdk）

mpf-sdk 是**纯头文件（header-only）**的接口库，不包含实现代码。所有接口的实现由 mpf-host 提供。

### IPlugin — 插件生命周期

```cpp
class IPlugin {
    virtual bool initialize(ServiceRegistry* registry) = 0;  // 创建服务、注册 QML 类型
    virtual bool start() = 0;      // 注册路由、菜单、加载数据
    virtual void stop() = 0;       // 清理资源
    virtual QJsonObject metadata() const = 0;  // 插件元数据
    virtual QString qmlModuleUri() const;      // QML 模块 URI（如 "YourCo.Orders"）
    virtual QString entryQml() const;          // 入口 QML 文件路径（通常为空）
};
```

插件必须使用 `Q_PLUGIN_METADATA` 和 `Q_INTERFACES` 宏：
```cpp
Q_PLUGIN_METADATA(IID MPF_IPlugin_iid FILE "../my_plugin.json")
Q_INTERFACES(mpf::IPlugin)
```

### ServiceRegistry — 服务注册表

```cpp
class ServiceRegistry {
    template<T> bool add(T* instance, int version, const QString& providerId);
    template<T> T* get(int minVersion = 0);
    template<T> bool has(int minVersion = 0) const;
};
```

**重要约束**：服务实现必须同时继承 `QObject` 和接口类型。`add()` 内部使用 `dynamic_cast<QObject*>` 检查，非 QObject 类型会被拒绝注册。

Host 使用 `ServiceRegistryImpl`（继承 QObject + ServiceRegistry），还提供：
- `getObject<T>()` — 返回 `QObject*`（用于 QML 暴露，避免多重继承的 cast 问题）
- `registeredServices()` — 获取所有已注册服务名称
- `serviceAdded` / `serviceRemoved` 信号

### IEventBus v3 — 跨插件通信

EventBus 是插件间通信的**唯一推荐方式**。两种模式：

#### 发布/订阅（一对多，无返回值）

用于通知、广播：

```cpp
// 发布事件（异步投递）
bus->publish("orders/created", {{"id", "42"}}, myPluginId);

// 同步发布（阻塞直到所有订阅者处理完成）
bus->publishSync("orders/created", data, myPluginId);

// 订阅（必须传 callback）
bus->subscribe("orders/*", myPluginId,
    [this](const Event& e) {
        // e.topic, e.senderId, e.data, e.timestamp
    });

// 通配符规则：
// * 匹配单级  → "orders/*" 匹配 orders/created, orders/updated
// ** 匹配多级 → "orders/**" 匹配 orders/created, orders/items/added
```

**SubscriptionOptions**:
- `async` (默认 true) — 异步投递 (QueuedConnection) 或同步
- `priority` — 数字越大越先收到
- `receiveOwnEvents` (默认 false) — 是否接收自己发的事件

#### 请求/响应（一对一，有返回值）

用于跨插件数据查询、RPC 调用：

```cpp
// Provider 注册处理器（一个 topic 只能一个 handler）
bus->registerHandler("orders/getById", myPluginId,
    [this](const Event& e) -> QVariantMap {
        auto id = e.data["id"].toString();
        return m_service->getOrder(id);
    });

// Consumer 发请求
auto result = bus->request("orders/getById", {{"id", "42"}}, myPluginId);
if (result) {
    QString customer = result->value("customer").toString();
}
// result 是 std::optional<QVariantMap>，无 handler 或异常时返回 nullopt
```

#### EventBus QML 接口

EventBusService 继承 QObject，通过 `EventBus` 上下文属性暴露给 QML：

```qml
// 信号驱动订阅
Connections {
    target: EventBus
    function onEventPublished(topic, data, senderId) {
        if (topic === "orders/created") {
            console.log("New order:", data.id)
        }
    }
}

// 调用 Q_INVOKABLE 方法
EventBus.publish("orders/created", {"id": "42"}, "com.yourco.orders")
var subId = EventBus.subscribeSimple("orders/*", "com.yourco.dashboard")
```

#### 插件清理

```cpp
void MyPlugin::stop() {
    auto* bus = m_registry->get<IEventBus>();
    bus->unsubscribeAll(myPluginId);
    bus->unregisterAllHandlers(myPluginId);
}
```

### INavigation — Loader-based 页面路由

简化的导航模型，避免跨 DLL 动态加载 QML 组件的问题：

```cpp
// 插件注册主页面 URL（QML 文件由 qt_add_qml_module 嵌入 DLL 的 qrc 资源）
nav->registerRoute("orders", "qrc:/YourCo/Orders/OrdersPage.qml");

// Host 使用 getPageUrl() 通过 Loader 加载页面
QString url = nav->getPageUrl("orders");
```

插件内部导航使用 Popup/Dialog，不依赖框架导航。

### 其他内置服务

| 接口 | QML 上下文名 | 用途 |
|------|-------------|------|
| `IMenu` | `AppMenu` | 侧边栏菜单管理（注册/注销/分组/排序/徽章） |
| `ISettings` | `Settings` | 应用设置（QSettings + INI，按 pluginId 命名空间隔离） |
| `ITheme` | `Theme` | 主题管理（Light/Dark，颜色/间距/圆角属性） |
| `ILogger` | — | 统一日志（Trace/Debug/Info/Warning/Error 五级） |

## 插件依赖管理

### 元数据声明（plugin.json）

```json
{
  "id": "com.yourco.dashboard",
  "name": "Dashboard Plugin",
  "version": "1.0.0",
  "provides": ["DashboardService"],
  "requires": [
    {"type": "plugin", "id": "com.yourco.orders", "min": "1.0"},
    {"type": "service", "id": "OrdersService", "min": "1.0"},
    {"type": "service", "id": "OptionalThing", "optional": true}
  ],
  "qmlModules": ["YourCo.Dashboard"],
  "priority": 10,
  "loadOnStartup": true
}
```

### 依赖解析流程

1. **discover()** — 扫描插件目录，读取 MetaData JSON，建立 `provides → pluginId` 映射
2. **computeLoadOrder()** — 拓扑排序（plugin 和 service 依赖都通过 provides 映射解析为 plugin ID）
   - 环形依赖会被检测并报警告
3. **checkDependencies()** — 加载前验证所有必需依赖存在且版本满足
4. **loadAll → initializeAll → startAll** — 按拓扑序执行生命周期

### 插件间通信策略

| 场景 | 推荐方式 |
|------|---------|
| 多插件共享的通用能力 | 提取为独立组件库（如 http-client），头文件进 SDK |
| 插件间松耦合通信 | EventBus publish/subscribe |
| 插件间需要返回值 | EventBus request/response |
| 强耦合插件 | 合并为一个插件或提取为组件库 |

**不推荐**：插件直接暴露 C++ 接口头文件给其他插件。

## UI 组件库（mpf-ui-components）

提供统一风格的 QML 组件和 C++ 工具类：

**QML 组件**（`import MPF.Components 1.0`）：
- `MPFButton` — 多类型按钮（primary/secondary/success/warning/danger/ghost）
- `MPFCard` — 卡片容器（标题、阴影、悬停效果）
- `MPFDialog` — 对话框（header/footer、类型图标、加载状态）
- `MPFTextField` — 输入框（标签、前后缀、校验、错误提示）
- `MPFIconButton` — 图标按钮
- `MPFLoadingIndicator` — 加载指示器
- `StatusBadge` — 状态徽章（自动颜色映射）

**C++ 工具类**（QML_ELEMENT + QML_SINGLETON）：
- `ColorHelper` — 颜色操作（lighten/darken/blend/contrastColor/statusColor）
- `InputValidator` — 输入验证（email/phone/required/length/range/password/url）

**重要约束**：插件**不得链接** `MPF::mpf-ui-components`。此库由 Host 链接加载，插件通过 `QML_IMPORT_PATH` 在运行时访问 QML 组件。在 Windows/MinGW 上直接链接会导致跨 DLL 堆损坏。

## 跨 DLL 内存安全

MinGW DLL 默认各自独立堆。`CrossDllSafety::deepCopy()` 确保所有从插件传入 host 的 Qt COW 类型（QString, QVariantMap, QStringList 等）在 host 堆上重新分配。

```cpp
// host 的服务实现中，所有从插件接收的字符串/容器都经过 deep copy
sub.pattern = deepCopy(pattern);
return deepCopy(response);
```

所有 MPF 组件在 MinGW 下使用 `-static-libgcc -static-libstdc++` 链接。

## Host 启动流程

```
main()
  └→ QQuickStyle::setStyle("Basic")
  └→ Application::initialize()
       ├→ setupPaths()         // SDK 检测、dev.json 读取、PATH 更新
       ├→ setupLogging()       // Logger 实例创建
       ├→ ServiceRegistryImpl  // 创建注册表
       ├→ 注册 6 个核心服务    // Navigation, Settings, Theme, Menu, Logger, EventBus
       ├→ QQmlApplicationEngine
       ├→ setupQmlContext()    // 注入 App, Navigation, Theme, AppMenu, Settings, EventBus
       ├→ loadPlugins()        // discover → loadAll → initializeAll → startAll
       └→ loadMainQml()       // MPF/Host/Main.qml
```

## 测试

```bash
# EventBus 测试
cd mpf-host/tests && cmake -B build && cmake --build build
./build/test_event_bus

# 插件依赖测试
./build/test_plugin_dependencies
```

覆盖：
- 发布/订阅：同步、异步、通配符、优先级、自身事件过滤
- 请求/响应：正常调用、无 handler、异常处理、重复注册
- 依赖：service 依赖解析、可选依赖、混合依赖、自引用检测、拓扑排序
