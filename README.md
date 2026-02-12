# MPF Release

Qt Modular Plugin Framework - Integrated Release

## 概述

这个仓库负责将所有 MPF 组件整合成完整的可运行程序，并发布到 GitHub Releases。

## 组件

| 组件 | 仓库 |
|------|------|
| SDK | [mpf-sdk](https://github.com/dyzdyz010/mpf-sdk) |
| HTTP Client | [mpf-http-client](https://github.com/dyzdyz010/mpf-http-client) |
| UI Components | [mpf-ui-components](https://github.com/dyzdyz010/mpf-ui-components) |
| Host | [mpf-host](https://github.com/dyzdyz010/mpf-host) |
| Orders Plugin | [mpf-plugin-orders](https://github.com/dyzdyz010/mpf-plugin-orders) |
| Rules Plugin | [mpf-plugin-rules](https://github.com/dyzdyz010/mpf-plugin-rules) |
| Dev CLI | [mpf-dev](https://github.com/dyzdyz010/mpf-dev) |

## 文档

详细文档见 [docs/](./docs/) 目录。

## 下载

从 [Releases](https://github.com/dyzdyz010/mpf-release/releases) 页面下载预编译包：

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
git clone https://github.com/dyzdyz010/mpf-release.git
cd mpf-release
./scripts/build-release.sh
```

## 版本管理

每个组件都有独立的版本号。Release 版本号为 `YYYY.MM.DD` 格式。

## 许可证

MIT License
