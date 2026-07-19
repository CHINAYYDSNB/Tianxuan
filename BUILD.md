# Tianxuan CI/CD 配置

## GitHub Actions 自动构建

推送到 `main`/`master` 分支时自动触发，构建 release APK。

### Secrets 配置

需在仓库 `CHINAYYDSNB/Tianxuan` 配置以下 4 个 Secrets：

| Secret | 说明 |
|---|---|
| `KEYSTORE_BASE64` | keystore 文件的 base64 编码 |
| `KEYSTORE_PASSWORD` | keystore 密码 |
| `KEY_ALIAS` | `tianxuan` |
| `KEY_PASSWORD` | key 密码 |

> ⚠️ **密码值不要记录在此文件中！** 通过 `gh secret set` 或 GitHub 网页设置。

### Keystore 信息

- **文件位置**：`android/app/tianxuan.keystore`（已 gitignore，不提交到仓库）
- **别名 (alias)**：`tianxuan`
- **算法**：RSA 2048 位
- **有效期**：10000 天
- **证书主体**：CN=Tianxuan, OU=Dev, O=Tianxuan, L=Shenzhen, ST=Guangdong, C=CN

### 工作流文件

#### `.github/workflows/build.yml` — APK 构建
1. Checkout 代码
2. 安装 Java 17 + Flutter
3. `flutter pub get`
4. `dart run build_runner build` 生成代码
5. 从 Secrets 解码 keystore，写入 `android/app/key.properties`
6. `flutter build apk --release`
7. 上传 APK artifact

#### `.github/workflows/mirror-cnb.yml` — CNB 镜像
Push 到 main 后自动推送至 `cnb.cool/Lingqi_Team/Tianxuan.git`。
需配置 Secrets: `CNB_USERNAME`, `CNB_TOKEN`。

### 触发条件
- Push 到 `main` 或 `master` 分支
- Pull Request 到 `main` 或 `master` 分支
- 手动触发（workflow_dispatch）

### 未配置 Secrets 时的回退
若签名 Secrets 未配置，Gradle 回退到 debug 签名，构建仍能完成（产出 debug-signed APK）。

---

## 本地构建

```bash
# 生成代码
dart run build_runner build --delete-conflicting-outputs

# Debug APK
flutter build apk --debug

# Release APK（需要在 android/app/key.properties 配置签名信息）
flutter build apk --release
```

### 本地 key.properties 模板

创建 `android/app/key.properties`（该文件已 gitignore）：

```properties
storeFile=tianxuan.keystore
storePassword=<从管理员获取>
keyAlias=tianxuan
keyPassword=<从管理员获取>
```

---

## 更新签名密钥

```bash
keytool -genkey -v -keystore android/app/tianxuan.keystore -alias tianxuan \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass <新密码> -keypass <新密码> \
  -dname "CN=Tianxuan, OU=Dev, O=Tianxuan, L=Shenzhen, ST=Guangdong, C=CN"

# 更新 GitHub Secrets
base64 -w0 android/app/tianxuan.keystore | gh secret set KEYSTORE_BASE64 -R CHINAYYDSNB/Tianxuan
gh secret set KEYSTORE_PASSWORD -R CHINAYYDSNB/Tianxuan -b '<新密码>'
gh secret set KEY_PASSWORD -R CHINAYYDSNB/Tianxuan -b '<新密码>'
```
