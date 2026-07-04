# Tianxuan — 1Panel 第三方移动管理工具

*本软件开发借助了 DeepSeek API 和 Claude Code 进行实际操作*

> **v0.0.10** | [下载 APK](https://github.com/CHINAYYDSNB/Tianxuan/releases/latest) | [使用文档](docs/user-guide.md)

## 这是什么

1Panel Linux 面板的手机端管理器。调 API 远程操作，支持 Web 和 Android。

[1Panel API 文档](https://1panel.cn/docs/v2/dev_manual/api_manual/)（面板 API 属高敏感文件，请勿泄露）

## 已实现功能

| 模块 | 功能 |
|------|------|
| **服务器概览** | CPU/内存/磁盘实时环状图、系统信息、运行时间 |
| **网站管理** | 列表/启停/删除、状态标签 |
| **文件管理** | 浏览/创建/编辑/重命名/移动/复制/压缩解压/上传下载 |
| **Docker 管理** | 容器列表/详情/启停/日志(SSE 实时), 镜像拉取/删除 |
| **Docker Compose** | 列表/启停/编辑, 应用商店浏览/安装/更新 |
| **WAF 防护** | 概览、IP 规则、规则组、日志 (4 子 Tab) |
| **SSH 终端** | WebSocket 连接, 远程 Shell |
| **云备份** | 1Panel 云备份功能入口 |
| **健康检测** | CPU/内存/磁盘/容器健康聚合, 阈值配置 |
| **多服务器** | 切换/添加/删除, API Key 加密存储 |
| **Logto 登录** | PKCE 授权码流程 (Web PKCE / Native deep link) |
| **版本检测** | GitHub Release 自动检查更新 |

## 连接配置

首页输入：
- **服务器地址**：`http(s)://ip:端口`
- **API Key**：1Panel 后台 → 设置 → API Key 生成

保存后自动连接，支持多服务器切换。

## 快速开始

```bash
# 开发
flutter pub get
flutter run           # 需连接设备/模拟器

# Web 开发（绕过 CORS）
node server.mjs       # 同源代理: 端口 25568

# 构建 APK
flutter build apk --release
```

## 导航结构

```
底部导航 (6 Tab)
├── 概览 — 服务器状态 + 系统信息
├── 文件 — 文件浏览器
├── 网站 — 网站管理
├── 容器 — Docker 管理 (容器/镜像/Compose/商店/已安装)
├── WAF  — WAF 防护
└── 设置 — 服务器切换 / 健康检测 / 关于
```

## 架构

```
lib/
├── api/          Dio 封装 + 各模块 API
├── models/       数据模型
├── providers/    Riverpod 状态管理
├── pages/        页面 UI
├── widgets/      通用组件
├── services/     跨平台服务 (Logto/SSH/更新检测)
└── utils/        工具 (下载器)
```

原则：UI 只调 providers/models，不直接调 api。

## 构建

```bash
flutter build apk --release
```

APK 产物: `build/app/outputs/flutter-apk/app-release.apk`
