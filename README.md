# MPF Release

> 📖 **[MPF 开发环境完整教程](https://github.com/QMPF/mpf-dev/blob/main/docs/USAGE.md)** — 安装指南、命令参考、开发流程、IDE 配置、常见问题

Qt Modular Plugin Framework - Integrated Release

## 概述

这个仓库负责将所有 MPF 组件整合成完整的可运行程序，并发布到 GitHub Releases。

## 组件

| 组件 | 仓库 | 说明 |
|------|------|------|
| SDK | [mpf-sdk](https://github.com/QMPF/mpf-sdk) | 纯头文件接口库 |
| HTTP Client | [mpf-http-client](https://github.com/QMPF/mpf-http-client) | HTTP 客户端库 |
| UI Components | [mpf-ui-components](https://github.com/QMPF/mpf-ui-components) | QML 组件库 + C++ 工具类 |
| Host | [mpf-host](https://github.com/QMPF/mpf-host) | 宿主应用 |
| Orders Plugin | [mpf-plugin-orders](https://github.com/QMPF/mpf-plugin-orders) | 订单管理示例插件 |
| Rules Plugin | [mpf-plugin-rules](https://github.com/QMPF/mpf-plugin-rules) | 规则管理示例插件 |
| Dev CLI | [mpf-dev](https://github.com/QMPF/mpf-dev) | 开发环境 CLI 工具（Rust） |

## 文档

架构设计、开发工作流等详见 [docs/](./docs/) 目录。

## 下载

从 [Releases](https://github.com/QMPF/mpf-release/releases) 页面下载预编译包：

- `mpf-linux-x64.tar.gz` - Linux x64
- `mpf-windows-x64.zip` - Windows x64

## 运行

### Linux

```bash
tar -xzf mpf-linux-x64.tar.gz
cd mpf
./bin/mpf-host
```

### Windows

```powershell
# 解压 mpf-windows-x64.zip
cd mpf
.\bin\mpf-host.exe
```

## 手动构建

```bash
# 克隆并运行构建脚本
git clone https://github.com/QMPF/mpf-release.git
cd mpf-release
./scripts/build-release.sh
```

## 版本管理

每个组件都有独立的版本号。Release 版本号为 `YYYY.MM.DD` 格式。

## 许可证

MIT License
