# MPF 架构文档

> 最后更新: 2026-02-12

## 概述

MPF (Modular Plugin Framework) 是一个基于 Qt 6 的模块化插件框架，支持：
- 插件动态发现、加载、依赖管理
- 跨插件通信（EventBus：发布/订阅 + 请求/响应）
- 服务注册表（ServiceRegistry）
- 跨 DLL 内存安全（MinGW/Windows）
- 开发环境隔离（mpf-dev CLI）

## 仓库结构

```
mpf-sdk            纯头文件接口库（IPlugin, IEventBus, INavigation 等）
mpf-host           宿主应用（插件管理、服务实现、QML 引擎）
mpf-http-client    HTTP 组件库
mpf-ui-components  公共 QML 组件库
mpf-plugin-orders  示例插件：订单管理
mpf-plugin-rules   示例插件：规则引擎
mpf-release        SDK 打包发布
mpf-dev            开发环境 CLI 工具（Rust）
```

## 核心接口（mpf-sdk）

### IPlugin — 插件生命周期

```cpp
class IPlugin {
    virtual bool initialize(ServiceRegistry* registry) = 0;  // 注册服务、QML 类型
    virtual bool start() = 0;      // 注册路由、菜单、加载数据
    virtual void stop() = 0;       // 清理资源
    virtual QJsonObject metadata() const = 0;  // 插件元数据
};
```

### ServiceRegistry — 服务注册表

```cpp
class ServiceRegistry {
    template<T> bool add(T* instance, int version, const QString& providerId);
    template<T> T* get(int minVersion = 0);
    template<T> bool has(int minVersion = 0) const;
};
```

**注意**：服务实现必须同时继承 `QObject` 和接口类型。`add()` 内部使用 `dynamic_cast<QObject*>`，非 QObject 类型会被拒绝注册。

### IEventBus v3 — 跨插件通信

EventBus 是插件间通信的**唯一推荐方式**。两种模式：

#### 发布/订阅（一对多，无返回值）

用于通知、广播：

```cpp
// 发布事件
bus->publish("orders/created", {{"id", "42"}}, myPluginId);
bus->publishSync("orders/created", data, myPluginId);  // 同步版

// 订阅（必须传 callback）
bus->subscribe("orders/*", myPluginId,
    [this](const Event& e) {
        // 处理事件
    });

// 通配符：* 匹配单级，** 匹配多级
// "orders/*"    匹配 orders/created, orders/updated
// "orders/**"   匹配 orders/created, orders/items/added
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
        auto order = m_service->getOrder(id);
        return order.toVariantMap();
    });

// Consumer 发请求
auto result = bus->request("orders/getById", {{"id", "42"}}, myPluginId);
if (result) {
    QString customer = result->value("customer").toString();
}
// result 是 std::optional<QVariantMap>，无 handler 或异常时返回 nullopt

// QML 侧
var result = EventBus.requestFromQml("orders/getById", {"id": "42"})
if (result.__success) { /* use result.customer */ }
```

#### 插件清理

```cpp
void MyPlugin::stop() {
    auto* bus = m_registry->get<IEventBus>();
    bus->unsubscribeAll(myPluginId);
    bus->unregisterAllHandlers(myPluginId);
}
```

### 其他内置服务

| 接口 | 用途 |
|------|------|
| `INavigation` | Loader-based 页面路由 |
| `IMenu` | 侧边栏菜单管理 |
| `ISettings` | 应用设置 |
| `ITheme` | 主题管理 |
| `ILogger` | 统一日志 |

## 插件依赖管理

### 元数据声明

```json
{
  "id": "com.yourco.dashboard",
  "version": "1.0.0",
  "provides": ["DashboardService"],
  "requires": [
    {"type": "plugin", "id": "com.yourco.orders", "min": "1.0"},
    {"type": "service", "id": "OrdersService", "min": "1.0"},
    {"type": "service", "id": "OptionalThing", "optional": true}
  ]
}
```

### 依赖解析流程

1. **discover()** — 扫描插件目录，读取元数据，建立 `provides → pluginId` 映射
2. **computeLoadOrder()** — 拓扑排序，**plugin 和 service 依赖都参与排序**
   - service 依赖通过 provides 映射解析为 plugin ID
   - 环形依赖会被检测并报警
3. **checkDependencies()** — 加载前验证所有必需依赖存在
4. **loadAll → initializeAll → startAll** — 按拓扑序执行生命周期

### 插件间通信策略

| 场景 | 方式 |
|------|------|
| 多插件共享的通用能力 | 提取为独立组件库（如 http-client），头文件进 SDK |
| 插件间松耦合通信 | EventBus publish/subscribe |
| 插件间需要返回值 | EventBus request/response |
| 强耦合插件 | 合并为一个插件或提取为组件库 |

**不推荐**：插件直接暴露 C++ 接口头文件给其他插件。

## 跨 DLL 内存安全

MinGW DLL 默认各自独立堆。`CrossDllSafety::deepCopy()` 确保所有从插件传入 host 的 Qt COW 类型（QString, QVariantMap 等）在 host 堆上重新分配。

```cpp
// 所有从插件接收的字符串/容器都经过 deep copy
sub.pattern = deepCopy(pattern);
return deepCopy(response);
```

Host 在 MinGW 下使用 `-static-libgcc -static-libstdc++` 避免 CRT 不匹配。

## 测试

```bash
# EventBus 测试（27 个）
cd mpf-host/tests/build && ./test_event_bus

# 插件依赖测试（10 个）
cd mpf-host/tests/build && ./test_plugin_dependencies
```

覆盖：
- 发布/订阅：同步、异步、通配符、优先级、自身事件过滤
- 请求/响应：正常调用、无 handler、异常处理、重复注册、QML 接口
- 依赖：service 依赖解析、可选依赖、混合依赖、自引用检测
