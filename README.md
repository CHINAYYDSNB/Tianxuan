# Tianxuan — 1Panel 第三方管理工具

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)

> 🚀 基于 Flutter 的 1Panel 服务器管理面板客户端。
>
> 支持 Android / iOS / Web 全平台。

## 快速开始

### 前提
- Flutter SDK 3.12+
- 一台运行 1Panel v2.x 的服务器
- 在 1Panel 后台生成 API Key（面板设置 → API 接口）

### 克隆 & 运行

```bash
git clone https://github.com/CHINAYYDSNB/Tianxuan_panel.git
cd Tianxuan_panel
flutter pub get
```

**Android APK:**
```bash
flutter build apk --release
# 安装到手机, 打开输入你的 1Panel 地址 + API Key
```

**iOS (需要 macOS):**
```bash
flutter build ios --release
```

**Web (浏览器直连, 有 CORS 限制):**
```bash
flutter run -d chrome
# 如果 API 跨域报错, 用下面同源服务器方案
```

**Web (同源服务器, 推荐开发用):**
```bash
# 1. 构建
flutter build web --release

# 2. 设置你的 1Panel 地址
export API_HOST=你的服务器IP   # Linux/macOS
set API_HOST=你的服务器IP      # Windows

# 3. 启动同源开发服务器
node server.mjs

# 4. 浏览器访问 http://localhost:25568
# 5. 登录页填入 localhost:25568 + 你的 API Key
```

## 许可证

本项目采用 **GNU Affero General Public License v3.0 (AGPLv3)** 开源。

- ✅ **个人/团队使用** — 免费，随意改
- ❌ **商业闭源使用** — 需购买商业授权
- 💖 **捐赠** — 支持作者继续开发

### 商业授权

如需将本项目集成到商业产品中（闭源发布、企业内部使用等），请联系作者获取商业授权。

---

## 项目分工

| 角色 | 负责 | 目录 |
|------|------|------|
| **逻辑开发** | API 封装、数据模型、状态管理 | `api/` `models/` `providers/` |
| **UI 开发** | 页面布局、交互、组件 | `pages/` `widgets/` |

---

## 开发环境

```bash
flutter pub get    # 安装依赖
flutter run        # 启动（需连接设备/模拟器）
```

### Web 开发（CORS 绕过）

```bash
# 构建
flutter build web --release

# 启动同源开发服务器（同时托管 Flutter + 代理 API）
node server.mjs
# 访问 http://localhost:25568
# 登录时填入 localhost:25568 和你的 API Key
```

## 架构总览

```
lib/
├── api/              ← HTTP 请求（不用动）
│   ├── client.dart      统一客户端（拦截器+错误处理）
│   └── *.dart           各模块 API
├── models/           ← 数据模型（不用动）
│   ├── website.dart
│   └── ...
├── providers/        ← Riverpod 状态管理（不用动）
│   ├── website_provider.dart
│   └── ...
├── pages/            ← UI 页面（你的地盘）
│   ├── dashboard/   服务器状态
│   ├── website/    网站管理
│   └── ...
├── widgets/          ← 公共 UI 组件（你的地盘）
│   └── ...
└── main.dart
```

**原则：UI 层只 import `providers/` 和 `models/`，不直接调 `api/`。**

---

## 连接配置

首页会先让用户输入：
- **服务器地址**：`http(s)://ip:端口`
- **API Key**：1Panel 后台生成的密钥

存储在 `SharedPreferences`，以后自动连接。

---

## 如何使用 Provider 获取数据

所有数据通过 Riverpod 的 `Provider` / `AsyncNotifierProvider` 暴露。

### 基础模式

```dart
// 读取数据
ref.watch(websitesProvider)          // → AsyncValue<List<Website>>
ref.watch(serverStatusProvider)      // → AsyncValue<ServerStatus>

// 触发操作
ref.read(websitesProvider.notifier).deleteWebsite(id: "123")
```

### AsyncValue 三种状态

```dart
final websites = ref.watch(websitesProvider);

websites.when(
  data: (list) => ListView.builder(/* 正常显示列表 */),
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text("加载失败: $e"),
);
```

---

## 各模块可用的 Provider

### 服务器状态 (`pages/dashboard/`)

| Provider | 类型 | 说明 |
|----------|------|------|
| `serverStatusProvider` | `AsyncNotifierProvider` | CPU、内存、磁盘、运行时间 |
| `dashboardProvider` | `FutureProvider` | 面板概览数据 |

用法示例：
```dart
class DashboardPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider);

    return status.when(
      data: (data) => Column(
        children: [
          // data.cpuUsage — CPU 使用率 (double 0~100)
          // data.memoryUsage — 内存使用率 (double 0~100)
          // data.diskUsage — 磁盘使用率 (double 0~100)
          // data.uptime — 运行时间 (String)
          Text("CPU: ${data.cpuUsage.toStringAsFixed(1)}%"),
          LinearProgressIndicator(value: data.cpuUsage / 100),
          Text("内存: ${data.memoryUsage.toStringAsFixed(1)}%"),
          LinearProgressIndicator(value: data.memoryUsage / 100),
        ],
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text("加载失败: $e"),
    );
  }
}
```

### 网站管理 (`pages/website/`)

| Provider | 类型 | 说明 |
|----------|------|------|
| `websitesProvider` | `AsyncNotifierProvider` | 网站列表+增删操作 |
| 方法 | 参数 | 说明 |
| `fetchWebsites()` | — | 刷新列表 |
| `deleteWebsite(id)` | `String id` | 删除网站 |

用法示例：
```dart
class WebsiteListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final websites = ref.watch(websitesProvider);

    return Scaffold(
      appBar: AppBar(title: Text("网站管理")),
      body: websites.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(list[i].domain),
            subtitle: Text(list[i].status), // running / stopped
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => ref.read(websitesProvider.notifier).deleteWebsite(list[i].id),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("错误: $e")),
      ),
    );
  }
}
```

---

## 当前已有的数据模型

### `ServerStatus`

| 字段 | 类型 | 说明 |
|------|------|------|
| `cpuUsage` | `double` | CPU 使用率 0~100 |
| `memoryUsage` | `double` | 内存使用率 0~100 |
| `diskUsage` | `double` | 磁盘使用率 0~100 |
| `uptime` | `String` | 系统运行时间 |
| `memoryTotal` | `String` | 总内存 |
| `memoryUsed` | `String` | 已用内存 |
| `diskTotal` | `String` | 总磁盘 |
| `diskUsed` | `String` | 已用磁盘 |

### `Website`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 网站 ID |
| `domain` | `String` | 域名 |
| `status` | `String` | 运行状态 |
| `path` | `String` | 网站目录 |
| `phpVersion` | `String?` | PHP 版本 |
| `createdAt` | `String` | 创建时间 |

---

## 导航结构

```dart
// main.dart — 已配好路由
MaterialApp(
  routes: {
    '/': (context) => const LoginPage(),          // 首次配置
    '/dashboard': (context) => const DashboardPage(), // 主页
    '/websites': (context) => const WebsiteListPage(), // 网站列表
  },
)
```

---

## 常用操作

```dart
// 1. 触发刷新
ref.invalidate(websitesProvider);

// 2. 监听某个值变化后执行操作
ref.listen(websitesProvider, (prev, next) {
  next.whenOrNull(data: (list) {
    if (list.isEmpty) showSnackBar("暂无网站");
  });
});

// 3. 组合多个数据
final both = ref.watch([serverStatusProvider, websitesProvider]);
```

---

## 设计建议

- **LoginPage**：服务器地址 + API Key 输入框，连接成功后跳转 Dashboard
- **DashboardPage**：四个卡片展示 CPU/内存/磁盘/运行时间，底部导航或抽屉菜单
- **WebsiteListPage**：列表+下拉刷新，每项显示域名和状态
- 风格：Material 3，主色蓝，支持深色模式
