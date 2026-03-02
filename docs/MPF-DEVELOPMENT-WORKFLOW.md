# MPF 组件开发全流程指南

## 概述

MPF (Modular Plugin Framework) 采用组件化架构，每个开发者只需关注自己负责的组件源码，其他依赖以二进制形式提供。

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      mpf-release (SDK)                       │
│  ┌─────────┬──────────────┬────────────────┬─────────────┐  │
│  │   bin/  │    lib/      │    include/    │    qml/     │  │
│  │mpf-host │ 所有组件库    │  所有组件头文件  │  QML模块    │  │
│  └─────────┴──────────────┴────────────────┴─────────────┘  │
└─────────────────────────────────────────────────────────────┘

依赖关系:
┌─────────┐
│ mpf-sdk │ (核心接口)
└────┬────┘
     │
     ├──────────────┬────────────────┐
     ▼              ▼                ▼
┌──────────┐  ┌─────────────┐  ┌──────────┐
│http-client│  │ui-components│  │   其他   │
└─────┬────┘  └──────┬──────┘  └─────┬────┘
      │              │               │
      └──────────────┼───────────────┘
                     ▼
              ┌───────────┐
              │  mpf-host │ (宿主程序)
              └─────┬─────┘
                    │
      ┌─────────────┼─────────────┐
      ▼             ▼             ▼
┌───────────┐ ┌───────────┐ ┌───────────┐
│plugin-orders│ │plugin-rules│ │ 你的插件  │
└───────────┘ └───────────┘ └───────────┘
```

---

## 一、环境准备

### 1.1 安装 mpf-dev 工具

**Windows:**
```powershell
# 下载
Invoke-WebRequest -Uri "https://github.com/QMPF/mpf-dev/releases/latest/download/mpf-dev-windows-x86_64.zip" -OutFile mpf-dev.zip

# 解压
Expand-Archive mpf-dev.zip -DestinationPath C:\Tools\mpf-dev

# 添加到 PATH
$env:Path += ";C:\Tools\mpf-dev"
```

**Linux:**
```bash
curl -LO https://github.com/QMPF/mpf-dev/releases/latest/download/mpf-dev-linux-x86_64.tar.gz
tar xzf mpf-dev-linux-x86_64.tar.gz
sudo mv mpf-dev /usr/local/bin/
```

### 1.2 安装 SDK

```bash
mpf-dev setup
```

这会下载完整的 MPF SDK 到 `~/.mpf-sdk/`，包含：
- `bin/` - mpf-host 可执行文件
- `lib/` - 所有组件的库文件
- `include/` - 所有组件的头文件
- `qml/` - QML 模块
- `plugins/` - 已有插件

### 1.3 验证安装

```bash
mpf-dev status
```

输出示例：
```
MPF Development Environment Status

SDK:
  Root: C:\Users\you\.mpf-sdk
  Current version: v1.0.0
  Config: C:\Users\you\.mpf-sdk\dev.json

Components:
  No components linked for source development.
```

---

## 二、开发新组件

### 2.1 确定组件类型

| 类型 | 说明 | 依赖 | 示例 |
|------|------|------|------|
| 库 (Library) | 共享功能模块 | mpf-sdk | http-client, ui-components |
| 插件 (Plugin) | 可动态加载的功能 | mpf-sdk + libs + host | plugin-orders, plugin-rules |
| 宿主 (Host) | 主程序 | mpf-sdk + libs | mpf-host |

### 2.2 创建项目

**创建 GitHub 仓库:**
```bash
# 创建本地项目
mkdir mpf-my-component
cd mpf-my-component

# 初始化 Git
git init
```

**项目结构:**
```
mpf-my-component/
├── CMakeLists.txt
├── include/
│   └── my_component/
│       └── my_component.h
├── src/
│   └── my_component.cpp
├── qml/                      # 如果有 QML
│   └── MyComponent/
│       └── qmldir
├── .github/
│   └── workflows/
│       └── ci.yml
└── README.md
```

### 2.3 CMakeLists.txt 模板

**库组件:**
```cmake
cmake_minimum_required(VERSION 3.21)
project(mpf-my-component VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Qt 和 SDK 通过 CMAKE_PREFIX_PATH 发现（mpf-dev init 自动配置）
find_package(Qt6 REQUIRED COMPONENTS Core Qml)
find_package(MPF REQUIRED)

add_library(mpf-my-component SHARED
    src/my_component.cpp
    include/my_component/my_component.h
)

target_include_directories(mpf-my-component PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(mpf-my-component
    PUBLIC Qt6::Core Qt6::Qml
    PRIVATE MPF::foundation-sdk  # header-only SDK
)

# 安装
include(GNUInstallDirs)
install(TARGETS mpf-my-component
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
```

**插件组件:**
```cmake
cmake_minimum_required(VERSION 3.21)
project(mpf-plugin-my VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(MPF REQUIRED)
find_package(MPFHttpClient QUIET)  # 可选

# 插件是 SHARED 类型（Qt 插件系统要求）
add_library(mpf-plugin-my SHARED
    src/my_plugin.cpp
    include/my_plugin.h
)

target_include_directories(mpf-plugin-my PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(mpf-plugin-my PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick
    MPF::foundation-sdk
    $<$<TARGET_EXISTS:MPF::mpf-http-client>:MPF::mpf-http-client>
    # 注意：不要链接 MPF::mpf-ui-components！由 Host 加载。
)

# QML 模块
set(PLUGIN_QML_FILES qml/MyPage.qml)
foreach(file ${PLUGIN_QML_FILES})
    string(REGEX REPLACE "^qml/" "" alias "${file}")
    set_source_files_properties(${file} PROPERTIES QT_RESOURCE_ALIAS ${alias})
endforeach()

qt_add_qml_module(mpf-plugin-my
    URI YourCo.MyModule
    VERSION 1.0
    RESOURCE_PREFIX /
    QML_FILES ${PLUGIN_QML_FILES}
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/YourCo/MyModule
    NO_PLUGIN
)

# 输出到 plugins 目录
set_target_properties(mpf-plugin-my PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/plugins
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/plugins
)

install(TARGETS mpf-plugin-my LIBRARY DESTINATION plugins RUNTIME DESTINATION plugins)
install(DIRECTORY ${CMAKE_BINARY_DIR}/qml/YourCo DESTINATION qml)
```

---

## 三、开发流程

### 3.1 初始化项目

```bash
cd mpf-my-component

# 生成 CMakeUserPresets.json（自动检测 Qt、MinGW、SDK 路径）
mpf-dev init
```

### 3.2 构建

```bash
# 配置（使用 mpf-dev init 生成的 preset）
cmake --preset dev

# 构建
cmake --build build
```

### 3.3 注册组件

构建完成后，将组件注册到 `dev.json`，使 host 能发现它：

```bash
# 插件
mpf-dev link plugin my-plugin ./build

# 库组件
mpf-dev link component my-component ./build

# 检查状态
mpf-dev status
```

> **注意：** `link` 必须在构建之后执行，因为它需要 `build/` 目录下的构建产物路径存在。

### 3.4 运行测试

```bash
# 使用 SDK 的 host，但加载你的组件
mpf-dev run

# 或带调试信息
mpf-dev run --debug
```

`mpf-dev run` 会自动设置环境变量，让系统优先加载你的构建产物：
- Linux: `LD_LIBRARY_PATH`
- Windows: `PATH`
- 两者: `QML_IMPORT_PATH`, `QT_PLUGIN_PATH`

### 3.5 开发循环

```
修改代码 → cmake --build build → mpf-dev run → 测试 → 重复
```

### 3.6 切换回二进制模式

开发完成后：
```bash
mpf-dev unlink my-component
```

---

## 四、CI/CD 配置

### 4.1 GitHub Actions 模板

创建 `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]

env:
  QT_VERSION: '6.8.3'
  SDK_VERSION: 'v1.0.0'

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-22.04
            platform: linux
            artifact: mpf-my-component-linux-x64
          - os: windows-latest
            platform: windows
            artifact: mpf-my-component-windows-x64

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Install Qt
        uses: jurplel/install-qt-action@v4
        with:
          version: ${{ env.QT_VERSION }}
          arch: ${{ matrix.platform == 'windows' && 'win64_mingw' || 'linux_gcc_64' }}
          tools: ${{ matrix.platform == 'windows' && 'tools_mingw1310' || '' }}

      - name: Setup MinGW (Windows)
        if: runner.os == 'Windows'
        run: echo "${{ runner.temp }}/../Qt/Tools/mingw1310_64/bin" >> $GITHUB_PATH
        shell: bash

      - name: Install Ninja
        run: |
          if [ "$RUNNER_OS" == "Windows" ]; then
            choco install ninja -y
          else
            sudo apt-get install -y ninja-build
          fi
        shell: bash

      - name: Download SDK
        run: |
          mkdir -p deps/sdk
          curl -L "https://github.com/QMPF/mpf-release/releases/download/${{ env.SDK_VERSION }}/mpf-${{ matrix.platform }}-x64.${{ matrix.platform == 'windows' && 'zip' || 'tar.gz' }}" -o sdk-archive
          if [ "${{ matrix.platform }}" == "windows" ]; then
            unzip sdk-archive -d deps/sdk
          else
            tar xzf sdk-archive -C deps/sdk
          fi
        shell: bash

      - name: Configure
        run: |
          cmake -B build -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DMPF_SDK_ROOT=${{ github.workspace }}/deps/sdk
        shell: bash

      - name: Build
        run: cmake --build build

      - name: Package
        run: |
          mkdir -p dist/lib dist/include
          cp build/*.so build/*.dll dist/lib/ 2>/dev/null || true
          cp -r include/* dist/include/
          if [ "${{ matrix.platform }}" == "windows" ]; then
            cd dist && 7z a ../${{ matrix.artifact }}.zip *
          else
            cd dist && tar czvf ../${{ matrix.artifact }}.tar.gz *
          fi
        shell: bash

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact }}
          path: ${{ matrix.artifact }}.*

  release:
    needs: build
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - uses: actions/download-artifact@v4
        with:
          path: artifacts

      - uses: softprops/action-gh-release@v2
        with:
          files: artifacts/**/*
          generate_release_notes: true
```

### 4.2 发布流程

```bash
# 提交代码
git add .
git commit -m "feat: add new feature"
git push

# 创建版本
git tag v1.0.0
git push origin v1.0.0
```

CI 会自动：
1. 构建 Linux + Windows 版本
2. 创建 GitHub Release
3. 上传二进制包

---

## 五、多组件协作开发

### 5.1 同时开发多个组件

```bash
# 在各项目中初始化并构建
cd ~/projects/mpf-http-client
mpf-dev init
cmake --preset dev
cmake --build build

cd ~/projects/mpf-ui-components
mpf-dev init
cmake --preset dev
cmake --build build

# 构建完成后，注册组件
mpf-dev link component ui-components ./build
cd ~/projects/mpf-http-client
mpf-dev link component http-client ./build

# 查看状态
mpf-dev status
```

### 5.2 环境变量查看

```bash
mpf-dev env
```

输出：
```bash
# Add these to your shell:
export LD_LIBRARY_PATH="/home/user/mpf-http-client/build/lib:/home/user/mpf-ui-components/build/lib:/home/user/.mpf-sdk/current/lib"
export QML_IMPORT_PATH="/home/user/mpf-ui-components/qml:/home/user/.mpf-sdk/current/qml"
export QT_PLUGIN_PATH="/home/user/.mpf-sdk/current/plugins"
```

---

## 六、IDE 配置

### 6.1 QML 智能提示

**推荐方式：** 执行 `mpf-dev init` 生成的 `CMakeUserPresets.json` 已包含 `QML_IMPORT_PATH`，Qt Creator 会自动读取。通常无需额外配置。

如果仍需手动设置，可选以下方式：

**方法 1：系统环境变量**

Linux/macOS (`~/.bashrc` 或 `~/.zshrc`):
```bash
export QML_IMPORT_PATH="$HOME/.mpf-sdk/current/qml"
```

Windows (系统环境变量):
```
QML_IMPORT_PATH = %USERPROFILE%\.mpf-sdk\current\qml
```

**方法 2：Qt Creator 项目设置**
1. 左侧 Projects → Build Settings
2. Build Environment → Add
3. 变量: `QML_IMPORT_PATH`
4. 值: `~/.mpf-sdk/current/qml`

### 6.2 头文件智能提示

CMakeLists.txt 中已包含 SDK include 路径，IDE 应自动识别：
```cmake
include_directories("${MPF_SDK_ROOT}/include")
```

如果 IDE 仍无法找到头文件，手动添加 include 路径：
- **VS Code (c_cpp_properties.json)**:
  ```json
  {
    "configurations": [{
      "includePath": [
        "${workspaceFolder}/**",
        "${env:HOME}/.mpf-sdk/current/include"
      ]
    }]
  }
  ```

- **Qt Creator**: 通常自动从 CMake 读取，无需额外配置

- **CLion**: 同样自动从 CMake 读取

### 6.3 调试配置

**Qt Creator:**

mpf-host 启动时自动读取 `~/.mpf-sdk/dev.json`，发现已注册的源码组件路径。因此在 Qt Creator 中直接运行/调试时**无需手动配置环境变量**，只需确保已通过 `mpf-dev link` 注册组件即可。

**VS Code (launch.json)**:
```json
{
  "version": "0.2.0",
  "configurations": [{
    "name": "Debug MPF",
    "type": "cppdbg",
    "request": "launch",
    "program": "${env:HOME}/.mpf-sdk/current/bin/mpf-host",
    "environment": [
      {"name": "LD_LIBRARY_PATH", "value": "${workspaceFolder}/build/lib:${env:HOME}/.mpf-sdk/current/lib"},
      {"name": "QML_IMPORT_PATH", "value": "${workspaceFolder}/qml:${env:HOME}/.mpf-sdk/current/qml"},
      {"name": "QT_PLUGIN_PATH", "value": "${workspaceFolder}/build:${env:HOME}/.mpf-sdk/current/plugins"}
    ]
  }]
}
```

---

## 七、常见问题

### Q: 找不到头文件？
确保 CMakeLists.txt 中正确设置了 `MPF_SDK_ROOT` 并 include 了 `${MPF_SDK_ROOT}/include`。

### Q: 链接错误？
1. 检查 `link_directories("${MPF_SDK_ROOT}/lib")`
2. 确保依赖的库已在 `target_link_libraries` 中列出

### Q: 运行时找不到库？
使用 `mpf-dev run` 而不是直接运行 mpf-host，它会自动设置正确的库搜索路径。

### Q: Windows 上 setup 报权限错误？
v0.1.2 已修复。请更新 mpf-dev 到最新版本。

### Q: 如何切换 SDK 版本？
```bash
mpf-dev setup --version 1.1.0  # 安装新版本
mpf-dev use 1.1.0              # 切换
mpf-dev versions               # 查看已安装版本
```

### Q: IDE 中 QML import 报错？
设置 `QML_IMPORT_PATH` 环境变量指向 SDK 的 qml 目录，详见第六节 IDE 配置。

### Q: 如何同时调试多个组件？
使用 `mpf-dev link` 注册多个组件，然后用 `mpf-dev run --debug` 查看加载了哪些源码版本。

---

## 八、目录结构参考

```
~/.mpf-sdk/
├── v1.0.26/                   # SDK 版本
│   ├── bin/mpf-host
│   ├── lib/
│   │   ├── libmpf-http-client.so/.dll
│   │   └── libmpf-ui-components.so/.dll
│   ├── include/
│   │   └── mpf/               # foundation-sdk 头文件（header-only）
│   ├── plugins/
│   │   ├── liborders-plugin.so/.dll
│   │   └── librules-plugin.so/.dll
│   └── qml/
│       ├── MPF/Components/    # ui-components
│       ├── MPF/Host/          # host QML
│       ├── YourCo/Orders/     # orders 插件
│       └── Biiz/Rules/        # rules 插件
├── current -> v1.0.26         # junction/symlink 指向当前版本
└── dev.json                   # 开发配置
```

> 注意：mpf-sdk 是纯头文件库，不产生 .so/.dll 文件。

---

## 九、插件间通信（EventBus）

插件之间**不直接暴露 C++ 接口**，统一通过 EventBus 通信。

### 发布/订阅（通知，一对多）

```cpp
// 在 start() 中订阅
auto* bus = m_registry->get<mpf::IEventBus>();
bus->subscribe("orders/*", "com.yourco.dashboard",
    [this](const mpf::Event& e) {
        refreshDashboard();
    });

// 在业务逻辑中发布
bus->publish("orders/created", {{"id", orderId}}, "com.yourco.orders");
```

### 请求/响应（查询，一对一）

```cpp
// Provider 在 initialize() 中注册
bus->registerHandler("orders/getAll", "com.yourco.orders",
    [this](const mpf::Event&) -> QVariantMap {
        return {{"orders", m_service->getAllAsVariant()}};
    });

// Consumer 在需要时请求
auto result = bus->request("orders/getAll", {}, "com.yourco.dashboard");
if (result) {
    auto orders = result->value("orders").toList();
}
```

### 清理（在 stop() 中）

```cpp
void MyPlugin::stop() {
    auto* bus = m_registry->get<mpf::IEventBus>();
    bus->unsubscribeAll("com.yourco.myplugin");
    bus->unregisterAllHandlers("com.yourco.myplugin");
}
```

详细 API 参考见 `MPF-ARCHITECTURE.md`。

---

## 十、流程总结

```
1. mpf-dev setup                              # 安装 SDK
2. 创建项目 + CMakeLists.txt
3. mpf-dev init                               # 生成 CMakeUserPresets.json
4. cmake --preset dev && cmake --build build  # 配置 + 构建
5. mpf-dev link plugin <name> ./build         # 注册到 dev.json（构建后）
6. mpf-dev run                                # 测试
7. 修改代码 → cmake --build build → mpf-dev run  # 日常迭代
8. git push + git tag                         # 发布
9. mpf-dev unlink <component>                 # 切回二进制模式
```

> **依赖关系：** `init` 在 `link` 之前（init 生成当前项目自己的 CMake 配置）；`link` 在构建之后（link 需要 `build/plugins` 和 `build/qml` 目录存在）。
