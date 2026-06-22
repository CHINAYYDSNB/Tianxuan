# Tianxuan — 1Panel 第三方管理工具

*本软件开发借助了DeepSeek api和claude code进行实际操作*

## 前言

当我第一次看到1panel的时候，觉得界面真的很好看，那为什么不能做一个有着相同颜值的手机端管理呢？于是就有了这个项目

## 原理

其实就是调用api进行远程操作，具体方式可以看看[这个](https://1panel.cn/docs/v2/dev_manual/api_manual/)（面板api属于高敏感文件，请勿泄露）

## 项目分工

| 角色 | 负责 | 目录 |
|------|------|------|
| **逻辑开发** | API 封装、数据模型、状态管理 | `api/` `models/` `providers/` |
| **UI 开发**  *（估计还没上线的吧）*| 页面布局、交互、组件 | `pages/` `widgets/` |

---

## 开发环境

```bash
flutter pub get    # 安装依赖
flutter run        # 启动（需连接设备/模拟器）
```

## 架构总览

```
lib/
├── api/             
│   ├── client.dart      
│   └── *.dart           
├── models/           
│   ├── website.dart
│   └── ...
├── providers/       
│   ├── website_provider.dart
│   └── ...
├── pages/            
│   ├── dashboard/   
│   ├── website/    
│   └── ...
├── widgets/          
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

## 开发进度
新建文件夹
学习flutter
跑个界面
获取服务器基本信息
文件管理
## TODO
UI更新
网站状态管理
docker管理
高级功能（WAF等等）
