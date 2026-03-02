# MPF 开发环境设计文档

> 最后更新: 2026-02-26

## 核心理念

**"SDK即完整运行时，源码构建覆盖运行"**

- 每个组件开发者只需要自己组件的源码
- 依赖通过SDK的二进制包提供（headers + libs）
- 开发时，自己的构建产物通过环境变量覆盖SDK中对应部分
- SDK本体保持只读，dev.json控制覆盖关系

## 方案选择

**方案B：运行时路径覆盖** ✅ 已选定

- SDK保持不可变
- `mpf-dev run` 读取 dev.json
- 通过 LD_LIBRARY_PATH / QML_IMPORT_PATH 等环境变量实现覆盖
- 优点：干净、支持多人/多组件开发、无文件系统冲突

## 目录结构

```
~/.mpf-sdk/
├── v1.0.0/                        # 版本化存储
│   ├── bin/
│   │   └── mpf-host(.exe)         # 主程序
│   ├── lib/
│   │   ├── （mpf-sdk 是 header-only，无库文件）
│   │   ├── libmpf-http-client.so/.dll
│   │   └── libmpf-ui-components.so/.dll
│   ├── plugins/
│   │   ├── libplugin-orders.so/.dll
│   │   └── libplugin-rules.so/.dll
│   ├── include/
│   │   ├── mpf-sdk/
│   │   ├── mpf-http-client/
│   │   ├── mpf-ui-components/
│   │   └── mpf-host/
│   └── qml/
│       ├── HttpClient/
│       ├── UiComponents/
│       └── Plugins/
├── current -> v1.0.26             # junction（Windows）或 symlink（Unix）指向当前版本
└── dev.json                       # 开发配置（哪些组件用源码模式）
```

## dev.json 格式

```json
{
  "sdk_version": "v1.0.33",
  "components": {
    "host": {
      "mode": "source",
      "bin": "/home/dev/mpf-host/build/bin",
      "qml": "/home/dev/mpf-host/build/qml",
      "root": "/home/dev/mpf-host"
    },
    "plugin-orders": {
      "mode": "source",
      "lib": "/home/dev/mpf-plugin-orders/build/plugins",
      "qml": "/home/dev/mpf-plugin-orders/build/qml",
      "plugin": "/home/dev/mpf-plugin-orders/build",
      "root": "/home/dev/mpf-plugin-orders"
    },
    "ui-components": {
      "mode": "source",
      "lib": "/home/dev/mpf-ui-components/build",
      "qml": "/home/dev/mpf-ui-components/build/qml",
      "root": "/home/dev/mpf-ui-components"
    }
  }
}
```

**字段说明：**
- `mode` — `"source"` 表示源码开发模式
- `lib` — 库文件目录
- `qml` — QML 模块目录
- `bin` — 可执行文件目录（仅 host）
- `plugin` — 插件构建根目录
- `root` — 项目源码根目录（由 `link` 自动推断或 `init` 设置），使 `link`/`unlink` 能自动为该项目重新生成 `CMakeUserPresets.json`

## mpf-dev CLI 命令

### 安装/管理 SDK

```bash
# 下载并安装SDK（从GitHub Releases）
mpf-dev setup [--version 1.0.0]

# 列出已安装版本
mpf-dev versions

# 切换当前版本
mpf-dev use <version>
```

### 组件开发

```bash
# 初始化项目（生成 CMakeUserPresets.json）
mpf-dev init

# 注册组件（构建完成后执行）
mpf-dev link plugin <name> <build-path>      # 插件
mpf-dev link component <name> <build-path>   # 库组件
mpf-dev link host <build-path>               # Host

# 取消注册
mpf-dev unlink <component>

# 查看当前开发状态
mpf-dev status
```

### 运行

```bash
# 启动主程序（自动应用dev.json中的覆盖）
mpf-dev run [--debug] [-- extra-args]

# 显示将要设置的环境变量（调试用）
mpf-dev env
```

## 运行时覆盖机制

`mpf-dev run` 执行时：

1. 读取 `~/.mpf-sdk/dev.json`
2. 构建环境变量：
   - **Linux**: `LD_LIBRARY_PATH`, `QML_IMPORT_PATH`, `QT_PLUGIN_PATH`
   - **Windows**: `PATH`, `QML_IMPORT_PATH`, `QT_PLUGIN_PATH`
3. 源码模式的路径插入到最前面（优先级最高）
4. 读取 `~/.mpf-sdk/current` 链接获取版本，启动对应版本的 `mpf-host`

```python
# 伪代码（实际 mpf-dev 用 Rust 实现，此处用 Python 说明逻辑）
def build_env():
    sdk_version = (Path.home() / ".mpf-sdk" / "current")
    sdk = Path.home() / ".mpf-sdk" / sdk_version
    dev = json.load(open(sdk.parent / "dev.json"))
    
    lib_paths = []
    qml_paths = []
    plugin_paths = []
    
    # 源码组件优先
    for name, cfg in dev.get("components", {}).items():
        if cfg.get("mode") == "source":
            if "lib" in cfg:
                lib_paths.append(cfg["lib"])
            if "qml" in cfg:
                qml_paths.append(cfg["qml"])
            if "plugin" in cfg:
                plugin_paths.append(cfg["plugin"])
    
    # SDK路径作为fallback
    lib_paths.append(str(sdk / "lib"))
    qml_paths.append(str(sdk / "qml"))
    plugin_paths.append(str(sdk / "plugins"))
    
    return {
        "LD_LIBRARY_PATH": ":".join(lib_paths),
        "QML_IMPORT_PATH": ":".join(qml_paths),
        "QT_PLUGIN_PATH": ":".join(plugin_paths),
    }
```

## 组件 CMakeLists.txt 模板

```cmake
cmake_minimum_required(VERSION 3.16)
project(mpf-http-client)

# 支持从SDK获取依赖
set(MPF_SDK_ROOT "$ENV{HOME}/.mpf-sdk/current" CACHE PATH "MPF SDK root")

# 添加SDK的include和lib路径
list(APPEND CMAKE_PREFIX_PATH "${MPF_SDK_ROOT}")
include_directories("${MPF_SDK_ROOT}/include")
link_directories("${MPF_SDK_ROOT}/lib")

find_package(Qt6 REQUIRED COMPONENTS Core Network Qml)

add_library(mpf-http-client SHARED
    src/http_client.cpp
)

target_link_libraries(mpf-http-client
    Qt6::Core
    Qt6::Network
    Qt6::Qml
    MPF::foundation-sdk  # header-only SDK
)

# 安装到build/lib，方便mpf-dev link
install(TARGETS mpf-http-client LIBRARY DESTINATION lib)
```

## 依赖关系

```
mpf-sdk (基础库)
    ↓
mpf-http-client (依赖 sdk)
mpf-ui-components (依赖 sdk)
    ↓
mpf-host (依赖 sdk, http-client, ui-components)
    ↓
plugin-orders (依赖 sdk, http-client, host headers)
plugin-rules (依赖 sdk, http-client, host headers)
    ↓
mpf-release (打包所有组件 → 生成SDK发布包)
```

## CI/CD 流程

1. **组件CI**: 每个组件独立构建，产出 lib + headers + qml
2. **mpf-release CI**: 
   - 下载所有组件的release artifacts
   - 组装成完整SDK目录结构
   - 打包发布到GitHub Releases

## 实现计划

- [ ] 创建 `mpf-dev` Rust CLI 工具（独立仓库 mpf-dev）
- [ ] 修改 mpf-release 的打包逻辑，生成符合目录结构的SDK包
- [ ] 更新各组件的 CMakeLists.txt 支持 `MPF_SDK_ROOT`
- [ ] 编写使用文档

## 开发者工作流示例

```bash
# 1. 首次设置（只需一次）
cargo install mpf-dev  # 或从 GitHub Releases 下载二进制
mpf-dev setup

# 2. 克隆自己负责的组件
git clone https://github.com/QMPF/mpf-http-client
cd mpf-http-client

# 3. 初始化项目（生成 CMakeUserPresets.json）
mpf-dev init

# 4. 构建
cmake --preset dev
cmake --build build

# 5. 注册为源码开发模式（构建完成后）
mpf-dev link component http-client ./build

# 6. 运行测试（使用 SDK 的 host，但加载自己的构建产物）
mpf-dev run

# 7. 日常迭代：修改代码 → cmake --build build → mpf-dev run
```

> **依赖关系：** `init` 在 `link` 之前（init 生成当前项目的 CMake 配置）；`link` 在构建之后（link 需要 build 目录存在）。`link` 后会自动为所有已注册项目重新生成 `CMakeUserPresets.json`（不影响构建目录）。
